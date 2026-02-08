import SwiftUI

struct CurrencySelectionView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // Aesthetic Colors (Creamy Palette)
    let dynamicText: Color
    let accentColor = Color(red: 0.35, green: 0.65, blue: 0.55) // Mint Green
    
    var filteredCurrencies: [SettingsManager.Currency] {
        if searchText.isEmpty {
            return SettingsManager.allAvailableCurrencies
        } else {
            return SettingsManager.allAvailableCurrencies.filter { currency in
                currency.code.localizedCaseInsensitiveContains(searchText) ||
                currency.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var autoCurrencyCode: String {
        Locale.autoupdatingCurrent.currency?.identifier ?? "USD"
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
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(dynamicText)
                            .frame(width: 40, height: 40)
                            .background(dynamicText.opacity(0.04))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                    
                    Text("Currency")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    
                    Spacer()
                    
                    // Balance
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Custom Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(dynamicText.opacity(0.4))
                    
                    TextField("Search", text: $searchText, prompt: Text("Search Currency").foregroundColor(dynamicText.opacity(0.3)))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(dynamicText)
                        .tint(accentColor)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(dynamicText.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(dynamicText.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Auto Button (Only show if not searching or matches search)
                        if searchText.isEmpty || "auto".contains(searchText.lowercased()) {
                            Button(action: {
                                HapticManager.shared.selection()
                                settings.customCurrencyCode = "" // Empty string means Auto
                                dismiss()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 16, weight: .medium))
                                    Text("Auto (\(autoCurrencyCode))")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Color(red: 0.1, green: 0.3, blue: 0.2)) // Dark green text
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.9, green: 0.96, blue: 0.94)) // Light mint background
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(settings.customCurrencyCode.isEmpty ? accentColor : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 24)
                            .padding(.top, 4) // Reduced top padding
                        }
                        
                        // Currency List
                        LazyVStack(spacing: 0) {
                            ForEach(filteredCurrencies) { currency in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    settings.customCurrencyCode = currency.code
                                    dismiss()
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(currency.code)
                                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                                .foregroundColor(dynamicText)
                                            
                                            Text(currency.name)
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                                .foregroundColor(dynamicText.opacity(0.5))
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(currency.symbol)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText.opacity(0.4))
                                        
                                        if settings.customCurrencyCode == currency.code {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(accentColor)
                                                .padding(.leading, 8)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}
