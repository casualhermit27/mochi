import SwiftUI
import SwiftData

struct RecurringSetupSheet: View {
	@Environment(\.dismiss) var dismiss
	@Binding var isPresented: Bool
	let amount: Double
	let note: String
	let category: String
	let paymentMethodId: String?
	let onConfirm: (RecurringTransaction) -> Void

	@State private var selectedFrequency: RecurrenceFrequency = .monthly

	var body: some View {
		VStack(spacing: 24) {
			VStack(spacing: 12) {
				Text("Keep it recurring?")
					.font(.system(size: 18, weight: .semibold))
					.foregroundColor(.primary)

				Text("Looks like a \(frequencyLabel(selectedFrequency)) thing — want Mochi to remind you?")
					.font(.system(size: 14, weight: .regular))
					.foregroundColor(.secondary)
					.lineLimit(2)
			}

			VStack(spacing: 12) {
				Text("When should we remind you?")
					.font(.system(size: 12, weight: .semibold))
					.foregroundColor(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)

				HStack(spacing: 8) {
					ForEach([RecurrenceFrequency.daily, .weekly, .monthly, .yearly], id: \.self) { freq in
						Button(action: { selectedFrequency = freq }) {
							Text(frequencyLabel(freq))
								.font(.system(size: 13, weight: .semibold))
								.foregroundColor(selectedFrequency == freq ? .white : .secondary)
								.frame(maxWidth: .infinity)
								.padding(.vertical, 10)
								.background(selectedFrequency == freq ? Color.blue : Color(.systemGray5))
								.cornerRadius(8)
						}
					}
				}
			}

			Spacer()

			HStack(spacing: 12) {
				Button(action: { isPresented = false }) {
					Text("Skip")
						.font(.system(size: 16, weight: .semibold))
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 12)
						.background(Color(.systemGray5))
						.cornerRadius(10)
				}

				Button(action: confirm) {
					Text("Remind Me")
						.font(.system(size: 16, weight: .semibold))
						.foregroundColor(.white)
						.frame(maxWidth: .infinity)
						.padding(.vertical, 12)
						.background(Color.blue)
						.cornerRadius(10)
				}
			}
		}
		.padding(24)
		.presentationDetents([.height(380)])
		.presentationDragIndicator(.visible)
	}

	private func frequencyLabel(_ freq: RecurrenceFrequency) -> String {
		switch freq {
		case .daily: return "Daily"
		case .weekly: return "Weekly"
		case .biweekly: return "Biweekly"
		case .monthly: return "Monthly"
		case .quarterly: return "Quarterly"
		case .yearly: return "Yearly"
		}
	}

	private func nextDueDate(frequency: RecurrenceFrequency) -> Date {
		let calendar = Calendar.current
		let now = Date()

		switch frequency {
		case .daily:
			return calendar.date(byAdding: .day, value: 1, to: now) ?? now
		case .weekly:
			return calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
		case .biweekly:
			return calendar.date(byAdding: .day, value: 14, to: now) ?? now
		case .monthly:
			return calendar.date(byAdding: .month, value: 1, to: now) ?? now
		case .quarterly:
			return calendar.date(byAdding: .month, value: 3, to: now) ?? now
		case .yearly:
			return calendar.date(byAdding: .year, value: 1, to: now) ?? now
		}
	}

	private func confirm() {
		let nextDue = nextDueDate(frequency: selectedFrequency)
		let recurring = RecurringTransaction(
			originalItemId: UUID().uuidString,
			amount: amount,
			note: note,
			category: category,
			paymentMethodId: paymentMethodId,
			frequency: selectedFrequency,
			nextDueDate: nextDue
		)
		onConfirm(recurring)
		isPresented = false
	}
}
