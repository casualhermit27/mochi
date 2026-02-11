import SwiftUI
import RevenueCat
import Combine
import StoreKit

// MARK: - Subscription Manager (RevenueCat)

class SubscriptionManager: NSObject, ObservableObject {
    static let shared = SubscriptionManager()
    
    // RevenueCat Configuration
    private static let apiKey = "appl_IzgFGpKnIBDJhCTKGzmyryLRegh"
    private static let entitlementID = "Mochi +"
    
    // Published state
    @Published var isPro: Bool = false
    @Published var isTrialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var currentOffering: Offering?
    @Published var showCustomerCenter: Bool = false
    @Published var showPaywall: Bool = false
    
    // Debug Override
    @Published var debugForcedPro: Bool {
        didSet {
            UserDefaults.standard.set(debugForcedPro, forKey: "debug_forced_pro")
            checkSubscriptionStatusSync()
        }
    }
    
    // Local Trial State
    private let localTrialKey = "local_trial_end_date"
    var localTrialEndDate: Date? {
        get { UserDefaults.standard.object(forKey: localTrialKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: localTrialKey) }
    }
    
    override private init() {
        self.debugForcedPro = UserDefaults.standard.bool(forKey: "debug_forced_pro")
        super.init()
        
        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
        
        // Listen for customer info changes
        Purchases.shared.delegate = self
        
        // Initial status check
        Task {
            await checkSubscriptionStatus()
            await fetchOfferings()
        }
    }
    
    // MARK: - Check Subscription Status
    
    @MainActor
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateStatus(from: customerInfo)
        } catch {
            #if DEBUG
            print("❌ Failed to get customer info: \(error)")
            #endif
        }
    }
    
    private func checkSubscriptionStatusSync() {
        let entitlementActive = Purchases.shared.cachedCustomerInfo?.entitlements[Self.entitlementID]?.isActive == true
        let isLocalTrialValid = (localTrialEndDate ?? .distantPast) > Date()
        self.isPro = debugForcedPro || entitlementActive || isLocalTrialValid
    }
    
    @MainActor
    func updateStatus(from customerInfo: CustomerInfo) {
        // Check if user has "Mochi +" entitlement
        let entitlement = customerInfo.entitlements[Self.entitlementID]
        let entitlementActive = entitlement?.isActive == true
        let isLocalTrialValid = (localTrialEndDate ?? .distantPast) > Date()
        
        self.isPro = debugForcedPro || entitlementActive || isLocalTrialValid
        
        // Check trial status (StoreKit)
        if let expirationDate = entitlement?.expirationDate,
           entitlement?.periodType == .trial {
            self.isTrialActive = true
            let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
            self.trialDaysRemaining = max(0, days)
        } else if isLocalTrialValid {
            // Local trial is active
            self.isTrialActive = true
            let days = Calendar.current.dateComponents([.day], from: Date(), to: localTrialEndDate!).day ?? 0
            self.trialDaysRemaining = max(0, days)
        } else {
            self.isTrialActive = false
            self.trialDaysRemaining = 0
        }
    }
    
    func startLocalTrial() {
        // Start a 3-day trial from now
        let endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())
        localTrialEndDate = endDate
        Task { @MainActor in
            checkSubscriptionStatusSync()
        }
    }
    
    @Published var offeringsDebugInfo: String = "Initializing..."
    @Published var offeringsError: String?
    
    // MARK: - Fetch Offerings
    
    @MainActor
    func fetchOfferings() async {
        offeringsError = nil
        offeringsDebugInfo = "Fetching..."
        
        do {
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current
            
            // Build Debug Info
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
            
            // Fallback: Check StoreKit directly to diagnose
            Task {
                await verifyStoreKitConfiguration()
            }
            
            #if DEBUG
            print("❌ Failed to fetch offerings: \(error)")
            #endif
        }
    }
    
    // MARK: - Diagnostic
    
    @MainActor
    func verifyStoreKitConfiguration() async {
        // Check if StoreKit can see ANY of our products
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
    
    @MainActor
    func purchase(package: Package) async -> Bool {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            updateStatus(from: result.customerInfo)
            return !result.userCancelled
        } catch {
            #if DEBUG
            print("❌ Purchase failed: \(error)")
            #endif
            return false
        }
    }
    
    // MARK: - Restore Purchases
    
    @MainActor
    func restorePurchases() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateStatus(from: customerInfo)
            return isPro
        } catch {
            #if DEBUG
            print("❌ Restore failed: \(error)")
            #endif
            return false
        }
    }
}

// MARK: - Delegate Support
extension SubscriptionManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            updateStatus(from: customerInfo)
        }
    }
}

// MARK: - Subscription Plan Model

struct SubscriptionPlan: Identifiable {
    let id: String
    let name: String
    let price: String
    let period: String
    let badge: String?
    let savings: String?
    var package: Package?
    
    static let monthly = SubscriptionPlan(
        id: "monthly",
        name: "Monthly",
        price: "$2.99",
        period: "/month",
        badge: nil,
        savings: nil
    )
    
    static let yearly = SubscriptionPlan(
        id: "yearly",
        name: "Yearly",
        price: "$19.99",
        period: "/year",
        badge: "BEST DEAL",
        savings: "Save 44%"
    )
    
    static let lifetime = SubscriptionPlan(
        id: "lifetime",
        name: "Lifetime",
        price: "$39.99",
        period: "once",
        badge: "FOREVER",
        savings: "Pay once, own forever"
    )
    
    static let all: [SubscriptionPlan] = [monthly, yearly, lifetime]
}

