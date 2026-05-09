import SwiftUI
import SwiftData

struct RecurringExpensesSettingsView: View {
	@ObservedObject var settings = SettingsManager.shared
	@Environment(\.dismiss) var dismiss
	let dynamicText: Color
	let dynamicBackground: Color

	var body: some View {
		ZStack {
			dynamicBackground.ignoresSafeArea()

			VStack(spacing: 0) {
				HStack {
					Button(action: {
						HapticManager.shared.softSquish()
						dismiss()
					}) {
						Image(systemName: "chevron.left")
							.font(.system(size: 16, weight: .bold))
							.foregroundColor(dynamicText)
							.frame(width: 40, height: 40)
							.background(dynamicText.opacity(0.04))
							.clipShape(Circle())
							.overlay(Circle().stroke(dynamicText.opacity(0.1), lineWidth: 1))
					}
					Spacer()
					Text("Recurring Expenses")
						.font(.system(size: 17, weight: .bold, design: .rounded))
						.foregroundColor(dynamicText)
					Spacer()
					Color.clear.frame(width: 32, height: 32)
				}
				.padding(.horizontal, 20)
				.padding(.top, 16)
				.padding(.bottom, 12)

				if settings.recurringTransactions.isEmpty {
					VStack(spacing: 16) {
						Image(systemName: "repeat.circle")
							.font(.system(size: 48))
							.foregroundColor(dynamicText.opacity(0.3))
						Text("No Recurring Expenses")
							.font(.system(size: 16, weight: .semibold))
							.foregroundColor(dynamicText.opacity(0.6))
						Text("Transactions you add repeatedly will appear here")
							.font(.system(size: 13))
							.foregroundColor(dynamicText.opacity(0.4))
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.padding(24)
				} else {
					ScrollView(showsIndicators: false) {
						VStack(spacing: 12) {
							ForEach(settings.recurringTransactions) { recurring in
								RecurringExpenseRow(recurring: recurring, dynamicText: dynamicText)
									.padding(.horizontal, 20)
							}
						}
						.padding(.vertical, 16)
					}
				}
			}
		}
		.toolbar(.hidden, for: .navigationBar)
	}
}

struct RecurringExpenseRow: View {
	let recurring: RecurringTransaction
	let dynamicText: Color
	@ObservedObject var settings = SettingsManager.shared
	@State private var showDeleteAlert = false

	var body: some View {
		VStack(spacing: 12) {
			HStack(spacing: 12) {
				VStack(alignment: .leading, spacing: 4) {
					Text(recurring.note ?? recurring.category)
						.font(.system(size: 15, weight: .semibold))
						.foregroundColor(dynamicText)
					Text(frequencyLabel(recurring.frequency))
						.font(.system(size: 12))
						.foregroundColor(dynamicText.opacity(0.6))
				}
				Spacer()
				VStack(alignment: .trailing, spacing: 4) {
					Text("\(SettingsManager.shared.currencySymbol)\(String(format: "%.2f", recurring.amount))")
						.font(.system(size: 15, weight: .semibold))
						.foregroundColor(dynamicText)
					Text(nextDueText(recurring.nextDueDate))
						.font(.system(size: 12))
						.foregroundColor(dynamicText.opacity(0.6))
				}
			}

			HStack(spacing: 8) {
				Toggle(isOn: Binding(
					get: { recurring.isActive },
					set: { newValue in
						updateRecurring(recurring, isActive: newValue)
					}
				)) {
					Text(recurring.isActive ? "Active" : "Paused")
						.font(.system(size: 12, weight: .medium))
						.foregroundColor(dynamicText.opacity(0.7))
				}
				.tint(.blue)

				Spacer()

				Button(action: { showDeleteAlert = true }) {
					Image(systemName: "trash.fill")
						.font(.system(size: 12))
						.foregroundColor(.red.opacity(0.7))
						.frame(width: 32, height: 32)
						.background(Color.red.opacity(0.1))
						.clipShape(Circle())
				}
			}
		}
		.padding(12)
		.background(dynamicText.opacity(0.04))
		.cornerRadius(10)
		.alert("Delete Recurring", isPresented: $showDeleteAlert) {
			Button("Delete", role: .destructive) {
				deleteRecurring(recurring)
			}
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("This recurring expense will be permanently deleted.")
		}
	}

	private func frequencyLabel(_ freq: RecurrenceFrequency) -> String {
		switch freq {
		case .daily: return "Every day"
		case .weekly: return "Every week"
		case .biweekly: return "Every 2 weeks"
		case .monthly: return "Every month"
		case .quarterly: return "Every 3 months"
		case .yearly: return "Every year"
		}
	}

	private func nextDueText(_ date: Date) -> String {
		let formatter = DateFormatter()
		let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
		if daysUntil < 0 {
			return "Overdue"
		} else if daysUntil == 0 {
			return "Today"
		} else if daysUntil == 1 {
			return "Tomorrow"
		} else {
			return "In \(daysUntil) days"
		}
	}

	private func updateRecurring(_ recurring: RecurringTransaction, isActive: Bool) {
		var all = settings.recurringTransactions
		if let index = all.firstIndex(where: { $0.id == recurring.id }) {
			all[index].isActive = isActive
			settings.recurringTransactions = all
			if isActive {
				NotificationManager.shared.scheduleRecurringReminder(transaction: all[index])
			} else {
				NotificationManager.shared.cancelRecurringReminder(recurringId: recurring.id)
			}
		}
	}

	private func deleteRecurring(_ recurring: RecurringTransaction) {
		var all = settings.recurringTransactions
		all.removeAll { $0.id == recurring.id }
		settings.recurringTransactions = all
		NotificationManager.shared.cancelRecurringReminder(recurringId: recurring.id)
	}
}
