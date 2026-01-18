import Foundation
import SwiftUI

// MARK: - Widget Data Manager
// Handles data sharing between the main app and widgets via App Groups

class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // App Group identifier - Update this with your actual App Group ID
    private let appGroupID = "group.com.mochi.spent"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
    
    // MARK: - Keys
    private let todayTotalKey = "widget_today_total"
    private let yesterdayTotalKey = "widget_yesterday_total"
    private let lastTransactionKey = "widget_last_transaction"
    private let lastTransactionNoteKey = "widget_last_transaction_note"
    private let lastUpdateKey = "widget_last_update"
    private let currencySymbolKey = "widget_currency_symbol"
    private let colorThemeKey = "widget_color_theme"
    private let themeModeKey = "widget_theme_mode"
    
    // MARK: - Save Data (Called from main app)
    
    func updateWidgetData(
        todayTotal: Double,
        yesterdayTotal: Double,
        lastTransaction: Double?,
        lastTransactionNote: String?,
        currencySymbol: String,
        colorTheme: String,
        themeMode: String
    ) {
        sharedDefaults?.set(todayTotal, forKey: todayTotalKey)
        sharedDefaults?.set(yesterdayTotal, forKey: yesterdayTotalKey)
        
        if let lastTransaction = lastTransaction {
            sharedDefaults?.set(lastTransaction, forKey: lastTransactionKey)
        }
        
        if let lastTransactionNote = lastTransactionNote {
            sharedDefaults?.set(lastTransactionNote, forKey: lastTransactionNoteKey)
        }
        
        sharedDefaults?.set(Date(), forKey: lastUpdateKey)
        sharedDefaults?.set(currencySymbol, forKey: currencySymbolKey)
        sharedDefaults?.set(colorTheme, forKey: colorThemeKey)
        sharedDefaults?.set(themeMode, forKey: themeModeKey)
    }
    
    // MARK: - Read Data (Called from widget)
    
    var todayTotal: Double {
        sharedDefaults?.double(forKey: todayTotalKey) ?? 0
    }
    
    var yesterdayTotal: Double {
        sharedDefaults?.double(forKey: yesterdayTotalKey) ?? 0
    }
    
    var lastTransaction: Double {
        sharedDefaults?.double(forKey: lastTransactionKey) ?? 0
    }
    
    var lastTransactionNote: String {
        sharedDefaults?.string(forKey: lastTransactionNoteKey) ?? ""
    }
    
    var lastUpdate: Date? {
        sharedDefaults?.object(forKey: lastUpdateKey) as? Date
    }

    var currencySymbol: String {
        sharedDefaults?.string(forKey: currencySymbolKey) ?? "$"
    }

    var colorTheme: String {
        sharedDefaults?.string(forKey: colorThemeKey) ?? "default"
    }

    var themeMode: String {
        sharedDefaults?.string(forKey: themeModeKey) ?? "auto"
    }
    
    // MARK: - Widget Theme Colors
    
    struct WidgetTheme {
        let background: Color
        let text: Color
        let accent: Color
        
        static func forTheme(_ themeId: String, themeMode: String, systemIsDark: Bool) -> WidgetTheme {
            // Determine effective dark mode
            let isDark: Bool
            let isOled: Bool
            
            switch themeMode {
            case "dark":
                isDark = true
                isOled = false
            case "amoled", "oled":
                isDark = true
                isOled = true
            case "light":
                isDark = false
                isOled = false
            default: // "auto"
                isDark = systemIsDark
                isOled = false
            }
            
            // Helper to get OLED background if needed
            let darkBg = isOled ? Color.black : nil
            
            switch themeId {
            case "pink":
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.18, green: 0.12, blue: 0.14)) : Color(red: 1.0, green: 0.94, blue: 0.95),
                    text: isDark ? Color(red: 1.0, green: 0.85, blue: 0.88) : Color(red: 0.55, green: 0.25, blue: 0.32),
                    accent: Color(red: 0.85, green: 0.45, blue: 0.55)
                )
            case "blue":
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.10, green: 0.14, blue: 0.20)) : Color(red: 0.93, green: 0.96, blue: 1.0),
                    text: isDark ? Color(red: 0.82, green: 0.90, blue: 1.0) : Color(red: 0.20, green: 0.35, blue: 0.55),
                    accent: Color(red: 0.40, green: 0.60, blue: 0.85)
                )
            case "green":
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.08, green: 0.16, blue: 0.12)) : Color(red: 0.92, green: 0.98, blue: 0.95),
                    text: isDark ? Color(red: 0.78, green: 0.95, blue: 0.88) : Color(red: 0.18, green: 0.42, blue: 0.32),
                    accent: Color(red: 0.35, green: 0.70, blue: 0.55)
                )
            case "butterscotch":
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.18, green: 0.14, blue: 0.08)) : Color(red: 1.0, green: 0.97, blue: 0.90),
                    text: isDark ? Color(red: 1.0, green: 0.92, blue: 0.75) : Color(red: 0.50, green: 0.38, blue: 0.20),
                    accent: Color(red: 0.90, green: 0.70, blue: 0.35)
                )
            case "brown":
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.14, green: 0.11, blue: 0.09)) : Color(red: 0.97, green: 0.95, blue: 0.92),
                    text: isDark ? Color(red: 0.92, green: 0.88, blue: 0.82) : Color(red: 0.35, green: 0.28, blue: 0.22),
                    accent: Color(red: 0.60, green: 0.45, blue: 0.35)
                )
            default:
                // Default theme
                return WidgetTheme(
                    background: isDark ? (darkBg ?? Color(red: 0.11, green: 0.11, blue: 0.12)) : Color(red: 0.98, green: 0.97, blue: 0.95),
                    text: isDark ? Color.white : Color(red: 0.2, green: 0.2, blue: 0.2),
                    accent: Color(red: 0.35, green: 0.65, blue: 0.55)
                )
            }
        }
    }
    
    func getWidgetTheme(isDark: Bool) -> WidgetTheme {
        // Check if user has enabled theme matching for widget
        let matchTheme = sharedDefaults?.bool(forKey: "widget_match_theme") ?? true
        
        if !matchTheme {
            // Force default theme if matching is disabled
            return WidgetTheme.forTheme("default", themeMode: themeMode, systemIsDark: isDark)
        }
        
        return WidgetTheme.forTheme(colorTheme, themeMode: themeMode, systemIsDark: isDark)
    }
}
