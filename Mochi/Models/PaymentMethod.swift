import Foundation
import SwiftUI

// MARK: - Payment Method Model

struct PaymentMethod: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var type: PaymentType
    var isDefault: Bool
    
    enum PaymentType: String, Codable, CaseIterable {
        case cash = "cash"
        case card = "card"
        
        var icon: String {
            switch self {
            case .cash: return "banknote"
            case .card: return "creditcard"
            }
        }
    }
    
    init(id: UUID = UUID(), name: String, colorHex: String, type: PaymentType, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.type = type
        self.isDefault = isDefault
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    // Preset Colors for Selection
    static let presetColors: [String] = [
        "#4A90A4", // Teal
        "#7B68EE", // Soft Purple
        "#F5A623", // Warm Orange
        "#50C878", // Emerald
        "#E8B4B8", // Blush Pink
        "#6B8E23", // Olive
        "#87CEEB", // Sky Blue
        "#DDA0DD", // Plum
        "#F0E68C", // Khaki
        "#20B2AA", // Light Sea Green
        "#CD853F", // Peru
        "#708090", // Slate Gray
    ]
    
    // Default Cash Option
    static let defaultCash = PaymentMethod(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Cash",
        colorHex: "#50C878",
        type: .cash,
        isDefault: true
    )
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
