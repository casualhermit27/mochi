import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subscription = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var selectedStaticPlan: StaticPlan? = .yearly
    @State private var packages: [Package] = []
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
        return Color(UIColor.systemBackground)
    }
    
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return .primary
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
                        
                        Spacer().frame(height: 20)
                        
                        // Logo + (centered)
                        HStack(alignment: .center, spacing: 4) {
                            Image("MochiLogo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            
                            Text("+")
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicAccent)
                        }
                        
                        Text("Unlock everything")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.5))
                    }
                    
                    // Features (minimal)
                    HStack(spacing: 24) {
                        FeatureIcon(icon: "clock.fill", label: "History", color: dynamicText)
                        FeatureIcon(icon: "paintbrush.fill", label: "Themes", color: dynamicText)
                        FeatureIcon(icon: "arrow.up.doc.fill", label: "Export", color: dynamicText)
                        FeatureIcon(icon: "square.grid.2x2.fill", label: "Widget", color: dynamicText)
                    }
                    
                    // Widget Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Beautiful Home Screen Widgets")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(dynamicText.opacity(0.6))
                            .padding(.horizontal, 24)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                WidgetPreviewView(size: .small, theme: .pink)
                                WidgetPreviewView(size: .medium, theme: .blue)
                                WidgetPreviewView(size: .small, theme: .green)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20) // Space for shadow
                        }
                    }
                    
                    // Pricing Plans
                    VStack(spacing: 10) {
                        if packages.isEmpty {
                            // Fallback static plans
                            ForEach(StaticPlan.all) { plan in
                                StaticPlanCard(
                                    plan: plan,
                                    isSelected: selectedStaticPlan?.id == plan.id,
                                    textColor: dynamicText,
                                    accentColor: dynamicAccent,
                                    isNightTime: isNightTime
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedStaticPlan = plan
                                    }
                                    HapticManager.shared.selection()
                                }
                            }
                        } else {
                            // RevenueCat packages
                            ForEach(packages, id: \.identifier) { package in
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
                                    .tint(.white)
                            } else {
                                Text("Start Free Trial")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                        }
                        .foregroundColor(settings.colorTheme == "default" && !isNightTime ? .white : (isNightTime ? currentTheme.backgroundDark : .white))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(dynamicAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isLoading || (selectedPackage == nil && selectedStaticPlan == nil))
                    .padding(.horizontal, 24)
                    
                    // Fine Print
                    VStack(spacing: 6) {
                        if let pkg = selectedPackage {
                            Text("7 days free, then \(pkg.localizedPriceString)/\(periodLabel(for: pkg.packageType))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.4))
                        } else if let plan = selectedStaticPlan {
                            Text("7 days free, then \(plan.price)\(plan.period)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.4))
                        }
                        
                        HStack(spacing: 12) {
                            Button("Restore") { restoreTapped() }
                            Text("·")
                            Button("Terms") { }
                            Text("·")
                            Button("Privacy") { }
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(dynamicText.opacity(0.3))
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .preferredColorScheme(isNightTime ? .dark : .light)
        .task {
            await loadOfferings()
        }
    }
    
    private func loadOfferings() async {
        await subscription.fetchOfferings()
        if let offering = subscription.currentOffering {
            packages = offering.availablePackages
            // Select yearly by default
            selectedPackage = offering.annual ?? offering.availablePackages.first
        }
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

    private func periodLabel(for type: PackageType) -> String {
        switch type {
        case .monthly: return "month"
        case .annual: return "year"
        case .weekly: return "week"
        case .lifetime: return "lifetime"
        case .sixMonth: return "6 months"
        case .threeMonth: return "3 months"
        case .twoMonth: return "2 months"
        default: return "period"
        }
    }
}

// MARK: - Feature Icon (Minimal)

// MARK: - Feature Icon (Minimal)

struct FeatureIcon: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(color.opacity(0.8))
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.6))
        }
    }
}

// MARK: - Package Card (RevenueCat)

// MARK: - Package Card (RevenueCat)

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
    
    var badge: String? {
        switch package.packageType {
        case .annual: return "BEST VALUE"
        case .lifetime: return "FOREVER"
        default: return nil
        }
    }
    
    // Computed colors for contrast
    var activeTextColor: Color {
        if isSelected && isNightTime {
            return Color.black.opacity(0.8)
        }
        return textColor
    }
    
    var activeBackgroundColor: Color {
        if isSelected {
            return Color.white
        } else {
            return isNightTime ? Color.white.opacity(0.12) : Color.white.opacity(0.6)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(packageName)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(activeTextColor)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                        }
                    }
                    
                    if package.packageType == .annual {
                        Text("Save 14%")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(activeTextColor.opacity(0.6))
                    } else if package.packageType == .lifetime {
                        Text("Pay once, own forever")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(activeTextColor.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(package.localizedPriceString)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(activeTextColor)
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? accentColor : activeTextColor.opacity(0.15))
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(activeBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accentColor.opacity(0.5) : activeTextColor.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Static Plan Model (Fallback)

struct StaticPlan: Identifiable, Equatable {
    let id: String
    let name: String
    let price: String
    let period: String
    let badge: String?
    let savings: String?
    
    static let monthly = StaticPlan(
        id: "monthly",
        name: "Monthly",
        price: "$2.99",
        period: "/month",
        badge: nil,
        savings: nil
    )
    
    static let yearly = StaticPlan(
        id: "yearly",
        name: "Yearly",
        price: "$30.99",
        period: "/year",
        badge: "BEST VALUE",
        savings: "Save 14%"
    )
    
    static let lifetime = StaticPlan(
        id: "lifetime",
        name: "Lifetime",
        price: "$49.99",
        period: " once",
        badge: "FOREVER",
        savings: "Pay once, own forever"
    )
    
    static let all: [StaticPlan] = [monthly, yearly, lifetime]
}

// MARK: - Static Plan Card (Fallback)

struct StaticPlanCard: View {
    let plan: StaticPlan
    let isSelected: Bool
    let textColor: Color
    let accentColor: Color
    let isNightTime: Bool
    let action: () -> Void
    
    // Computed colors for contrast
    var activeTextColor: Color {
        if isSelected && isNightTime {
            return Color.black.opacity(0.8)
        }
        return textColor
    }
    
    var activeBackgroundColor: Color {
        if isSelected {
            return Color.white
        } else {
            return isNightTime ? Color.white.opacity(0.12) : Color.white.opacity(0.6)
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(activeTextColor)
                        
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(accentColor)
                        }
                    }
                    
                    if let savings = plan.savings {
                        Text(savings)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(activeTextColor.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(plan.price)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(activeTextColor)
                
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? accentColor : activeTextColor.opacity(0.15))
                    .padding(.leading, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(activeBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? accentColor.opacity(0.5) : activeTextColor.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
