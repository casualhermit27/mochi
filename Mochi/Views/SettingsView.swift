import SwiftUI
import MessageUI
import SwiftData
import WidgetKit
import RevenueCatUI
import RevenueCat

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    
    // Theme Logic
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        if settings.themeMode == "auto" {
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour >= 20
        }
        return colorScheme == .dark
    }
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    // Adaptive Colors
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return isNightTime ? .white : .primary
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return isNightTime ? Color.mochiBlueDark : Color.mochiRose
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                dynamicBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        Spacer()
                        Button(action: { 
                            HapticManager.shared.softSquish()
                            dismiss() 
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(dynamicText.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(dynamicText.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityIdentifier("close_settings_button")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // 0. Membership Status
                            SettingsSection(icon: "sparkles", title: "MEMBERSHIP", textColor: dynamicText) {
                                Button(action: {
                                    HapticManager.shared.rigidImpact()
                                    if subscription.isPro {
                                        subscription.showCustomerCenter = true
                                    } else {
                                        subscription.showPaywall = true
                                    }
                                }) {
                                    MembershipCard()
                                }
                                .accessibilityIdentifier("membership_card")
                                .buttonStyle(.plain)
                            }
                            .padding(.bottom, 8)

                            // 1. Appearance
                            NavigationLink(destination: AppearanceSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "moon.stars.fill", title: "Appearance", value: settings.themeMode == "amoled" ? "OLED" : settings.themeMode.capitalized, dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("appearance_row")
                            .padding(.horizontal, 20)
                            
                            // 2. Logging
                            NavigationLink(destination: LoggingSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "pencil.line", title: "Logging", value: settings.currencySymbol, dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("logging_row")
                            .padding(.horizontal, 20)
                            
                            // 2.1 Speed Dial
                            NavigationLink(destination: SpeedDialSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground)) {
                                MenuRow(icon: "bolt.fill", title: "Speed Dial", value: "", dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("speed_dial_row")
                            .padding(.horizontal, 20)
                            
                            // 2.1 Data & Export
                            if subscription.isFullAccess {
                                NavigationLink(destination: ExportDataView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                    MenuRow(icon: "square.and.arrow.up.fill", title: "Data & Export", value: "CSV, PDF", dynamicText: dynamicText)
                                }
                                .accessibilityIdentifier("export_row")
                                .padding(.horizontal, 20)
                            } else {
                                Button(action: {
                                    HapticManager.shared.rigidImpact()
                                    subscription.showPaywall = true
                                }) {
                                    MenuRow(icon: "square.and.arrow.up.fill", title: "Data & Export", value: "CSV, PDF", dynamicText: dynamicText)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // 2.2 Cloud Sync
                            if subscription.isFullAccess {
                                NavigationLink(destination: CloudSyncSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                    MenuRow(icon: "icloud.fill", title: "Cloud Sync", value: settings.iCloudSyncEnabled ? "On" : "Off", dynamicText: dynamicText)
                                }
                                .accessibilityIdentifier("cloud_sync_row")
                                .padding(.horizontal, 20)
                            } else {
                                Button(action: {
                                    HapticManager.shared.rigidImpact()
                                    subscription.showPaywall = true
                                }) {
                                    MenuRow(icon: "icloud.fill", title: "Cloud Sync", value: settings.iCloudSyncEnabled ? "On" : "Off", dynamicText: dynamicText)
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // 3. Notifications
                            NavigationLink(destination: NotificationSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "bell.fill", title: "Notifications", value: settings.dailyNotificationEnabled ? "On" : "Off", dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("notifications_row")
                            .padding(.horizontal, 20)
                            
                            // 4. Feedback
                            NavigationLink(destination: FeedbackSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "waveform", title: "Feedback", value: settings.hapticsEnabled ? "On" : "Off", dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("feedback_row")
                            .padding(.horizontal, 20)
                            
                            // 5. About (Separated Rhythm)
                            NavigationLink(destination: AboutSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, accentColor: accentColor, isNightTime: isNightTime)) {
                                MenuRow(
                                    icon: "info.circle.fill",
                                    title: "About",
                                    value: "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")",
                                    dynamicText: dynamicText
                                )
                            }
                            .accessibilityIdentifier("about_row")
                            .padding(.top, 16) // Extra rhythm separation
                            .padding(.horizontal, 20)

                            // 6. Debug Controls
                            NavigationLink(destination: DebugControlsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "ant.fill", title: "Debug Controls", value: "", dynamicText: dynamicText)
                            }
                            .accessibilityIdentifier("debug_controls_row")
                            .padding(.horizontal, 20)

                            // Footer Anchor
                            VStack(spacing: 4) {
                                Text("Mochi")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(dynamicText.opacity(0.15))
                                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(dynamicText.opacity(0.1))
                            }
                            .padding(.top, 32)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $subscription.showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $subscription.showCustomerCenter) {
            if subscription.isLifetime {
                LifetimeOwnerView()
            } else {
                SubscriptionCustomerCenterView()
            }
        }
        .fullScreenCover(item: $notificationManager.activeReflection) { data in
            ReflectionView(
                data: data,
                onDismiss: {
                    notificationManager.activeReflection = nil
                },
                onViewHistory: {
                    notificationManager.activeReflection = nil
                    // Trigger history on main screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        notificationManager.shouldOpenHistory = true
                        dismiss() // Dismiss Settings to show History
                    }
                }
            )
        }
        .preferredColorScheme(isNightTime ? .dark : .light)
    }
}

// MARK: - Level 1 Components

struct MenuRow: View {
    let icon: String
    let title: String
    let value: String
    let dynamicText: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(dynamicText.opacity(0.06))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(dynamicText.opacity(0.7))
            }
            
            Text(title)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(dynamicText)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(dynamicText.opacity(0.4))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dynamicText.opacity(0.2))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12) // Slightly tighter for grounded feel
        .background(dynamicText.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly bolder
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40) // Increased touch target
                            .background(dynamicText.opacity(0.04)) // Subtle background
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1) // Border
                            )
                    }
                    .accessibilityIdentifier("back_button")
                    
                    Spacer()
                    
                    Text("Appearance")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    
                    Spacer()
                    
                    // Balance the header (invisible 32px box)
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16) // Safe area buffer handled by parent view padding or system
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        SettingsSection(icon: "moon.stars.fill", title: "THEME", textColor: dynamicText) {
                            VStack(spacing: 2) {
                                ThemeModeRow(icon: "iphone", title: "System", subtitle: "Match iOS appearance", mode: "system", current: settings.themeMode, color: dynamicText) {
                                    updateTheme("system")
                                }
                                ThemeModeRow(icon: "clock.fill", title: "Auto", subtitle: "Dark after 8 pm", mode: "auto", current: settings.themeMode, color: dynamicText) {
                                    updateTheme("auto")
                                }
                                ThemeModeRow(icon: "sun.max.fill", title: "Light", subtitle: "Always light", mode: "light", current: settings.themeMode, color: dynamicText) {
                                    updateTheme("light")
                                }
                                ThemeModeRow(icon: "moon.fill", title: "Dark", subtitle: "Always dark", mode: "dark", current: settings.themeMode, color: dynamicText) {
                                    updateTheme("dark")
                                }
                                ThemeModeRow(icon: "circle.fill", title: "OLED", subtitle: "True black", mode: "amoled", current: settings.themeMode, color: dynamicText) {
                                    updateTheme("amoled")
                                }
                            }
                            .padding(.vertical, 4)
                            .background(dynamicText.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        SettingsSection(icon: "paintpalette.fill", title: "COLOR THEME", textColor: dynamicText) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(SettingsManager.PastelTheme.all) { theme in
                                        ColorThemeButton(
                                            theme: theme,
                                            isSelected: settings.colorTheme == theme.id,
                                            dynamicText: dynamicText
                                        ) {
                                            if theme.id == "default" || SubscriptionManager.shared.isFullAccess {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    settings.colorTheme = theme.id
                                                }
                                                HapticManager.shared.selection()
                                            } else {
                                                HapticManager.shared.rigidImpact()
                                                SubscriptionManager.shared.showPaywall = true
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        SettingsSection(icon: "app.badge.fill", title: "WIDGET", textColor: dynamicText) {
                            Toggle(isOn: $settings.widgetMatchTheme) {
                                Text("Match Widget Theme")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(dynamicText)
                            }
                            .accessibilityIdentifier("widget_match_theme_toggle")
                            .tint(accentColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func updateTheme(_ mode: String) {
        HapticManager.shared.softSquish()
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.themeMode = mode
        }
    }
}

// MARK: - Logging Settings

struct LoggingSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) var items: [Item]
    
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool

    var dailyTotal: Double {
        let currentRitualDay = settings.getRitualDay(for: Date())
        let todayItems = items.filter {
            settings.getRitualDay(for: $0.timestamp) == currentRitualDay && settings.isItemInActiveCurrency($0)
        }
        return todayItems.reduce(0) { $0 + $1.amount }
    }
    
    var yesterdayTotal: Double {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayRitualDay = settings.getRitualDay(for: yesterday)
        let yesterdayItems = items.filter {
            settings.getRitualDay(for: $0.timestamp) == yesterdayRitualDay && settings.isItemInActiveCurrency($0)
        }
        return yesterdayItems.reduce(0) { $0 + $1.amount }
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly bolder
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40) // Increased touch target
                            .background(dynamicText.opacity(0.04)) // Subtle background
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1) // Border
                            )
                    }
                    Spacer()
                    Text("Logging")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        SettingsSection(icon: "banknote.fill", title: "CURRENCY", textColor: dynamicText) {
                            NavigationLink(destination: CurrencySelectionView(dynamicText: dynamicText)) {
                                HStack {
                                    Text(settings.customCurrencyCode.isEmpty ? "Auto" : settings.customCurrencyCode)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text(settings.currencySymbol)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText.opacity(0.4))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(dynamicText.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        SettingsSection(icon: "creditcard.fill", title: "PAYMENT METHODS", textColor: dynamicText) {
                            NavigationLink(destination: PaymentMethodsView(dynamicText: dynamicText)) {
                                HStack {
                                    HStack(spacing: 10) {
                                        Image(systemName: settings.selectedPaymentMethod.type == .cash ? "banknote" : "creditcard")
                                            .font(.system(size: 14))
                                            .foregroundColor(settings.selectedPaymentMethod.color)
                                            .frame(width: 32, height: 22)
                                            .background(settings.selectedPaymentMethod.color.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        Text(settings.selectedPaymentMethod.name)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(dynamicText.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        SettingsSection(icon: "sunrise.fill", title: "DAY CYCLE", textColor: dynamicText) {
                            HStack {
                                Text("New Day Starts")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(dynamicText)
                                Spacer()
                                DatePicker("", selection: $settings.dayStartDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(accentColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .onChange(of: settings.dayStartDate) { _, _ in
                            // Sync reset settings to widget immediately
                            let lastItem = items.first
                            WidgetDataManager.shared.updateWidgetData(
                                todayTotal: dailyTotal,
                                yesterdayTotal: yesterdayTotal,
                                lastTransaction: lastItem?.amount,
                                lastTransactionNote: lastItem?.note,
                                currencySymbol: settings.currencySymbol,
                                colorTheme: settings.colorTheme,
                                themeMode: settings.themeMode,
                                isPro: SubscriptionManager.shared.isFullAccess,
                                dayStartHour: settings.dayStartHour,
                                dayStartMinute: settings.dayStartMinute
                            )
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly bolder
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40) // Increased touch target
                            .background(dynamicText.opacity(0.04)) // Subtle background
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1) // Border
                            )
                    }
                    Spacer()
                    Text("Notifications")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        SettingsSection(icon: "bell.badge.fill", title: "NOTIFICATIONS", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                // Daily Toggle
                                Toggle(isOn: $settings.dailyNotificationEnabled) {
                                    Text("Daily Summary")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider()
                                    .background(dynamicText.opacity(0.1))
                                    .padding(.horizontal, 16)
                                
                                // Weekly Toggle
                                Toggle(isOn: $settings.weeklyNotificationEnabled) {
                                    Text("Weekly Summary")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                // Shared Time & Day Settings
                                if settings.dailyNotificationEnabled || settings.weeklyNotificationEnabled {
                                    Divider()
                                        .background(dynamicText.opacity(0.1))
                                        .padding(.horizontal, 16)
                                    
                                    // Time Picker
                                    HStack {
                                        Text("Time")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                        Spacer()
                                        DatePicker("", selection: $settings.notificationDate, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                            .tint(accentColor)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    
                                    // Day Picker (Weekly Only)
                                    if settings.weeklyNotificationEnabled {
                                        Divider()
                                            .background(dynamicText.opacity(0.1))
                                            .padding(.horizontal, 16)
                                        
                                        HStack {
                                            Text("Weekly Day")
                                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                                .foregroundColor(dynamicText)
                                            Spacer()
                                            Picker("", selection: $settings.weeklyNotificationWeekday) {
                                                Text("Sun").tag(1)
                                                Text("Mon").tag(2)
                                                Text("Tue").tag(3)
                                                Text("Wed").tag(4)
                                                Text("Thu").tag(5)
                                                Text("Fri").tag(6)
                                                Text("Sat").tag(7)
                                            }
                                            .tint(accentColor)
                                            .labelsHidden()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        SettingsSection(icon: "eye.fill", title: "PREVIEW", textColor: dynamicText) {
                            HStack(spacing: 12) {
                                // Daily Preview Card
                                Button(action: {
                                    HapticManager.shared.softSquish()
                                    NotificationManager.shared.sendTestNotification(type: .daily)
                                }) {
                                    ZStack(alignment: .bottomLeading) {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(Color.mochiSage.opacity(isNightTime ? 0.1 : 0.2))
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            HStack {
                                                Image("MochiLogo")
                                                    .resizable()
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                Spacer()
                                                Image(systemName: "sun.max.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(dynamicText.opacity(0.3))
                                            }
                                            Spacer()
                                            Text("DAILY")
                                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                                .foregroundColor(dynamicText)
                                        }
                                        .padding(14)
                                    }
                                    .frame(height: 84)
                                }
                                
                                // Weekly Preview Card
                                Button(action: {
                                    HapticManager.shared.softSquish()
                                    NotificationManager.shared.sendTestNotification(type: .weekly)
                                }) {
                                    ZStack(alignment: .bottomLeading) {
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .fill(Color.mochiBlue.opacity(isNightTime ? 0.1 : 0.2))
                                        
                                        VStack(alignment: .leading, spacing: 0) {
                                            HStack {
                                                Image("MochiLogo")
                                                    .resizable()
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                Spacer()
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(dynamicText.opacity(0.3))
                                            }
                                            Spacer()
                                            Text("WEEKLY")
                                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                                .foregroundColor(dynamicText)
                                        }
                                        .padding(14)
                                    }
                                    .frame(height: 84)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: settings.dailyNotificationEnabled) { _, enabled in
            if enabled { NotificationManager.shared.requestPermission() }
            else { NotificationManager.shared.scheduleNotifications() }
        }
        .onChange(of: settings.weeklyNotificationEnabled) { _, enabled in
            if enabled { NotificationManager.shared.requestPermission() }
            else { NotificationManager.shared.scheduleNotifications() }
        }
        .onChange(of: settings.notificationDate) { _, _ in
            NotificationManager.shared.scheduleNotifications()
        }
        .onChange(of: settings.weeklyNotificationWeekday) { _, _ in
             NotificationManager.shared.scheduleNotifications()
        }
    }
}

// MARK: - Feedback Settings

struct FeedbackSettingsView: View {
    @State private var showMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>?
    @ObservedObject var settings = SettingsManager.shared
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly bolder
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40) // Increased touch target
                            .background(dynamicText.opacity(0.04)) // Subtle background
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1) // Border
                            )
                    }
                    Spacer()
                    Text("Feedback")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        SettingsSection(icon: "waveform", title: "FEEDBACK", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                Toggle(isOn: $settings.hapticsEnabled) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "hand.tap.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(dynamicText.opacity(0.5))
                                        Text("Haptics")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    }
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider()
                                    .background(dynamicText.opacity(0.1))
                                    .padding(.horizontal, 16)
                                
                                Toggle(isOn: $settings.soundsEnabled) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(dynamicText.opacity(0.5))
                                        Text("Sounds")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    }
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        SettingsSection(icon: "envelope.fill", title: "CONTACT", textColor: dynamicText) {
                            Button(action: {
                                HapticManager.shared.rigidImpact()
                                if MFMailComposeViewController.canSendMail() {
                                    showMailView = true
                                } else {
                                    if let url = URL(string: "mailto:harshachaganti12@gmail.com?subject=Mochi%20App%20Feedback") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(accentColor.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(accentColor)
                                    }
                                    
                                    Text("Send Suggestions")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(dynamicText.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMailView) {
            MailView(result: $mailResult)
                .ignoresSafeArea()
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    let isNightTime: Bool
    
    @Environment(\.dismiss) var dismiss
    @State private var isRestoring = false

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40)
                            .background(dynamicText.opacity(0.04))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1)
                            )
                    }
                    Spacer()
                    Text("About")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Mochi+ Status
                        SettingsSection(icon: "sparkles", title: "SUBSCRIPTION", textColor: dynamicText) {
                            Button(action: {
                                HapticManager.shared.softSquish()
                                if subscription.isPro {
                                    subscription.showCustomerCenter = true
                                } else {
                                    subscription.showPaywall = true
                                }
                            }) {
                                MembershipCard()
                            }
                            .buttonStyle(.plain)
                        }
                        
                        SettingsSection(icon: "info.circle.fill", title: "ABOUT", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Mochi+")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    Text(subscription.detailedStatus)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(subscription.isPro ? accentColor : dynamicText.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().background(dynamicText.opacity(0.1)).padding(.horizontal, 16)
                                
                                HStack {
                                    Text("Restore Purchase")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    Button(action: {
                                        isRestoring = true
                                        Task {
                                            _ = await subscription.restorePurchases()
                                            isRestoring = false
                                        }
                                    }) {
                                        if isRestoring {
                                            MochiSpinner(size: 22)
                                        } else {
                                            Text("Restore")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(dynamicText.opacity(0.5))
                                        }
                                    }
                                    .disabled(isRestoring)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().background(dynamicText.opacity(0.1)).padding(.horizontal, 16)
                                
                                HStack {
                                    Text("Version")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(dynamicText.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $subscription.showPaywall) { PaywallView() }
    }
}

struct MembershipCard: View {
    @ObservedObject var subscription = SubscriptionManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image("MochiLogo")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.6)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .opacity(0.3)
        }
        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.28))
        .padding(16)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    
    private var title: String {
        return subscription.statusLabel == "Free" ? "Upgrade to Mochi+" : subscription.statusLabel
    }
    
    private var subtitle: String {
        if subscription.isPro { 
            if subscription.isOnTrial { return "Free trial ending soon" }
            if let pid = subscription.activeProductId, pid.contains("lifetime") {
                return "Welcome to the family"
            }
            return "Thank you for supporting Mochi! ♥️" 
        }
        return "Unlock history, themes & widgets"
    }
}

// MARK: - Reusable Components (Keep existing designs)

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    let textColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor.opacity(0.4))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(textColor.opacity(0.4))
                    .tracking(1.2)
            }
            .padding(.leading, 4)
            content
        }
        .padding(.horizontal, 24)
    }
}

struct ThemeModeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let mode: String
    let current: String
    let color: Color
    let action: () -> Void
    
    var isSelected: Bool { mode == current }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                action()
            }
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSelected ? color : color.opacity(0.35))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .monospaced))
                        .foregroundColor(isSelected ? color : color.opacity(0.6))
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(color.opacity(0.35))
                }
                
                Spacer()
                
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : color.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ColorThemeButton: View {
    let theme: SettingsManager.PastelTheme
    let isSelected: Bool
    let dynamicText: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(theme.background).frame(width: 50, height: 50)
                    Image(systemName: theme.icon).font(.system(size: 16, weight: .medium)).foregroundColor(theme.accent)
                    if isSelected { Circle().stroke(dynamicText, lineWidth: 2).frame(width: 54, height: 54) }
                }
                Text(theme.name).font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded)).foregroundColor(isSelected ? dynamicText : dynamicText.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}

