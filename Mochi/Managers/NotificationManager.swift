import UserNotifications
import SwiftUI
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
                self.scheduleDailyNotification()
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleDailyNotification() {
        let settings = SettingsManager.shared
        guard settings.dailyNotificationEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Mochi Spent"
        content.body = "Wrap up your day! Check your total spending."
        content.sound = .default
        
        // Calculate Trigger Date
        // We use the stored notificationTime (seconds from midnight)
        let totalSeconds = Int(settings.notificationTime)
        let hour = totalSeconds / 3600
        let minute = (totalSeconds % 3600) / 60
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(identifier: "daily_summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled for \(hour):\(minute)")
            }
        }
    }
}
