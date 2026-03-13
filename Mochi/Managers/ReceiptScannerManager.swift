import Foundation
import Vision
import UIKit

// MARK: - Data Models

struct ReceiptLineItem: Identifiable {
    let id = UUID()
    let description: String
    let amount: Double
    let quantity: Double?
    let unitPrice: Double?
    let confidence: Double
    var isSelected: Bool = true

    init(
        description: String,
        amount: Double,
        quantity: Double? = nil,
        unitPrice: Double? = nil,
        confidence: Double = 0.7,
        isSelected: Bool = true
    ) {
        self.description = description
        self.amount = amount
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.confidence = confidence
        self.isSelected = isSelected
    }
}

struct ReceiptScanResult {
    enum ExtractionStatus: String {
        case ocrOnly = "Local OCR"
    }

    let rawLines: [String]
    let merchantName: String?
    let billType: String?
    let totalAmount: Double?
    let lineItems: [ReceiptLineItem]
    let receiptDate: Date?
    let extractionStatus: ExtractionStatus

    var hasLineItems: Bool { !lineItems.isEmpty }
    var hasSelectableLineItems: Bool { lineItems.count >= 1 }

    var isBackdatedDate: Bool {
        guard let d = receiptDate else { return false }
        return !Calendar.current.isDateInToday(d)
    }
}

// MARK: - ReceiptScannerManager

final class ReceiptScannerManager {
    static let shared = ReceiptScannerManager()
    private init() {}

    // MARK: - Internal Types

    private struct OCRToken {
        let text: String
        let normalizedBox: CGRect
        let confidence: Float
        let isNumericAmount: Bool
        let isPercentage: Bool
        
