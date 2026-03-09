import SwiftUI
import PhotosUI

// MARK: - ReceiptReviewView

struct ReceiptReviewView: View {
    // Theme (passed in from MainContentView — same pattern as HistoryView)
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    let isNightTime: Bool

    let result: ReceiptScanResult
    let onSave: (Double, String?, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    // MARK: Local State
    @State private var editableNote: String = ""
    @State private var lineItems: [ReceiptLineItem] = []
    @State private var addAsSingleTotal: Bool = true
    @State private var useReceiptDate: Bool = true

    // MARK: Computed

    private var finalDate: Date {
        useReceiptDate ? (result.receiptDate ?? Date()) : Date()
    }

    private var defaultTotalNote: String {
        result.billType ?? result.merchantName ?? ""
    }

    private var finalAmount: Double {
        if result.hasSelectableLineItems && !addAsSingleTotal {
            return lineItems.filter(\.isSelected).reduce(0) { $0 + $1.amount }
        }
        return result.totalAmount ?? 0
    }

    private var selectedCount: Int {
        lineItems.filter(\.isSelected).count
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    // MARK: Body

    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(dynamicText.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        amountSection

                        if result.hasSelectableLineItems {
                            lineItemsSection
                        }

                        if addAsSingleTotal || !result.hasSelectableLineItems {
                            noteSection
                        }

                        if result.isBackdatedDate {
                            dateSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 120)
                }

                // Sticky confirm button
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(dynamicText.opacity(0.06))
                        .frame(height: 1)

                    Button(action: confirmAndSave) {
                        Text("Add to Mochi")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(isNightTime ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(SquishyButtonStyle(isDoneButton: true))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .disabled(finalAmount <= 0)
                }
                .background(dynamicBackground)
            }
        }
        .onAppear {
            lineItems = result.lineItems
            addAsSingleTotal = !result.hasSelectableLineItems
            editableNote = defaultTotalNote
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt Scanned")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(dynamicText)

                Text(result.extractionStatus.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(result.extractionStatus == .aiEnhanced ? .green.opacity(0.85) : dynamicText.opacity(0.45))

                if let merchant = result.merchantName {
                    Text(merchant)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(dynamicText.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dynamicText.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(dynamicText.opacity(0.08))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Amount")

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(settings.currencySymbol)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.45))

                Text(String(format: "%.2f", finalAmount))
                    .font(.system(size: 52, weight: .semibold, design: .monospaced))
                    .foregroundColor(dynamicText)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: finalAmount)
            }
        }
    }

    // MARK: - Line Items

    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Items Found")

            // Segmented pill toggle
            HStack(spacing: 0) {
                pillOption("One Total", selected: addAsSingleTotal) {
                    withAnimation(.spring(response: 0.28)) { addAsSingleTotal = true }
                }
                pillOption("Separate (\(selectedCount))", selected: !addAsSingleTotal) {
                    withAnimation(.spring(response: 0.28)) { addAsSingleTotal = false }
                }
            }
            .padding(3)
            .background(dynamicText.opacity(0.06))
            .clipShape(Capsule())

            if !addAsSingleTotal {
                VStack(spacing: 6) {
                    ForEach(lineItems.indices, id: \.self) { i in
                        lineItemRow(i)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private func lineItemRow(_ index: Int) -> some View {
        let item = lineItems[index]
        HStack(spacing: 12) {
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(item.isSelected ? accentColor : dynamicText.opacity(0.25))

            Text(item.description)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(item.isSelected ? dynamicText : dynamicText.opacity(0.35))
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(settings.currencySymbol)\(String(format: "%.2f", item.amount))")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(item.isSelected ? dynamicText : dynamicText.opacity(0.35))

                if let qty = item.quantity, let unit = item.unitPrice, qty > 0, unit > 0 {
                    Text("\(String(format: "%.2f", qty)) x \(String(format: "%.2f", unit))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(dynamicText.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(dynamicText.opacity(item.isSelected ? 0.04 : 0.02))
        )
        .onTapGesture {
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.25)) {
                lineItems[index].isSelected.toggle()
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Bill Type")

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(accentColor)

                TextField("e.g. Restaurant, Grocery, Fuel", text: $editableNote)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(dynamicText)
                    .tint(accentColor)
                    .submitLabel(.done)

                if !editableNote.isEmpty {
                    Button(action: { editableNote = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(dynamicText.opacity(0.28))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(dynamicText.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(accentColor.opacity(0.18), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Date

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Add to which day?")

            HStack(spacing: 0) {
                if let receiptDate = result.receiptDate {
                    pillOption(dateFormatter.string(from: receiptDate), selected: useReceiptDate) {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.28)) { useReceiptDate = true }
                    }
                }
                pillOption("Today", selected: !useReceiptDate) {
                    HapticManager.shared.selection()
                    withAnimation(.spring(response: 0.28)) { useReceiptDate = false }
                }
            }
            .padding(3)
            .background(dynamicText.opacity(0.06))
            .clipShape(Capsule())

            if let receiptDate = result.receiptDate {
                Text("Receipt date: \(dateFormatter.string(from: receiptDate))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.35))
            }
        }
    }

    // MARK: - Save

    private func confirmAndSave() {
        HapticManager.shared.rigidImpact()

        if result.hasSelectableLineItems && !addAsSingleTotal {
            for item in lineItems.filter(\.isSelected) {
                onSave(item.amount, item.description, finalDate)
            }
        } else {
            let note = editableNote.isEmpty ? nil : editableNote
            onSave(finalAmount, note, finalDate)
        }

        dismiss()
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(dynamicText.opacity(0.38))
            .tracking(1.5)
    }

    private func pillOption(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundColor(selected ? (isNightTime ? .black : .white) : dynamicText.opacity(0.55))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? accentColor : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28), value: selected)
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - PhotoLibraryPickerView

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoLibraryPickerView
        init(_ parent: PhotoLibraryPickerView) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.parent.onImageSelected(image)
                    }
                }
            }
        }
    }
}
