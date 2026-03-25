//
//  MochiWidget.swift
//  MochiWidget
//
//  Created by Harsha on 17/01/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            configuration: ConfigurationAppIntent(),
            todayTotal: 0,
            yesterdayTotal: 0,
            lastTransaction: 0,
            lastTransactionNote: "",
            currencySymbol: "$",
            isPro: false,
            colorTheme: "default",
            themeMode: "auto"
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let data = WidgetDataManager.shared
        return SimpleEntry(
            date: Date(),
            configuration: configuration,
            todayTotal: data.todayTotal,
            yesterdayTotal: data.yesterdayTotal,
            lastTransaction: data.lastTransaction,
            lastTransactionNote: data.lastTransactionNote,
            currencySymbol: data.currencySymbol,
            isPro: data.isPro,
            colorTheme: data.colorTheme,
            themeMode: data.themeMode
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let currentDate = Date()
        let data = WidgetDataManager.shared
        
        // Use a 15-minute heartbeat to keep things fresh
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        
        // This call to 'todayTotal' / 'yesterdayTotal' triggers 'checkAndResetStaleData'
        let todayVal = data.todayTotal
        let yesterdayVal = data.yesterdayTotal
        
        let entry = SimpleEntry(
            date: currentDate,
            configuration: configuration,
            todayTotal: todayVal,
            yesterdayTotal: yesterdayVal,
            lastTransaction: data.lastTransaction,
            lastTransactionNote: data.lastTransactionNote,
            currencySymbol: data.currencySymbol,
            isPro: data.isPro,
            colorTheme: data.colorTheme,
            themeMode: data.themeMode
        )
        
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

// Data model for the widget
struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    
    let todayTotal: Double
    let yesterdayTotal: Double
    let lastTransaction: Double
    let lastTransactionNote: String
    let currencySymbol: String
    let isPro: Bool
    let colorTheme: String
    let themeMode: String
}

struct MochiWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.widgetFamily) var family

    // Theme Colors
    var widgetLocale: Locale {
        let lang = WidgetDataManager.shared.appLanguage
        return lang == "system" ? Locale.autoupdatingCurrent : Locale(identifier: lang)
    }

    var theme: WidgetDataManager.WidgetTheme {
        WidgetDataManager.WidgetTheme.forTheme(
            entry.colorTheme,
            themeMode: entry.themeMode,
            systemIsDark: colorScheme == .dark
        )
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // Lock Screen Widget (Rectangular)
            HStack(spacing: 6) {
                // Divider line
                Rectangle()
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 2)
                    .clipShape(Capsule())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "TODAY", locale: widgetLocale))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 1) {
                        Text(entry.currencySymbol)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(formatAmount(entry.todayTotal))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .minimumScaleFactor(0.8)
                }
                Spacer()
            }
            .containerBackground(for: .widget) {
                 Color.clear
            }
            
        default:
            // Home Screen Widgets
            ZStack {
                // Background
                theme.background
                
                // Top Left: Date (Month + Day)
                HStack(spacing: 4) {
                    Text(entry.date.formatted(.dateTime.month().locale(widgetLocale)).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.text.opacity(0.6))
                    
                    Text(entry.date.formatted(.dateTime.day().locale(widgetLocale)))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
                
                // Top Right: Last Transaction
                VStack(alignment: .trailing, spacing: 2) {
                    if entry.lastTransaction != 0 {
                        Text(entry.lastTransactionNote.isEmpty ? String(localized: "LAST", locale: widgetLocale) : entry.lastTransactionNote.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.text.opacity(0.5))
                            .lineLimit(1)
                        
                        let sign = entry.lastTransaction > 0 ? "+" : "-"
                        let absAmount = abs(entry.lastTransaction)
                        
                        HStack(spacing: 2) {
                            Text("\(sign) \(entry.currencySymbol)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.text.opacity(0.5))
                            
                            Text(formatAmount(absAmount))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.text.opacity(0.9))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(16)
                
                // Bottom Left: Today Total
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(localized: "TODAY", locale: widgetLocale))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(theme.text.opacity(0.5))
                        .padding(.bottom, 2)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(entry.currencySymbol)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.text.opacity(0.5))
                            .padding(.trailing, 2)
                        
                        Text(formatAmount(entry.todayTotal))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.text)
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
            }
            .containerBackground(for: .widget) {
                theme.background
            }
        }
    }
    
    func formatAmount(_ amount: Double) -> String {
        // Abbreviate for small widgets (SystemSmall, LockScreen widgets) and large numbers (>= 1,000)
        let isSmallWidget = family == .systemSmall || family == .accessoryRectangular
        
        if isSmallWidget && abs(amount) >= 1000 {
            return abbreviateNumber(amount)
        }
        
        // Standard full format for larger widgets (SystemMedium, SystemLarge) or small numbers
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
    }
    
    func abbreviateNumber(_ amount: Double) -> String {
        let absAmount = abs(amount)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1 // 1.2M, 5.5K
        
        // Check for Indian Locale (Lakh/Crore)
        let locale = Locale.current
        // Simple check for IN region
        if locale.region?.identifier == "IN" || locale.identifier.contains("en_IN") {
             if absAmount >= 10_000_000 {
                let val = absAmount / 10_000_000
                return "\(formatCompact(val))Cr"
            } else if absAmount >= 100_000 {
                let val = absAmount / 100_000
                return "\(formatCompact(val))L"
            }
        }
        
        // Standard K/M/B
        if absAmount >= 1_000_000_000 {
            let val = absAmount / 1_000_000_000
            return "\(formatCompact(val))B"
        } else if absAmount >= 1_000_000 {
            let val = absAmount / 1_000_000
            return "\(formatCompact(val))M"
        } else if absAmount >= 1_000 {
            let val = absAmount / 1_000
            return "\(formatCompact(val))K"
        }
        
        // Fallback
        return "\(Int(absAmount))"
    }
    
    func formatCompact(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

struct MochiWidget: Widget {
    let kind: String = "MochiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            MochiWidgetEntryView(entry: entry)
                .environment(\.locale, WidgetDataManager.shared.appLanguage == "system" ? Locale.autoupdatingCurrent : Locale(identifier: WidgetDataManager.shared.appLanguage))
                .environment(\.layoutDirection, ["ar", "he", "fa", "ur"].contains(String((WidgetDataManager.shared.appLanguage == "system" ? Locale.autoupdatingCurrent.identifier : WidgetDataManager.shared.appLanguage).prefix(2))) ? .rightToLeft : .leftToRight)
        }
        .configurationDisplayName("Daily Spend")
        .description("Keep track of your daily expenses.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        // We can disable accent color content margins if we want full bleed background color easily
        .contentMarginsDisabled() 
    }
}

// Helper Extensions specific for this file/preview

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    MochiWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        configuration: .smiley,
        todayTotal: 222,
        yesterdayTotal: 100,
        lastTransaction: 222,
        lastTransactionNote: "Lunch",
        currencySymbol: "₹",
        isPro: true,
        colorTheme: "default",
        themeMode: "auto"
    )
}
