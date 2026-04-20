import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @ObservedObject var settings = SettingsManager.shared
    
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    let isNightTime: Bool
    
    @State private var expandedCategories: Set<String> = []
    
    enum TimeFilter: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case yearly = "1Y"
        case lifetime = "All"
        case custom = "Custom"
        
        var limitDate: Date? {
            let cal = Calendar.current
            switch self {
            case .oneMonth: return cal.date(byAdding: .month, value: -1, to: Date())
            case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date())
            case .sixMonths: return cal.date(byAdding: .month, value: -6, to: Date())
            case .yearly: return cal.date(byAdding: .year, value: -1, to: Date())
            case .lifetime, .custom: return nil
            }
        }
    }
    
    @State private var selectedFilter: TimeFilter = .oneMonth
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEndDate: Date = Date()
    
    var filteredItems: [Item] {
        let activeItems = items.filter { settings.isItemInActiveCurrency($0) }
        
        if selectedFilter == .custom {
            let start = Calendar.current.startOfDay(for: customStartDate)
            let end = Calendar.current.startOfDay(for: customEndDate).addingTimeInterval(86399)
            return activeItems.filter { $0.timestamp >= start && $0.timestamp <= end }
        }
        
        guard let limit = selectedFilter.limitDate else { return activeItems }
        return activeItems.filter { $0.timestamp >= limit }
    }
    
    var categoryData: [(category: String, amount: Double)] {
        var totals: [String: Double] = [:]
        
        for item in filteredItems {
            let cat = item.category ?? "Other 📦"
            totals[cat, default: 0.0] += item.amount
        }
        
        return totals.map { (category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }
    
    // Total spent
    var totalSpent: Double {
        categoryData.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                dynamicBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Custom Header aligned to original Mochi theme
                    HStack {
                        Button(action: {
                            HapticManager.shared.softSquish()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(dynamicText)
                                .frame(width: 40, height: 40)
                                .background(dynamicText.opacity(0.04))
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(dynamicText.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .accessibilityIdentifier("stats_back_button")
                        
                        Spacer()
                        
                        Text("Insights")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        
                        Spacer()
                        
                        Color.clear.frame(width: 40, height: 40) // Balance
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    // Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimeFilter.allCases, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                    }
                                    HapticManager.shared.selection()
                                }) {
                                    Text(filter.rawValue)
                                        .font(.system(size: 14, weight: selectedFilter == filter ? .bold : .medium, design: .monospaced))
                                        .foregroundColor(selectedFilter == filter ? dynamicBackground : dynamicText.opacity(0.6))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? dynamicText : dynamicText.opacity(0.05))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, selectedFilter == .custom ? 12 : 24)
                    
                    if selectedFilter == .custom {
                        HStack(spacing: 8) {
                            Spacer()
                            DatePicker("", selection: $customStartDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(accentColor)
                                .colorScheme(isNightTime ? .dark : .light)
                            
                            Text("—")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.3))
                                
                            DatePicker("", selection: $customEndDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(accentColor)
                                .colorScheme(isNightTime ? .dark : .light)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    
                    if categoryData.isEmpty {
                        Spacer()
                        Image(systemName: "chart.bar")
                            .font(.system(size: 64, weight: .light))
                            .foregroundColor(dynamicText.opacity(0.2))
                        Text("No data yet.")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.5))
                            .padding(.top, 16)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 40) {
                                
                                // Chart Section
                                VStack(spacing: 32) {
                                    HStack(alignment: .bottom) {
                                        Text("Spending Flow")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(dynamicText.opacity(0.3))
                                        
                                        Spacer()
                                        
                                        Text("\(settings.currencySymbol)\(String(format: "%.0f", totalSpent))")
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    let chartColors = settings.currentPastelTheme.chartPalette
                                    SankeyChartView(data: categoryData, totalSpent: totalSpent, dynamicText: dynamicText, currencySymbol: settings.currencySymbol, colors: chartColors)
                                        .frame(height: 250)
                                        .padding(.horizontal, 24)
                                }
                                .padding(.top, 24)
                                
                                // Legend & Details Grid
                                VStack(spacing: 12) {
                                    let chartColors = settings.currentPastelTheme.chartPalette
                                    let categorizedItems = Dictionary(grouping: filteredItems, by: { $0.category ?? "Other 📦" })
                                    
                                    ForEach(Array(categoryData.enumerated()), id: \.element.category) { index, data in
                                        let categoryName = data.category
                                        let isExpanded = expandedCategories.contains(categoryName)
                                        
                                        VStack(spacing: 0) {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                    if isExpanded {
                                                        expandedCategories.remove(categoryName)
                                                    } else {
                                                        expandedCategories.insert(categoryName)
                                                    }
                                                }
                                                HapticManager.shared.selection()
                                            }) {
                                                HStack(spacing: 12) {
                                                    Capsule()
                                                        .fill(chartColors[index % chartColors.count])
                                                        .frame(width: 4, height: 16)
                                                    
                                                    Text(categoryName)
                                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                                        .foregroundColor(dynamicText)
                                                    
                                                    Spacer()
                                                    
                                                    let percentage = totalSpent == 0 ? 0 : (data.amount / totalSpent) * 100
                                                    Text("\(settings.currencySymbol)\(String(format: "%.2f", data.amount)) (\(String(format: "%.0f", percentage))%)")
                                                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                                                        .foregroundColor(dynamicText.opacity(0.6))
                                                        
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(dynamicText.opacity(0.3))
                                                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                                }
                                                .padding(.vertical, 16)
                                                .padding(.horizontal, 20)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            
                                            // Transactions Detail List
                                            if isExpanded {
                                                if let itemsForCategory = categorizedItems[categoryName] {
                                                    Divider().background(dynamicText.opacity(0.05))
                                                    
                                                    VStack(spacing: 0) {
                                                        ForEach(itemsForCategory.prefix(30)) { item in
                                                            HStack {
                                                                VStack(alignment: .leading, spacing: 4) {
                                                                    HStack(spacing: 8) {
                                                                        Text(item.timestamp, format: .dateTime.month().day().hour().minute())
                                                                            .font(.system(size: 12, design: .monospaced))
                                                                            .foregroundColor(dynamicText.opacity(0.5))
                                                                        
                                                                        if let methodId = item.paymentMethodId,
                                                                           let method = settings.getPaymentMethod(by: methodId) {
                                                                            CompactPaymentBadge(method: method, dynamicText: dynamicText)
                                                                        }
                                                                    }
                                                                    
                                                                    if let note = item.note, !note.isEmpty {
                                                                        Text(note)
                                                                            .font(.system(size: 12, design: .monospaced))
                                                                            .foregroundColor(dynamicText.opacity(0.8))
                                                                            .padding(.horizontal, 6)
                                                                            .padding(.vertical, 2)
                                                                            .background(dynamicText.opacity(0.04))
                                                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                                                    }
                                                                }
                                                                Spacer()
                                                                HStack(spacing: 2) {
                                                                    Text(settings.currencySymbol(for: item.currencyCode))
                                                                        .font(.system(size: 14))
                                                                        .foregroundColor(dynamicText.opacity(0.5))
                                                                    Text(item.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.amount) : String(format: "%.2f", item.amount))
                                                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                                                        .foregroundColor(dynamicText)
                                                                }
                                                            }
                                                            .padding(.vertical, 12)
                                                            .padding(.horizontal, 20)
                                                            
                                                            // Inner divider between rows
                                                            if item != itemsForCategory.last && item != itemsForCategory.prefix(30).last {
                                                                Divider()
                                                                    .background(dynamicText.opacity(0.03))
                                                                    .padding(.leading, 20)
                                                            }
                                                        }
                                                        .background(dynamicText.opacity(0.015)) // slight inset shadow effect feel
                                                    }
                                                }
                                            }
                                        }
                                        .background(dynamicText.opacity(0.03))
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
