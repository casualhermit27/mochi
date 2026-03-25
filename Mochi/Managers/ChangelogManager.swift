import SwiftUI
import Combine

class ChangelogManager: ObservableObject {
    static let shared = ChangelogManager()
    
    private let versionKey = "mochi_lastSeenAppVersion_key"
    
    @Published var lastSeenAppVersion: String {
        didSet {
            UserDefaults.standard.set(lastSeenAppVersion, forKey: versionKey)
        }
    }
    
    @Published var showChangelog: Bool = false
    
    init() {
        self.lastSeenAppVersion = UserDefaults.standard.string(forKey: "mochi_lastSeenAppVersion_key") ?? ""
    }
    
    struct ChangelogItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let description: String
    }
    
    // The current changelog to show for the latest version
    let currentChangelog: [ChangelogItem] = [
        ChangelogItem(icon: "square.grid.2x2.fill", title: "Lavender Widget", description: "The purple theme now extends to your home screen widget. Set your theme to Lavender and your widget matches."),
        ChangelogItem(icon: "checkmark.seal.fill", title: "Free Trial Fixed", description: "New users now correctly see the 3-day free trial offer. Everything is unlocked during your trial — no strings attached."),
        ChangelogItem(icon: "wrench.and.screwdriver.fill", title: "Bug Fixes & Improvements", description: "Squashed several under-the-hood bugs and improved stability across the app.")
    ]
    
    func checkVersion() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        if lastSeenAppVersion.isEmpty {
            // First time this specific feature is running.
            // If they have completed onboarding, they are an existing user updating to this version! Show them the changelog.
            // If they haven't completed onboarding, they are a brand new user. Don't spam them with what's new on a fresh install.
            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            
            if hasCompletedOnboarding {
                showChangelog = true
            } else {
                lastSeenAppVersion = currentVersion
            }
        } else if lastSeenAppVersion != currentVersion {
            // Normal update flow for subsequent future updates
            showChangelog = true
        }
    }
    
    func markAsSeen() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        lastSeenAppVersion = currentVersion
        showChangelog = false
    }
}
