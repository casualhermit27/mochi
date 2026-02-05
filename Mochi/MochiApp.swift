import SwiftUI
import SwiftData

@main
struct MochiApp: App {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .onAppear {
                    NotificationManager.shared.setModelContainer(sharedModelContainer)
                }
                .sheet(isPresented: $subscriptionManager.showCustomerCenter) {
                    SubscriptionCustomerCenterView()
                }
                .sheet(isPresented: $subscriptionManager.showPaywall) {
                    PaywallView()
                }
                .sheet(isPresented: .init(
                    get: { !settings.hasCompletedOnboarding },
                    set: { if !$0 { settings.hasCompletedOnboarding = true } }
                )) {
                    OnboardingView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.hidden)
                        .presentationCornerRadius(32)
                        .interactiveDismissDisabled()
                }
                .fullScreenCover(item: $notificationManager.activeReflection) { data in
                    ReflectionView(
                        data: data,
                        onDismiss: {
                            notificationManager.activeReflection = nil
                        },
                        onViewHistory: {
                            notificationManager.activeReflection = nil
                            // Trigger history on main screen
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                notificationManager.shouldOpenHistory = true
                            }
                        }
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - RevenueCat Customer Center Wrapper
import RevenueCatUI

struct SubscriptionCustomerCenterView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        CustomerCenterView()
    }
}
