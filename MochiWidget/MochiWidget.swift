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
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        // Fetch real data for snapshot or use dummy data
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        // The widget just needs to update when the main app tells it to relad, 
        // or periodically to keep the "Yesterday" date accurate.
        // We'll update every 15 minutes roughly.
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
        
        let entry = SimpleEntry(date: currentDate, configuration: configuration)
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }
}

// Data model for the widget
struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

// Data model for the widget
struct MochiWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    // Read data from Shared UserDefaults
    var dataManager = WidgetDataManager.shared
    
    var todayTotal: Double {
        dataManager.todayTotal
    }
    
    var yesterdayTotal: Double {
        dataManager.yesterdayTotal
    }
    
    var lastTransaction: Double {
        dataManager.lastTransaction
    }
    
    var lastTransactionNote: String {
        dataManager.lastTransactionNote
    }
    
    var currencySymbol: String {
        dataManager.currencySymbol
    }
    
    // Date Formatter
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // e.g. "JAN 18"
        return formatter.string(from: Date()).uppercased()
    }
    
    // Theme Colors
    var theme: WidgetDataManager.WidgetTheme {
        dataManager.getWidgetTheme(isDark: colorScheme == .dark)
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
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 1) {
                        Text(currencySymbol)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        // Use abbreviated number here always for space
                        Text(formatAmount(todayTotal))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .minimumScaleFactor(0.8)
                }
                Spacer()
            }
            .containerBackground(for: .widget) {
                 // System provides background
                 Color.clear
            }
            
        default:
            // Home Screen Widgets
            ZStack {
                // Background
                theme.background
                
                // Top Left: Date (Month + Day)
                HStack(spacing: 4) {
                    Text(Date().formatted(.dateTime.month()).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.text.opacity(0.6))
                    
                    Text(Date().formatted(.dateTime.day()))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.text)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(16)
                
                // Top Right: Last Transaction
                VStack(alignment: .trailing, spacing: 2) {
                    if lastTransaction != 0 {
                        Text(lastTransactionNote.isEmpty ? "LAST" : lastTransactionNote.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.text.opacity(0.5))
                            .lineLimit(1)
                        
                        let sign = lastTransaction > 0 ? "+" : "-"
                        let absAmount = abs(lastTransaction)
                        
                        HStack(spacing: 2) {
                            Text("\(sign) \(currencySymbol)")
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
                    Text("TODAY")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(theme.text.opacity(0.5))
                        .padding(.bottom, 2)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(currencySymbol)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.text.opacity(0.5))
                            .padding(.trailing, 2)
                        
                        Text(formatAmount(todayTotal))
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
    
    @Environment(\.widgetFamily) var family
    
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
    SimpleEntry(date: .now, configuration: .smiley)
}
