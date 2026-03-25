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
