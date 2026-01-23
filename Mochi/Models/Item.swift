import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var amount: Double
    var note: String? // The tag/note
    var paymentMethodId: String? // UUID string of the PaymentMethod used
    
    init(timestamp: Date, amount: Double, note: String? = nil, paymentMethodId: String? = nil) {
        self.timestamp = timestamp
        self.amount = amount
        self.note = note
        self.paymentMethodId = paymentMethodId
    }
}
