import SwiftUI
import RevenueCat
import Combine

// MARK: - Subscription Manager (RevenueCat)

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // TODO: Replace with your RevenueCat API Key
    private static let apiKey = "appl_YOUR_REVENUECAT_API_KEY"
    
    // Entitlement ID (set in RevenueCat dashboard)
    private static let entitlementID = "pro"
    
    // Published state
    @Published var isPro: Bool = false
    @Published var isTrialActive: Bool = false
    @Published var trialDaysRemaining: Int = 0
    @Published var currentOffering: Offering?
    
    private init() {
        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
        
        // Check subscription status on launch
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    // MARK: - Check Subscription Status
    
    @MainActor
    func checkSubscriptionStatus() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateStatus(from: customerInfo)
        } catch {
            print("❌ Failed to get customer info: \(error)")
        }
    }
    
    private func updateStatus(from customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            // Check if user has "pro" entitlement
            let entitlement = customerInfo.entitlements[Self.entitlementID]
            self.isPro = entitlement?.isActive == true
            
            // Check trial status
            if let expirationDate = entitlement?.expirationDate,
               entitlement?.periodType == .trial {
                self.isTrialActive = true
                let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
                self.trialDaysRemaining = max(0, days)
            } else {
                self.isTrialActive = false
                self.trialDaysRemaining = 0
            }
        }
    }
    
    // MARK: - Feature Access
    
    var hasFullAccess: Bool { isPro }
    var canAccessHistory: Bool { isPro }
    var canAccessThemes: Bool { isPro }
    var canExport: Bool { isPro }
    var canUseWidget: Bool { isPro }
    
    // MARK: - Fetch Offerings
    
    @MainActor
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current
        } catch {
            print("❌ Failed to fetch offerings: \(error)")
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
            print("❌ Purchase failed: \(error)")
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
            print("❌ Restore failed: \(error)")
            return false
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
        price: "$30.99",
        period: "/year",
        badge: "BEST VALUE",
        savings: "Save 14%"
    )
    
    static let lifetime = SubscriptionPlan(
        id: "lifetime",
        name: "Lifetime",
        price: "$49.99",
        period: "once",
        badge: "FOREVER",
        savings: "Pay once, own forever"
    )
    
    static let all: [SubscriptionPlan] = [monthly, yearly, lifetime]
}

