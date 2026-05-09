import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()
    var amount: Double = 0.0
    var note: String? // The tag/note
    var category: String? // Auto-categorized 
    var isCategoryUserEdited: Bool = false
    var paymentMethodId: String? // UUID string of the PaymentMethod used
    var currencyCode: String? // ISO 4217 currency code (e.g. "USD", "INR")
    
    init(timestamp: Date = Date(), amount: Double = 0.0, note: String? = nil, category: String? = nil, isCategoryUserEdited: Bool = false, paymentMethodId: String? = nil, currencyCode: String? = nil) {
        self.timestamp = timestamp
        self.amount = amount
        self.note = note
        self.category = category
        self.isCategoryUserEdited = isCategoryUserEdited
        self.paymentMethodId = paymentMethodId
        self.currencyCode = currencyCode
    }
}
