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
    @State private var showNoDataAlert = false
    
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
                            .frame(maxHeight: UIWindowScene.screenBounds.height * 0.75)
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
            .padding(.bottom, 12)
            .shadow(color: Color.black.opacity(0.12), radius: 32, x: 0, y: 16)
        }
        .contentShape(Rectangle()) // allow gesture on entire space
        .gesture(
            DragGesture()
                .onEnded { value in
                    // slide left to go back
                    if value.translation.width > 50 && currentPage > 0 {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage -= 1
                        }
                    }
                }
        )
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
        VStack(alignment: .leading, spacing: 32) {
            
            AnimatedHeroView(
                chunks: [
                    .text("Hi, I'm ", isHighlight: false),
                    .text("Mochi\u{00A0}", isHighlight: true),
                    .mascot("MochiCharacter"),
                    .newline,
                    .text("I'll help you track your spending effortlessly. ", isHighlight: false),
                    .text("A simple space for ", isHighlight: false),
                    .text("you.", isHighlight: true)
                ],
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                startDelay: 0.1
            )
            .padding(.bottom, 16)
            
            // Button Group
            VStack(spacing: 8) {
                nextButton(text: "Continue")
                    .accessibilityIdentifier("onboarding_continue_button")
                
                skipButton
                    .accessibilityIdentifier("onboarding_skip_button")
            }
            .padding(.top, 12)
            .opacity(buttonAppeared ? 1 : 0)
            .offset(y: buttonAppeared ? 0 : 20)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
    

    
    // MARK: - Page 3: Track Spending
    
    private var trackSpendingPage: some View {
        VStack(alignment: .leading, spacing: 32) {
            AnimatedHeroView(
                chunks: [
                    .text("Built for ", isHighlight: false),
                    .text("speed ⚡\u{00A0}", isHighlight: true),
                    .newline,
                    .text("No fluff, just flow. Open\u{00A0}", isHighlight: false),
                    .image("MochiLogo"),
                    .text(",\u{00A0}Log\u{00A0}", isHighlight: false),
                    .button("I Spent", buttonColor),
                    .text(",\u{00A0}and Close\u{00A0}", isHighlight: true),
                    .iconButton("xmark", textPrimary.opacity(0.1)),
                    .text(". We'll handle the numbers.", isHighlight: false)
                ],
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                startDelay: 0.1
            )
            .padding(.bottom, 16)
            
            // Button Group
            VStack(spacing: 8) {
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
                        .frame(height: 56)
                        .frame(maxWidth: .infinity)
                        .background(buttonColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                
                skipButton
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
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
        VStack(alignment: .leading, spacing: 32) {
            
            AnimatedHeroView(
                chunks: [
                    .text("Keep your history ", isHighlight: false),
                    .text("safe 🔒 ", isHighlight: true),
                    .text("Enable\u{00A0}", isHighlight: false),
                    .icon("icloud.fill", textPrimary),
                    .text("\u{00A0}iCloud ", isHighlight: true),
                    .text("to perfectly sync or ", isHighlight: false),
                    .text("restore\u{00A0}", isHighlight: true),
                    .icon("arrow.triangle.2.circlepath", textPrimary),
                    .text("\u{00A0}it securely.", isHighlight: false)
                ],
                textPrimary: textPrimary,
                textSecondary: textSecondary,
                startDelay: 0.1
            )
            .padding(.bottom, 16)
            
            VStack(spacing: 12) {
                if !settings.iCloudSyncEnabled {
                    Button(action: {
                        HapticManager.shared.success()
                        settings.iCloudSyncEnabled = true
                        CloudSyncManager.shared.startSyncing()
                    }) {
                        Text("Enable iCloud Sync")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .foregroundColor(isDarkMode ? .black : .white)
                            .frame(height: 56)
                            .frame(maxWidth: .infinity)
                            .background(accentGreen)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                } else {
                    Button(action: {
                        HapticManager.shared.rigidImpact()
                        isRestoringCloudData = true
                        
                        Task {
                            let hasData = CloudSyncManager.shared.forceRestore()
                            try? await Task.sleep(nanoseconds: 1_200_000_000)
                            await MainActor.run {
                                isRestoringCloudData = false
                                if hasData {
                                    completeOnboarding()
                                } else {
                                    showNoDataAlert = true
                                }
                            }
                        }
                    }) {
                        HStack {
                            if isRestoringCloudData {
                                MochiSpinner(size: 20)
                                    .padding(.trailing, 4)
                            }
                            Text("Restore from iCloud")
                        }
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
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 48)
        .alert("No Data Found", isPresented: $showNoDataAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("We couldn't find any Mochi data in your iCloud account.")
        }
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
