import Foundation

struct RecurringDetector {
	static func detectRecurring(note: String, category: String, amount: Double, history: [Item]) -> RecurrenceFrequency? {
		let subscriptionTerms = ["netflix", "spotify", "apple music", "adobe", "microsoft", "amazon prime", "hulu", "disney", "hbo", "crunchyroll", "dropbox", "icloud", "slack", "notion", "chatgpt"]
		let lowerNote = note.lowercased()

		for term in subscriptionTerms {
			if lowerNote.contains(term) {
				return .monthly
			}
		}

		let prefix = String(lowerNote.prefix(3))
		let relevantItems = history.filter { item in
			let itemNote = item.note ?? ""
			return itemNote.lowercased().contains(prefix) &&
			item.category == category &&
			abs(item.amount - amount) < 0.01
		}

		guard relevantItems.count >= 2 else { return nil }

		let sorted = relevantItems.sorted { $0.timestamp > $1.timestamp }
		let dates = sorted.map { $0.timestamp }
		var intervals: [Int] = []

		for i in 1..<dates.count {
			let days = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
			if days > 0 { intervals.append(days) }
		}

		guard !intervals.isEmpty else { return nil }

		let avgInterval = intervals.reduce(0, +) / intervals.count
		let variance = intervals.map { pow(Double($0 - avgInterval), 2) }.reduce(0, +) / Double(intervals.count)
		let stdDev = sqrt(variance)

		if stdDev < Double(avgInterval) * 0.2 {
			if (26...35).contains(avgInterval) { return .monthly }
			if (6...8).contains(avgInterval) { return .weekly }
			if (89...95).contains(avgInterval) { return .quarterly }
			if (355...366).contains(avgInterval) { return .yearly }
		}

		return nil
	}
}