struct CloudSyncSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    @State private var showRestartAlert = false
    @State private var showRestoreSuccessAlert = false
    @State private var showNoDataAlert = false
    @State private var isRestoring = false
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold)) // Slightly bolder
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40) // Increased touch target
                            .background(dynamicText.opacity(0.04)) // Subtle background
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1) // Border
                            )
                    }
                    .opacity(isRestoring ? 0.4 : 1.0)
                    Spacer()
                    Text("Cloud Sync")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16) // Safe area buffer handled by parent view padding or system
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        SettingsSection(icon: "icloud.fill", title: "ICLOUD BACKUP", textColor: dynamicText) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Sync your transactions securely to your personal iCloud account. This seamlessly brings back your history on reinstall.")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(dynamicText.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                
                                Toggle(isOn: Binding(
                                    get: { settings.iCloudSyncEnabled },
                                    set: { newValue in
                                        settings.iCloudSyncEnabled = newValue
                                        showRestartAlert = true
                                        HapticManager.shared.selection()
                                    }
                                )) {
                                    Text("Enable iCloud Sync")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(dynamicText)
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        
                        SettingsSection(icon: "arrow.triangle.2.circlepath", title: "DATA RECOVERY", textColor: dynamicText) {
                            Button(action: {
                                HapticManager.shared.rigidImpact()
                                isRestoring = true
                                Task {
                                    let hasData = CloudSyncManager.shared.forceRestore()
                                    try? await Task.sleep(nanoseconds: 800_000_000)
                                    await MainActor.run {
                                        isRestoring = false
                                        if hasData {
                                            showRestoreSuccessAlert = true
                                        } else {
                                            showNoDataAlert = true
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    Text("Force Restore from iCloud")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    if isRestoring {
                                        MochiSpinner(size: 22)
                                    } else {
                                        Image(systemName: "arrow.down.doc.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(dynamicText.opacity(0.5))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isRestoring)
                        }
                    }
                    .padding(.top, 12)
                }
            }
            
            if isRestoring {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        MochiSpinner(size: 28)
                        Text("Restoring from iCloud…")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(dynamicText)
                        Text("Please keep Mochi open.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.6))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(dynamicBackground.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Restart Required", isPresented: $showRestartAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please fully restart Mochi (swipe up to force close in App Switcher, then reopen) for iCloud Sync changes to take effect.")
        }
        .alert("Restored", isPresented: $showRestoreSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your settings and saved cards have been forcefully restored from iCloud.")
        }
        .alert("No Data Found", isPresented: $showNoDataAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We couldn't find any Mochi data in your iCloud account.")
        }
    }
}

// MARK: - Debug Controls

struct DebugControlsView: View {
    @ObservedObject var settings = SettingsManager.shared
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool

    @Environment(\.dismiss) var dismiss
    @State private var copiedRC = false

    var accentColor: Color {
        settings.colorTheme != "default" ? settings.currentPastelTheme.accent : Color(red: 0.35, green: 0.65, blue: 0.55)
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
    var iosVersion: String { UIDevice.current.systemVersion }
    var deviceName: String { UIDevice.current.model }

    var rcID: String { Purchases.shared.appUserID }
    var rcIDTruncated: String {
        guard rcID.count > 20 else { return rcID }
        return "\(rcID.prefix(10))...\(rcID.suffix(10))"
    }

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40)
                            .background(dynamicText.opacity(0.04))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(dynamicText.opacity(0.1), lineWidth: 1))
                    }
                    Spacer()
                    Text("Debug Controls")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ── Copy RevenueCat ID ──
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: {
                                UIPasteboard.general.string = rcID
                                HapticManager.shared.success()
                                withAnimation { copiedRC = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { copiedRC = false }
                                }
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(dynamicText.opacity(0.08))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: copiedRC ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(copiedRC ? accentColor : dynamicText.opacity(0.7))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(copiedRC ? "Copied!" : "Copy RevenueCat ID")
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundColor(dynamicText)
                                        Text(rcIDTruncated)
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundColor(dynamicText.opacity(0.45))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(dynamicText.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Text("Copy this ID if you need help from support to investigate subscription issues.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.45))
                                .padding(.horizontal, 4)
                        }

                        // ── Device Information ──
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Device Information")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.45))
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                DebugInfoRow(icon: "app.badge", label: "App Version", value: appVersion, dynamicText: dynamicText)
                                Divider()
                                    .background(dynamicText.opacity(0.1))
                                    .padding(.horizontal, 16)
                                DebugInfoRow(icon: "iphone", label: "iOS Version", value: iosVersion, dynamicText: dynamicText)
                                Divider()
                                    .background(dynamicText.opacity(0.1))
                                    .padding(.horizontal, 16)
                                DebugInfoRow(icon: "person.text.rectangle", label: "Device Name", value: deviceName, dynamicText: dynamicText)
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct DebugInfoRow: View {
    let icon: String
    let label: String
    let value: String
    let dynamicText: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(dynamicText.opacity(0.08))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(dynamicText.opacity(0.65))
            }
            Text(label)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(dynamicText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(dynamicText.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}
