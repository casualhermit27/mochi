import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var subscription = SubscriptionManager.shared
    @State private var showPaywall = false
    
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
    
    // Adaptive Colors with Pastel Theme Support
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return .primary
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return Color(UIColor.systemBackground)
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
            // Background - uses pastel theme or system colors
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
                            .frame(width: 30, height: 30)
                            .background(dynamicText.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        
                        // 1. Appearance
                        SettingsSection(icon: "moon.stars.fill", title: "APPEARANCE", textColor: dynamicText) {
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
                        
                        // 1.5 Color Theme
                        SettingsSection(icon: "paintpalette.fill", title: "COLOR THEME", textColor: dynamicText) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(SettingsManager.PastelTheme.all) { theme in
                                        ColorThemeButton(
                                            theme: theme,
                                            isSelected: settings.colorTheme == theme.id,
                                            dynamicText: dynamicText
                                        ) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                settings.colorTheme = theme.id
                                            }
                                            HapticManager.shared.selection()
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // 2. Currency
                        // 2. Currency
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
                            .buttonStyle(.plain)
                        }
                        
                        // 3. Notifications
                        SettingsSection(icon: "bell.badge.fill", title: "NOTIFICATIONS", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                Toggle(isOn: $settings.dailyNotificationEnabled) {
                                    Text("Daily Summary")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                }
                                .tint(accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                
                                if settings.dailyNotificationEnabled {
                                    Divider()
                                        .background(dynamicText.opacity(0.1))
                                        .padding(.horizontal, 16)
                                    
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
                                }
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .onChange(of: settings.dailyNotificationEnabled) { _, enabled in
                            if enabled {
                                NotificationManager.shared.requestPermission()
                            } else {
                                NotificationManager.shared.scheduleDailyNotification()
                            }
                        }
                        .onChange(of: settings.notificationDate) { _, _ in
                            NotificationManager.shared.scheduleDailyNotification()
                        }
                        
                        // 4. Day Cycle
                        SettingsSection(icon: "sunrise.fill", title: "DAY CYCLE", textColor: dynamicText) {
                            SettingsRow(textColor: dynamicText) {
                                HStack {
                                    Text("New Day Starts")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText)
                                    Spacer()
                                    DatePicker("", selection: $settings.dayStartDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                        .tint(accentColor)
                                }
                            }
                        }
                        
                        // 5. Haptics & Sounds
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
                        
                        // 6. Mochi+ Subscription
                        if !subscription.isPro {
                            Button(action: {
                                HapticManager.shared.softSquish()
                                showPaywall = true
                            }) {
                                HStack(spacing: 10) {
                                    HStack(alignment: .center, spacing: 2) {
                                        Image("MochiLogo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 38, height: 38)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                        Text("+")
                                            .font(.system(size: 20, weight: .medium, design: .rounded))
                                            .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.55))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("Upgrade")
                                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                            
                                            if subscription.isTrialActive {
                                                Text("\(subscription.trialDaysRemaining) DAYS LEFT")
                                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(Color(red: 0.35, green: 0.65, blue: 0.55))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text("Unlock History, Themes, Export & Widget")
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .opacity(0.6)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .opacity(0.4)
                                }
                                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.28))
                                .padding(14)
                                .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.28).opacity(0.08), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        } else {
                            // Pro Badge
                            HStack(spacing: 8) {
                                HStack(spacing: 2) {
                                    Image("MochiLogo")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                    Text("+")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(red: 0.35, green: 0.65, blue: 0.55))
                                }
                                Text("Active")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.28))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.98, green: 0.96, blue: 0.93))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color(red: 0.45, green: 0.35, blue: 0.28).opacity(0.06), radius: 6, y: 3)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }
                        
                        // Restore Purchase
                        Button(action: {
                            HapticManager.shared.softSquish()
                            Task {
                                await subscription.restorePurchases()
                            }
                        }) {
                            Text("Restore Purchase")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        
                        // Footer
                        VStack(spacing: 4) {
                            Text("Mochi")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.3))
                            Text("v1.0.0")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.2))
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(isNightTime ? .dark : .light)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    private func updateTheme(_ mode: String) {
        HapticManager.shared.softSquish()
        withAnimation(.easeInOut(duration: 0.2)) {
            settings.themeMode = mode
        }
    }
}

// MARK: - Reusable Components

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

struct SettingsRow<Content: View>: View {
    let textColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(textColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .animation(.easeInOut(duration: 0.15), value: isSelected)
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
                    // Simple solid pastel background
                    Circle()
                        .fill(theme.background)
                        .frame(width: 50, height: 50)
                    
                    // Colored icon matching theme accent
                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.accent)
                    
                    // Selection ring
                    if isSelected {
                        Circle()
                            .stroke(dynamicText, lineWidth: 2)
                            .frame(width: 54, height: 54)
                    }
                }
                
                Text(theme.name)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? dynamicText : dynamicText.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
