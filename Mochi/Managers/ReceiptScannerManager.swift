import Foundation
import Vision
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

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
        case ocrOnly = "OCR only"
        case aiEnhanced = "OCR + Apple AI"
        case aiUnavailable = "OCR fallback (AI unavailable)"
        case aiTimeout = "OCR fallback (AI timeout)"
        case aiFailed = "OCR fallback (AI error)"
    }

    let rawLines: [String]
    let merchantName: String?
    let billType: String?
    let totalAmount: Double?
    let lineItems: [ReceiptLineItem]
    let receiptDate: Date?
    let extractionStatus: ExtractionStatus

    var hasLineItems: Bool { !lineItems.isEmpty }
    var hasSelectableLineItems: Bool { lineItems.count >= 2 }

    var isBackdatedDate: Bool {
        guard let d = receiptDate else { return false }
        return !Calendar.current.isDateInToday(d)
    }
}

// MARK: - ReceiptScannerManager

final class ReceiptScannerManager {
    static let shared = ReceiptScannerManager()
    private init() {}
    private let aiStateQueue = DispatchQueue(label: "ReceiptScannerManager.aiState")
    private var aiDidSchedulePrewarm = false
    private var aiHasAttemptedExtraction = false
    private let aiFirstAttemptTimeout: TimeInterval = 5.0
    private let aiWarmTimeout: TimeInterval = 1.8

    // MARK: - Public

    func scan(image: UIImage) async throws -> ReceiptScanResult {
        scheduleAppleAIPrewarmIfNeeded()
        let lines = try await performOCR(on: image)
        let baseline = parseLines(lines)
        let timeout = nextAITimeoutAndMarkAttempt()
        return await enrichWithAppleAI(base: baseline, timeoutSeconds: timeout)
    }

    private func nextAITimeoutAndMarkAttempt() -> TimeInterval {
        aiStateQueue.sync {
            defer { aiHasAttemptedExtraction = true }
            return aiHasAttemptedExtraction ? aiWarmTimeout : aiFirstAttemptTimeout
        }
    }

    private func scheduleAppleAIPrewarmIfNeeded() {
        let shouldSchedule = aiStateQueue.sync {
            if aiDidSchedulePrewarm { return false }
            aiDidSchedulePrewarm = true
            return true
        }
        guard shouldSchedule else { return }

#if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            Task { @MainActor in
                self.prewarmAppleAIIfAvailable()
            }
        }