        init(observation: VNRecognizedTextObservation) {
            let rawText = observation.topCandidates(1).first?.string ?? ""
            self.text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.normalizedBox = observation.boundingBox
            self.confidence = observation.confidence
            
            self.isPercentage = rawText.contains("%")
            
            // Refined currency detection: 120.00 or integers > 5. Discard percentages.
            let cleaned = rawText.replacingOccurrences(of: #"[^0-9,.]"#, with: "", options: .regularExpression)
            let hasDecimal = rawText.range(of: #"\d+[.,]\d{2}\b"#, options: .regularExpression) != nil
            let integerVal = Int(cleaned.prefix(while: { $0.isNumber })) ?? 0
            
            self.isNumericAmount = !isPercentage && (hasDecimal || integerVal > 5)
        }
    }

    private struct OCRRow {
        let tokens: [OCRToken]
        let midY: CGFloat
        let height: CGFloat
        let text: String
        let containsTaxKeyword: Bool
        let containsNoiseKeyword: Bool
        
        init(tokens: [OCRToken]) {
            self.tokens = tokens.sorted(by: { $0.normalizedBox.minX < $1.normalizedBox.minX })
            self.midY = tokens.map { $0.normalizedBox.midY }.reduce(0, +) / CGFloat(tokens.count)
            self.height = tokens.map { $0.normalizedBox.height }.max() ?? 0.01
            self.text = tokens.map { $0.text }.joined(separator: " ")
            
            let lower = self.text.lowercased()
            self.containsTaxKeyword = ReceiptPattern.taxKeywords.contains(where: { lower.contains($0) })
            self.containsNoiseKeyword = ReceiptPattern.noiseKeywords.contains(where: { lower.contains($0) })
        }
    }

    private struct SpatialMetrics {
        let priceColumnX: CGFloat?
        let headerBoundary: Int
        let itemRegion: ClosedRange<Int>
        let totalRegion: ClosedRange<Int>
        let footerBoundary: Int
    }

    // MARK: - Public

    func scan(image: UIImage) async throws -> ReceiptScanResult {
        let tokens = try await performUnifiedOCR(on: image)
        let rows = reconstructRowsAdaptively(from: tokens)
        
        guard !rows.isEmpty else { throw ScanError.noTextFound }

        let metrics = analyzeSpatialStructure(rows: rows)
        return parseWithSpatialContext(rows: rows, metrics: metrics)
    }

    // MARK: - Phase 1: OCR (Single Pass)

    private func performUnifiedOCR(on image: UIImage) async throws -> [OCRToken] {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let tokens = observations.map { OCRToken(observation: $0) }.filter { !$0.text.isEmpty }
                continuation.resume(returning: tokens)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-IN", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Phase 2: Row Reconstruction

    private func reconstructRowsAdaptively(from tokens: [OCRToken]) -> [OCRRow] {
        let sortedTokens = tokens.sorted(by: { $0.normalizedBox.midY > $1.normalizedBox.midY })
        var groupedRows: [[OCRToken]] = []
        
        for token in sortedTokens {
            var found = false
            for (idx, row) in groupedRows.enumerated() {
                let rowMidY = row.map { $0.normalizedBox.midY }.reduce(0, +) / CGFloat(row.count)
                let rowHeight = row.map { $0.normalizedBox.height }.max() ?? 0.02
                
                // Grouping: uses adaptive threshold (85% of row height)
                let threshold = rowHeight * 0.85
                if abs(token.normalizedBox.midY - rowMidY) < threshold {
                    groupedRows[idx].append(token)
                    found = true
                    break
                }
            }
            if !found {
                groupedRows.append([token])
            }
        }
        
        return groupedRows
            .map { OCRRow(tokens: $0) }
            .sorted(by: { $0.midY > $1.midY })
    }

    // MARK: - Phase 3: Spatial Analysis & Zoning

    private func analyzeSpatialStructure(rows: [OCRRow]) -> SpatialMetrics {
        // 1. Detect dominant price column via clustering
        var numericXPositions: [CGFloat] = []
        for row in rows {
            if let lastNumeric = row.tokens.last(where: { $0.isNumericAmount }) {
                numericXPositions.append(lastNumeric.normalizedBox.maxX)
            }
        }
        
        var priceColumnX: CGFloat? = nil
        if !numericXPositions.isEmpty {
            let clusters = Dictionary(grouping: numericXPositions, by: { Int($0 * 100) / 2 * 2 }) // 2% buckets
            if let bestBin = clusters.max(by: { $0.value.count < $1.value.count }) {
                priceColumnX = bestBin.value.reduce(0, +) / CGFloat(bestBin.value.count)
            }
        }

        // 2. Identify Anchors for Zoning
        var headerEnd = 0
        var itemsStart = 1
        var totalsStart = rows.count - 1
        var footerStart = rows.count - 1
        
        for (idx, row) in rows.enumerated() {
            let lower = row.text.lowercased()
            
            // Header anchors
            if lower.contains("item") || lower.contains("qty") || lower.contains("description") || lower.contains("particulars") {
                headerEnd = max(0, idx - 1)
                itemsStart = idx + 1
            }
            
            // Totals anchors
            if lower.contains("subtotal") || lower.contains("taxable") || (lower.contains("total") && idx > rows.count / 2) {
                if idx < totalsStart { totalsStart = idx }
            }
            
            // Footer anchors
            if lower.contains("upi") || lower.contains("thank you") || lower.contains("scan & pay") || lower.contains("mode of pay") {
                if idx < footerStart { footerStart = idx }
            }
        }
        
        // Sanity adjustments
        let safeItemsStart = min(itemsStart, rows.count - 1)
        let safeTotalsStart = max(safeItemsStart, min(totalsStart, rows.count - 1))
        let safeFooterStart = max(safeTotalsStart, min(footerStart, rows.count - 1))
        
        return SpatialMetrics(
            priceColumnX: priceColumnX,
            headerBoundary: headerEnd,
            itemRegion: safeItemsStart...max(safeItemsStart, safeTotalsStart - 1),
            totalRegion: safeTotalsStart...max(safeTotalsStart, safeFooterStart - 1),
            footerBoundary: safeFooterStart
        )
    }

    // MARK: - Phase 4: Multi-Pass Execution

    private func parseWithSpatialContext(rows: [OCRRow], metrics: SpatialMetrics) -> ReceiptScanResult {
        let allRowText = rows.map { $0.text }
        
        let merchantName = parseMerchantName(from: rows, metrics: metrics)
        let receiptDate = parseDate(from: allRowText)
        let lineItems = extractLineItems(rows: rows, metrics: metrics)
        let totalAmount = extractTotalAmount(rows: rows, metrics: metrics)
        let billType = parseBillType(from: allRowText, merchantName: merchantName, lineItems: lineItems)

        return ReceiptScanResult(
            rawLines: allRowText,
            merchantName: merchantName,
            billType: billType,
            totalAmount: totalAmount,
            lineItems: lineItems,
            receiptDate: receiptDate,
            extractionStatus: .ocrOnly
        )
    }

    // MARK: - Specialized Extraction

    private func parseMerchantName(from rows: [OCRRow], metrics: SpatialMetrics) -> String? {
        var best: (text: String, score: Float)?
        
        // Focus on header region (first 8 rows or up to header boundary)
        let searchLimit = min(max(8, metrics.headerBoundary), rows.count)
        for (i, row) in rows.prefix(searchLimit).enumerated() {
            let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 3 && text.count < 50 else { continue }
            
            if row.containsNoiseKeyword || row.containsTaxKeyword { continue }
            if row.tokens.contains(where: { $0.isNumericAmount }) { continue } // Names rarely have prices
            
            var score = 10.0 - Float(i)
            score += Float(row.height * 100)
            if text == text.uppercased() { score += 2.0 }
            
            if best == nil || score > best!.score {
                best = (text, score)
            }
        }
        return best?.text
    }

    private func extractLineItems(rows: [OCRRow], metrics: SpatialMetrics) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        let region = metrics.itemRegion
        
        var i = region.lowerBound
        while i <= region.upperBound && i < rows.count {
            let row = rows[i]
            
            // Filter 1: Skip noise/tax rows
            if row.containsNoiseKeyword || row.containsTaxKeyword {
                i += 1; continue
            }
            
            if let extracted = tryExtractItem(from: row, priceColumnX: metrics.priceColumnX) {
                // Confidence scoring
                var score = extracted.confidence
                if let px = metrics.priceColumnX, let lastToken = row.tokens.last(where: { $0.isNumericAmount }),
                   abs(lastToken.normalizedBox.maxX - px) < 0.05 {
                    score += 0.2 // Alignment bonus
                }
                
                items.append(ReceiptLineItem(
                    description: extracted.description,
                    amount: extracted.amount,
                    quantity: extracted.quantity,
                    unitPrice: extracted.unitPrice,
                    confidence: Double(min(1.0, score))
                ))
            } else if i + 1 <= region.upperBound && !row.tokens.isEmpty {
                // Wrapped Item Merging
                let nextRow = rows[i + 1]
                if let nextExtracted = tryExtractItem(from: nextRow, priceColumnX: metrics.priceColumnX) {
                    let mergedDesc = row.text + " " + nextExtracted.description
                    items.append(ReceiptLineItem(
                        description: mergedDesc.trimmingCharacters(in: .whitespaces),
                        amount: nextExtracted.amount,
                        quantity: nextExtracted.quantity,
                        unitPrice: nextExtracted.unitPrice,
                        confidence: Double(nextExtracted.confidence * 0.9)
                    ))
                    i += 1 // Skip next row as merged
                }
            }
            i += 1
        }
        return items.filter { $0.confidence > 0.45 }
    }

    private func tryExtractItem(from row: OCRRow, priceColumnX: CGFloat?) -> (description: String, amount: Double, quantity: Double?, unitPrice: Double?, confidence: Float)? {
        let text = row.text
        
        // 1. Table Match (Qty + Price + Total)
        if let match = ReceiptPattern.tableLineItemRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let desc = (text as NSString).substring(with: match.range(at: 1))
            let qty = Double((text as NSString).substring(with: match.range(at: 2)).replacingOccurrences(of: ",", with: "."))
            let amtStr = (text as NSString).substring(with: match.range(at: 4))
            if let amt = parseCurrencyAmount(amtStr) {
                return (desc.trimmingCharacters(in: .whitespaces), amt, qty, amt/max(1, qty ?? 1), 0.85)
            }
        }
        
        // 2. Trailing Match (Desc + Amount)
        if let match = ReceiptPattern.trailingAmountItemRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let desc = (text as NSString).substring(with: match.range(at: 1))
            let amtStr = (text as NSString).substring(with: match.range(at: 2))
            if let amt = parseCurrencyAmount(amtStr) {
                return (desc.trimmingCharacters(in: .whitespaces), amt, nil, nil, 0.75)
            }
        }
        
