import SwiftUI
import MessageUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    
    // Theme Logic
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            // 1. Appearance
                            NavigationLink(destination: AppearanceSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "moon.stars.fill", title: "Appearance", value: settings.themeMode.capitalized, dynamicText: dynamicText)
                            }
                            
                            // 2. Logging
                            NavigationLink(destination: LoggingSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "pencil.line", title: "Logging", value: settings.currencySymbol, dynamicText: dynamicText)
                            }
                            
                            // 2.1 Speed Dial
                            NavigationLink(destination: SpeedDialSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground)) {
                                MenuRow(icon: "bolt.fill", title: "Speed Dial", value: "", dynamicText: dynamicText)
                            }
                            
                            // 2.1 Data & Export
                            if subscription.isPro {
                                NavigationLink(destination: ExportDataView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                    MenuRow(icon: "square.and.arrow.up.fill", title: "Data & Export", value: "CSV, PDF", dynamicText: dynamicText)
                                }
                            } else {
                                Button(action: {
                                    HapticManager.shared.rigidImpact()
                                    subscription.showPaywall = true
                                }) {
                                    MenuRow(icon: "square.and.arrow.up.fill", title: "Data & Export", value: "CSV, PDF", dynamicText: dynamicText)
                                }
                            }
                            
                            
                            // 3. Notifications
                            NavigationLink(destination: NotificationSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "bell.fill", title: "Notifications", value: settings.dailyNotificationEnabled ? "On" : "Off", dynamicText: dynamicText)
                            }
                            
                            // 4. Feedback
                            NavigationLink(destination: FeedbackSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, isNightTime: isNightTime)) {
                                MenuRow(icon: "waveform", title: "Feedback", value: settings.hapticsEnabled ? "On" : "Off", dynamicText: dynamicText)
                            }
                            
                            // 5. About (Separated Rhythm)
                            NavigationLink(destination: AboutSettingsView(dynamicText: dynamicText, dynamicBackground: dynamicBackground, accentColor: accentColor, isNightTime: isNightTime)) {
                                MenuRow(icon: "info.circle.fill", title: "About", value: "v1.0.0", dynamicText: dynamicText)
                            }
                            .padding(.top, 16) // Extra rhythm separation
                            
                            // Footer Anchor
                            VStack(spacing: 4) {
                                Text("Mochi")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(dynamicText.opacity(0.15))
                                Text("v1.0.0")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(dynamicText.opacity(0.1))
                            }
                            .padding(.top, 32)
                            .padding(.bottom, 24)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $subscription.showPaywall) {
            PaywallView()
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
                            HStack(spacing: 0) {
                                ThemeButton(title: "Auto", mode: "auto", current: settings.themeMode, color: dynamicText, inverseColor: dynamicBackground) {
                                    updateTheme("auto")
                                }
                                ThemeButton(title: "Light", mode: "light", current: settings.themeMode, color: dynamicText, inverseColor: dynamicBackground) {
                                    updateTheme("light")
                                }
                                ThemeButton(title: "Dark", mode: "dark", current: settings.themeMode, color: dynamicText, inverseColor: dynamicBackground) {
                                    updateTheme("dark")
                                }
                                ThemeButton(title: "OLED", mode: "amoled", current: settings.themeMode, color: dynamicText, inverseColor: dynamicBackground) {
                                    updateTheme("amoled")
                                }
                            }
                            .background(dynamicText.opacity(0.06))
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
                                            if theme.id == "default" || SubscriptionManager.shared.isPro {
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
                            if !subscription.isPro {
                                Button(action: { subscription.showPaywall = true }) {
                                    UpgradePromoView(subscription: subscription)
                                }
                            } else {
                                Button(action: { 
                                    HapticManager.shared.softSquish()
                                    subscription.showCustomerCenter = true 
                                }) {
                                    HStack(spacing: 12) {
                                        Image("MochiLogo")
                                            .resizable()
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Mochi+ Active")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                                .foregroundColor(isNightTime ? .white : .primary)
                                            
                                            Text("Thank you for your support!")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(isNightTime ? .white.opacity(0.6) : .secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(accentColor)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(accentColor.opacity(isNightTime ? 0.15 : 0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        
                        SettingsSection(icon: "info.circle.fill", title: "ABOUT", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Restore Purchase")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    Button("Restore") {
                                        Task { await subscription.restorePurchases() }
                                    }
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(dynamicText.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                Divider().background(dynamicText.opacity(0.1)).padding(.horizontal, 16)
                                
                                HStack {
                                    Text("Version")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    Text("1.0.0")
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

struct UpgradePromoView: View {
    @ObservedObject var subscription: SubscriptionManager
    var body: some View {
        HStack(spacing: 12) {
            Image("MochiLogo")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Upgrade to Mochi+")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Unlock history, themes & widgets")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .opacity(0.6)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).opacity(0.4)
        }
        .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.28))
        .padding(16)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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

struct ThemeButton: View {
    let title: String
    let mode: String
    let current: String
    let color: Color
    let inverseColor: Color
    let action: () -> Void
    var isSelected: Bool { mode == current }
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? inverseColor : color.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? color : Color.clear)
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
