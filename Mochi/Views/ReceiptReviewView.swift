import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
#if canImport(VisionKit)
import VisionKit
#endif

// MARK: - ReceiptReviewView

struct ReceiptReviewView: View {
    // Theme (passed in from MainContentView — same pattern as HistoryView)
    let dynamicText: Color
    let dynamicBackground: Color
    let accentColor: Color
    let isNightTime: Bool

    let result: ReceiptScanResult
    let onSave: (Double, String?, Date, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsManager.shared

    // MARK: Local State
    @State private var editableNote: String = ""
    @State private var useReceiptDate: Bool = true
    @State private var editableAmountText: String = ""
    @State private var manualDate: Date = Date()
    @State private var showCurrencyMismatchAlert: Bool = false

    // MARK: Computed

    private var finalDate: Date {
        if useReceiptDate, let receiptDate = result.receiptDate, result.isDateReliable {
            return receiptDate
        }
        return manualDate
    }

    private var defaultTotalNote: String {
        return result.merchantName ?? "Scanned Receipt"
    }

    private var displayStoreName: String {
        if !editableNote.isEmpty { return editableNote }
        return result.merchantName ?? "Unknown Store"
    }

    private var finalAmount: Double {
        let cleaned = editableAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(cleaned) ?? 0
    }

    private var displayCurrencySymbol: String {
        settings.currencySymbol(for: result.currencyCode)
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

                        noteSection

                        if !result.isDateReliable || result.isBackdatedDate {
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

                    Button(action: { confirmAndSave() }) {
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
            editableNote = defaultTotalNote
            if editableAmountText.isEmpty {
                let amount = result.totalAmount ?? 0
                editableAmountText = String(format: "%.2f", amount)
            }
            manualDate = result.receiptDate ?? Date()
            useReceiptDate = result.receiptDate != nil && result.isDateReliable
        }
        .alert("Currency Mismatch", isPresented: $showCurrencyMismatchAlert) {
            Button("Switch to \(result.currencyCode ?? "")") {
                if let code = result.currencyCode, !code.isEmpty {
                    settings.customCurrencyCode = code
                }
                confirmAndSave(forceSave: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This receipt appears to be in \(result.currencyCode ?? "a different currency"), but your app currency is \(settings.activeCurrencyCode). Switch currency to save?")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt Scanned")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(dynamicText)

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
            sectionLabel(String(localized: "AMOUNT"))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(displayCurrencySymbol)
                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.45))

                TextField("0.00", text: $editableAmountText)
                    .font(.system(size: 52, weight: .semibold, design: .monospaced))
                    .foregroundColor(dynamicText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            
            Text("OCR is ~90% accurate. Please verify before saving.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(dynamicText.opacity(0.4))
        }
    }

    // MARK: - Note (Visual Store Name input)

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(String(localized: "BILL TYPE/STORE NAME"))

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(accentColor)

                // We only show the Merchant visually in standard text box if the user wants to change the store name
                TextField("e.g. Restaurant, Grocery, Fuel", text: $editableNote)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(dynamicText)
                    .tint(accentColor)
                    .submitLabel(.done)
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

            if let receiptDate = result.receiptDate, result.isDateReliable {
                HStack(spacing: 0) {
                    pillOption(dateFormatter.string(from: receiptDate), selected: useReceiptDate) {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.28)) { useReceiptDate = true }
                    }
                    pillOption("Today", selected: !useReceiptDate) {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.28)) { useReceiptDate = false }
                    }
                }
                .padding(3)
                .background(dynamicText.opacity(0.06))
                .clipShape(Capsule())

                Text("Receipt date: \(dateFormatter.string(from: receiptDate))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.35))
            } else {
                DatePicker("Select date", selection: $manualDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(accentColor)

                Text("Receipt date not found. Please select a date.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(dynamicText.opacity(0.35))
            }
        }
    }

    // MARK: - Save

    private func confirmAndSave(forceSave: Bool = false) {
        HapticManager.shared.rigidImpact()

        if !forceSave,
           let detected = result.currencyCode,
           !detected.isEmpty,
           detected != settings.activeCurrencyCode {
            showCurrencyMismatchAlert = true
            return
        }

        let note = editableNote.isEmpty ? nil : editableNote
        onSave(finalAmount, note, finalDate, result.currencyCode)

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

// MARK: - DocumentScannerView

#if canImport(VisionKit)
struct DocumentScannerView: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                parent.onImageSelected(image)
            }
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}
#else
// Fallback for platforms without VisionKit.
struct DocumentScannerView: UIViewControllerRepresentable {
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
        let parent: DocumentScannerView
        init(_ parent: DocumentScannerView) { self.parent = parent }

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
#endif

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

            let typeId = UTType.image.identifier
            if provider.hasItemConformingToTypeIdentifier(typeId) {
                provider.loadFileRepresentation(forTypeIdentifier: typeId) { [weak self] url, _ in
                    guard let url else { return }
                    if let data = try? Data(contentsOf: url),
                       let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self?.parent.onImageSelected(image)
                        }
                    }
                }
            } else {
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
}
