import SwiftUI

struct SpeedDialSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @Environment(\.dismiss) var dismiss
    
    // Dynamic Colors
    let dynamicText: Color
    let dynamicBackground: Color
    
    // Edit State
    @State private var editingKey: Int?
    @State private var editAmount = ""
    @State private var editLabel = ""
    @State private var editPaymentMethodId: String?
    @State private var showEditSheet = false

    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
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
                            .overlay(
                                Circle()
                                    .stroke(dynamicText.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    Spacer()
                    
                    // Icon or Title
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18))
                            .foregroundColor(SettingsManager.shared.currentPastelTheme.accent)
                        Text("Speed Dial")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                    }
                    
                    Spacer()
                    
                    // Balance
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)
                
                Spacer()
                
                // Content Group
                VStack(spacing: 32) {
                    Text("Long press any number on the keypad to\ninstantly add a preset transaction.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(dynamicText.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    // Keypad Grid Preview
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 24) {
                        ForEach(1...9, id: \.self) { num in
                            Button {
                                editingKey = num
                                if let preset = settings.speedDialPresets[num] {
                                    editAmount = String(format: "%.2f", preset.amount)
                                    editLabel = preset.label
                                    editPaymentMethodId = preset.paymentMethodId
                                } else {
                                    editAmount = ""
                                    editLabel = ""
                                    editPaymentMethodId = nil
                                }
                                showEditSheet = true
                                HapticManager.shared.lightImpact()
                            } label: {
                                SpeedDialKeyView(
                                    number: num,
                                    preset: settings.speedDialPresets[num],
                                    dynamicText: dynamicText,
                                    accentColor: SettingsManager.shared.currentPastelTheme.accent
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                Spacer() // Weighted push to keep it slightly above true center for optical balance
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                VStack(spacing: 24) {
                    // Key Indicator
                    VStack(spacing: 4) {
                        Text("Key \(editingKey ?? 0)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(dynamicText.opacity(0.5))
                            .padding(.top, 24)
                    }
                    
                    // Input Fields
                    VStack(spacing: 16) {
                        HStack {
                            Text(settings.currencySymbol)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.7))
                            
                            TextField("0.00", text: $editAmount)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundColor(dynamicText)
                        }
                        .padding()
                        .background(dynamicText.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        TextField("Label (e.g. Coffee)", text: $editLabel)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding()
                            .background(dynamicText.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .foregroundColor(dynamicText)
                            
                        // Payment Type Selector
                        HStack {
                            Text("Payment Type")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(dynamicText.opacity(0.8))
                            Spacer()
                            Menu {
                                Button {
                                    editPaymentMethodId = nil
                                } label: {
                                    HStack {
                                        Text("App Default")
                                        if editPaymentMethodId == nil {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                ForEach(settings.paymentMethods) { method in
                                    Button {
                                        editPaymentMethodId = method.id.uuidString
                                    } label: {
                                        HStack {
                                            Text(method.name)
                                            if editPaymentMethodId == method.id.uuidString {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if let methodId = editPaymentMethodId, let method = settings.paymentMethods.first(where: { $0.id.uuidString == methodId }) {
                                        Image(systemName: method.type.icon)
                                            .foregroundColor(method.color)
                                        Text(method.name)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText)
                                    } else {
                                        Text("App Default")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(dynamicText.opacity(0.5))
                                    }
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(dynamicText.opacity(0.3))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(dynamicText.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding()
                        .background(dynamicText.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .background(dynamicBackground)
                .navigationTitle("Edit Preset")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditSheet = false }
                            .foregroundColor(dynamicText)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            savePreset()
                        }
                        .fontWeight(.bold)
                        .foregroundColor(SettingsManager.shared.currentPastelTheme.accent)
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") {
                            clearPreset()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(32)
        }
    }
    
    private func savePreset() {
        guard let key = editingKey, let amount = Double(editAmount) else { return }
        let preset = SettingsManager.SpeedDialPreset(amount: amount, label: editLabel, icon: "", paymentMethodId: editPaymentMethodId)
        settings.speedDialPresets[key] = preset
        showEditSheet = false
        HapticManager.shared.success()
    }
    
    private func clearPreset() {
        guard let key = editingKey else { return }
        settings.speedDialPresets.removeValue(forKey: key)
        showEditSheet = false
        HapticManager.shared.softSquish()
    }
}

struct SpeedDialKeyView: View {
    let number: Int
    let preset: SettingsManager.SpeedDialPreset?
    let dynamicText: Color
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(preset != nil ? accentColor.opacity(0.15) : dynamicText.opacity(0.05))
                    .frame(width: 96, height: 96) // Increased from 80
                
                if let preset = preset {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", preset.amount))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(accentColor)
                    }
                } else {
                    Text("\(number)")
                        .font(.system(size: 38, weight: .medium, design: .monospaced)) // Increased from 32
                        .foregroundColor(dynamicText.opacity(0.3))
                }
            }
            
            Text(preset?.label ?? "Empty")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(dynamicText.opacity(preset != nil ? 0.8 : 0.3))
                .lineLimit(1)
                .frame(width: 96)
        }
    }
}
