import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    
    @State private var currentPage = 0
    @State private var showPaywall = false
    
    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var buttonAppeared = false
    
    private let totalPages = 5
    
    // Colors
    private let creamBackground = Color.mochiBackground
    private let textPrimary = Color.mochiText
    private let textSecondary = Color.mochiText.opacity(0.45)
    private let accentGreen = Color.mochiGreen
    private let buttonColor = Color.mochiRose
    
    var body: some View {
        ZStack {
            // Cream background
            creamBackground.ignoresSafeArea()
            
            // Subtle floating shapes in background
            floatingShapes
            
            VStack(spacing: 0) {
                // Page Indicator at top
                pageIndicator
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                
                // Page Content
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    privacyPage.tag(1)
                    trackSpendingPage.tag(2)
                    cardsHistoryPage.tag(3)
                    widgetUpgradePage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.5), value: currentPage)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationCornerRadius(32)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: currentPage) { _, _ in
            HapticManager.shared.lightImpact()
        }
    }
    
    // MARK: - Floating Background Shapes
    
    private var floatingShapes: some View {
        GeometryReader { geo in
            ZStack {
                // Top right - rose
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.mochiRose.opacity(0.4), Color.mochiRose.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.35 + floatingOffset)
                
                // Bottom left - sage
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.mochiSage.opacity(0.5), Color.mochiSage.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: -geo.size.width * 0.35, y: geo.size.height * 0.3 - floatingOffset * 0.7)
                
                // Center right - blue accent
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.mochiBlue.opacity(0.3), Color.mochiBlue.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.1 + floatingOffset * 0.5)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: floatingOffset)
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(currentPage >= index ? textPrimary : textPrimary.opacity(0.12))
                    .frame(width: currentPage == index ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title with subtle animation
            Text("Hello.")
                .font(.system(size: 52, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary)
                .scaleEffect(breathingScale)
                .padding(.bottom, 40)
            
            // Logo with glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(buttonColor.opacity(0.25))
                    .frame(width: 180, height: 180)
                    .blur(radius: 40)
                
                // Inner glow
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image("MochiLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: textPrimary.opacity(0.1), radius: 24, y: 12)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
            .padding(.bottom, 44)
            
            // Description
            VStack(spacing: 8) {
                Text("I am Mochi.")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
                
                Text("The mindful way to\ntrack your spending.")
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
            .opacity(contentOpacity)
            
            Spacer()
            
            // Button
            nextButton(text: "Nice to meet you")
                .opacity(buttonAppeared ? 1 : 0)
                .offset(y: buttonAppeared ? 0 : 20)
            
            skipButton
                .opacity(buttonAppeared ? 1 : 0)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 56)
    }
    
    // MARK: - Page 2: Privacy
    
    private var privacyPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 2) {
                Text("Your money.")
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
                
                Text("Your business.")
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
            }
            .padding(.bottom, 44)
            
            // Illustration
            ZStack {
                // Background Circle (Subtle)
                Circle()
                    .stroke(textPrimary.opacity(0.1), lineWidth: 1)
                    .frame(width: 140, height: 140)
                
                // Lock Icon (Central)
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(textPrimary)
                
                // Floating Data Particles (Orbiting)
                ForEach(0..<6) { i in
                    Circle()
                        .fill(i % 2 == 0 ? Color.mochiSage : Color.mochiRose)
                        .frame(width: 8, height: 8)
                        .offset(y: -70)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .rotationEffect(.degrees(buttonAppeared ? 360 : 0)) // Subtle rotation if needed, or static
                }
            }
            .padding(.bottom, 50)
            
            // Privacy Points
            VStack(alignment: .leading, spacing: 14) {
                privacyPoint(text: "No bank syncing")
                privacyPoint(text: "No data sharing")
                privacyPoint(text: "No clutter")
            }
            .padding(.bottom, 20)
            
            Text("Just you and your numbers.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(textSecondary)
            
            Spacer()
            
            nextButton(text: "Love that")
            
            skipButton
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 56)
    }
    
    // MARK: - Page 3: Track Spending
    
    private var trackSpendingPage: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Good morning.")
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(textSecondary)
                
                Spacer()
                
                Image(systemName: "clock")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            Spacer()
            
            // Amount Display
            HStack(spacing: 2) {
                Text(settings.currencySymbol)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary.opacity(0.35))
                
                Text("42")
                    .font(.system(size: 72, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
            }
            .padding(.bottom, 8)
            
            Text("Tap. Log. Done.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)
                .tracking(1)
            
            Spacer()
            
            // Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 12) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 26, weight: .medium, design: .monospaced))
                        .foregroundColor(textPrimary)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 48)
            
            Spacer()
            
            // I Spent button as next
            Button(action: {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            }) {
                Text("I Spent")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(textPrimary)
                    .frame(width: 140, height: 58)
                    .background(buttonColor)
                    .clipShape(Capsule())
                    .shadow(color: buttonColor.opacity(0.35), radius: 16, y: 8)
            }
            .buttonStyle(SquishyButtonStyle(isDoneButton: true))
            .buttonStyle(SquishyButtonStyle(isDoneButton: true))
            
            skipButton
                .padding(.bottom, 24)
        }
    }
    
    // MARK: - Page 4: Cards & History
    
    private var cardsHistoryPage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 2) {
                Text("Organize")
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
                
                Text("everything.")
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
            }
            .padding(.bottom, 44)
            
            // Cards Fan
            HStack(spacing: -8) {
                cardPreview(icon: "banknote.fill", color: Color.mochiSage)
                    .rotationEffect(.degrees(-6))
                    .offset(y: 8)
                
                cardPreview(icon: "creditcard.fill", color: Color.mochiBlue)
                    .scaleEffect(1.08)
                    .zIndex(1)
                
                cardPreview(icon: "plus", color: Color.mochiRose)
                    .rotationEffect(.degrees(6))
                    .offset(y: 8)
            }
            .padding(.bottom, 44)
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                featureRow(icon: "creditcard.and.123", text: "Track by card or cash")
                featureRow(icon: "arrow.up", text: "Swipe up for history")
                featureRow(icon: "tag.fill", text: "Add notes to expenses")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            nextButton(text: "Neat")
            
            skipButton
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 56)
    }
    
    // MARK: - Page 5: Widget + Upgrade
    
    private var widgetUpgradePage: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Title
            VStack(spacing: 6) {
                Text("Mochi+")
                    .font(.system(size: 34, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
                
                Text("Unlock the full experience.")
                    .font(.system(size: 15, weight: .regular, design: .monospaced))
                    .foregroundColor(textSecondary)
            }
            .padding(.bottom, 32)
            
            // Bento Grid Feature Layout
            VStack(spacing: 12) {
                // Top Row: Large Widgets Card
                bentoCard(title: "Widgets", size: .large) {
                    ZStack {
                        // Medium Widget (Back)
                        WidgetPreviewView(size: .medium, theme: .green, isDark: false)
                            .scaleEffect(0.8)
                            .rotationEffect(.degrees(-2))
                            .offset(y: -10)
                            .shadow(color: textPrimary.opacity(0.1), radius: 12, y: 6)
                        
                        // Small Widget (Front)
                        WidgetPreviewView(size: .small, theme: .pink, isDark: false)
                            .scaleEffect(0.8)
                            .rotationEffect(.degrees(3))
                            .offset(x: 80, y: 30)
                            .shadow(color: textPrimary.opacity(0.15), radius: 16, y: 8)
                    }
                    .frame(height: 180)
                }
                
                // Bottom Row: Two Smaller Cards
                HStack(spacing: 12) {
                    // Themes
                    bentoCard(title: "Themes", size: .small) {
                        HStack(spacing: -12) {
                            Circle().fill(Color.mochiRose).frame(width: 44, height: 44)
                            Circle().fill(Color.mochiSage).frame(width: 44, height: 44)
                            Circle().fill(Color.mochiBlue).frame(width: 44, height: 44)
                        }
                        .shadow(color: textPrimary.opacity(0.1), radius: 10, y: 5)
                    }
                    
                    // Export
                    bentoCard(title: "Export", size: .small) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 42))
                            .foregroundColor(textPrimary.opacity(0.7))
                            .rotationEffect(.degrees(-8))
                            .shadow(color: textPrimary.opacity(0.1), radius: 10, y: 5)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 14) {
                Button(action: {
                    HapticManager.shared.success()
                    SubscriptionManager.shared.startLocalTrial()
                    completeOnboarding()
                }) {
                    HStack(spacing: 10) {
                        Text("Start 3-Day Free Trial")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(creamBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(accentGreen)
                    .clipShape(Capsule())
                    .shadow(color: accentGreen.opacity(0.35), radius: 16, y: 8)
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                
                Button(action: {
                    HapticManager.shared.softSquish()
                    completeOnboarding()
                }) {
                    Text("Start Using")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
    
    enum BentoSize {
        case small, large
    }
    
    private func bentoCard<Content: View>(title: String, size: BentoSize, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .bottomLeading) {
            
            // Content
            ZStack {
                Color.white.opacity(0.6) // More subtle background
                content()
            }
            .frame(maxWidth: .infinity)
            .frame(height: size == .large ? 200 : 140) // Taller cards
            
            // Minimal Title Overlay
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)
                .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Components
    
    private func nextButton(text: String) -> some View {
        Button(action: {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentPage += 1
            }
        }) {
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(textPrimary)
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(buttonColor)
                .clipShape(Capsule())
                .shadow(color: buttonColor.opacity(0.3), radius: 14, y: 7)
        }
        .buttonStyle(SquishyButtonStyle(isDoneButton: true))
        .padding(.horizontal, 16)
    }
    
    private func privacyPoint(text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.mochiBrickRed.opacity(0.6))
                .frame(width: 20, height: 20)
                .background(Color.mochiBrickRed.opacity(0.1))
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary.opacity(0.7))
                .strikethrough(color: textSecondary)
        }
    }
    
    private func cardPreview(icon: String, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(color)
            .frame(width: 72, height: 52)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(textPrimary.opacity(0.55))
            )
            .shadow(color: color.opacity(0.4), radius: 10, y: 5)
    }
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(accentGreen)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary.opacity(0.8))
            
            Spacer()
        }
    }
    
    private func proFeature(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentGreen.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accentGreen)
            }
            
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Logo entrance
        withAnimation(.spring(response: 0.9, dampingFraction: 0.6).delay(0.3)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Content fade
        withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
            contentOpacity = 1.0
        }
        
        // Button slide up
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8)) {
            buttonAppeared = true
        }
        
        // Floating blobs
        floatingOffset = 30
        
        // Subtle breathing
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            breathingScale = 1.02
        }
    }
    
    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        dismiss()
    }
    private var skipButton: some View {
        Button(action: {
            HapticManager.shared.softSquish()
            completeOnboarding()
        }) {
            Text("Skip to Mochi")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary.opacity(0.8))
                .padding(.top, 12)
        }
    }
}

#Preview {
    OnboardingView()
}
