import SwiftUI

struct PrivacyLockView: View {
    @ObservedObject var biometricManager = BiometricManager.shared
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var settings = SettingsManager.shared
    
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        if settings.themeMode == "auto" {
            let hour = Calendar.current.component(.hour, from: Date())
            return hour < 6 || hour >= 20
        }
        return colorScheme == .dark
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? settings.currentPastelTheme.backgroundDark : settings.currentPastelTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? settings.currentPastelTheme.textDark : settings.currentPastelTheme.text
        }
        return isNightTime ? Color.mochiBackground : Color.mochiText
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return isNightTime ? Color.mochiBlueDark : Color.mochiRose
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            // Subtle blur over the background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(accentColor)
                
                VStack(spacing: 8) {
                    Text("Mochi is locked")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    
                    Text("Authenticate to view your data")
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(dynamicText.opacity(0.6))
                }
                
                Button(action: {
                    biometricManager.authenticate()
                }) {
                    Text("Unlock")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(isNightTime ? .black : .white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
                .padding(.top, 16)
            }
        }
        .onAppear {
            biometricManager.authenticate()
        }
    }
}
