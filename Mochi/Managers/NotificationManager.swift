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
            let content = UNMutableNotificationContent()
            content.title = "Mochi"
            content.body = "Here’s a calm look at today’s spending."
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
                let todayItems = items.filter { calendar.isDateInToday($0.timestamp) }
                dailyTotal = todayItems.reduce(0) { $0 + $1.amount }
                
                // Weekly
                if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) {
                     let weekItems = items.filter { weekInterval.contains($0.timestamp) }
                     let weekTotal = weekItems.reduce(0) { $0 + $1.amount }
                     weeklyAvg = weekTotal / 7.0
                }
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
            content.body = "Your average daily spend was \(symbol)\(formatAmount(weeklyAvg))."
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
    
    // MARK: - Reflection Trigger (UI)
    
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
                    
                    switch type {
                    case .daily:
                        // Real Daily Data
                        let todayItems = items.filter { calendar.isDateInToday($0.timestamp) }
                        let todayTotal = todayItems.reduce(0) { $0 + $1.amount }
                        
                        // Calculate Average (Last 30 active days)
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
                        // Real Weekly Data
                        // This week (Sunday/Monday to now)
                        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today)!
                        let weekItems = items.filter { weekInterval.contains($0.timestamp) }
                        let weekTotal = weekItems.reduce(0) { $0 + $1.amount }
                        let dailyAvg = weekTotal / 7.0 // Simple average over 7 days
                        
                        // Highest Day
                        let weekGrouped = Dictionary(grouping: weekItems) { calendar.component(.weekday, from: $0.timestamp) }
                        let maxDay = weekGrouped.max { a, b in
                            let sumA = a.value.reduce(0) { $0 + $1.amount }
                            let sumB = b.value.reduce(0) { $0 + $1.amount }
                            return sumA < sumB
                        }
                        
                        let weekdaySymbols = calendar.weekdaySymbols
                        let maxDayName = maxDay != nil ? weekdaySymbols[maxDay!.key - 1] : "None"
                        
                        let startFormatter = DateFormatter()
                        startFormatter.dateFormat = "MMM d"
                        let startStr = startFormatter.string(from: weekInterval.start)
                        
                        let endFormatter = DateFormatter()
                        let endDate = weekInterval.end.addingTimeInterval(-1)
                        // Smart formatting: if same month, show only day
                        if calendar.isDate(weekInterval.start, equalTo: endDate, toGranularity: .month) {
                            endFormatter.dateFormat = "d"
                        } else {
                            endFormatter.dateFormat = "MMM d"
                        }
                        let endStr = endFormatter.string(from: endDate)
                        
                        self.activeReflection = ReflectionData(
                            type: .weekly,
                            timeLabel: "This Week • \(startStr) – \(endStr)",
                            currencySymbol: symbol,
                            amount: self.formatAmount(dailyAvg), // "Daily Average" asked in mock
                            primaryText: "Daily Average",
                            secondaryText: "Highest spend: \(maxDayName)."
                        )
                    }
                }
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        // "rounded to nearest number"
        return String(format: "%.0f", amount)
    }
}
