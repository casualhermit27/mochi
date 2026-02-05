import SwiftUI
import SwiftData
import WidgetKit
import StoreKit

// MARK: - Theme & Extensions
// Moved to Util/ColorExtensions.swift


struct MainContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var notificationManager = NotificationManager.shared
    
    @State private var showHistory = false
    @State private var showToast = false
    @State private var toastMessage = "Mochi eaten."
    @State private var showAddedAnimation = false
    @State private var addedAmount: Double = 0
    @State private var isNegativeDelta = false
    @State private var sessionDeletedAmount: Double = 0
    
    // Input State
    @State private var isInputActive = false
    @State private var currentInput = "0"
    
    // Undo State (Add)
    @State private var lastAddedItem: Item?
    @State private var lastAddedTime: Date?
    
    // Animation states
    @State private var numberScale: CGFloat = 1.0
    @State private var breathingScale: CGFloat = 1.0
    @State private var wiggleOffset: CGFloat = 0
    @State private var sideAddOffset: CGFloat = 0
    @State private var shakeRippleScale: CGFloat = 0
    @State private var shakeRippleOpacity: Double = 0
    
    // Payment Method Selector
    @State private var showPaymentSelector = false
    @State private var showPaymentMethods = false
    

    
    var dailyTotal: Double {
        let currentRitualDay = settings.getRitualDay(for: Date())
        let todayItems = items.filter { settings.getRitualDay(for: $0.timestamp) == currentRitualDay }
        return todayItems.reduce(0) { $0 + $1.amount }
    }
    
    var yesterdayTotal: Double {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayRitualDay = settings.getRitualDay(for: yesterday)
        let yesterdayItems = items.filter { settings.getRitualDay(for: $0.timestamp) == yesterdayRitualDay }
        return yesterdayItems.reduce(0) { $0 + $1.amount }
    }
    
    func updateWidgetData(includeLastTransaction: Bool = true) {
        let lastItem = items.first
        let lastTransactionAmount = lastItem?.amount ?? 0
        let lastTransactionNote = lastItem?.note ?? ""
        
        WidgetDataManager.shared.updateWidgetData(
            todayTotal: dailyTotal,
            yesterdayTotal: yesterdayTotal,
            lastTransaction: includeLastTransaction ? lastTransactionAmount : nil,
            lastTransactionNote: includeLastTransaction ? lastTransactionNote : nil,
            currencySymbol: settings.currencySymbol,
            colorTheme: settings.colorTheme,
            themeMode: settings.themeMode,
            isPro: SubscriptionManager.shared.isPro
        )
        // Refresh widgets immediately
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    static func reloadWidget() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    var isEffectivelyInputting: Bool {
        return isInputActive && currentInput != "0"
    }
    
    var displayValue: String {
        // Show input only if active and not just "0"
        if isEffectivelyInputting {
            return currentInput
        } else {
            return dailyTotal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dailyTotal) : String(format: "%.2f", dailyTotal)
        }
    }
    
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default: return "Midnight mochi."
        }
    }
    
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        
        // If using a pastel theme (not default), use its colors
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.height < -50 {
                    HapticManager.shared.softSquish()
                    showHistory = true
                }
            }
    }
    
    var dynamicText: Color {
        // If using a pastel theme (not default), use its colors
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        
        return isNightTime ? Color.mochiBackground : Color.mochiText
    }
    
    var dynamicSecondary: Color {
        dynamicText.opacity(0.6)
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return isNightTime ? Color.mochiBlueDark : Color.mochiRose
    }
    
    var doneButtonColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        // Use Rose for light mode, but a brighter "Blue" for dark mode contrast
        return isNightTime ? Color.mochiBlueDark : Color.mochiRose
    }
    
    var doneButtonTextColor: Color {
        isNightTime ? Color.black : Color.mochiText
    }

    private var isTrialOver: Bool {
        return settings.daysSinceFirstUse >= 3 && !SubscriptionManager.shared.isPro
    }

    var body: some View {
        ZStack {
            // Background with smooth theme transition
            dynamicBackground.ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: isNightTime)
                .animation(.easeInOut(duration: 0.6), value: settings.themeMode)
            
            // Shake Ripple Effect
            Circle()
                .fill(dynamicText.opacity(0.08))
                .scaleEffect(shakeRippleScale)
                .opacity(shakeRippleOpacity)
                .allowsHitTesting(false)
            
            VStack(spacing: 0) {
                // Header (Greeting + History)
                HStack {
                    Text(greeting)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(dynamicSecondary)
                        .padding(.leading, 24)
                    
                    Spacer()
                    
                    // History Button (Only clock now, toggle moved to settings)
                    Button(action: {
                        HapticManager.shared.softSquish()
                        showHistory = true
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(dynamicSecondary)
                            .padding(.trailing, 24)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 10)
                
                Spacer(minLength: 12)
                    .frame(maxHeight: 32)
                
                // Display
                ZStack {
                    HStack(spacing: 4) {
                        // Currency Symbol (Subtle)
                        Text(settings.currencySymbol)
                            .font(.system(size: 48, weight: .medium, design: .monospaced))
                            .foregroundColor(isEffectivelyInputting ? dynamicText : accentColor.opacity(0.55))
                        
                        Text(displayValue)
                            .font(.system(size: 108, weight: .medium, design: .monospaced))
                            .foregroundColor(isEffectivelyInputting ? dynamicText : accentColor.opacity(0.55))
                    }
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .padding(.horizontal)
                    .scaleEffect(numberScale)
                    .scaleEffect(breathingScale)
                    .offset(x: wiggleOffset)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: numberScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: displayValue)
                    .contentTransition(.numericText(countsDown: false))
                    
                    // Side Adding Animation
                    if showAddedAnimation {
                        let formattedAmount = addedAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", addedAmount) : String(format: "%.2f", addedAmount)
                        Text("\(isNegativeDelta ? "-" : "+") \(formattedAmount)")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundColor(isNegativeDelta ? .mochiBrickRed : .mochiGreen)
                            .offset(x: 0, y: -80)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .scale(scale: 0.8)).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxHeight: 200)
                
                // Label indicating state
                if !isEffectivelyInputting && dailyTotal > 0 {
                    Text("Total Spent Today")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(dynamicSecondary)
                        .padding(.top, -10)
                        .transition(.opacity)
                }
                
                Spacer()
                
                // Payment Method Selector (Subtle, appears when inputting)
                if isEffectivelyInputting || showPaymentSelector {
                    PaymentMethodSelector(
                        isVisible: $showPaymentSelector,
                        dynamicText: dynamicText,
                        dynamicBackground: dynamicBackground,
                        accentColor: accentColor,
                        onAddRequest: {
                            showPaymentMethods = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                    .padding(.bottom, 12)
                }
                
                // Keypad
                KeypadView(onTap: handleKeypadInput, textColor: dynamicText)
                    .padding(.bottom, 20)
                
                // Done Button
                Button(action: saveEntry) {
                    Text("I Spent")
                        .font(.system(size: 20, weight: .semibold, design: .monospaced))
                        .foregroundColor(doneButtonTextColor)
                        .frame(width: 140, height: 60)
                        .background(doneButtonColor)
                        .clipShape(Capsule())
                }
                .disabled(!isInputActive)
                .padding(.bottom, 40)
            }
            
            // Trial Completed Block
            if isTrialOver {
                TrialCompletedOverlay(
                    dynamicText: dynamicText, 
                    dynamicBackground: dynamicBackground, 
                    accentColor: accentColor, 
                    isNightTime: isNightTime
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
            
            // Toast
            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(dynamicText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 130)
                }
                .zIndex(100)
            }
        }
        .simultaneousGesture(dragGesture)
        .sheet(isPresented: $showHistory) {
            HistoryView(sessionDeletedAmount: $sessionDeletedAmount, isNightTime: isNightTime)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showPaymentMethods) {
            NavigationStack {
                PaymentMethodsView(dynamicText: dynamicText)
            }
            .presentationDetents([.large])
            .presentationCornerRadius(32)
            .presentationBackground(dynamicBackground)
            .preferredColorScheme(isNightTime ? .dark : .light)
        }
        .onChange(of: notificationManager.shouldDismissAllSheets) { _, shouldDismiss in
            if shouldDismiss {
                showHistory = false
                showPaymentMethods = false
            }
        }
        .onChange(of: showHistory) { _, isPresented in
            if !isPresented && sessionDeletedAmount > 0 {
                // Return from History with deletions
                addedAmount = sessionDeletedAmount
                isNegativeDelta = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showAddedAnimation = true
                }
                sessionDeletedAmount = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showAddedAnimation = false }
                }
            }
        }
        .onAppear {
            // Start Breathing Animation
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                breathingScale = 1.02
            }
            // Update widget data
            updateWidgetData()
        }
        .onChange(of: items.count) { oldValue, newValue in
            // Update widget when items change
            // If deleting (newValue < oldValue), we let HistoryView (or delete handler) set the "Removed" state.
            // But we MUST update Totals. We pass false to avoid overwriting the "Removed" note with the old transaction.
            if newValue < oldValue {
                updateWidgetData(includeLastTransaction: false)
            } else {
                updateWidgetData(includeLastTransaction: true)
            }
        }
        .onChange(of: settings.colorTheme) { _, _ in updateWidgetData() }
        .onChange(of: settings.themeMode) { _, _ in updateWidgetData() }
        .onChange(of: settings.customCurrencyCode) { _, _ in updateWidgetData() }
        .onShake {
            undoLastAdd()
        }
        .onChange(of: notificationManager.shouldOpenHistory) { _, shouldOpen in
            if shouldOpen {
                notificationManager.shouldOpenHistory = false
                showHistory = true
            }
        }
    }

    private func handleKeypadInput(_ key: String) {
        HapticManager.shared.softSquish()
        
        // Start Input Mode on first tap
        if !isInputActive {
            isInputActive = true
            currentInput = "0"
            // If they tap a number, replace 0. If backspace, ignore?
        }
        
        // Subtle Bounce effect
        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
            numberScale = 1.04
        }
        
        // Input logic
        if key == "backspace" {
            if currentInput.count > 1 {
                currentInput.removeLast()
            } else {
                currentInput = "0"
                withAnimation { isInputActive = false }
            }
        } else if key == "." {
            if !currentInput.contains(".") {
                currentInput += "."
            }
        } else {
            if currentInput == "0" {
                currentInput = key
            } else if currentInput.count < 9 {
                currentInput += key
            }
        }
        
        // Reset scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                numberScale = 1.0
            }
        }
        

    }
    
    private func saveEntry() {
        guard let amount = Double(currentInput), amount > 0 else {
            // Error Wiggle
            HapticManager.shared.softSquish() // Error haptic (double tap feels like error)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { HapticManager.shared.softSquish() }
            
            withAnimation(.default) {
                wiggleOffset = 10
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.2).delay(0.05)) {
                wiggleOffset = 0
            }
            return
        }
        
        HapticManager.shared.rigidImpact()
        
        let methodId = settings.selectedPaymentMethod.id.uuidString
        let newItem = Item(timestamp: Date(), amount: amount, paymentMethodId: methodId)
        modelContext.insert(newItem)
        
        // Update Undo State
        lastAddedItem = newItem
        lastAddedTime = Date()
        
        // Show Animation
        addedAmount = amount
        isNegativeDelta = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showAddedAnimation = true
        }
        
        // Reset Input
        HapticManager.shared.selection() // Just a subtle tap when resetting, or nothing. Let's stick to just the cash sound earlier.
        toastMessage = "Mochi eaten." // Reset message
        
        withAnimation {
            isInputActive = false // Go back to Total view
            currentInput = "0"
        }
        
        // Hide Animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { showAddedAnimation = false; showToast = false }
        }
        
        // Review Request Logic
        let count = items.count + 1 // +1 because the query updates asynchronously usually, or we just count this one
        if [5, 20, 50].contains(count) {
             if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                 SKStoreReviewController.requestReview(in: scene)
             }
        }
    }
    
    private func undoLastAdd() {
        guard let item = lastAddedItem, let time = lastAddedTime else { return }
        
        // 6 Seconds Limit
        if Date().timeIntervalSince(time) < 6 {
            HapticManager.shared.softSquish()
            
            // Trigger Ripple Effect
            shakeRippleScale = 0.1
            shakeRippleOpacity = 0.6
            withAnimation(.easeOut(duration: 0.8)) {
                shakeRippleScale = 3.0
                shakeRippleOpacity = 0
            }
            
            // Show Animation (Negative)
            addedAmount = item.amount
            isNegativeDelta = true
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showAddedAnimation = true
            }
            
            // Delete the item
            modelContext.delete(item)
            
            // Show Feedback
            toastMessage = "Undo successful."
            withAnimation {
                showToast = true
                currentInput = String(format: "%.0f", item.amount) // Optional: Restore Input
                lastAddedItem = nil // Prevent double undo
                lastAddedTime = nil
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { 
                withAnimation { showToast = false; showAddedAnimation = false } 
            }
        }
    }
}

// MARK: - Trial Completed Component
struct TrialCompletedOverlay: View {
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    let isNightTime: Bool
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Icon
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(accentColor)
                }
                .padding(.top, 40)
                
                VStack(spacing: 12) {
                    Text("Trial Completed")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    
                    Text("You've used Mochi for 3 days.\nUpgrade to keep your data and unlock all features.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(dynamicText.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        HapticManager.shared.rigidImpact()
                        SubscriptionManager.shared.showPaywall = true
                    }) {
                        HStack {
                            Text("Upgrade to Mochi +")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(isNightTime ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    
                    Button(action: {
                        HapticManager.shared.softSquish()
                        Task {
                            await SubscriptionManager.shared.restorePurchases()
                        }
                    }) {
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.4))
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Fine print
                Text("Your history is safe. Unlock it anytime.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.3))
                    .padding(.bottom, 40)
            }
        }
    }
}
