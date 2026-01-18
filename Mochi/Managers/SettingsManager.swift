import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @AppStorage("isDarkModeOverride") var isDarkModeOverride: Bool = false // We need a way to represent 'auto', but AppStorage bool is true/false. 
    // Actually, to support 'System' vs 'Dark' vs 'Light', we need an Int or String.
    // simpler: Let's stick to the current logic but persist it? 
    // The previous implementation used @State private var isDarkModeOverride: Bool? = nil
    // AppStorage doesn't support Optional Bool easily. 
    // Let's use a String: "auto", "light", "dark".
    
    @AppStorage("themeMode") var themeMode: String = "auto"
    @AppStorage("colorTheme") var colorTheme: String = "default" // default, pink, blue, green, butterscotch, brown
    @AppStorage("customCurrencyCode") var customCurrencyCode: String = "" // Stores ISO code (e.g. "USD", "KRW")
    @AppStorage("widgetMatchTheme") var widgetMatchTheme: Bool = true // Should widget match app theme?
    
    // Day Settings
    @AppStorage("dayStartHour") var dayStartHour: Int = 0 // 0 = Midnight
    @AppStorage("dayStartMinute") var dayStartMinute: Int = 0
    
    // Helper to bind Day Start to Date (for DatePicker)
    var dayStartDate: Date {
        get {
            let now = Date()
            let calendar = Calendar.current
            // Create a date for today at the stored hour:minute
            return calendar.date(bySettingHour: dayStartHour, minute: dayStartMinute, second: 0, of: now) ?? now
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            dayStartHour = components.hour ?? 0
            dayStartMinute = components.minute ?? 0
        }
    }
    
    // Notification Settings
    @AppStorage("dailyNotificationEnabled") var dailyNotificationEnabled: Bool = false
    @AppStorage("notificationTime") var notificationTime: Double = 21 * 3600 // Default 9 PM
    
    // Haptics & Sounds
    @AppStorage("hapticsEnabled") var hapticsEnabled: Bool = true
    @AppStorage("soundsEnabled") var soundsEnabled: Bool = true
    
    // MARK: - Pastel Theme Colors
    
    struct PastelTheme: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: String
        let background: Color
        let backgroundDark: Color
        let accent: Color
        let text: Color
        let textDark: Color
        
        static let defaultTheme = PastelTheme(
            id: "default",
            name: "Default",
            icon: "circle.lefthalf.filled",
            background: Color(UIColor.systemBackground),
            backgroundDark: Color(UIColor.systemBackground),
            accent: Color(red: 0.35, green: 0.65, blue: 0.55),
            text: Color.primary,
            textDark: Color.primary
        )
        
        static let pink = PastelTheme(
            id: "pink",
            name: "Rose",
            icon: "heart.fill",
            background: Color(red: 1.0, green: 0.94, blue: 0.95),       // Light pink
            backgroundDark: Color(red: 0.18, green: 0.12, blue: 0.14),  // Dark pink-brown
            accent: Color(red: 0.85, green: 0.45, blue: 0.55),          // Dusty rose
            text: Color(red: 0.55, green: 0.25, blue: 0.32),            // Dark rose
            textDark: Color(red: 1.0, green: 0.85, blue: 0.88)          // Light rose
        )
        
        static let blue = PastelTheme(
            id: "blue",
            name: "Ocean",
            icon: "drop.fill",
            background: Color(red: 0.93, green: 0.96, blue: 1.0),       // Light blue
            backgroundDark: Color(red: 0.10, green: 0.14, blue: 0.20),  // Deep navy
            accent: Color(red: 0.40, green: 0.60, blue: 0.85),          // Soft blue
            text: Color(red: 0.20, green: 0.35, blue: 0.55),            // Dark blue
            textDark: Color(red: 0.82, green: 0.90, blue: 1.0)          // Light blue
        )
        
        static let green = PastelTheme(
            id: "green",
            name: "Mint",
            icon: "leaf.fill",
            background: Color(red: 0.92, green: 0.98, blue: 0.95),      // Light mint
            backgroundDark: Color(red: 0.08, green: 0.16, blue: 0.12),  // Deep forest
            accent: Color(red: 0.35, green: 0.70, blue: 0.55),          // Fresh mint
            text: Color(red: 0.18, green: 0.42, blue: 0.32),            // Dark green
            textDark: Color(red: 0.78, green: 0.95, blue: 0.88)         // Light mint
        )
        
        static let butterscotch = PastelTheme(
            id: "butterscotch",
            name: "Honey",
            icon: "sun.max.fill",
            background: Color(red: 1.0, green: 0.97, blue: 0.90),       // Warm cream
            backgroundDark: Color(red: 0.18, green: 0.14, blue: 0.08),  // Deep amber
            accent: Color(red: 0.90, green: 0.70, blue: 0.35),          // Golden honey
            text: Color(red: 0.50, green: 0.38, blue: 0.20),            // Dark amber
            textDark: Color(red: 1.0, green: 0.92, blue: 0.75)          // Light cream
        )
        
        static let brown = PastelTheme(
            id: "brown",
            name: "Mocha",
            icon: "cup.and.saucer.fill",
            background: Color(red: 0.97, green: 0.95, blue: 0.92),      // Light beige
            backgroundDark: Color(red: 0.14, green: 0.11, blue: 0.09),  // Deep espresso
            accent: Color(red: 0.60, green: 0.45, blue: 0.35),          // Warm mocha
            text: Color(red: 0.35, green: 0.28, blue: 0.22),            // Dark coffee
            textDark: Color(red: 0.92, green: 0.88, blue: 0.82)         // Light latte
        )
        
        static let all: [PastelTheme] = [defaultTheme, pink, blue, green, butterscotch, brown]
    }
    
    var currentPastelTheme: PastelTheme {
        PastelTheme.all.first { $0.id == colorTheme } ?? .defaultTheme
    }
    
    // Quick helper to bind Date to the double
    var notificationDate: Date {
        get {
            let now = Date()
            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: now)
            return midnight.addingTimeInterval(notificationTime)
        }
        set {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: newValue)
            let seconds = (Double(components.hour ?? 0) * 3600) + (Double(components.minute ?? 0) * 60)
            notificationTime = seconds
        }
    }
    
    var currencySymbol: String {
        if !customCurrencyCode.isEmpty {
            // Find the currency and return its symbol
            if let currency = SettingsManager.allAvailableCurrencies.first(where: { $0.code == customCurrencyCode }) {
                return currency.symbol
            }
        }
        return Locale.autoupdatingCurrent.currencySymbol ?? "$"
    }
    
    // Currency Model
    struct Currency: Hashable, Identifiable {
        let code: String
        let symbol: String
        let name: String
        var id: String { code }
    }
    
    // Cache of all available global currencies
    static let allAvailableCurrencies: [Currency] = {
        let codes = Locale.commonISOCurrencyCodes
        var result = [Currency]()
        
        // precise mapping for top currencies to avoid "US$" vs "$" confusion
        // we want the shortest/standard symbol
        var bestSymbols = [String: String]()
        
        // pre-fill with current locale's opinion if possible, or iterate identifiers
        for id in Locale.availableIdentifiers {
            let locale = Locale(identifier: id)
            guard let code = locale.currencyCode, let symbol = locale.currencySymbol else { continue }
            
            if let existing = bestSymbols[code] {
                // Heuristics for "better" symbol:
                // 1. Shorter is usually better ($ vs US$)
                // 2. If length same, prefer symbol that DOESN'T contain the code (AED vs AED) - actually no, sometimes code is best.
                // 3. For Arabic/Asian scripts, if the user is in English, we might prefer English.
                // But detecting language of symbol is hard.
                // Simple heuristic: Shortest.
                if symbol.count < existing.count {
                    bestSymbols[code] = symbol
                }
            } else {
                bestSymbols[code] = symbol
            }
        }
        
        for code in codes {
            let name = Locale.autoupdatingCurrent.localizedString(forCurrencyCode: code) ?? code
            let symbol = bestSymbols[code] ?? code
            result.append(Currency(code: code, symbol: symbol, name: name))
        }
        
        return result.sorted { $0.code < $1.code }
    }()
    func triggerSelectionHaptic() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Shared Logic
    
    /// Determines the "Ritual Day" for a given date based on usage settings (Start Hour/Minute).
    func getRitualDay(for date: Date) -> Date {
        let calendar = Calendar.current
        
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        // Convert to minutes from midnight
        let timeInMinutes = hour * 60 + minute
        let thresholdInMinutes = dayStartHour * 60 + dayStartMinute
        
        if timeInMinutes < thresholdInMinutes {
            // Belongs to previous day
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!)
        } else {
            // Belongs to today (or the day of the date)
            return calendar.startOfDay(for: date)
        }
    }
}
