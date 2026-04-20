import SwiftUI
import UIKit

// MARK: - Screen Helpers (replaces deprecated UIScreen.main)
extension UIWindowScene {
    static var current: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }
    static var screenBounds: CGRect { current?.screen.bounds ?? CGRect(x: 0, y: 0, width: 390, height: 844) }
}

// MARK: - Theme & Extensions
extension Color {
    // Soft Cream
    static let mochiBackground = Color(red: 253/255, green: 252/255, blue: 240/255)
    // Deep Charcoal (off-black)
    static let mochiText = Color(red: 45/255, green: 45/255, blue: 45/255)
    
    // Pastels
    static let mochiSage = Color(red: 216/255, green: 226/255, blue: 220/255)
    static let mochiRose = Color(red: 240/255, green: 185/255, blue: 195/255)
    static let mochiBlue = Color(red: 224/255, green: 231/255, blue: 242/255)
    static let mochiBlueDark = Color(red: 160/255, green: 190/255, blue: 230/255)
    
    // Feedback Colors - Explicitly non-optional
    static let mochiGreen = Color(red: 90/255, green: 165/255, blue: 140/255)
    static let mochiBrickRed = Color(red: 220/255, green: 130/255, blue: 130/255)
}

extension SettingsManager.PastelTheme {
    /// Generates a curated, distinctly visible color palette mathematically matched to the active app theme
    var chartPalette: [Color] {
        switch self.id {
        case "pink":
            return [
                self.accent, // Dusty rose
                Color(red: 0.95, green: 0.60, blue: 0.65), // Peach Pink
                Color(red: 0.70, green: 0.35, blue: 0.65), // Plum
                Color(red: 0.55, green: 0.25, blue: 0.35), // Dark Rose
                Color(red: 0.90, green: 0.70, blue: 0.85), // Soft Lavender
                Color(red: 0.85, green: 0.30, blue: 0.40)  // Deep Coral
            ]
        case "blue":
            return [
                self.accent, // Soft blue
                Color(red: 0.30, green: 0.75, blue: 0.85), // Cyan
                Color(red: 0.45, green: 0.45, blue: 0.85), // Indigo
                Color(red: 0.20, green: 0.35, blue: 0.60), // Deep Navy
                Color(red: 0.65, green: 0.75, blue: 0.95), // Powder Blue
                Color(red: 0.35, green: 0.80, blue: 0.75)  // Teal
            ]
        case "green":
            return [
                self.accent, // Fresh mint
                Color(red: 0.60, green: 0.85, blue: 0.45), // Lime Green
                Color(red: 0.20, green: 0.55, blue: 0.45), // Emerald
                Color(red: 0.15, green: 0.40, blue: 0.30), // Forest Green
                Color(red: 0.50, green: 0.90, blue: 0.75), // Seafoam
                Color(red: 0.75, green: 0.90, blue: 0.35)  // Yellow Green
            ]
        case "butterscotch":
            return [
                self.accent, // Golden honey
                Color(red: 0.95, green: 0.55, blue: 0.25), // Orange
                Color(red: 0.95, green: 0.85, blue: 0.40), // Bright Yellow
                Color(red: 0.75, green: 0.45, blue: 0.15), // Bronze
                Color(red: 0.95, green: 0.40, blue: 0.30), // Coral
                Color(red: 0.80, green: 0.60, blue: 0.25)  // Mustard
            ]
        case "brown":
            return [
                self.accent, // Warm mocha
                Color(red: 0.80, green: 0.65, blue: 0.50), // Latte
                Color(red: 0.40, green: 0.25, blue: 0.15), // Espresso
                Color(red: 0.75, green: 0.55, blue: 0.40), // Caramel
                Color(red: 0.50, green: 0.35, blue: 0.25), // Cocoa
                Color(red: 0.90, green: 0.75, blue: 0.60)  // Beige
            ]
        case "purple":
            return [
                self.accent, // Vibrant violet
                Color(red: 0.75, green: 0.55, blue: 0.95), // Light Purple
                Color(red: 0.45, green: 0.25, blue: 0.75), // Deep Purple
                Color(red: 0.85, green: 0.45, blue: 0.85), // Magenta
                Color(red: 0.35, green: 0.15, blue: 0.55), // Dark Violet
                Color(red: 0.90, green: 0.70, blue: 1.00)  // Lavender Light
            ]
        default: // Default (Minty Greenish)
            return [
                self.accent,
                Color(red: 0.40, green: 0.75, blue: 0.80), // Teal
                Color(red: 0.25, green: 0.50, blue: 0.45), // Dark Mint
                Color(red: 0.55, green: 0.85, blue: 0.65), // Light Mint
                Color(red: 0.30, green: 0.60, blue: 0.85), // Sky Blue
                Color(red: 0.45, green: 0.85, blue: 0.45)  // Bright Green
            ]
        }
    }
}
