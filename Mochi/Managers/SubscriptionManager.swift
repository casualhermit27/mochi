import SwiftUI
import RevenueCat
import StoreKit
import Combine

// MARK: - Subscription Manager (RevenueCat)

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // RevenueCat Configuration
    private static let apiKey = "appl_IzgFGpKnIBDJhCTKGzmyryLRegh"
    private static let entitlementID = "Mochi +"
    
    private var delegate: RevenueCatDelegate?
    
    // MARK: - Published State
    
    /// Whether the user has active Mochi+ access (paid, trial, or lifetime)
    @Published var isPro: Bool = false
    
    /// Current RevenueCat offering for the paywall
    @Published var currentOffering: Offering?
    
    /// Whether the user has full access (paid subscription OR within 3-day soft trial)
    var isFullAccess: Bool {
        return isPro || SettingsManager.shared.daysSinceFirstUse < 3
    }
    
    /// Whether the user is in the 3-day soft trial period
    var isSoftTrial: Bool {
        return !isPro && SettingsManager.shared.daysSinceFirstUse < 3
    }
    
    /// Whether the user is on a free trial (subset of isPro)
    @Published var isOnTrial: Bool = false
    
    /// Days remaining in trial (0 if not on trial)
    @Published var trialDaysRemaining: Int = 0
    
    // MARK: - UI Presentation
    
    @Published var showPaywall: Bool = false
    @Published var showCustomerCenter: Bool = false
    
    // MARK: - Debug
    
    @Published var offeringsDebugInfo: String = "Initializing..."
    @Published var offeringsError: String?
    
    // MARK: - Init
    
    private init() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
        
        // Use separate delegate to avoid NSObject conflict
        let delegate = RevenueCatDelegate()
        self.delegate = delegate
        delegate.manager = self
        Purchases.shared.delegate = delegate
        
        // Initial status check
        Task {
            await checkSubscriptionStatus()
            await fetchOfferings()
        }
    }
    
    // MARK: - Check Subscription Status
    
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateStatus(from: customerInfo)
        } catch {
            print("❌ Failed to get customer info: \(error)")
        }
    }
    
    func updateStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[Self.entitlementID]
        let isActive = entitlement?.isActive == true
        
        // Single source of truth: entitlement active = premium
        self.isPro = isActive
        
        // Detect trial state (for optional UI badge, NOT for gating)
        if isActive, let entitlement = entitlement {
            if entitlement.periodType == .trial {
                self.isOnTrial = true
                if let expiration = entitlement.expirationDate {
                    let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                    self.trialDaysRemaining = max(0, days)
                }
            } else {
                self.isOnTrial = false
                self.trialDaysRemaining = 0
            }
        } else {
            self.isOnTrial = false
            self.trialDaysRemaining = 0
        }
    }
    
    // MARK: - Fetch Offerings
    
    func fetchOfferings() async {
        offeringsError = nil
        offeringsDebugInfo = "Fetching..."
        
        do {
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current
            
            var debug = "Offerings Source: RevenueCat\n"
            if let current = offerings.current {
                debug += "Current Offering: \(current.identifier)\n"
                debug += "Packages: \(current.availablePackages.count)\n"
                for pkg in current.availablePackages {
                    debug += "- \(pkg.identifier): \(pkg.storeProduct.productIdentifier) (\(pkg.localizedPriceString))\n"
                }
            } else {
                debug += "Current Offering: None (Check RC Dashboard)\n"
            }
            
            if !offerings.all.isEmpty {
                debug += "\nAvailable Offerings:\n"
                for (key, off) in offerings.all {
                    debug += "- \(key): \(off.availablePackages.count) pkgs\n"
                }
            } else {
                debug += "\nNo Offerings Found.\n"
            }
            
            self.offeringsDebugInfo = debug
            
            if self.currentOffering == nil || self.currentOffering?.availablePackages.isEmpty == true {
                self.offeringsError = "No products found.\n\nCheck Debug Info below."
            }
        } catch {
            self.offeringsDebugInfo = "Error: \(error.localizedDescription)"
            self.offeringsError = error.localizedDescription
            
            Task {
                await verifyStoreKitConfiguration()
            }
        }
    }
    
    // MARK: - Diagnostic
    
    func verifyStoreKitConfiguration() async {
        let commonIds = ["com.mochi.plus.lifetime", "com.mochi.plus.monthly", "com.mochi.plus.annual"]
        
        do {
            let products = try await Product.products(for: commonIds)
            var debug = "\n[StoreKit Direct Check]\n"
            if products.isEmpty {
                debug += "⚠️ StoreKit returned 0 products.\n"
                debug += "Config file is NOT loaded or IDs don't match.\n"
            } else {
                debug += "✅ StoreKit found \(products.count) products:\n"
                for p in products {
                    debug += "- \(p.id): \(p.displayPrice)\n"
                }
                debug += "-> Issue is likely RevenueCat Mismatch.\n"
            }
            self.offeringsDebugInfo += debug
        } catch {
            self.offeringsDebugInfo += "\n[StoreKit Check Failed]: \(error)"
        }
    }
    
    // MARK: - Purchase
    
    func purchase(package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            updateStatus(from: result.customerInfo)
            return !result.userCancelled
        } catch {
            print("❌ Purchase failed: \(error)")
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateStatus(from: customerInfo)
            return isPro
        } catch {
            print("❌ Restore failed: \(error)")
            return false
        }
    }
    
    // MARK: - Status Label (for Settings / About)
    
    var statusLabel: String {
        if isPro {
            if isOnTrial { return "Free Trial · \(trialDaysRemaining)d left" }
            return "Mochi+ Active"
        }
        
        let daysUsed = SettingsManager.shared.daysSinceFirstUse
        if daysUsed < 3 {
            let left = 3 - daysUsed
            return left == 0 ? "Trial Active · Last day!" : "Trial Active · \(left)d left"
        }
        
        return "Free"
    }
}

// MARK: - Private Delegate

private class RevenueCatDelegate: NSObject, PurchasesDelegate {
    weak var manager: SubscriptionManager?
    
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            manager?.updateStatus(from: customerInfo)
        }
    }
}
