import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    
    @Environment(\.colorScheme) var colorScheme

    @State private var currentPage = 0
    @State private var hasConfirmedRestoreChoice = false
    
    // Animation states
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var floatingOffset: CGFloat = 0
    @State private var breathingScale: CGFloat = 1.0
    @State private var buttonAppeared = false
    @State private var isRestoringCloudData = false
    
    private var totalPages: Int {
        shouldShowRestorePage ? 5 : 4
    }
    
    private var shouldShowRestorePage: Bool {
        !items.isEmpty && !hasConfirmedRestoreChoice
    }
    
    // Colors
    private var isDarkMode: Bool { colorScheme == .dark }
    
    private var creamBackground: Color {
        isDarkMode ? Color.mochiText : Color.mochiBackground
    }
    
    private var textPrimary: Color {
        isDarkMode ? .white : .mochiText
    }
    
    private var textSecondary: Color {
        isDarkMode ? .white.opacity(0.6) : .mochiText.opacity(0.45)
    }
    
    private var accentGreen: Color {
        Color.mochiGreen
    }
    
    private var buttonColor: Color {
        Color.mochiRose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer() // Push the card to the bottom
            
            VStack(spacing: 0) {
                // Page Indicator at top
                pageIndicator
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                
                // Page Content
                Group {
                    if currentPage == -1 {
                        restorePage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else if currentPage == 0 {
                        welcomePage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else if currentPage == 1 {
                        trackSpendingPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else if currentPage == 2 {
                        paywallPage
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else if currentPage == 3 {
                        cloudSyncPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    }
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)
            }
            .frame(maxWidth: .infinity)
            .background(creamBackground)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
        }
        .onAppear {
            if shouldShowRestorePage {
                currentPage = -1
            }
            startAnimations()
        }
        .onChange(of: currentPage) { _, _ in
            HapticManager.shared.lightImpact()
        }
    }
    
    // MARK: - Page Indicator
    
    private var pageIndicator: some View {
        HStack(spacing: 6) {
            let pageRange = shouldShowRestorePage ? Array(-1...2) : Array(0...2)
            ForEach(pageRange, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(currentPage >= index ? textPrimary : textPrimary.opacity(0.12))
                    .frame(width: currentPage == index ? 20 : 6, height: 6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
            }
        }
        .opacity(currentPage == 3 ? 0 : 1)
    }
    
    // MARK: - Page 1: Emotional Hook
    
    private var welcomePage: some View {
        VStack(spacing: 0) {
            // Title with subtle animation
            Text("Calm spending\nawareness.")
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary)
                .multilineTextAlignment(.center)
                .scaleEffect(breathingScale)
                .padding(.bottom, 32)
            
            // Logo
            Image("MochiLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .padding(.bottom, 32)
            
            // Description
            Text("Mochi helps you log expenses quickly\nwithout turning budgeting into work.")
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .opacity(contentOpacity)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            
            // Button
            nextButton(text: "Continue")
                .accessibilityIdentifier("onboarding_continue_button")
                .opacity(buttonAppeared ? 1 : 0)
                .offset(y: buttonAppeared ? 0 : 20)
            
            skipButton
                .accessibilityIdentifier("onboarding_skip_button")
                .opacity(buttonAppeared ? 1 : 0)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
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
            .padding(.bottom, 32)
            
            // Amount Display
            HStack(spacing: 2) {
                Text(settings.currencySymbol)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary.opacity(0.35))
                
                Text("42")
                    .font(.system(size: 64, weight: .medium, design: .monospaced))
                    .foregroundColor(textPrimary)
            }
            .padding(.bottom, 8)
            
            Text("Tap. Log. Done.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)
                .tracking(1)
                .padding(.bottom, 32)
            
            // Keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 8) {
                ForEach(["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"], id: \.self) { key in
                    Text(key)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundColor(textPrimary)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
            
            // Next button
            Button(action: {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if SubscriptionManager.shared.isPro {
                        currentPage = 3 // skip paywall seamlessly
                    } else {
                        currentPage += 1
                    }
                }
            }) {
                Text("I Spent")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(textPrimary)
                    .frame(width: 140, height: 50)
                    .background(buttonColor)
                    .clipShape(Capsule())
            }
            .buttonStyle(SquishyButtonStyle(isDoneButton: true))
            
            skipButton
                .padding(.bottom, 24)
        }
        .padding(.top, 48)
        .padding(.bottom, 64)
    }
    
    
    // MARK: - Page 4: Paywall
    
    private var paywallPage: some View {
        PaywallView(
            isEmbedded: true,
            onComplete: {
                if SubscriptionManager.shared.isFullAccess {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage = 3
                    }
                } else {
                    completeOnboarding()
                }
            }
        )
    }

    // MARK: - Restore Page
    
    private var restorePage: some View {
        VStack(spacing: 0) {
            // Title
            Text("Welcome back.")
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)
            
            // Icon
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 50, weight: .light))
                .foregroundColor(accentGreen)
                .padding(.bottom, 24)
            
            // Description
            Text("We found \(items.count) past transactions on your device. Would you like to keep them?")
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            
            // Choices
            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.success()
                    withAnimation {
                        hasConfirmedRestoreChoice = true
                        currentPage = 0
                    }
                }) {
                    Text("Restore My History")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(isDarkMode ? .black : .white)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(accentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                
                Button(action: {
                    HapticManager.shared.softSquish()
                    deleteAllData()
                    withAnimation {
                        hasConfirmedRestoreChoice = true
                        currentPage = 0
                    }
                }) {
                    Text("Start Fresh")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(textPrimary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: false))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
    
    // MARK: - Page 5: Cloud Sync (Pro Only)

    private var cloudSyncPage: some View {
        VStack(spacing: 0) {
            Text("iCloud Sync.")
                .font(.system(size: 34, weight: .medium, design: .monospaced))
                .foregroundColor(textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 24)

            ZStack {
                Image(systemName: "icloud.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundColor(accentGreen.opacity(0.3))

                if isRestoringCloudData {
                    MochiSpinner(size: 28)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accentGreen)
                        .background(
                            Circle().fill(creamBackground).frame(width: 36, height: 36)
                        )
                        .offset(x: 20, y: 20)
                }
            }
            .padding(.bottom, 32)
            .animation(.default, value: isRestoringCloudData)

            Text("Enable iCloud to safely backup your data across devices, perfectly syncing your history. Returning members can restore their past records securely.")
                .font(.system(size: 15, weight: .regular, design: .monospaced))
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 16)
                .padding(.bottom, 40)

            VStack(spacing: 12) {
                Button(action: {
                    HapticManager.shared.rigidImpact()
                    isRestoringCloudData = true
                    
                    Task {
                        settings.iCloudSyncEnabled = true
                        CloudSyncManager.shared.forceRestore()
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        await MainActor.run {
                            isRestoringCloudData = false
                            completeOnboarding()
                        }
                    }
                }) {
                    Text("Enable & Restore")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(isDarkMode ? .black : .white)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(accentGreen)
                        .clipShape(Capsule())
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                .disabled(isRestoringCloudData)

                Button(action: {
                    HapticManager.shared.softSquish()
                    completeOnboarding()
                }) {
                    Text("Start Clean")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(textPrimary)
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(textPrimary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: false))
                .disabled(isRestoringCloudData)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
    }
    
    private func deleteAllData() {
        for item in items {
            modelContext.delete(item)
        }
        // Also reset widgets
        WidgetDataManager.shared.updateWidgetData(
            todayTotal: 0,
            yesterdayTotal: 0,
            lastTransaction: nil,
            lastTransactionNote: nil,
            currencySymbol: settings.currencySymbol,
            colorTheme: settings.colorTheme,
            themeMode: settings.themeMode,
            isPro: SubscriptionManager.shared.isPro,
            dayStartHour: settings.dayStartHour,
            dayStartMinute: settings.dayStartMinute
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
        }
        .buttonStyle(SquishyButtonStyle(isDoneButton: true))
        .padding(.horizontal, 16)
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
