import Foundation

enum RecurrenceFrequency: Codable {
	case daily
	case weekly
	case biweekly
	case monthly
	case quarterly
	case yearly

	enum CodingKeys: String, CodingKey {
		case daily, weekly, biweekly, monthly, quarterly, yearly
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if container.contains(.daily) {
			self = .daily
		} else if container.contains(.weekly) {
			self = .weekly
		} else if container.contains(.biweekly) {
			self = .biweekly
		} else if container.contains(.monthly) {
			self = .monthly
		} else if container.contains(.quarterly) {
			self = .quarterly
		} else if container.contains(.yearly) {
			self = .yearly
		} else {
			throw DecodingError.dataCorruptedError(forKey: .daily, in: container, debugDescription: "Invalid RecurrenceFrequency")
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .daily:
			_ = try container.encode(true, forKey: .daily)
		case .weekly:
			_ = try container.encode(true, forKey: .weekly)
		case .biweekly:
			_ = try container.encode(true, forKey: .biweekly)
		case .monthly:
			_ = try container.encode(true, forKey: .monthly)
		case .quarterly:
			_ = try container.encode(true, forKey: .quarterly)
		case .yearly:
			_ = try container.encode(true, forKey: .yearly)
		}
	}
}

final class RecurringTransaction: Codable, Identifiable {
	var id: UUID
	var originalItemId: String
	var amount: Double
	var note: String?
	var category: String
	var paymentMethodId: String?
	var frequency: RecurrenceFrequency
	var nextDueDate: Date
	var lastGeneratedDate: Date?
	var isActive: Bool
	var endDate: Date?
	var createdAt: Date

	init(
		id: UUID = UUID(),
		originalItemId: String,
		amount: Double,
		note: String? = nil,
		category: String,
		paymentMethodId: String? = nil,
		frequency: RecurrenceFrequency,
		nextDueDate: Date,
		lastGeneratedDate: Date? = nil,
		isActive: Bool = true,
		endDate: Date? = nil,
		createdAt: Date = Date()
	) {
		self.id = id
		self.originalItemId = originalItemId
		self.amount = amount
		self.note = note
		self.category = category
		self.paymentMethodId = paymentMethodId
		self.frequency = frequency
		self.nextDueDate = nextDueDate
		self.lastGeneratedDate = lastGeneratedDate
		self.isActive = isActive
		self.endDate = endDate
		self.createdAt = createdAt
	}
}
