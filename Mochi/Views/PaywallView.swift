import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscription = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var isLoading = false
    
    @ObservedObject var settings = SettingsManager.shared
    
    /// When true, hides close button and shows "Maybe Later" skip
    var isEmbedded: Bool = false
    /// Called on successful purchase/restore when embedded
    var onComplete: (() -> Void)? = nil
    
    @Environment(\.colorScheme) var colorScheme
    
    // Dynamic Theme Logic
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
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return isNightTime ? Color.mochiBackground : Color.mochiText
    }
    
    var dynamicAccent: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    var body: some View {
        ZStack {
            // Dynamic Background
            dynamicBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // Header
                    VStack(spacing: 16) {
                        // Close Button (only when presented as sheet)
                        if !isEmbedded {
                            HStack {
                                Spacer()
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(dynamicText.opacity(0.4))
                                        .frame(width: 28, height: 28)
                                        .background(dynamicText.opacity(0.06))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                        }
                        
                        // Logo + (centered)
                        HStack(alignment: .center, spacing: 4) {
                            Image("MochiLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            
                            Text("+")
                                .font(.system(size: 40, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicAccent)
                        }
                        
                        Text(headerTitle)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        
                        Text(headerSubtitle)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 18) {
                        FeatureRow(icon: "clock.badge.checkmark", title: "Full History", subtitle: "Access every mochi you've ever tracked.", color: dynamicAccent, text: dynamicText)
                        FeatureRow(icon: "paintpalette.fill", title: "Premium Themes", subtitle: "A collection of curated pastel palettes.", color: dynamicAccent, text: dynamicText)
                        FeatureRow(icon: "brain.head.profile", title: "Daily Reflection", subtitle: "Summarize your day with AI insights.", color: dynamicAccent, text: dynamicText)
                        FeatureRow(icon: "doc.badge.arrow.up", title: "CSV & PDF Export", subtitle: "Export your data for backup or analysis.", color: dynamicAccent, text: dynamicText)
                    }
                    .padding(.horizontal, 32)
                    
                    // Widget Preview
                    VStack(spacing: 12) {
                        Text("Beautiful on your Home Screen")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.4))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(SettingsManager.PastelTheme.all.enumerated()), id: \.element.id) { index, theme in
                                    WidgetPreviewView(
                                        size: .small,
                                        theme: theme,
                                        isDark: isNightTime
                                    )
                                    
                                    WidgetPreviewView(
                                        size: .medium,
                                        theme: theme,
                                        isDark: isNightTime
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    
                    // Pricing Plans or Status Card
                    VStack(spacing: 12) {
                        if subscription.isFullAccess && !isEmbedded {
                            // Status Card (Full Access Active)
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(dynamicAccent.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(dynamicAccent)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(subscription.isPro ? "Mochi+ Membership Active" : "Mochi+ Trial Active")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(dynamicText)
                                        Text("All premium features are unlocked")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText.opacity(0.5))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(dynamicAccent.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(dynamicAccent.opacity(0.1), lineWidth: 1)
                                )
                                
                                if !subscription.isPro {
                                    Text("Mochi is free during your 3-day trial. We'll remind you before it ends so you can decide if you'd like to continue with Mochi+.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(dynamicText.opacity(0.4))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.vertical, 8)
                        } else if let error = subscription.offeringsError {
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Products Failed to Load")
                                    .font(.headline)
                                Text(error)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(dynamicText.opacity(0.6))
                                
                                // Debug Detail
                                Text(subscription.offeringsDebugInfo)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(dynamicText.opacity(0.5))
                                    .padding(8)
                                    .background(dynamicText.opacity(0.05))
                                    .cornerRadius(8)
                                
                                Button("Retry") {
                                    Task { await subscription.fetchOfferings() }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 20)
                        } else if subscription.currentOffering?.availablePackages.isEmpty ?? true {
                            // Loading state while fetching from RevenueCat
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading prices...")
                                    .font(.caption)
                                    .foregroundColor(dynamicText.opacity(0.5))
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(subscription.currentOffering?.availablePackages ?? [], id: \.identifier) { package in
                                PackageCard(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier,
                                    textColor: dynamicText,
                                    accentColor: dynamicAccent,
                                    isNightTime: isNightTime
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPackage = package
                                    }
                                    HapticManager.shared.selection()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Subscribe Button or Manage Button
                    Button(action: subscribeTapped) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(isNightTime ? Color.black : Color.white)
                            } else {
                                Text(buttonLabel)
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                            }
                        }
                        .foregroundColor(isNightTime ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(dynamicAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isLoading || (selectedPackage == nil && !subscription.isFullAccess))
                    .padding(.horizontal, 24)
                    
                    // Fine Print (Only show when not in trial)
                    if !subscription.isFullAccess {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button("Restore") { restoreTapped() }
                                Text("·")
                                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Text("·")
                                Link("Privacy", destination: URL(string: "https://mochi-privacy-policy.vercel.app/")!)
                            }
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.4))
                            
                            Text("Cancel anytime in the App Store.")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.3))
                        }
                        .padding(.bottom, isEmbedded ? 8 : 32)
                    } else {
                        Spacer().frame(height: isEmbedded ? 8 : 32)
                    }
                    
                    // Skip button (Not needed in onboarding as we have Start Trial)
                    if isEmbedded {
                        Spacer().frame(height: 24)
                    }
                }
            }
        }
        .task {
            // Load offerings on appear
            await subscription.fetchOfferings()
            if selectedPackage == nil {
                selectedPackage = subscription.currentOffering?.annual ?? subscription.currentOffering?.availablePackages.first
            }
        }
    }
    
    // MARK: - Layout Helpers
    
    private var headerTitle: String {
        if subscription.isPro { return "Mochi+ Membership" }
        if subscription.isFullAccess { return "Mochi+ Trial Active" }
        return "Unlock Mochi +"
    }
    
    private var headerSubtitle: String {
        if subscription.isFullAccess { return "Everything is unlocked for you." }
        return "Everything you need for perfect tracking."
    }
    
    private var buttonLabel: String {
        if subscription.isPro { return "Manage Subscription" }
        if subscription.isFullAccess && !isEmbedded { return "Got it" }
        
        if isEmbedded { return "Start 3-Day Free Trial" }
        guard let pkg = selectedPackage else { return "Select a Plan" }
        if let intro = pkg.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            return "Start \(intro.subscriptionPeriod.value)-\(introDurationUnit(intro.subscriptionPeriod.unit)) Free Trial"
        } else {
            return "Get Mochi +"
        }
    }
    
    private func subscribeTapped() {
        if subscription.isPro {
            subscription.showCustomerCenter = true
            return
        }
        
        if subscription.isFullAccess && !isEmbedded {
            dismiss()
            return
        }
        
        if isEmbedded {
            // Direct Start Soft Trial
            HapticManager.shared.rigidImpact()
            if let onComplete {
                onComplete()
            } else {
                dismiss()
            }
            return
        }
        
        guard let package = selectedPackage else { return }
        isLoading = true
        HapticManager.shared.rigidImpact()
        
        Task {
            let success = await subscription.purchase(package: package)
            await MainActor.run {
                isLoading = false
                if success {
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func restoreTapped() {
        isLoading = true
        HapticManager.shared.softSquish()
        
        Task {
            let success = await subscription.restorePurchases()
            await MainActor.run {
                isLoading = false
                if success && subscription.isPro {
                    if let onComplete {
                        onComplete()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Components

struct FeatureRow: View {
    let icon: String
    var label: String = ""
    var title: String = ""
    var subtitle: String
    let color: Color
    let text: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon.isEmpty ? label : icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(text)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(text.opacity(0.5))
            }
        }
    }
}

struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let textColor: Color
    let accentColor: Color
    let isNightTime: Bool
    let action: () -> Void
    
    var packageName: String {
        switch package.packageType {
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        default: return package.storeProduct.localizedTitle
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(packageName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? (isNightTime ? .black : .white) : textColor)
                    
                    if let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
                        Text("Best Value · \(intro.subscriptionPeriod.value)-\(introDurationUnit(intro.subscriptionPeriod.unit)) Trial")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? (isNightTime ? .black.opacity(0.6) : .white.opacity(0.7)) : accentColor)
                    } else if package.packageType == .annual {
                        Text("Best Value")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? (isNightTime ? .black.opacity(0.6) : .white.opacity(0.7)) : accentColor)
                    }
                }
                
                Spacer()
                
                Text(package.localizedPriceString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? (isNightTime ? .black : .white) : textColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accentColor : textColor.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : textColor.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func introDurationUnit(_ unit: SubscriptionPeriod.Unit) -> String {
    switch unit {
    case .day: return "Day"
    case .week: return "Week"
    case .month: return "Month"
    case .year: return "Year"
    @unknown default: return ""
    }
}