#endif
    }

    // MARK: - OCR

    private func performOCR(on image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else {
            throw ScanError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = self.reconstructLines(from: observations)
                if lines.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                } else {
                    continuation.resume(returning: lines)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-IN", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private struct OCRToken {
        let text: String
        let box: CGRect
    }

    // Vision often returns many small text boxes per row. Group by vertical alignment and join left-to-right.
    private func reconstructLines(from observations: [VNRecognizedTextObservation]) -> [String] {
        let tokens: [OCRToken] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { return nil }
            return OCRToken(text: text, box: observation.boundingBox)
        }

        guard !tokens.isEmpty else { return [] }

        let sortedByY = tokens.sorted { $0.box.midY > $1.box.midY }
        var rows: [[OCRToken]] = []
        var rowCenters: [CGFloat] = []
        var rowHeights: [CGFloat] = []

        for token in sortedByY {
            let tokenY = token.box.midY
            let tokenHeight = token.box.height

            if let rowIndex = rowCenters.indices.first(where: { index in
                let tolerance = max(0.012, max(rowHeights[index], tokenHeight) * 0.7)
                return abs(rowCenters[index] - tokenY) <= tolerance
            }) {
                rows[rowIndex].append(token)
                let existingCount = CGFloat(rows[rowIndex].count - 1)
                rowCenters[rowIndex] = ((rowCenters[rowIndex] * existingCount) + tokenY) / (existingCount + 1)
                rowHeights[rowIndex] = max(rowHeights[rowIndex], tokenHeight)
            } else {
                rows.append([token])
                rowCenters.append(tokenY)
                rowHeights.append(tokenHeight)
            }
        }

        let rowOrder = rowCenters.indices.sorted { rowCenters[$0] > rowCenters[$1] }
        return rowOrder.compactMap { index in
            let joined = rows[index]
                .sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: " ")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return joined.isEmpty ? nil : joined
        }
    }

    // MARK: - Parse Coordinator

    private func parseLines(_ lines: [String]) -> ReceiptScanResult {
        let normalized = lines
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let lineItems = parseLineItems(from: normalized)
        let merchantName = parseMerchantName(from: normalized)
        let billType = parseBillType(from: normalized, merchantName: merchantName, lineItems: lineItems)

        return ReceiptScanResult(
            rawLines: normalized,
            merchantName: merchantName,
            billType: billType,
            totalAmount: parseTotalAmount(from: normalized),
            lineItems: lineItems,
            receiptDate: parseDate(from: normalized),
            extractionStatus: .ocrOnly
        )
    }

    // MARK: - Merchant Name

    private func parseMerchantName(from lines: [String]) -> String? {
        var best: (name: String, score: Int)?

        for line in lines.prefix(20) {
            let lower = line.lowercased()

            if merchantHardStopKeywords.contains(where: { lower.contains($0) }), best != nil {
                break
            }

            guard let score = merchantScore(for: line) else { continue }
            if best == nil || score > best!.score {
                best = (line, score)
            }
        }

        return best?.name
    }

    private let merchantHardStopKeywords = [
        "bill no", "invoice", "date", "time", "item", "qty", "subtotal",
        "tax", "grand total", "total", "table:", "kot", "cashier", "waiter",
        "payment mode"
    ]

    private let merchantSkipKeywords = [
        "copy", "download", "visit", "sample", "scan & pay", "upi id",
        "thank you", "preview", "screenshot", "gst-compliant", "www", "http",
        "guest signature", "signature", "authorized signatory", "customer copy"
    ]

    private func merchantScore(for line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 42 else { return nil }

        let lower = trimmed.lowercased()
        if merchantSkipKeywords.contains(where: { lower.contains($0) }) { return nil }

        let letters = trimmed.filter(\.isLetter).count
        let digits = trimmed.filter(\.isNumber).count
        let symbols = trimmed.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace && $0 != "&" && $0 != "." && $0 != "-" }.count
        guard letters >= 3 else { return nil }

        let totalChars = max(trimmed.count, 1)
        if Double(digits) / Double(totalChars) > 0.35 { return nil }
        if Double(symbols) / Double(totalChars) > 0.25 { return nil }

        let words = trimmed
            .split(whereSeparator: { !$0.isLetter && $0 != "&" })
            .map(String.init)
            .filter { !$0.isEmpty }

        var score = 0
        if words.count >= 2 && words.count <= 4 { score += 4 }
        if digits == 0 { score += 2 }
        if trimmed == trimmed.uppercased() { score += 2 }
        if words.allSatisfy({ $0.first?.isUppercase == true }) { score += 2 }
        if trimmed.count >= 5 && trimmed.count <= 26 { score += 2 }
        if !trimmed.contains(":") { score += 1 }
        return score
    }

    // MARK: - Total Amount

    // Priority: grand total (1) → amount/total due (2) → \btotal\b (3) → subtotal (4) → largest value (99)
    private let totalKeywords: [(pattern: String, priority: Int)] = [
        ("grand\\s+total",                                          1),
        ("total\\s+due|amount\\s+due|balance\\s+due|pay\\s+this",  2),
        ("\\btotal\\b(?!s)",                                        3),
        ("subtotal|sub\\s+total",                                   4),
    ]

    // Matches: $12.50  12.50  475,00  1,234.56  1.234,56
    private let amountRegex = try! NSRegularExpression(
        pattern: #"[$€£¥₹]?\s*(\d{1,7}(?:[.,]\d{3})*(?:[.,]\d{2}))"#
    )

    private func parseTotalAmount(from lines: [String]) -> Double? {
        struct Candidate { let amount: Double; let priority: Int }
        var candidates: [Candidate] = []

        for line in lines {
            let lower = line.lowercased()
            var priority: Int? = nil
            for (pattern, p) in totalKeywords {
                if lower.range(of: pattern, options: .regularExpression) != nil {
                    if priority == nil || p < priority! { priority = p }
                }
            }

            if let amount = extractLargestAmount(from: line) {
                candidates.append(Candidate(amount: amount, priority: priority ?? 99))
            }
        }

        guard !candidates.isEmpty else { return nil }

        // Sort: lowest priority number first (most confident), then largest amount as tiebreaker
        let sorted = candidates.sorted {
            $0.priority != $1.priority ? $0.priority < $1.priority : $0.amount > $1.amount
        }

        // If everything is fallback (99), just return the largest value on the receipt
        if sorted.first!.priority == 99 {
            return candidates.max(by: { $0.amount < $1.amount })?.amount
        }

        return sorted.first?.amount
    }

    private func extractLargestAmount(from line: String) -> Double? {
        let range = NSRange(line.startIndex..., in: line)
        let matches = amountRegex.matches(in: line, range: range)
        return matches.compactMap { match -> Double? in
            guard let r = Range(match.range(at: 1), in: line) else { return nil }
            return parseCurrencyAmount(String(line[r]))
        }.max()
    }

    // MARK: - Line Items

    // Match table-style rows: "Paneer Tikka 2 120.00 240.00"
    private let tableLineItemRegex = try! NSRegularExpression(
        pattern: #"^(.+?)\s+(\d+(?:[.,]\d+)?)\s+([$€£¥₹]?\s*\d{1,7}(?:[.,]\d{3})*(?:[.,]\d{2}))\s+([$€£¥₹]?\s*\d{1,7}(?:[.,]\d{3})*(?:[.,]\d{2}))$"#,
        options: .caseInsensitive
    )

    // Match simple rows: "Coffee $4.50" / "Butter Naan 90.00"
    private let trailingAmountItemRegex = try! NSRegularExpression(
        pattern: #"^(.+?)\s+([$€£¥₹]?\s*\d{1,7}(?:[.,]\d{3})*(?:[.,]\d{2}))$"#,
        options: .caseInsensitive
    )

    // Used for loose extraction where OCR glues columns (example: "575,002875,00")
    private let moneyTokenRegex = try! NSRegularExpression(
        pattern: #"[$€£¥₹]?\s*\d{1,7}(?:[.,]\d{3})*(?:[.,]\d{2})"#
    )

    private let lineItemSkipKeywords = [
        "total", "tax", "tip", "subtotal", "discount", "savings", "value",
        "change", "cash", "visa", "mastercard", "amex", "thank", "receipt",
        "invoice", "order", "table", "cgst", "sgst", "igst", "gst", "paid",
        "balance", "mode", "upi", "cashier", "waiter", "bill", "kot", "date",
        "signature", "guest", "cover"
    ]

    private let lineItemSkipPhrases = [
        "payment mode", "paid amount", "grand total", "scan & pay", "item qty rate amt"
    ]

    private struct ParsedLineItemCandidate {
        let description: String
        let amount: Double
        let quantity: Double?
        let unitPrice: Double?
        let confidence: Double
    }

    private func parseLineItems(from lines: [String]) -> [ReceiptLineItem] {
        var parsedItems: [ReceiptLineItem] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let lower = line.lowercased()
            let tokens = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
            if lineItemSkipKeywords.contains(where: { tokens.contains($0) }) {
                index += 1
                continue
            }
            if lineItemSkipPhrases.contains(where: { lower.contains($0) }) {
                index += 1
                continue
            }

            if var candidate = parseTableLineItemCandidate(from: line)
                ?? parseTrailingAmountLineItemCandidate(from: line)
                ?? parseLooseLineItemCandidate(from: line) {
                // Join wrapped item names: e.g. "Teacher Highland ... 750.00" + "Cream (60 ML)"
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    if isLikelyContinuationLine(nextLine) {
                        candidate = ParsedLineItemCandidate(
                            description: sanitizeItemDescription(candidate.description + " " + nextLine),
                            amount: candidate.amount,
                            quantity: candidate.quantity,
                            unitPrice: candidate.unitPrice,
                            confidence: min(1.0, candidate.confidence + 0.08)
                        )
                        index += 1
                    }
                }

                if let valid = validatedLineItem(from: candidate) {
                    parsedItems.append(valid)
                }
            }
            index += 1
        }

        // Remove obvious duplicates caused by OCR echo lines.
        var bestByKey: [String: ReceiptLineItem] = [:]
        for item in parsedItems {
            let key = "\(item.description.lowercased())|\(String(format: "%.2f", item.amount))"
            if let existing = bestByKey[key], existing.confidence >= item.confidence { continue }
            bestByKey[key] = item
        }

        let filtered = bestByKey.values
            .filter { $0.confidence >= 0.55 }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                return lhs.description < rhs.description
            }

        return filtered
    }

    private func parseTableLineItemCandidate(from line: String) -> ParsedLineItemCandidate? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = tableLineItemRegex.firstMatch(in: line, range: range),
              match.numberOfRanges == 5,
              let descRange = Range(match.range(at: 1), in: line),
              let qtyRange = Range(match.range(at: 2), in: line),
              let unitRange = Range(match.range(at: 3), in: line),
              let amountRange = Range(match.range(at: 4), in: line),
              let amount = parseCurrencyAmount(String(line[amountRange]))
        else { return nil }

        let description = sanitizeItemDescription(String(line[descRange]))
        let quantity = parseCurrencyAmount(String(line[qtyRange]))
        let unitPrice = parseCurrencyAmount(String(line[unitRange]))

        return ParsedLineItemCandidate(
            description: description,
            amount: amount,
            quantity: quantity,
            unitPrice: unitPrice,
            confidence: 0.72
        )
    }

    private func parseTrailingAmountLineItemCandidate(from line: String) -> ParsedLineItemCandidate? {
        let range = NSRange(line.startIndex..., in: line)
        guard let match = trailingAmountItemRegex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let descRange = Range(match.range(at: 1), in: line),
              let amountRange = Range(match.range(at: 2), in: line),
              let amount = parseCurrencyAmount(String(line[amountRange]))
        else { return nil }

        var description = String(line[descRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        var quantity: Double? = nil

        if let qtyCapture = description.range(of: #"\s+(\d+(?:[.,]\d+)?)\s*(?:x|pcs?)?$"#, options: .regularExpression) {
            let qtyText = String(description[qtyCapture])
                .replacingOccurrences(of: "[^0-9,.-]", with: "", options: .regularExpression)
            quantity = parseCurrencyAmount(qtyText)
            description = String(description[..<qtyCapture.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        description = sanitizeItemDescription(description)

        let unitPrice: Double?
        if let q = quantity, q > 0 {
            unitPrice = amount / q
        } else {
            unitPrice = nil
        }

        return ParsedLineItemCandidate(
            description: description,
            amount: amount,
            quantity: quantity,
            unitPrice: unitPrice,
            confidence: quantity != nil ? 0.62 : 0.56
        )
    }

    // Handles OCR lines where item rows are malformed but still contain multiple money tokens.
    private func parseLooseLineItemCandidate(from line: String) -> ParsedLineItemCandidate? {
        let range = NSRange(line.startIndex..., in: line)
        let matches = moneyTokenRegex.matches(in: line, range: range)
        guard matches.count >= 2,
              let first = Range(matches[0].range, in: line),
              let last = Range(matches[matches.count - 1].range, in: line),
              let amount = parseCurrencyAmount(String(line[last]))
        else { return nil }

        var description = String(line[..<first.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        var quantity: Double? = nil

        if let qtyRange = description.range(of: #"\b(\d+(?:[.,]\d+)?)\s*$"#, options: .regularExpression) {
            let qtyText = String(description[qtyRange]).replacingOccurrences(of: "[^0-9,.-]", with: "", options: .regularExpression)
            quantity = parseCurrencyAmount(qtyText)
            description = String(description[..<qtyRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Preserve wrapped suffix if OCR glued continuation text after final amount.
        let trailing = String(line[last.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if isLikelyContinuationLine(trailing) {
            description += " " + trailing
        }

        description = sanitizeItemDescription(description)
        let unitPrice = parseCurrencyAmount(String(line[first]))

        return ParsedLineItemCandidate(
            description: description,
            amount: amount,
            quantity: quantity,
            unitPrice: unitPrice,
            confidence: 0.48
        )
    }

    private func validatedLineItem(from candidate: ParsedLineItemCandidate) -> ReceiptLineItem? {
        let description = sanitizeItemDescription(candidate.description)
        guard isLikelyItemDescription(description) else { return nil }
        guard candidate.amount > 0, candidate.amount <= 500_000 else { return nil }

        let lower = description.lowercased()
        let tokens = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        if lineItemSkipKeywords.contains(where: { tokens.contains($0) }) { return nil }
        if lineItemSkipPhrases.contains(where: { lower.contains($0) }) { return nil }

        var confidence = candidate.confidence

        if let qty = candidate.quantity, let unit = candidate.unitPrice, qty > 0, unit > 0 {
            let expected = qty * unit
            let tolerance = max(1.0, candidate.amount * 0.04)
            let delta = abs(expected - candidate.amount)
            if delta <= tolerance {
                confidence += 0.20
            } else if delta <= tolerance * 2.2 {
                confidence += 0.05
            } else {
                confidence -= 0.25
            }
        } else {
            confidence -= 0.03
        }

        if description.split(separator: " ").count >= 2 { confidence += 0.04 }
        if containsMoneyToken(description) { confidence -= 0.20 }
        if description.contains(":") { confidence -= 0.20 }

        let clamped = min(1.0, max(0.0, confidence))
        guard clamped >= 0.45 else { return nil }

        return ReceiptLineItem(
            description: description,
            amount: candidate.amount,
            quantity: candidate.quantity,
            unitPrice: candidate.unitPrice,
            confidence: clamped
        )
    }

    private func sanitizeItemDescription(_ description: String) -> String {
        var cleaned = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove trailing catalog/SAC-like numeric codes: "KINGFISHER ULTRA 23996239"
            .replacingOccurrences(of: #"\s+\d{4,}$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { cleaned = description.trimmingCharacters(in: .whitespacesAndNewlines) }
        return cleaned
    }

    private func isLikelyContinuationLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard !containsMoneyToken(trimmed) else { return false }

        let lower = trimmed.lowercased()
        let tokens = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        if lineItemSkipKeywords.contains(where: { tokens.contains($0) }) { return false }
        if lineItemSkipPhrases.contains(where: { lower.contains($0) }) { return false }
        if trimmed.contains(":") { return false }

        let letters = trimmed.filter(\.isLetter).count
        let digits = trimmed.filter(\.isNumber).count
        guard letters >= 2, trimmed.count <= 34 else { return false }
        return Double(digits) / Double(max(trimmed.count, 1)) < 0.25
    }

    private func containsMoneyToken(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return moneyTokenRegex.firstMatch(in: line, range: range) != nil
    }

    private func parseCurrencyAmount(_ raw: String) -> Double? {
        var cleaned = raw
            .replacingOccurrences(of: "[^0-9,.-]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")

        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            if comma > dot {
                // 1.234,56 -> decimal is comma
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // 1,234.56 -> decimal is dot
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        case let (comma?, nil):
            let trailingDigits = cleaned.distance(from: comma, to: cleaned.endIndex) - 1
            if trailingDigits == 2 {
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        case (nil, _):
            break
        }

        return Double(cleaned)
    }

    private func isLikelyItemDescription(_ description: String) -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }

        let letters = trimmed.filter(\.isLetter).count
        guard letters >= 2 else { return false }

        let digits = trimmed.filter(\.isNumber).count
        return Double(digits) / Double(max(trimmed.count, 1)) < 0.35
    }

    // MARK: - Bill Type

    private let billTypeKeywordRules: [(label: String, keywords: [String])] = [
        ("Restaurant", [
            "restaurant", "cafe", "dine", "table", "waiter", "fssai", "kot", "food", "beverage",
            "biryani", "paneer", "naan", "pizza", "burger", "coffee", "tea", "beer", "ultra"
        ]),
        ("Grocery", [
            "grocery", "supermarket", "mart", "kirana", "vegetable", "fruit", "provision"
        ]),
        ("Fuel", [
            "petrol", "diesel", "fuel", "hpcl", "bpcl", "indian oil", "pump"
        ]),
        ("Pharmacy", [
            "pharmacy", "medical", "chemist", "drug", "tablet", "capsule"
        ]),
        ("Travel", [
            "uber", "ola", "taxi", "cab", "metro", "railway", "airline", "flight", "bus"
        ]),
        ("Shopping", [
            "retail", "store", "mall", "apparel", "fashion", "electronics", "purchase"
        ]),
        ("Utility", [
            "electricity", "water bill", "internet", "broadband", "postpaid", "prepaid", "recharge"
        ])
    ]

    private func parseBillType(from lines: [String], merchantName: String?, lineItems: [ReceiptLineItem]) -> String? {
        let corpus = (lines + lineItems.map(\.description) + [merchantName ?? ""])
            .joined(separator: " ")
            .lowercased()
        guard !corpus.isEmpty else { return nil }

        var best: (label: String, score: Int)?
        for rule in billTypeKeywordRules {
            let score = rule.keywords.reduce(0) { partial, keyword in
                partial + (corpus.contains(keyword) ? 1 : 0)
            }
            guard score > 0 else { continue }
            if best == nil || score > best!.score {
                best = (rule.label, score)
            }
        }

        return best?.label
    }

    // MARK: - Apple AI Fallback

    private enum AIFallbackResult {
        case merged(billType: String?, items: [ReceiptLineItem])
        case unavailable
        case timeout
        case failed
    }

    private func enrichWithAppleAI(base: ReceiptScanResult, timeoutSeconds: TimeInterval) async -> ReceiptScanResult {
        let shouldUseAI = base.lineItems.count < 2
        guard shouldUseAI else { return base }

        let aiResult = await parseWithAppleAIWithTimeout(from: base.rawLines, timeoutSeconds: timeoutSeconds)

        switch aiResult {
        case .unavailable:
            return withStatus(base, .aiUnavailable)
        case .timeout:
            return withStatus(base, .aiTimeout)
        case .failed:
            return withStatus(base, .aiFailed)
        case let .merged(billType, items):
            let mergedLineItems: [ReceiptLineItem]
            if items.count >= max(2, base.lineItems.count + 1) {
                mergedLineItems = items
            } else {
                mergedLineItems = mergeLineItems(primary: base.lineItems, fallback: items)
            }
            let mergedBillType = normalizedBillType(billType) ?? base.billType

            return ReceiptScanResult(
                rawLines: base.rawLines,
                merchantName: base.merchantName,
                billType: mergedBillType,
                totalAmount: base.totalAmount,
                lineItems: mergedLineItems,
                receiptDate: base.receiptDate,
                extractionStatus: .aiEnhanced
            )
        }
    }

    private func withStatus(_ base: ReceiptScanResult, _ status: ReceiptScanResult.ExtractionStatus) -> ReceiptScanResult {
        ReceiptScanResult(
            rawLines: base.rawLines,
            merchantName: base.merchantName,
            billType: base.billType,
            totalAmount: base.totalAmount,
            lineItems: base.lineItems,
            receiptDate: base.receiptDate,
            extractionStatus: status
        )
    }

    private func mergeLineItems(primary: [ReceiptLineItem], fallback: [ReceiptLineItem]) -> [ReceiptLineItem] {
        var merged = primary
        var seen = Set(primary.map { "\($0.description.lowercased())|\(String(format: "%.2f", $0.amount))" })

        for item in fallback {
            let key = "\(item.description.lowercased())|\(String(format: "%.2f", item.amount))"
            if seen.insert(key).inserted {
                merged.append(item)
            }
        }
        return merged
    }

    private func normalizedBillType(_ value: String?) -> String? {
        guard var t = value?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: "[^A-Za-z ]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return t.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }

#if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func prewarmAppleAIIfAvailable() {
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else { return }

        let session = LanguageModelSession(model: model) {
            "Extract receipt line items with quantity, unit price, and line total. Ignore totals, taxes, signatures, and footers."
        }
        session.prewarm()
    }

    private func parseWithAppleAIWithTimeout(
        from lines: [String],
        timeoutSeconds: TimeInterval
    ) async -> AIFallbackResult {
        await withTaskGroup(of: AIFallbackResult.self) { group in
            group.addTask {
                await self.parseWithAppleAI(from: lines)
            }
            group.addTask {
                let nanos = UInt64(max(0, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                return .timeout
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
        }
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct AIReceiptItem {
        @Guide(description: "Item name exactly as on receipt without tax/summary labels.")
        let description: String
        @Guide(description: "Quantity numeric if present. Use 1 if not visible.")
        let quantity: Double?
        @Guide(description: "Unit price numeric if present.")
        let unitPrice: Double?
        @Guide(description: "Final line total amount for this item as number.")
        let lineTotal: Double
    }

    @available(iOS 26.0, *)
    @Generable
    fileprivate struct AIReceiptExtraction {
        @Guide(description: "Broad bill tag like Restaurant, Grocery, Fuel, Pharmacy, Travel, Shopping, Utility, Other.")
        let billType: String?
        @Guide(.count(0...20))
        let items: [AIReceiptItem]
    }

    private func parseWithAppleAI(from lines: [String]) async -> AIFallbackResult {
        guard #available(iOS 26.0, *) else { return .unavailable }
        guard !lines.isEmpty else { return .failed }

        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else {
#if DEBUG
            print("Apple AI unavailable for receipt parsing: \(model.availability)")
#endif
            return .unavailable
        }

        let session = LanguageModelSession(model: model) {
            "Extract structured purchase items from OCR text. Ignore totals, taxes, signatures, footer text, GST numbers, addresses, payment rows, and headers."
        }

        let prompt = """
        OCR receipt lines:
        \(lines.prefix(80).joined(separator: "\n"))

        Return:
        1) `items`: rows that are actual purchased items with `quantity`, `unitPrice`, and `lineTotal`.
        2) `billType`: one short tag (Restaurant, Grocery, Fuel, Pharmacy, Travel, Shopping, Utility, Other).
        3) Ignore totals, tax, service charge, payment rows, headers, and signature/footer text.
        """

        do {
            let response = try await session.respond(
                to: prompt,
                generating: AIReceiptExtraction.self,
                options: GenerationOptions(temperature: 0.0, maximumResponseTokens: 220)
            )

            let mapped: [ReceiptLineItem] = response.content.items.compactMap { (ai: AIReceiptItem) -> ReceiptLineItem? in
                let candidate = ParsedLineItemCandidate(
                    description: ai.description,
                    amount: ai.lineTotal,
                    quantity: ai.quantity,
                    unitPrice: ai.unitPrice,
                    confidence: 0.68
                )
                return validatedLineItem(from: candidate)
            }

            guard !mapped.isEmpty || normalizedBillType(response.content.billType) != nil else {
                return .failed
            }

            return .merged(billType: response.content.billType, items: mapped)
        } catch {
            return .failed
        }
    }
#else
    private func parseWithAppleAI(from lines: [String]) async -> AIFallbackResult {
        .unavailable
    }

    private func parseWithAppleAIWithTimeout(
        from lines: [String],
        timeoutSeconds: TimeInterval
    ) async -> AIFallbackResult {
        .unavailable
    }
#endif

    // MARK: - Date

    // Each tuple: (regex to find the substring, DateFormatter format string)
    private let dateFormats: [(regex: String, format: String)] = [
        (#"\b\d{4}[\/\-]\d{2}[\/\-]\d{2}\b"#,             "yyyy/MM/dd"),  // ISO first
        (#"\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}\b"#,         "MM/dd/yyyy"),
        (#"\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2}\b"#,          "MM/dd/yy"),
        (#"\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2},?\s+\d{4}\b"#,
         "MMM dd yyyy"),
        (#"\b\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{4}\b"#,
         "dd MMM yyyy"),
        (#"\b\d{1,2}[\/\-](?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[\/\-]\d{2}\b"#,
         "dd/MMM/yy"),
    ]

    private func parseDate(from lines: [String]) -> Date? {
        let text = lines.joined(separator: " ")
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for (pattern, format) in dateFormats {
            guard let range = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { continue }
            var matched = String(text[range])
                .replacingOccurrences(of: "-", with: "/")
                .replacingOccurrences(of: ",", with: "")
            // Collapse multiple spaces
            matched = matched.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            formatter.dateFormat = format
            if let date = formatter.date(from: matched), date <= now {
                return date
            }
        }
        return nil
    }

    // MARK: - Errors

    enum ScanError: LocalizedError {
        case invalidImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Could not process this image."
            case .noTextFound:  return "No text was detected in the image."
            }
        }
    }
}
