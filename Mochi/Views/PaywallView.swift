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
    
    // Dynamic distinct colors per plan
    private func packageAccent(for type: PackageType) -> Color {
        if settings.colorTheme != "default" {
            switch type {
            case .annual: return currentTheme.accent
            case .monthly: return currentTheme.accent.opacity(isNightTime ? 0.7 : 0.6)
            case .lifetime: return currentTheme.accent.opacity(isNightTime ? 0.6 : 0.4)
            default: return currentTheme.accent
            }
        }
        switch type {
        case .annual: return Color(red: 0.35, green: 0.65, blue: 0.55)
        case .monthly: return isNightTime ? Color.mochiBlueDark : Color(red: 0.40, green: 0.55, blue: 0.70)
        case .lifetime: return isNightTime ? Color.mochiRose : Color(red: 0.70, green: 0.45, blue: 0.50)
        default: return Color(red: 0.35, green: 0.65, blue: 0.55)
        }
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
                        
                        Text(LocalizedStringKey(headerTitle))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        
                        Text(LocalizedStringKey(headerSubtitle))
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
                        Text(LocalizedStringKey("Beautiful on your Home Screen"))
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
                                        Text(LocalizedStringKey(subscription.isPro ? "Mochi+ Membership Active" : "Mochi+ Trial Active"))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(dynamicText)
                                        Text(LocalizedStringKey("All premium features are unlocked"))
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
                                    accentColor: packageAccent(for: package.packageType),
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
                    
                    if !subscription.isPro {
                        if subscription.hasUsedTrial {
                            Text("TRIAL COMPLETED")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(Color.red.opacity(0.8))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                                .padding(.top, 0)
                                .padding(.bottom, 6)
                        } else {
                            Spacer().frame(height: 0)
                        }
                    } else {
                        Spacer().frame(height: 0)
                    }
                    
                    // Subscribe Button or Manage Button
                    Button(action: subscribeTapped) {
                        HStack {
                            if isLoading {
                                MochiSpinner(size: 28)
                            } else {
                                buttonLabelView
                                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                            }
                        }
                        .foregroundColor(isNightTime ? Color.black : Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedPackage != nil ? packageAccent(for: selectedPackage!.packageType) : dynamicAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isLoading || (selectedPackage == nil && !subscription.isFullAccess))
                    .padding(.horizontal, 24)
                    
                    if !subscription.isFullAccess {
                        Button(action: restoreTapped) {
                            if isLoading {
                                MochiSpinner(size: 16)
                            } else {
                                Text(LocalizedStringKey("Restore Purchases"))
                            }
                        }
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(dynamicText.opacity(0.6))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(dynamicText.opacity(0.04))
                        .clipShape(Capsule())
                        .disabled(isLoading)
                        .padding(.top, 8)
                    }
                    
                    // Skip button to drop to free tier in onboarding
                    if isEmbedded && !subscription.isPro {
                        Button(action: {
                            HapticManager.shared.softSquish()
                            if let onComplete {
                                onComplete()
                            } else {
                                dismiss()
                            }
                        }) {
                            Text("Continue Free Version")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.4))
                                .padding(.bottom, 2)
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(dynamicText.opacity(0.2)),
                                    alignment: .bottom
                                )
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                    }
                    
                    // Fine Print (Only show when not in trial)
                    if !subscription.isFullAccess {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
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
    
    @ViewBuilder
    private var buttonLabelView: some View {
        if subscription.isPro {
            Text(LocalizedStringKey(isEmbedded ? "Active · Continue" : "Manage Subscription"))
        } else if subscription.isFullAccess && !isEmbedded {
            Text(LocalizedStringKey("Got it"))
        } else if let pkg = selectedPackage {
            if !subscription.hasUsedTrial, let intro = pkg.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
                let unitStr = NSLocalizedString(introDurationUnit(intro.subscriptionPeriod.unit), comment: "")
                Text("Start \(intro.subscriptionPeriod.value)-\(unitStr) Free Trial")
            } else {
                Text(LocalizedStringKey("Get Mochi +"))
            }
        } else {
            Text(LocalizedStringKey("Select a Plan"))
        }
    }
    
    private func subscribeTapped() {
        if subscription.isPro {
            if isEmbedded {
                HapticManager.shared.selection()
                if let onComplete { onComplete() } else { dismiss() }
            } else {
                subscription.showCustomerCenter = true
            }
            return
        }
        
        if subscription.isFullAccess && !isEmbedded {
            dismiss()
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
                Text(LocalizedStringKey(title))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(text)
                Text(LocalizedStringKey(subtitle))
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
                    Text(LocalizedStringKey(packageName))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? (isNightTime ? .black : .white) : textColor)
                    
                    if let intro = package.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
                        let unitStr = NSLocalizedString(introDurationUnit(intro.subscriptionPeriod.unit), comment: "")
                        Text("Best Value · \(intro.subscriptionPeriod.value)-\(unitStr) Trial")
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
