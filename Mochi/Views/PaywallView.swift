import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscription = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var selectedStaticPlan: String? = "yearly" // Default to yearly for screenshots
    @State private var isLoading = false
    
    @ObservedObject var settings = SettingsManager.shared
    
    // Dynamic Theme Logic
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
                        // Close Button
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
                        
                        Text("Unlock Mochi +")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                        
                        Text("Everything you need for perfect tracking.")
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
                                ForEach(SettingsManager.PastelTheme.all) { theme in
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
                    
                    // Pricing Plans
                    VStack(spacing: 12) {
                        if subscription.currentOffering?.availablePackages.isEmpty ?? true {
                            // Static Fallback Plans (for screenshots / when RevenueCat isn't loaded)
                            StaticPlanCard(
                                name: "Monthly",
                                price: "$2.99",
                                subtitle: nil,
                                isSelected: selectedStaticPlan == "monthly",
                                textColor: dynamicText,
                                accentColor: dynamicAccent,
                                isNightTime: isNightTime
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedStaticPlan = "monthly"
                                }
                                HapticManager.shared.selection()
                            }
                            
                            StaticPlanCard(
                                name: "Yearly",
                                price: "$19.99",
                                subtitle: "Best Value · 7-Day Trial",
                                isSelected: selectedStaticPlan == "yearly",
                                textColor: dynamicText,
                                accentColor: dynamicAccent,
                                isNightTime: isNightTime
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedStaticPlan = "yearly"
                                }
                                HapticManager.shared.selection()
                            }
                            
                            StaticPlanCard(
                                name: "Lifetime",
                                price: "$39.99",
                                subtitle: "Pay once, own forever",
                                isSelected: selectedStaticPlan == "lifetime",
                                textColor: dynamicText,
                                accentColor: dynamicAccent,
                                isNightTime: isNightTime
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedStaticPlan = "lifetime"
                                }
                                HapticManager.shared.selection()
                            }
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
                    
                    // Subscribe Button
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
                        .shadow(color: dynamicAccent.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(isLoading || selectedPackage == nil)
                    .padding(.horizontal, 24)
                    
                    // Fine Print
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button("Restore") { restoreTapped() }
                            Text("·")
                            Link("Terms", destination: URL(string: "https://mochi.spent/terms")!)
                            Text("·")
                            Link("Privacy", destination: URL(string: "https://mochi.spent/privacy")!)
                        }
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(dynamicText.opacity(0.4))
                        
                        Text("Cancel anytime in the App Store.")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.3))
                    }
                    .padding(.bottom, 32)
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
    
    private var buttonLabel: String {
        // If real packages are loaded
        if let pkg = selectedPackage {
            if pkg.packageType == .annual {
                return "Start 7-Day Free Trial"
            } else {
                return "Get Mochi +"
            }
        }
        // Static fallback mode
        if let staticPlan = selectedStaticPlan {
            if staticPlan == "yearly" {
                return "Start 7-Day Free Trial"
            } else {
                return "Get Mochi +"
            }
        }
        return "Select a Plan"
    }
    
    private func subscribeTapped() {
        guard let package = selectedPackage else { return }
        isLoading = true
        HapticManager.shared.rigidImpact()
        
        Task {
            let success = await subscription.purchase(package: package)
            await MainActor.run {
                isLoading = false
                if success {
                    dismiss()
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
                    dismiss()
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
                    
                    if package.packageType == .annual {
                        Text("Best Value · 7-Day Trial")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? (isNightTime ? .black.opacity(0.6) : .white.opacity(0.7)) : accentColor)
                    }
                }
                
                Spacer()
                
                // Overriding price display for demo/test consistency as requested
                let displayPrice: String = {
                    switch package.packageType {
                    case .monthly: return "$2.99"
                    case .annual: return "$19.99"
                    case .lifetime: return "$39.99"
                    default: return package.localizedPriceString
                    }
                }()
                
                Text(displayPrice)
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

// MARK: - Static Plan Card (Fallback when RevenueCat not loaded)

struct StaticPlanCard: View {
    let name: String
    let price: String
    let subtitle: String?
    let isSelected: Bool
    let textColor: Color
    let accentColor: Color
    let isNightTime: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? (isNightTime ? .black : .white) : textColor)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(isSelected ? (isNightTime ? .black.opacity(0.6) : .white.opacity(0.7)) : accentColor)
                    }
                }
                
                Spacer()
                
                Text(price)
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
