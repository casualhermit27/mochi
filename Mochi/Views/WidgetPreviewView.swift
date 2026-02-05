import SwiftUI

enum WidgetPreviewSize {
    case small
    case medium
}

struct WidgetPreviewView: View {
    let size: WidgetPreviewSize
    let theme: SettingsManager.PastelTheme
    let isDark: Bool
    
    // Dummy Data
    let date = Date()
    let todayTotal: Double = 480.0
    let lastTransaction: Double = -12.40
    let lastTransactionNote = "COFFEE"
    let currencySymbol = "$"
    
    var body: some View {
        ZStack {
            // Background
            (isDark ? theme.backgroundDark : theme.background)
            
            // Top Left: Date (Month + Day)
            HStack(spacing: 4) {
                Text(date.formatted(.dateTime.month()).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.6))
                
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isDark ? theme.textDark : theme.text)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)

            // Top Right: Last Transaction
            VStack(alignment: .trailing, spacing: 2) {
                Text(lastTransactionNote)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.5))
                    .lineLimit(1)
                
                let sign = lastTransaction > 0 ? "+" : "-"
                let absAmount = abs(lastTransaction)
                
                HStack(spacing: 2) {
                    Text("\(sign) \(currencySymbol)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.5))
                    
                    Text("\(Int(absAmount))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(16)
            
            // Bottom Left: Today Total
            VStack(alignment: .leading, spacing: 0) {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.5))
                    .padding(.bottom, 2)
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(currencySymbol)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor((isDark ? theme.textDark : theme.text).opacity(0.5))
                        .padding(.trailing, 2)
                    
                    Text("\(Int(todayTotal))")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(isDark ? theme.textDark : theme.text)
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(16)
        }
        .frame(width: size == .small ? 155 : 329, height: 155) // Standard iOS Widget sizes roughly
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
