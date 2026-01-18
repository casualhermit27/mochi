import SwiftUI
import SwiftData
import Combine

// MARK: - History View

struct HistoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @ObservedObject var settings = SettingsManager.shared
    @Binding var sessionDeletedAmount: Double
    
    @State private var taggingItem: Item? = nil
    @State private var tagText: String = ""
    @FocusState private var isTagFocused: Bool
    @State private var showSettings = false
    @State private var showRestoreToast = false
    
    // Undo State
    @State private var pendingDeletions: [PersistentIdentifier: Date] = [:]
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var isNightTime: Bool
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return isNightTime ? Color.mochiText : Color.mochiBackground
    }
    
    var dynamicText: Color {
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.textDark : currentTheme.text
        }
        return isNightTime ? Color.mochiBackground : Color.mochiText
    }
    
    var dynamicSecondary: Color {
        dynamicText.opacity(0.6)
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return isNightTime ? Color.mochiBlueDark : Color.mochiRose
    }
    
    var swipeDeleteColor: Color {
        // Warm Pastel Coral (Light) vs Muted Earthy Red (Dark)
        // Updated to Brick Red for light mode as requested
        isNightTime ? Color(red: 0.7, green: 0.35, blue: 0.35) : Color(red: 0.8, green: 0.3, blue: 0.25)
    }
    
    var swipeTagColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        // Soft Matcha (Light) vs Muted Sage (Dark)
        return isNightTime ? Color(red: 0.4, green: 0.55, blue: 0.45) : Color(red: 0.68, green: 0.85, blue: 0.68)
    }
    
    @State private var expandedDays: Set<Date> = []
    
    // Selection & Bulk Delete State
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<PersistentIdentifier> = []
    @State private var undoSnapshots: [SnapshotItem] = []
    @State private var showUndoToast = false
    @State private var undoTimer: Timer?
    @State private var undoSecondsRemaining = 7
    
    // Drag-to-Select State
    @State private var isDragging = false
    @State private var dragSelectMode: Bool? = nil // nil = not set, true = selecting, false = deselecting
    
    struct SnapshotItem {
        let amount: Double
        let timestamp: Date
        let note: String?
    }
    
    var groupedItems: [Date: [Item]] {
        Dictionary(grouping: items) { item in
            settings.getRitualDay(for: item.timestamp)
        }
    }
    
    var sortedDates: [Date] {
        groupedItems.keys.sorted(by: >)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main List
                List {
                    ForEach(sortedDates, id: \.self) { date in
                        // Calculate Day Total
                        let dayItems = groupedItems[date] ?? []
                        let dayTotal = dayItems.reduce(0) { $0 + $1.amount }
                        let isExpanded = expandedDays.contains(date)
                        
                        // Custom Section Header with Disclosure Logic
                         Section {
                            if isExpanded {
                                let isOld = isDateLocked(date)
                                
                                if isOld {
                                    // Locked Entry
                                    HStack {
                                        Text("History Locked")
                                        Spacer()
                                        Image(systemName: "lock.fill")
                                        Text("$1.99")
                                    }
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(dynamicSecondary)
                                    .padding(.vertical, 8)
                                    .blur(radius: 3)
                                    .overlay {
                                        Button("Unlock") { }
                                            .buttonStyle(.borderedProminent)
                                            .tint(dynamicText)
                                            .foregroundColor(dynamicBackground)
                                    }
                                } else {
                                    // Unlocked entries
                                    ForEach(dayItems) { item in
                                        if let deletionDate = pendingDeletions[item.persistentModelID] {
                                             UndoRowView(
                                                deletionDate: deletionDate,
                                                amountText: "\(settings.currencySymbol)\(item.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.amount) : String(format: "%.2f", item.amount))",
                                                isNightTime: isNightTime,
                                                onUndo: { undoPendingDeletion(item) },
                                                onDeleteImmediately: { confirmDeletion(item) }
                                            )
                                            .listRowBackground(Color.clear)
                                        } else {
                                            // Normal Row
                                            HStack(spacing: 12) {
                                                if isSelectionMode {
                                                    Image(systemName: selectedItems.contains(item.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 18, height: 18)
                                                        .foregroundColor(selectedItems.contains(item.persistentModelID) ? swipeDeleteColor : dynamicSecondary)
                                                        .background(selectedItems.contains(item.persistentModelID) ? dynamicBackground : Color.clear)
                                                        .clipShape(Circle())
                                                        .transition(.move(edge: .leading).combined(with: .opacity))
                                                }
                                                
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(item.timestamp, format: .dateTime.hour().minute())
                                                            .foregroundColor(dynamicSecondary)
                                                        if let note = item.note, !note.isEmpty {
                                                            Text(note)
                                                                .font(.system(size: 12, design: .monospaced))
                                                                .foregroundColor(dynamicText.opacity(0.8))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(dynamicSecondary.opacity(0.2))
                                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                                        }
                                                    }
                                                    Spacer()
                                                    HStack(spacing: 2) {
                                                        Text(settings.currencySymbol)
                                                            .font(.system(size: 14))
                                                            .foregroundColor(dynamicSecondary)
                                                        Text(item.amount.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", item.amount) : String(format: "%.2f", item.amount))
                                                            .fontWeight(.semibold)
                                                            .foregroundColor(dynamicText)
                                                    }
                                                }
                                                .contentShape(Rectangle())
                                            }
                                            .font(.system(.body, design: .monospaced))
                                            .padding(.vertical, 4)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if isSelectionMode {
                                                    toggleSelection(item)
                                                }
                                            }
                                            .gesture(
                                                isSelectionMode ?
                                                DragGesture(minimumDistance: 0)
                                                    .onChanged { _ in
                                                        if !isDragging {
                                                            // Start drag - determine mode based on current item state
                                                            isDragging = true
                                                            let isCurrentlySelected = selectedItems.contains(item.persistentModelID)
                                                            dragSelectMode = !isCurrentlySelected // If not selected, we're selecting; if selected, we're deselecting
                                                            
                                                            // Apply to this item
                                                            if dragSelectMode == true && !isCurrentlySelected {
                                                                selectedItems.insert(item.persistentModelID)
                                                                HapticManager.shared.lightImpact()
                                                            } else if dragSelectMode == false && isCurrentlySelected {
                                                                selectedItems.remove(item.persistentModelID)
                                                                HapticManager.shared.lightImpact()
                                                            }
                                                        } else {
                                                            // Continue drag - apply mode to current item
                                                            let isCurrentlySelected = selectedItems.contains(item.persistentModelID)
                                                            if dragSelectMode == true && !isCurrentlySelected {
                                                                selectedItems.insert(item.persistentModelID)
                                                                HapticManager.shared.lightImpact()
                                                            } else if dragSelectMode == false && isCurrentlySelected {
                                                                selectedItems.remove(item.persistentModelID)
                                                                HapticManager.shared.lightImpact()
                                                            }
                                                        }
                                                    }
                                                    .onEnded { _ in
                                                        isDragging = false
                                                        dragSelectMode = nil
                                                    }
                                                : nil
                                            )
                                            .listRowBackground(Color.clear)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                if !isSelectionMode {
                                                    Button(role: .destructive) {
                                                        startPendingDeletion(item)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                    .tint(swipeDeleteColor)
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                if !isSelectionMode {
                                                    Button {
                                                        startTagging(item)
                                                    } label: {
                                                        Label("Tag", systemImage: "tag")
                                                    }
                                                    .tint(swipeTagColor)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            // Tappable Header
                            Button(action: {
                                if isSelectionMode {
                                    toggleDaySelection(date)
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                        if isExpanded { expandedDays.remove(date) }
                                        else { expandedDays.insert(date) }
                                    }
                                    HapticManager.shared.selection()
                                }
                            }) {
                                HStack {
                                    if isSelectionMode {
                                        Image(systemName: isDaySelected(date) ? "checkmark.circle.fill" : "circle")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(isDaySelected(date) ? swipeDeleteColor : dynamicSecondary)
                                            .background(isDaySelected(date) ? dynamicBackground : Color.clear)
                                            .clipShape(Circle())
                                            .padding(.trailing, 8)
                                            .onTapGesture {
                                                toggleDaySelection(date)
                                            }
                                            .transition(.move(edge: .leading).combined(with: .opacity))
                                    }
                                    
                                    Text(date, format: .dateTime.weekday().day().month())
                                        .font(.system(.subheadline, design: .monospaced))
                                        .textCase(nil)
                                        .foregroundColor(dynamicSecondary)
                                    
                                    Spacer()
                                    
                                    // Total Amount Badge
                                    HStack(spacing: 2) {
                                        Text(settings.currencySymbol)
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(dynamicSecondary)
                                        Text("\(dayTotal.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", dayTotal) : String(format: "%.2f", dayTotal))")
                                            .font(.system(.subheadline, design: .monospaced))
                                            .fontWeight(.bold)
                                            .foregroundColor(dynamicText)
                                    }
                                    
                                    if !isSelectionMode {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundColor(dynamicSecondary)
                                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if items.isEmpty {
                        Text("No mochi yet.")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(dynamicSecondary)
                            .listRowBackground(Color.clear)
                    }
                }.onAppear {
                    // Expand Today by default if empty
                    if expandedDays.isEmpty {
                        // Find today
                        let today = settings.getRitualDay(for: Date())
                        expandedDays.insert(today)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(dynamicBackground)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelectionMode)
                .onReceive(timer) { _ in
                    checkPendingDeletions()
                }
                
                // Tag Input Bar (Overlay)
                if taggingItem != nil {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            TextField("", text: $tagText, prompt: Text("add a note...").foregroundColor(dynamicSecondary))
                                .font(.system(.body, design: .monospaced))
                                .focused($isTagFocused)
                                .foregroundColor(dynamicText)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(dynamicText.opacity(0.05))
                                .clipShape(Capsule())
                            
                            Button(action: saveTag) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(isNightTime ? Color.black : Color.white)
                                    .frame(width: 44, height: 44)
                                    .background(swipeTagColor)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(dynamicBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.1), radius: 10, y: -2)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
                
                // Bulk Delete FAB
                if isSelectionMode && !selectedItems.isEmpty {
                    VStack {
                        Spacer()
                        Button(action: executeBulkDelete) {
                            Text("Delete (\(selectedItems.count))")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 32)
                                .background(swipeDeleteColor)
                                .clipShape(Capsule())
                                .shadow(color: swipeDeleteColor.opacity(0.4), radius: 10, y: 5)
                        }
                        .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(101)
                }
                
                // Undo Toast
                if showUndoToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 16) {
                            Text("\(undoSecondsRemaining)s")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(dynamicText)
                                .frame(width: 30)
                            
                            Text("Deleted")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(dynamicText)
                            
                            Spacer()
                            
                            Button("Undo", action: performUndo)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(dynamicBackground)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(dynamicText)
                                .clipShape(Capsule())
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(dynamicBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(102)
                }
            }
            .navigationTitle("Mochi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            withAnimation {
                                isSelectionMode = false
                                selectedItems.removeAll()
                            }
                        }
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(dynamicText)
                    } else {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(dynamicText)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 24) {
                        if !isSelectionMode {
                            Button {
                                withAnimation { isSelectionMode = true }
                            } label: {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 20, weight: .medium))
                            }
                            .tint(dynamicText)
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .tint(dynamicText)
                    }
                }
            }
            .toolbarColorScheme(isNightTime ? .dark : .light, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationBackground(.regularMaterial)
                    .presentationCornerRadius(32)
            }
        }
    }
    
    func isDateLocked(_ date: Date) -> Bool {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        return date < Calendar.current.startOfDay(for: threeDaysAgo)
    }
    
    // MARK: - Deletion Logic
    
    private func startPendingDeletion(_ item: Item) {
        HapticManager.shared.softSquish()
        // Set deletion for 4 seconds from now
        withAnimation {
            pendingDeletions[item.persistentModelID] = Date().addingTimeInterval(4)
        }
    }
    
    private func undoPendingDeletion(_ item: Item) {
        HapticManager.shared.success()
        withAnimation {
            pendingDeletions.removeValue(forKey: item.persistentModelID)
        }
    }
    
    private func confirmDeletion(_ item: Item) {
        withAnimation {
            if pendingDeletions[item.persistentModelID] != nil {
                pendingDeletions.removeValue(forKey: item.persistentModelID)
                sessionDeletedAmount += item.amount
                
                // Update Widget specifically for deletion
                WidgetDataManager.shared.updateWidgetData(
                    todayTotal: 0, // Does not matter, MainView will update totals
                    yesterdayTotal: 0,
                    lastTransaction: -item.amount,
                    lastTransactionNote: "",
                    currencySymbol: settings.currencySymbol,
                    colorTheme: settings.colorTheme,
                    themeMode: settings.themeMode
                )
                // Note: MainView will follow up with correct Totals due to items.count change
                
                modelContext.delete(item)
            }
        }
    }
    
    private func checkPendingDeletions() {
        let now = Date()
        for (id, deletionTime) in pendingDeletions {
            if now >= deletionTime {
                // Time to delete
                if let item = items.first(where: { $0.persistentModelID == id }) {
                    withAnimation {
                        sessionDeletedAmount += item.amount
                        modelContext.delete(item)
                        pendingDeletions.removeValue(forKey: id)
                    }
                } else {
                    // Item gone? cleanup key
                    pendingDeletions.removeValue(forKey: id)
                }
            }
        }
    }
    
    private func startTagging(_ item: Item) {
        HapticManager.shared.softSquish()
        taggingItem = item
        tagText = item.note ?? ""
        isTagFocused = true
    }
    
    private func saveTag() {
        if let item = taggingItem {
            item.note = tagText
            HapticManager.shared.success()
        }
        withAnimation {
            taggingItem = nil
            isTagFocused = false
        }
    }
    
    // MARK: - Selection Logic
    
    private func toggleSelection(_ item: Item) {
        HapticManager.shared.lightImpact()
        if selectedItems.contains(item.persistentModelID) {
            selectedItems.remove(item.persistentModelID)
        } else {
            selectedItems.insert(item.persistentModelID)
        }
    }
    
    private func toggleDaySelection(_ date: Date) {
        HapticManager.shared.softSquish()
        let dayItems = groupedItems[date] ?? []
        let ids = dayItems.map { $0.persistentModelID }
        let allSelected = ids.allSatisfy { selectedItems.contains($0) }
        
        if allSelected {
            // Deselect all
            for id in ids { selectedItems.remove(id) }
        } else {
            // Select all
            for id in ids { selectedItems.insert(id) }
        }
    }
    
    private func isDaySelected(_ date: Date) -> Bool {
        let dayItems = groupedItems[date] ?? []
        if dayItems.isEmpty { return false }
        return dayItems.map { $0.persistentModelID }.allSatisfy { selectedItems.contains($0) }
    }
    
    // MARK: - Bulk Deletion
    
    private func executeBulkDelete() {
        HapticManager.shared.rigidImpact()
        
        // Snapshot items
        undoSnapshots = []
        var amountDeleted: Double = 0
        
        for id in selectedItems {
            if let item = items.first(where: { $0.persistentModelID == id }) {
                undoSnapshots.append(SnapshotItem(amount: item.amount, timestamp: item.timestamp, note: item.note))
                amountDeleted += item.amount
                modelContext.delete(item)
            }
        }
        
        // Update session tracking if needed
        sessionDeletedAmount += amountDeleted
        
        // Update Widget for Bulk Deletion
        WidgetDataManager.shared.updateWidgetData(
            todayTotal: 0,
            yesterdayTotal: 0,
            lastTransaction: -amountDeleted,
            lastTransactionNote: "",
            currencySymbol: settings.currencySymbol,
            colorTheme: settings.colorTheme,
            themeMode: settings.themeMode
        )
        
        // Reset Selection
        selectedItems.removeAll()
        withAnimation {
            isSelectionMode = false
        }
        
        // Show Undo Toast
        undoSecondsRemaining = 7
        withAnimation { showUndoToast = true }
        
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if undoSecondsRemaining > 0 {
                undoSecondsRemaining -= 1
            } else {
                // Expired
                timer.invalidate()
                withAnimation { showUndoToast = false }
                undoSnapshots.removeAll()
            }
        }
    }
    
    private func performUndo() {
        HapticManager.shared.success()
        undoTimer?.invalidate()
        
        // Restore items
        for snapshot in undoSnapshots {
            let newItem = Item(timestamp: snapshot.timestamp, amount: snapshot.amount, note: snapshot.note)
            modelContext.insert(newItem)
            sessionDeletedAmount -= snapshot.amount
        }
        
        undoSnapshots.removeAll()
        withAnimation { showUndoToast = false }
    }
}

// MARK: - Undo Row Component

struct UndoRowView: View {
    let deletionDate: Date
    let amountText: String
    let isNightTime: Bool
    let onUndo: () -> Void
    let onDeleteImmediately: () -> Void
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            let remaining = deletionDate.timeIntervalSince(context.date)
            let progress = max(0, min(1, remaining / 4.0))
            
            ZStack {
                HStack(spacing: 16) {
                    // Deleted Label (Amount)
                    Text(amountText)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .strikethrough()
                        .foregroundColor(isNightTime ? .white.opacity(0.5) : .black.opacity(0.5))
                    
                    Spacer()
                    
                    // Undo Button
                    Button(action: onUndo) {
                        Text("Undo")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isNightTime ? Color.mochiText : Color.mochiBackground)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .background(isNightTime ? Color.mochiBackground : Color.mochiText)
                        .clipShape(Capsule())
                        .shadow(color: isNightTime ? .white.opacity(0.1) : .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                    
                    // Close / Timer Button
                    Button(action: onDeleteImmediately) {
                        ZStack {
                            // Timer Ring
                            Circle()
                                .stroke(isNightTime ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 3)
                            
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(isNightTime ? Color.mochiRose : Color.mochiText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isNightTime ? .white.opacity(0.8) : .black.opacity(0.6))
                        }
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                    }
                    .buttonStyle(SquishyButtonStyle())
                }
                .padding(.vertical, 6)
            }
            .id("undo_row")
        }
    }
}
