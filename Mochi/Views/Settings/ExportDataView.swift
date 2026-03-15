import SwiftUI
import SwiftData
import UIKit
import LinkPresentation

struct ExportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @ObservedObject var settings = SettingsManager.shared
    
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var exportType: ExportType = .csv
    
    @Namespace private var rangeNamespace
    
    // Range State
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var useAllTime = true
    
    enum ExportType {
        case csv, pdf
    }
    
    var filteredItems: [Item] {
        if useAllTime { return items }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        
        return items.filter { $0.timestamp >= start && $0.timestamp <= end }
    }

    private var summaryTotalValue: String {
        let currencyCodes = Set(filteredItems.map { settings.normalizedCurrencyCode(for: $0) })
        guard currencyCodes.count == 1, let code = currencyCodes.first else {
            return "MIXED"
        }
        let total = filteredItems.reduce(0) { $0 + $1.amount }
        return "\(settings.currencySymbol(for: code))\(String(format: "%.0f", total))"
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { /* Dismiss happens via NavStack/Link */ }) {
                        // This view is usually pushed, so back button is automatic
                        // But we want a custom header feel
                        Text("Data & Export")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(dynamicText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Reflection Summary Card
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(useAllTime ? "Full History" : "Filtered Range")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(dynamicText.opacity(0.4))
                                        .tracking(1)
                                    
                                    Text("\(filteredItems.count)")
                                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                                        .foregroundColor(dynamicText)
                                }
                                Spacer()
                                Circle()
                                    .fill(settings.currentPastelTheme.accent.opacity(0.1))
                                    .frame(width: 54, height: 54)
                                    .overlay {
                                        Image(systemName: useAllTime ? "infinity" : "calendar")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(settings.currentPastelTheme.accent)
                                    }
                            }
                            
                            HStack(spacing: 12) {
                                SummaryPill(
                                    label: "Total", 
                                    value: summaryTotalValue,
                                    dynamicText: dynamicText
                                )
                                SummaryPill(
                                    label: "Items", 
                                    value: "\(filteredItems.count)",
                                    dynamicText: dynamicText
                                )
                            }
                        }
                        .padding(28)
                        .background(
                            RoundedRectangle(cornerRadius: 32)
                                .fill(dynamicText.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32)
                                        .stroke(dynamicText.opacity(0.06), lineWidth: 1)
                                )
                        )
                        
                        // Date Range Filter
                        VStack(spacing: 20) {
                            // Professional Pill Switcher
                            HStack(spacing: 4) {
                                RangeOptionButton(title: "Full History", isSelected: useAllTime, dynamicText: dynamicText, accent: settings.currentPastelTheme.accent, namespace: rangeNamespace) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        useAllTime = true
                                    }
                                }
                                
                                RangeOptionButton(title: "Custom Range", isSelected: !useAllTime, dynamicText: dynamicText, accent: settings.currentPastelTheme.accent, namespace: rangeNamespace) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        useAllTime = false
                                    }
                                }
                            }
                            .padding(4)
                            .background(dynamicText.opacity(0.04))
                            .clipShape(Capsule())
                            
                            if !useAllTime {
                                VStack(spacing: 16) {
                                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .tint(settings.currentPastelTheme.accent)
                                    
                                    Divider().opacity(0.1)
                                    
                                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .tint(settings.currentPastelTheme.accent)
                                }
                                .padding(24)
                                .background(dynamicText.opacity(0.02))
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(dynamicText.opacity(0.05), lineWidth: 1)
                                )
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: -12)).combined(with: .scale(scale: 0.96)),
                                        removal: .opacity.combined(with: .offset(y: -8))
                                    )
                                )
                            }
                        }
                        
                        // Export Actions
                        VStack(alignment: .leading, spacing: 16) {
                            Text("EXPORT OPTIONS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.3))
                                .tracking(1)
                                .padding(.horizontal, 8)
                            
                            VStack(spacing: 12) {
                                ExportRow(
                                    title: "Spreadsheet (.csv)",
                                    subtitle: "Perfect for analysis in Excel or Notion.",
                                    icon: "tablecells",
                                    color: settings.currentPastelTheme.accent,
                                    textColor: dynamicText,
                                    action: { startExport(type: .csv) }
                                )
                                
                                ExportRow(
                                    title: "Visual Report (.pdf)",
                                    subtitle: "A clean, printable transaction ledger.",
                                    icon: "doc.text.fill",
                                    color: settings.currentPastelTheme.accent,
                                    textColor: dynamicText,
                                    action: { startExport(type: .pdf) }
                                )
                            }
                        }
                        
                        // Footer Tagline
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 12))
                            Text("Your data never leaves this device.")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(dynamicText.opacity(0.3))
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { exportURL = nil }) {
            if let url = exportURL {
                let subject = exportType == .csv ? "Mochi Data Export" : "Mochi Transaction History"
                let source = ShareActivityItemSource(url: url, subject: subject)
                
                ShareSheet(activityItems: [source])
                    .presentationDetents([.medium, .large])
            }
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("Preparing export...")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(32)
                    .background(Color.mochiText.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                }
            }
        }
    }
    
    private func startExport(type: ExportType) {
        HapticManager.shared.rigidImpact()
        isExporting = true
        
        // Dispatch to background for heavy generation
        let exportItems = filteredItems
        
        DispatchQueue.global(qos: .userInitiated).async {
            let url: URL?
            if type == .csv {
                url = ExportManager.shared.generateCSV(items: exportItems, settings: settings)
            } else {
                url = generatePDF(itemsToExport: exportItems)
            }
            
            DispatchQueue.main.async {
                self.isExporting = false
                if let url = url {
                    self.exportURL = url
                    self.showShareSheet = true
                }
            }
        }
    }
    
    private func generatePDF(itemsToExport: [Item]) -> URL? {
        let fileName = "Mochi_History_\(Date().formatted(.dateTime.year().month().day())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let format = UIGraphicsPDFRendererFormat()
        let pageWidth: CGFloat = 595.2 // A4 width
        let pageHeight: CGFloat = 841.8 // A4 height
        let margin: CGFloat = 50
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight), format: format)
        
        // Calculate items per page and total pages
        let itemsPerPage = 35
        let totalItems = itemsToExport.count
        let totalPages = max(1, Int(ceil(Double(totalItems) / Double(itemsPerPage))))
        
        // Use fixed print-safe colors (Black on White) to avoid Dark Mode invisibility
        let primaryUIColor = UIColor.black
        let secondaryUIColor = UIColor.darkGray
        let accentUIColor = UIColor.lightGray
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let periodStr = useAllTime ? "Full History" : "\(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        
        do {
            try renderer.writePDF(to: url) { context in
                for pageIndex in 0..<totalPages {
                    context.beginPage()
                    
                    // --- Header ---
                    var headerY = margin
                    
                    // Logo
                    if let logo = UIImage(named: "MochiLogo") {
                        logo.draw(in: CGRect(x: margin, y: headerY, width: 40, height: 40))
                        headerY += 50
                    }
                    
                    let titleAttributes: [NSAttributedString.Key: Any] = [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22, weight: .bold),
                        NSAttributedString.Key.foregroundColor: primaryUIColor
                    ]
                    "Mochi Transaction History".draw(at: CGPoint(x: margin, y: headerY), withAttributes: titleAttributes)
                    
                    let periodAttributes: [NSAttributedString.Key: Any] = [
                        NSAttributedString.Key.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                        NSAttributedString.Key.foregroundColor: secondaryUIColor
                    ]
                    "Statement Period: \(periodStr)".draw(at: CGPoint(x: margin, y: headerY + 28), withAttributes: periodAttributes)
                    
                    let dateAttributes: [NSAttributedString.Key: Any] = [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .regular),
                        NSAttributedString.Key.foregroundColor: secondaryUIColor.withAlphaComponent(0.6)
                    ]
                    "Generated: \(Date().formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: headerY + 45), withAttributes: dateAttributes)
                    
                    let pageInfoAttributes: [NSAttributedString.Key: Any] = [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 10, weight: .regular),
                        NSAttributedString.Key.foregroundColor: secondaryUIColor.withAlphaComponent(0.4)
                    ]
                    "Page \(pageIndex + 1) of \(totalPages)".draw(at: CGPoint(x: pageWidth - margin - 80, y: headerY), withAttributes: pageInfoAttributes)
                    
                    context.cgContext.setStrokeColor(accentUIColor.withAlphaComponent(0.3).cgColor)
                    context.cgContext.move(to: CGPoint(x: margin, y: headerY + 65))
                    context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: headerY + 65))
                    context.cgContext.strokePath()
                    
                    // --- Table Headers ---
                    var yOffset: CGFloat = headerY + 80
                    let headerFont = UIFont.systemFont(ofSize: 10, weight: .bold)
                    let itemFont = UIFont.systemFont(ofSize: 10, weight: .regular)
                    
                    let headers = ["Date", "Note", "Amount", "Method"]
                    // Adjusted widths to give Amount more space, but we will add padding
                    // Date: 75, Note: 170 (was 190), Amount: 140 (was 120), Method: 110
                    let columnWidths: [CGFloat] = [75, 170, 140, 110]
                    var xOffset: CGFloat = margin
                    
                    for (index, header) in headers.enumerated() {
                        let alignment: NSTextAlignment = (index == 2) ? .right : .left
                        // Add right padding to Amount column so it doesn't touch Method
                        let widthAdjustment: CGFloat = (index == 2) ? -20 : 0
                        
                        let rect = CGRect(x: xOffset, y: yOffset, width: columnWidths[index] + widthAdjustment, height: 20)
                        let para = NSMutableParagraphStyle()
                        para.alignment = alignment
                        header.draw(in: rect, withAttributes: [
                            NSAttributedString.Key.font: headerFont,
                            NSAttributedString.Key.foregroundColor: primaryUIColor,
                            NSAttributedString.Key.paragraphStyle: para
                        ])
                        xOffset += columnWidths[index]
                    }
                    
                    yOffset += 25
                    context.cgContext.move(to: CGPoint(x: margin, y: yOffset - 5))
                    context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset - 5))
                    context.cgContext.strokePath()
                    
                    // --- Rows ---
                    let startIdx = pageIndex * itemsPerPage
                    let endIdx = min(startIdx + itemsPerPage, totalItems)
                    let pageItems = itemsToExport[startIdx..<endIdx]
                    
                    let rowDateFormatter = DateFormatter()
                    rowDateFormatter.dateStyle = .short
                    
                    for item in pageItems {
                        xOffset = margin
                        let dateStr = rowDateFormatter.string(from: item.timestamp)
                        let noteStr = String((item.note ?? "-").prefix(30))
                        let amountStr = "\(settings.currencySymbol(for: item.currencyCode))\(String(format: "%.2f", item.amount))"
                        let methodStr = settings.getPaymentMethod(by: item.paymentMethodId)?.name ?? "Cash"
                        
                        let values = [dateStr, noteStr, amountStr, methodStr]
                        
                        for (index, value) in values.enumerated() {
                            let alignment: NSTextAlignment = (index == 2) ? .right : .left
                            // Add right padding to Amount column here too
                            let widthAdjustment: CGFloat = (index == 2) ? -20 : 0
                            
                            let rect = CGRect(x: xOffset, y: yOffset, width: columnWidths[index] + widthAdjustment, height: 18)
                            let para = NSMutableParagraphStyle()
                            para.alignment = alignment
                            value.draw(in: rect, withAttributes: [
                                NSAttributedString.Key.font: itemFont,
                                NSAttributedString.Key.foregroundColor: primaryUIColor,
                                NSAttributedString.Key.paragraphStyle: para
                            ])
                            xOffset += columnWidths[index]
                        }
                        yOffset += 20
                    }
                    
                    // --- Total (Last Page) ---
                    if pageIndex == totalPages - 1 {
                        yOffset += 20
                        context.cgContext.setStrokeColor(primaryUIColor.withAlphaComponent(0.15).cgColor)
                        context.cgContext.move(to: CGPoint(x: margin, y: yOffset))
                        context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: yOffset))
                        context.cgContext.strokePath()
                        yOffset += 10
                        
                        let totalLabelStr = "TOTAL:"
                        let currencyCodes = Set(itemsToExport.map { settings.normalizedCurrencyCode(for: $0) })
                        let totalValueStr: String
                        if currencyCodes.count == 1, let code = currencyCodes.first {
                            let totalAmount = itemsToExport.reduce(0) { $0 + $1.amount }
                            totalValueStr = "\(settings.currencySymbol(for: code))\(String(format: "%.2f", totalAmount))"
                        } else {
                            totalValueStr = "MIXED"
                        }
                        
                        let totalFont = UIFont.systemFont(ofSize: 12, weight: .bold)
                        
                        let labelRect = CGRect(x: margin, y: yOffset, width: columnWidths[0] + columnWidths[1], height: 25)
                        let leftPara = NSMutableParagraphStyle()
                        leftPara.alignment = .left
                        totalLabelStr.draw(in: labelRect, withAttributes: [
                            NSAttributedString.Key.font: totalFont,
                            NSAttributedString.Key.foregroundColor: primaryUIColor,
                            NSAttributedString.Key.paragraphStyle: leftPara
                        ])
                        
                        let amountX = margin + columnWidths[0] + columnWidths[1]
                        let amountWidth = columnWidths[2] - 20
                        let amountRect = CGRect(x: amountX, y: yOffset, width: amountWidth, height: 25)
                        let rightPara = NSMutableParagraphStyle()
                        rightPara.alignment = .right
                        totalValueStr.draw(in: amountRect, withAttributes: [
                            NSAttributedString.Key.font: totalFont,
                            NSAttributedString.Key.foregroundColor: primaryUIColor,
                            NSAttributedString.Key.paragraphStyle: rightPara
                        ])
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Components

struct SummaryPill: View {
    let label: String
    let value: String
    let dynamicText: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(dynamicText.opacity(0.3))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(dynamicText.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(dynamicText.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RangeOptionButton: View {
    let title: String
    let isSelected: Bool
    let dynamicText: Color
    let accent: Color
    var namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : dynamicText.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(accent)
                            .matchedGeometryEffect(id: "pill", in: namespace)
                    }
                }
        }
    }
}

struct ExportRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.system(size: 18, weight: .bold))
                    }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(textColor.opacity(0.5))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor.opacity(0.2))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(textColor.opacity(0.03))
            )
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Helpers

class ShareActivityItemSource: NSObject, UIActivityItemSource {
    let url: URL
    let subject: String
    
    init(url: URL, subject: String) {
        self.url = url
        self.subject = subject
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        return subject
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = subject
        metadata.originalURL = url
        metadata.url = url
        return metadata
    }
}
