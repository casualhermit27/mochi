import SwiftUI
import SwiftData

@main
struct MochiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        
        let appGroupID = "group.com.mochi.spent"
        let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)!
            .appendingPathComponent("Mochi.sqlite")
        
        // Migration logic: If data exists in the old default location, move it.
        let defaultURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("default.sqlite")
        
        if FileManager.default.fileExists(atPath: defaultURL.path) && !FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.moveItem(at: defaultURL, to: storeURL)
            // Also attempt to move the shm and wal files if they exist for a cleaner migration
            let shmOld = defaultURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let shmNew = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            try? FileManager.default.moveItem(at: shmOld, to: shmNew)
            
            let walOld = defaultURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let walNew = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? FileManager.default.moveItem(at: walOld, to: walNew)
        }

        // Use user's preference to determine if we sync to CloudKit
        let shouldSync = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: shouldSync ? .automatic : .none)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var body: some Scene {
        WindowGroup {
                ZStack {
                    MainContentView()
                        .onAppear {
                            NotificationManager.shared.setModelContainer(sharedModelContainer)
                        }
                        .sheet(isPresented: $subscriptionManager.showCustomerCenter) {
                            SubscriptionCustomerCenterView()
                        }
                        .sheet(isPresented: $subscriptionManager.showPaywall) {
                            PaywallView()
                                .presentationCornerRadius(32)
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
                        .onOpenURL { url in
                            print("Mochi opened with URL: \(url)")
                        }
                        .onChange(of: notificationManager.shouldDismissAllSheets) { _, shouldDismiss in
                            if shouldDismiss {
                                subscriptionManager.showCustomerCenter = false
                                subscriptionManager.showPaywall = false
                            }
                        }
                    
                    if !settings.hasCompletedOnboarding {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .zIndex(99)
                            .transition(.opacity)
                        
                        OnboardingView()
                            .zIndex(100)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
