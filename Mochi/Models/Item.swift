import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()
    var amount: Double = 0.0
    var note: String? // The tag/note
    var paymentMethodId: String? // UUID string of the PaymentMethod used
    
    init(timestamp: Date = Date(), amount: Double = 0.0, note: String? = nil, paymentMethodId: String? = nil) {
        self.timestamp = timestamp
        self.amount = amount
        self.note = note
        self.paymentMethodId = paymentMethodId
    }
}
