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
        ChangelogItem(icon: "bolt.fill", title: "Speed Dial Payment Types", description: "You can now assign specific payment methods to your speed dial presets! Long press a number in Settings > Speed Dial to edit."),
        ChangelogItem(icon: "doc.viewfinder", title: "Receipt Scanning", description: "Effortlessly add transactions by scanning your receipts directly from the Keypad."),
        ChangelogItem(icon: "creditcard", title: "Payment Method Icons", description: "View exactly how you paid with visual indicators in your History view.")
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
