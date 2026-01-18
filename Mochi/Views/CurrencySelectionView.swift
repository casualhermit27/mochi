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
        Locale.autoupdatingCurrent.currencyCode ?? "USD"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Auto Button
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
                .padding(.top, 16)
                
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}
