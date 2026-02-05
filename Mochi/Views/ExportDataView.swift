import SwiftUI
import SwiftData

struct ExportDataView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
    @ObservedObject var settings = SettingsManager.shared
    
    let dynamicText: Color
    let dynamicBackground: Color
    let isNightTime: Bool
    
    @State private var exportType: ExportType = .month
    @State private var exportFormat: ExportFormat = .csv
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedMonth = Date()
    @State private var selectedDay = Date()
    
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    
    enum ExportType: String, CaseIterable, Identifiable {
        case day = "Day"
        case month = "Month"
        case custom = "Custom"
        var id: String { self.rawValue }
    }
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case pdf = "PDF"
        var id: String { self.rawValue }
    }
    
    var filteredItems: [Item] {
        let calendar = Calendar.current
        switch exportType {
        case .day:
            return items.filter { calendar.isDate($0.timestamp, inSameDayAs: selectedDay) }
        case .month:
            return items.filter { calendar.isDate($0.timestamp, equalTo: selectedMonth, toGranularity: .month) && calendar.isDate($0.timestamp, equalTo: selectedMonth, toGranularity: .year) }
        case .custom:
            return items.filter { $0.timestamp >= calendar.startOfDay(for: startDate) && $0.timestamp <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate }
        }
    }
    
    var accentColor: Color {
        if settings.colorTheme != "default" {
            return settings.currentPastelTheme.accent
        }
        return Color(red: 0.35, green: 0.65, blue: 0.55)
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        HapticManager.shared.softSquish()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(dynamicText)
                            .frame(width: 32, height: 32)
                    }
                    Spacer()
                    Text("Export Data")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(dynamicText)
                    Spacer()
                    Color.clear.frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // Range Type
                        SettingsSection(icon: "calendar", title: "RANGE", textColor: dynamicText) {
                            HStack(spacing: 0) {
                                ForEach(ExportType.allCases) { type in
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        exportType = type
                                    }) {
                                        Text(type.rawValue)
                                            .font(.system(size: 14, weight: exportType == type ? .bold : .medium, design: .rounded))
                                            .foregroundColor(exportType == type ? dynamicBackground : dynamicText)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(exportType == type ? dynamicText : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                            .padding(4)
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Date Pickers
                        SettingsSection(icon: "clock.fill", title: "SELECT PERIOD", textColor: dynamicText) {
                            VStack(spacing: 0) {
                                if exportType == .day {
                                    DatePicker("Select Day", selection: $selectedDay, displayedComponents: .date)
                                        .tint(accentColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                } else if exportType == .month {
                                    DatePicker("Select Month", selection: $selectedMonth, displayedComponents: .date)
                                        .tint(accentColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                } else {
                                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                                        .tint(accentColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                    Divider().padding(.horizontal, 16).opacity(0.1)
                                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                                        .tint(accentColor)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                }
                            }
                            .background(dynamicText.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        // Format Type
                        SettingsSection(icon: "doc.fill", title: "FORMAT", textColor: dynamicText) {
                            HStack(spacing: 12) {
                                ForEach(ExportFormat.allCases) { format in
                                    Button(action: {
                                        HapticManager.shared.selection()
                                        exportFormat = format
                                    }) {
                                        HStack {
                                            Image(systemName: format == .csv ? "tablecells" : "doc.richtext")
                                            Text(format.rawValue)
                                        }
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(exportFormat == format ? dynamicBackground : dynamicText)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(exportFormat == format ? dynamicText : dynamicText.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                }
                            }
                        }
                        
                        // Export Button
                        Button(action: prepareExport) {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export \(filteredItems.count) Items")
                                }
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(isNightTime ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: accentColor.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.top, 16)
                        .disabled(filteredItems.isEmpty)
                        .opacity(filteredItems.isEmpty ? 0.5 : 1)
                        
                        if filteredItems.isEmpty {
                            Text("No items found for this period.")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(dynamicText.opacity(0.3))
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private func prepareExport() {
        HapticManager.shared.rigidImpact()
        
        if exportFormat == .csv {
            if let url = ExportManager.shared.generateCSV(items: filteredItems, settings: settings) {
                exportURL = url
                showShareSheet = true
            }
        } else {
            // PDF Generation using ImageRenderer
            generatePDF()
        }
    }
    
    @MainActor
    private func generatePDF() {
        let renderer = ImageRenderer(content: ExportPDFView(items: Array(filteredItems.prefix(25)), settings: settings, isNightTime: isNightTime, pageIndex: 1, totalPages: 1, totalAmount: nil))
        
        let fileName = "Mochi_Export_\(Date().formatted(.dateTime.year().month().day())).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        renderer.render { size, context in
            var box = CGRect(origin: .zero, size: size)
            guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            
            // Calculate pages
            let itemsPerPage = 25
            let totalPages = Int(ceil(Double(filteredItems.count) / Double(itemsPerPage)))
            // Handle empty case
            let loopCount = max(1, totalPages)
            
            for pageIndex in 0..<loopCount {
                let startIndex = pageIndex * itemsPerPage
                let endIndex = min(startIndex + itemsPerPage, filteredItems.count)
                let pageItems = Array(filteredItems[startIndex..<endIndex])
                
                // Update the view with current page data
                let pageView = ExportPDFView(
                    items: pageItems,
                    settings: settings,
                    isNightTime: isNightTime,
                    pageIndex: pageIndex + 1,
                    totalPages: loopCount,
                    totalAmount: pageIndex == loopCount - 1 ? filteredItems.reduce(0) { $0 + $1.amount } : nil
                )
                
                let pageRenderer = ImageRenderer(content: pageView)
                
                pdfContext.beginPDFPage(nil)
                pageRenderer.render { _, pageContext in
                    pageContext(pdfContext)
                }
                pdfContext.endPDFPage()
            }
            
            pdfContext.closePDF()
            
            self.exportURL = url
            self.showShareSheet = true
        }
    }
}

// MARK: - PDF Template
struct ExportPDFView: View {
    let items: [Item]
    let settings: SettingsManager
    let isNightTime: Bool
    let pageIndex: Int
    let totalPages: Int
    let totalAmount: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOCHI")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                    Text("Spending Export")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .opacity(0.6)
                }
                Spacer()
                Text("Page \(pageIndex) of \(totalPages)")
                    .font(.system(size: 12, design: .monospaced))
                    .opacity(0.4)
            }
            .padding(.bottom, 20)
            
            Divider()
            
            ForEach(items) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.timestamp, style: .date)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        Text(item.timestamp, style: .time)
                            .font(.system(size: 9, design: .monospaced))
                            .opacity(0.5)
                    }
                    
                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.leading, 10)
                    }
                    
                    Spacer()
                    
                    Text("\(settings.currencySymbol)\(String(format: "%.2f", item.amount))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .padding(.vertical, 4)
                Divider().opacity(0.1)
            }
            
            Spacer()
            
            if let total = totalAmount {
                HStack {
                    Text("TOTAL")
                    Spacer()
                    Text("\(settings.currencySymbol)\(String(format: "%.2f", total))")
                }
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .padding(.top, 20)
            }
        }
        .padding(40)
        .frame(width: 612) // A4 Width approx
        .background(Color.white)
        .foregroundColor(.black)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