        return nil
    }

    private func extractTotalAmount(rows: [OCRRow], metrics: SpatialMetrics) -> Double? {
        var potentialTotals: [(amount: Double, score: Float)] = []
        let region = metrics.totalRegion
        
        for i in region where i < rows.count {
            let row = rows[i]
            let lower = row.text.lowercased()
            
            var baseScore: Float = 0
            for rule in ReceiptPattern.totalKeywordRules {
                if lower.range(of: rule.pattern, options: .regularExpression) != nil {
                    baseScore = Float(rule.priorityScore)
                    break
                }
            }
            
            for token in row.tokens where token.isNumericAmount {
                if let amount = parseCurrencyAmount(token.text) {
                    var finalScore = baseScore
                    if let px = metrics.priceColumnX, abs(token.normalizedBox.maxX - px) < 0.04 {
                        finalScore += 10.0 // Massive bonus for pricing column alignment
                    }
                    // Depth bias: totals are usually towards the bottom of the section
                    finalScore += Float(i - region.lowerBound) * 0.5
                    potentialTotals.append((amount, finalScore))
                }
            }
        }
        
        return potentialTotals.max(by: { $0.score < $1.score })?.amount
    }

    // MARK: - Utilities & Patterns

    private func parseCurrencyAmount(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: #"[₹$€£¥]|Rs\.?|INR|\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: ",", with: ".")
        
        // Handle double decimal separators or noise
        let matches = cleaned.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
        return Double(matches)
    }

