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
        ZStack {
            // Background
            theme.background
            
            VStack(alignment: .leading, spacing: 0) {
                // Header (Today + Date)
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(theme.text.opacity(0.6))
                    
                    Spacer()
                    
                    Text(dateString)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(theme.text.opacity(0.6))
                }
                .padding(.bottom, 12)
                
                // Main Amount (Center)
                Text("\(currencySymbol) \(formatAmount(todayTotal))")
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                
                Spacer()
                
                // Footer (Last Transaction)
                VStack(spacing: 6) {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(theme.text.opacity(0.1))
                    
                    HStack(spacing: 4) {
                        // Last Transaction
                        if lastTransaction > 0 {
                            Text(lastTransactionNote.isEmpty ? "LAST" : lastTransactionNote.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.text.opacity(0.5))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("+ \(currencySymbol)\(formatAmount(lastTransaction))")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.text)

                        } else {
                            Text("NO SPEND")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.text.opacity(0.5))
                            
                            Spacer()
                        }
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .containerBackground(for: .widget) {
            theme.background
        }
    }
    
    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0 // Keep it clean for widget
        return formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
