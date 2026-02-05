import SwiftUI

// MARK: - Payment Methods List View

struct PaymentMethodsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    @State private var showAddSheet = false
    @State private var editingMethod: PaymentMethod? = nil
    
    let dynamicText: Color
    
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return Color(UIColor.systemBackground)
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return currentTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(dynamicText)
                    }
                    
                    Spacer()
                    
                    Text("Payment Methods")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(dynamicText)
                    
                    Spacer()
                    
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(dynamicText)
                            .frame(width: 32, height: 32)
                            .background(dynamicText.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(settings.paymentMethods) { method in
                            PaymentMethodCard(
                                method: method,
                                isSelected: settings.selectedPaymentMethodId == method.id.uuidString,
                                dynamicText: dynamicText,
                                onTap: {
                                    HapticManager.shared.selection()
                                    settings.selectPaymentMethod(method)
                                },
                                onEdit: {
                                    HapticManager.shared.softSquish()
                                    editingMethod = method
                                },
                                onDelete: {
                                    HapticManager.shared.softSquish()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        settings.deletePaymentMethod(method)
                                    }
                                }
                            )
                        }
                        
                        // Add New Card Prompt
                        Button(action: { showAddSheet = true }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(dynamicText.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [6]))
                                        .frame(width: 48, height: 32)
                                    
                                    Image(systemName: "plus")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(dynamicText.opacity(0.4))
                                }
                                
                                Text("Add a card or wallet")
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundColor(dynamicText.opacity(0.5))
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(dynamicText.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddSheet) {
            AddEditPaymentMethodView(dynamicText: dynamicText, editingMethod: nil)
                .presentationDetents([.medium])
                .presentationCornerRadius(32)
                .presentationBackground(dynamicBackground)
                .preferredColorScheme(isNightTime ? .dark : .light)
        }
        .sheet(item: $editingMethod) { method in
            AddEditPaymentMethodView(dynamicText: dynamicText, editingMethod: method)
                .presentationDetents([.medium])
                .presentationCornerRadius(32)
                .presentationBackground(dynamicBackground)
                .preferredColorScheme(isNightTime ? .dark : .light)
        }
    }
}

// MARK: - Payment Method Card

struct PaymentMethodCard: View {
    let method: PaymentMethod
    let isSelected: Bool
    let dynamicText: Color
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showActions = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Card Visual (Flat)
                Image(systemName: method.type == .cash ? "banknote" : "creditcard")
                    .font(.system(size: 18))
                    .foregroundColor(method.color)
                    .frame(width: 48, height: 32)
                    .background(method.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Name & Type
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.name)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(dynamicText)
                    
                    Text(method.type.rawValue.capitalized)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(dynamicText.opacity(0.5))
                }
                
                Spacer()
                
                // Selected Indicator
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(method.color)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // More Actions
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dynamicText.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(dynamicText.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? method.color.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(SquishyCardStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Add/Edit Payment Method View

struct AddEditPaymentMethodView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = SettingsManager.shared
    
    let dynamicText: Color
    var editingMethod: PaymentMethod?
    
    @State private var name: String = ""
    @State private var selectedType: PaymentMethod.PaymentType = .card
    @State private var selectedColorHex: String = PaymentMethod.presetColors[0]
    
    var isEditing: Bool { editingMethod != nil }
    
    var isNightTime: Bool {
        if settings.themeMode == "dark" || settings.themeMode == "amoled" { return true }
        if settings.themeMode == "light" { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }
    
    var currentTheme: SettingsManager.PastelTheme {
        settings.currentPastelTheme
    }
    
    var dynamicBackground: Color {
        if settings.themeMode == "amoled" { return Color.black }
        if settings.colorTheme != "default" {
            return isNightTime ? currentTheme.backgroundDark : currentTheme.background
        }
        return Color(UIColor.systemBackground)
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Handle
                Capsule()
                    .fill(dynamicText.opacity(0.1))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                // Minimal Header with Icon
                HStack(spacing: 12) {
                    Image(systemName: selectedType == .cash ? "banknote" : "creditcard")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(dynamicText)
                    
                    Text(isEditing ? "Edit Method" : "New Method")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(dynamicText)
                }
                .padding(.top, 8)
                
                VStack(spacing: 36) {
                    // Minimal Name Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("NAME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.3))
                            .tracking(1.5)
                        
                        TextField("", text: $name, prompt: Text("Apple Card, Cash, etc.").foregroundColor(dynamicText.opacity(0.2)))
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundColor(dynamicText)
                            .tint(dynamicText.opacity(0.5))
                        
                        Rectangle()
                            .fill(dynamicText.opacity(0.1))
                            .frame(height: 1)
                    }
                    
                    // Type Selector (Minimal)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("TYPE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.3))
                            .tracking(1.5)
                        
                        HStack(spacing: 32) {
                            ForEach(PaymentMethod.PaymentType.allCases, id: \.self) { type in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedType = type
                                    }
                                }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: type == .cash ? "banknote" : "creditcard")
                                            .font(.system(size: 16, weight: selectedType == type ? .semibold : .regular))
                                        Text(type.rawValue.capitalized)
                                            .font(.system(size: 16, weight: selectedType == type ? .semibold : .medium, design: .monospaced))
                                    }
                                    .foregroundColor(dynamicText.opacity(selectedType == type ? 1.0 : 0.3))
                                    .scaleEffect(selectedType == type ? 1.05 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // Color Selector (Dots only, no fill/background)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PALETTE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.3))
                            .tracking(1.5)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(PaymentMethod.presetColors, id: \.self) { colorHex in
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                            selectedColorHex = colorHex
                                        }
                                    }) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: colorHex) ?? .gray)
                                                .frame(width: 28, height: 28)
                                            
                                            if selectedColorHex == colorHex {
                                                Circle()
                                                    .stroke(dynamicText, lineWidth: 2)
                                                    .frame(width: 36, height: 36)
                                            }
                                        }
                                        .frame(width: 40, height: 40)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Save Button (Mochi Style)
                let currentHighlightColor = Color(hex: selectedColorHex) ?? dynamicText
                
                Button(action: saveMethod) {
                    Text(isEditing ? "Done" : "Save Method")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(currentHighlightColor)
                        .clipShape(Capsule())
                        .shadow(color: currentHighlightColor.opacity(0.3), radius: 12, y: 6)
                }
                .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if let method = editingMethod {
                name = method.name
                selectedType = method.type
                selectedColorHex = method.colorHex
            }
        }
    }
    
    private func saveMethod() {
        HapticManager.shared.success()
        var finalName = name.trimmingCharacters(in: .whitespaces)
        
        // Default name if empty
        if finalName.isEmpty {
            finalName = selectedType == .cash ? "Cash" : "Card"
        }
        
        if let existing = editingMethod {
            let updated = PaymentMethod(
                id: existing.id,
                name: finalName,
                colorHex: selectedColorHex,
                type: selectedType,
                isDefault: existing.isDefault
            )
            settings.updatePaymentMethod(updated)
        } else {
            let newMethod = PaymentMethod(name: finalName, colorHex: selectedColorHex, type: selectedType)
            settings.addPaymentMethod(newMethod)
            settings.selectPaymentMethod(newMethod)
        }
        dismiss()
    }
}

// MARK: - Squishy Card Style

struct SquishyCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
