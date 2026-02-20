import UserNotifications
import SwiftUI
import Combine
import SwiftData

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    
    @Published var activeReflection: ReflectionData?
    @Published var shouldDismissAllSheets = false
    @Published var shouldOpenHistory = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permission
    
    func requestPermission(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    #if DEBUG
                    print("Notification permission granted")
                    #endif
                    self.scheduleNotifications()
                } else if let error {
                    #if DEBUG
                    print("Notification permission error: \(error.localizedDescription)")
                    #endif
                }
                completion?(granted)
            }
        }
    }
    
    // MARK: - Foreground display
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Notification tap handling
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let typeStr = userInfo["type"] as? String
        
        DispatchQueue.main.async {
            switch typeStr {
            case "daily_summary":
                self.triggerReflection(type: .daily)
            case "weekly_summary":
                self.triggerReflection(type: .weekly)
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Scheduling
    
    @MainActor
    func scheduleNotifications() {
        let settings = SettingsManager.shared
        let center = UNUserNotificationCenter.current()
        
        // Remove existing
        center.removePendingNotificationRequests(withIdentifiers: ["daily_summary_recurring", "weekly_summary_recurring"])
        
        let totalSeconds = Int(settings.notificationTime)
        let hour = totalSeconds / 3600
        let minute = (totalSeconds % 3600) / 60
        
        // --- Daily Notification ---
        if settings.dailyNotificationEnabled {
            let symbol = settings.currencySymbol
            let dailyTotal = getDailyTotal()
            
            let content = UNMutableNotificationContent()
            content.title = "Mochi"
            
            if dailyTotal > 0 {
                content.body = "You spent \(symbol)\(formatAmount(dailyTotal)) today. Tap to view."
            } else {
                content.body = "You haven't tracked any spending today. Tap to view."
            }
            
            content.sound = .default
            content.userInfo = ["type": "daily_summary"]
            
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_summary_recurring", content: content, trigger: trigger)
            
            center.add(request) { error in
                #if DEBUG
                if let error { print("Error scheduling daily: \(error)") }
                #endif
            }
        }
        
        // --- Weekly Notification ---
        if settings.weeklyNotificationEnabled {
            let content = UNMutableNotificationContent()
            content.title = "Weekly Reflection"
            content.body = "Tap to view your spending insights for this week."
            content.sound = .default
            content.userInfo = ["type": "weekly_summary"]
            
            var components = DateComponents()
            components.weekday = settings.weeklyNotificationWeekday
            components.hour = hour
            components.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "weekly_summary_recurring", content: content, trigger: trigger)
            
            center.add(request) { error in
                #if DEBUG
                if let error { print("Error scheduling weekly: \(error)") }
                #endif
            }
        }
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification(type: ReflectionData.ReflectionType) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized:
                    self.fireTestNotification(type: type)
                case .notDetermined:
                    self.requestPermission { granted in
                        if granted {
                            self.fireTestNotification(type: type)
                        }
                    }
                default:
                    #if DEBUG
                    print("Notification permission denied or restricted.")
                    #endif
                }
            }
        }
    }
    
    @MainActor
    private func fireTestNotification(type: ReflectionData.ReflectionType) {
        let symbol = SettingsManager.shared.currencySymbol
        
        // Fetch Real Data for Notification Text
        var dailyTotal: Double = 0
        var weeklyAvg: Double = 0
        
        if let container = modelContainer {
            let context = container.mainContext
            let descriptor = FetchDescriptor<Item>()
            if let items = try? context.fetch(descriptor) {
                let calendar = Calendar.current
                let today = Date()
                
                // Daily
                let settings = SettingsManager.shared
                let currentRitual = settings.getRitualDay(for: today)
                let todayItems = items.filter { settings.getRitualDay(for: $0.timestamp) == currentRitual }
                dailyTotal = todayItems.reduce(0) { $0 + $1.amount }
                
                // Weekly: Ritual-aware sliding 7-day window
                let currentRitualDay = currentRitual // Reuse daily ritual day calculation
                let startOfWindow = calendar.date(byAdding: .day, value: -6, to: currentRitualDay)!
                
                let weekItems = items.filter { item in
                    let ritual = settings.getRitualDay(for: item.timestamp)
                    return ritual >= startOfWindow && ritual <= currentRitualDay
                }
                let weekTotal = weekItems.reduce(0) { $0 + $1.amount }
                weeklyAvg = weekTotal
            }
        }
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        switch type {
        case .daily:
            content.title = "Today"
            content.body = "You spent \(symbol)\(formatAmount(dailyTotal)) today."
            content.userInfo = ["type": "daily_summary"]
            
        case .weekly:
            content.title = "This Week"
            content.body = "You spent \(symbol)\(formatAmount(weeklyAvg)) this week." // Using Total
            content.userInfo = ["type": "weekly_summary"]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 2,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                #if DEBUG
                print("Error adding test notification: \(error.localizedDescription)")
                #endif
            } else {
                #if DEBUG
                print("Test notification scheduled.")
                #endif
            }
        }
    }
    
    var modelContainer: ModelContainer?
    
    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
    }
    
    @MainActor
    func triggerReflection(type: ReflectionData.ReflectionType) {
        let symbol = SettingsManager.shared.currencySymbol
        guard let container = modelContainer else {
            print("ModelContainer not set for NotificationManager")
            return
        }
        
        let context = container.mainContext
        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let items = (try? context.fetch(descriptor)) ?? []
        
        // Calculate Data
        let calendar = Calendar.current
        let today = Date()
        
        DispatchQueue.main.async {
            self.shouldDismissAllSheets = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.shouldDismissAllSheets = false
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                    
                    let startFormatter = DateFormatter()
                    startFormatter.dateFormat = "MMM d"
                    
                    let endFormatter = DateFormatter()
                    endFormatter.dateFormat = "MMM d"
                    
                    switch type {
                    case .daily:
                        // Real Daily Data (Ritual Aware)
                        let settings = SettingsManager.shared
                        let currentRitual = settings.getRitualDay(for: today)
                        let todayItems = items.filter { settings.getRitualDay(for: $0.timestamp) == currentRitual }
                        let todayTotal = todayItems.reduce(0) { $0 + $1.amount }
                        
                        let grouped = Dictionary(grouping: items) { calendar.startOfDay(for: $0.timestamp) }
                        let recentDays = grouped.keys.sorted(by: >).prefix(30)
                        let totalSpend = recentDays.reduce(0) { sum, date in sum + (grouped[date]?.reduce(0) { $0 + $1.amount } ?? 0) }
                        let average = recentDays.isEmpty ? 0 : totalSpend / Double(recentDays.count)
                        
                        let comparisonText: String
                        if todayTotal > average * 1.1 {
                            comparisonText = "Above your daily average."
                        } else if todayTotal < average * 0.9 {
                            comparisonText = "Below your daily average."
                        } else {
                            comparisonText = "On track with average."
                        }
                        
                        let dateString = today.formatted(.dateTime.month().day())
                        
                        self.activeReflection = ReflectionData(
                            type: .daily,
                            timeLabel: "Today • \(dateString)",
                            currencySymbol: symbol,
                            amount: self.formatAmount(todayTotal),
                            primaryText: "You spent",
                            secondaryText: comparisonText
                        )
                        
                    case .weekly:
                        // Ritual-Aware Weekly Data: Last 7 days including today
                        let settings = SettingsManager.shared
                        let currentRitualDay = settings.getRitualDay(for: today)
                        let startOfWindow = calendar.date(byAdding: .day, value: -6, to: currentRitualDay)!
                        
                        let weekItems = items.filter { item in
                            let ritual = settings.getRitualDay(for: item.timestamp)
                            return ritual >= startOfWindow && ritual <= currentRitualDay
                        }
                        
                        let weekTotal = weekItems.reduce(0) { $0 + $1.amount }
                        let dailyAvg = weekTotal / 7.0
                        
                        let startStr = startFormatter.string(from: startOfWindow)
                        let endStr = endFormatter.string(from: today)
                        
                        self.activeReflection = ReflectionData(
                            type: .weekly,
                            timeLabel: "Last 7 Days • \(startStr) – \(endStr)",
                            currencySymbol: symbol,
                            amount: self.formatAmount(weekTotal),
                            primaryText: "You spent",
                            secondaryText: "Daily Average: \(symbol)\(self.formatAmount(dailyAvg))"
                        )
                    }
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.2f", amount)
        }
    }
    
    @MainActor
    private func getDailyTotal() -> Double {
        guard let container = modelContainer else { return 0 }
        let context = container.mainContext
        let descriptor = FetchDescriptor<Item>()
        
        let items = (try? context.fetch(descriptor)) ?? []
        let settings = SettingsManager.shared
        let currentRitualDay = settings.getRitualDay(for: Date())
        
        let todayItems = items.filter { settings.getRitualDay(for: $0.timestamp) == currentRitualDay }
        return todayItems.reduce(0) { $0 + $1.amount }
    }
}