    private struct ReceiptPattern {
        static let taxKeywords = ["cgst", "sgst", "igst", "gst", "vat", "tax", "service charge", "service tax", "round off"]
        static let noiseKeywords = ["phone", "mob:", "tel:", "gstin", "invoice", "upi", "scan & pay", "transaction", "auth code", "rrn"]
        
        static let totalKeywordRules: [(pattern: String, priorityScore: Int)] = [
            ("(?i)grand\\s*total|net\\s*pay|total\\s*payable|amount\\s*payable|total\\s*bill", 50),
            ("(?i)total|amount\\s*due|balance\\s*due", 30),
            ("(?i)sub\\s*total|taxable\\s*value", 10)
        ]
        
        static let tableLineItemRegex = try! NSRegularExpression(
            pattern: #"(.*?)\s+(\d{1,3}(?:[.,]\d+)?)\s+([₹$€£¥]|Rs\.?)?\s*(\d+[.,]\d{2})\s+([₹$€£¥]|Rs\.?)?\s*(\d+[.,]\d{2})"#,
            options: .caseInsensitive
        )
        
        static let trailingAmountItemRegex = try! NSRegularExpression(
            pattern: #"(.*?)\s+([₹$€£¥]|Rs\.?)?\s*(\d+[.,]\d{2})\s*$"#,
            options: .caseInsensitive
        )
    }

    private func parseBillType(from allLines: [String], merchantName: String?, lineItems: [ReceiptLineItem]) -> String? {
        let corpus = (allLines + lineItems.map(\.description) + [merchantName ?? ""]).joined(separator: " ").lowercased()
        let rules: [(label: String, keywords: [String])] = [
            ("Restaurant", ["biryani", "paneer", "cafe", "food", "dine", "kot", "waiter", "table"]),
            ("Grocery", ["grocery", "supermarket", "mart", "vegetable", "fruit", "provision", "barcode"]),
            ("Fuel", ["petrol", "diesel", "fuel", "hpcl", "bpcl", "pump"]),
            ("Pharmacy", ["medical", "chemist", "pharmacy", "drug", "tablet", "capsule"]),
            ("Utility", ["electricity", "water", "recharge", "postpaid", "broadband"])
        ]
        var best: (label: String, score: Int)?
        for rule in rules {
            let score = rule.keywords.reduce(0) { $0 + (corpus.contains($1) ? 1 : 0) }
            if score > 0 && (best == nil || score > best!.score) { best = (rule.label, score) }
        }
        return best?.label
    }

    private func parseDate(from lines: [String]) -> Date? {
        let text = lines.joined(separator: " ")
        let pattern = #"\b(\d{1,2})[\/\-\.]([0-9]{1,2}|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[\/\-\.](\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        let matchStr = (text as NSString).substring(with: match.range).replacingOccurrences(of: ".", with: "/").replacingOccurrences(of: "-", with: "/")
        
        for format in ["dd/MM/yyyy", "dd/MMM/yy", "MM/dd/yyyy", "yyyy/MM/dd"] {
            df.dateFormat = format
            if let date = df.date(from: matchStr) { return date }
        }
        return nil
    }

    enum ScanError: LocalizedError {
        case invalidImage, noTextFound
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Could not process this image."
            case .noTextFound:  return "No text was detected in the image."
            }
        }
    }
}

extension UIImage {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
