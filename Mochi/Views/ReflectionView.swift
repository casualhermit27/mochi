import SwiftUI

// MARK: - Reflection Data Model
struct ReflectionData: Identifiable {
    let id = UUID()
    let type: ReflectionType
    let timeLabel: String        // "Today", "This Week"
    let currencySymbol: String  // ₹, $, etc.
    let amount: String          // "480"
    let primaryText: String     // "You spent"
    let secondaryText: String?  // Optional context
    
    enum ReflectionType {
        case daily
        case weekly
    }
}

// MARK: - Reflection View
struct ReflectionView: View {
    
    let data: ReflectionData
    var onDismiss: () -> Void
    var onViewHistory: (() -> Void)? = nil
    
    @ObservedObject var settings = SettingsManager.shared
    @State private var appear = false
    
    // MARK: - Theme Helpers
    
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    var backgroundColor: Color {
        if settings.themeMode == "amoled" { return .black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var textColor: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return isNightTime ? .white : .black
    }
    
    var accentColor: Color {
        if settings.colorTheme == "default" {
            return isNightTime
                ? Color(red: 0.45, green: 0.85, blue: 0.75)
                : Color(red: 0.25, green: 0.6, blue: 0.55)
        }
        return currentTheme.accent
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            // Mascot - Peeking from bottom left
            VStack {
                Spacer()
                HStack {
                    Image("MochiCharacter")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 300)
                        .rotationEffect(.degrees(15)) // Tilt to face top right
                        .offset(x: -120, y: 100) // Half outside screen
                        .shadow(color: accentColor.opacity(0.05), radius: 40, x: 20, y: -10)
                        .opacity(appear ? 0.7 : 0) // Reduced opacity
                    Spacer()
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Header
                Text(data.timeLabel.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(textColor.opacity(0.5))
                    .tracking(3)
                    .padding(.top, 80)
                    .opacity(appear ? 1 : 0)
                
                Spacer()
                
                // Center Content (Vertically Centered)
                VStack(spacing: 20) {
                    Text(data.primaryText)
                        .font(.system(size: 26, weight: .medium, design: .monospaced))
                        .foregroundColor(textColor.opacity(0.6))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(data.currencySymbol)
                            .font(.system(size: 48, weight: .medium, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.5))
                        
                        Text(data.amount)
                            .font(.system(size: 104, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    
                    if let secondary = data.secondaryText {
                        Text(secondary)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(textColor.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 48)
                            .lineSpacing(6)
                    }
                }
                .padding(.bottom, 60) // Offset slightly for visual balance against the actions
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                
                Spacer()
                
                // Action Bottom
                VStack(spacing: 28) {
                    if let onViewHistory {
                        Button {
                            HapticManager.shared.softSquish()
                            onViewHistory()
                        } label: {
                            HStack(spacing: 10) {
                                Text("Open History")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(accentColor.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Button {
                        HapticManager.shared.softSquish()
                        onDismiss()
                    } label: {
                        Text("Tap to Dismiss")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(textColor.opacity(0.3))
                    }
                }
                .padding(.bottom, 50)
                .opacity(appear ? 1 : 0)
            }
            
            // Close button (Top Right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.softSquish()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(textColor.opacity(0.3))
                            .padding(20)
                            .background(Circle().fill(textColor.opacity(0.06)))
                            .padding(24)
                    }
                }
                Spacer()
            }
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                appear = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ReflectionView(
        data: ReflectionData(
            type: .daily,
            timeLabel: "Today",
            currencySymbol: "₹",
            amount: "480",
            primaryText: "You spent",
            secondaryText: "A bit higher than your usual daily spending."
        ),
        onDismiss: {},
        onViewHistory: {}
    )
}

