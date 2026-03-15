import Foundation
import Vision
import UIKit

// MARK: - Data Models

// Removed ReceiptLineItem entirely

struct ReceiptScanResult {
    enum ExtractionStatus: String {
        case ocrOnly = "Local OCR"
    }

    let rawLines: [String]
    let merchantName: String?
    let billType: String?
    let totalAmount: Double?
    let receiptDate: Date?
    let isDateReliable: Bool
    let currencyCode: String?
    let extractionStatus: ExtractionStatus

    var isBackdatedDate: Bool {
        guard let d = receiptDate else { return false }
        return !Calendar.current.isDateInToday(d)
    }
}

// MARK: - ReceiptScannerManager

final class ReceiptScannerManager {
    static let shared = ReceiptScannerManager()
    private init() {}

    enum ScanError: LocalizedError {
        case invalidImage, noTextFound
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "Could not process this image."
            case .noTextFound:  return "No text was detected in the image."
            }
        }
    }

    func scan(image: UIImage) async throws -> ReceiptScanResult {
        let preprocessed = preprocessImageForOCR(image)
        guard let cgImage = preprocessed ?? image.cgImage else { throw ScanError.invalidImage }
        let orientation: CGImagePropertyOrientation = (preprocessed != nil) ? .up : image.cgImageOrientation
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                var rawTokens: [(text: String, box: CGRect)] = []
                
                for obs in observations {
                    if let topCandidate = obs.topCandidates(1).first {
                        let text = self.normalizeOCRNumberSpacing(
                            topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        if !text.isEmpty {
                            rawTokens.append((text: text, box: obs.boundingBox))
                        }
                    }
                }
                
                if rawTokens.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }
                
                let result = self.parseReceipt(tokens: rawTokens)
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US", "en-GB", "ar-AE"]
            request.minimumTextHeight = 0.015
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func preprocessImageForOCR(_ image: UIImage) -> CGImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let oriented = ciImage.oriented(forExifOrientation: Int32(image.cgImageOrientation.rawValue))

        var processed = oriented

        let targetWidth: CGFloat = 1600
        if processed.extent.width > 0, processed.extent.width < targetWidth {
            let scale = targetWidth / processed.extent.width
            if let scaled = processed.applyingFilter(
                "CILanczosScaleTransform",
                parameters: ["inputScale": scale, "inputAspectRatio": 1.0]
            ) as CIImage? {
                processed = scaled
            }
        }

        if let contrast = processed.applyingFilter(
            "CIColorControls",
            parameters: ["inputSaturation": 0.0, "inputContrast": 1.35, "inputBrightness": 0.0]
        ) as CIImage? {
            processed = contrast
        }

        if let exposure = processed.applyingFilter(
            "CIExposureAdjust",
            parameters: ["inputEV": 0.35]
        ) as CIImage? {
            processed = exposure
        }

        if let sharpen = processed.applyingFilter(
            "CISharpenLuminance",
            parameters: ["inputSharpness": 0.4]
        ) as CIImage? {
            processed = sharpen
        }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(processed, from: processed.extent)
    }

    // MARK: - Parsing Logic
    
    private func reconstructLines(from tokens: [(text: String, box: CGRect)]) -> [String] {
        let sortedTokens = tokens.sorted(by: { $0.box.midY > $1.box.midY })
        var groupedRows: [[(text: String, box: CGRect)]] = []
        
        for token in sortedTokens {
            var found = false
            for (idx, row) in groupedRows.enumerated() {
                let tokenMinY = token.box.minY
                let tokenMaxY = token.box.maxY
                let rowMinY = row.map { $0.box.minY }.min() ?? 0
                let rowMaxY = row.map { $0.box.maxY }.max() ?? 0
                
                let overlap = max(0, min(tokenMaxY, rowMaxY) - max(tokenMinY, rowMinY))
                let tokenHeight = token.box.height
                let rowHeight = row.map { $0.box.height }.max() ?? tokenHeight
                
                // Relaxed vertical tolerance to account for wrinkled or skewed receipts
                if overlap > tokenHeight * 0.25 || abs(token.box.midY - (rowMinY + rowMaxY)/2) < max(tokenHeight, rowHeight) * 0.65 {
                    groupedRows[idx].append(token)
                    found = true
                    break
                }
            }
            if !found {
                groupedRows.append([token])
            }
        }
        
        return groupedRows.map { row in
            row.sorted(by: { $0.box.minX < $1.box.minX })
               .map { $0.text }
               .joined(separator: " ")
        }
    }

    private func parseReceipt(tokens: [(text: String, box: CGRect)]) -> ReceiptScanResult {
        let lines = reconstructLines(from: tokens)
        
        // Find Date
        let (receiptDate, isDateReliable) = parseDate(from: lines)
        
        // Find Merchant Name (usually the first few lines)
        let merchantName = parseMerchantName(lines: lines)
        
        // Find Total
        let totalAmount = parseGrandTotal(tokens: tokens)

        // Detect Currency
        let currencyCode = parseCurrencyCode(lines: lines)
        
        // Deduce bill type
        let billType = parseBillType(lines: lines, merchantName: merchantName)

        return ReceiptScanResult(
            rawLines: lines,
            merchantName: merchantName,
            billType: billType,
            totalAmount: totalAmount,
            receiptDate: receiptDate,
            isDateReliable: isDateReliable,
            currencyCode: currencyCode,
            extractionStatus: .ocrOnly
        )
    }

    private func parseCurrencyCode(lines: [String]) -> String? {
        let explicitCodes = [
            "AED", "INR", "USD", "EUR", "GBP", "SAR", "QAR", "KWD", "BHD", "OMR",
            "JPY", "CNY", "SGD", "HKD", "AUD", "CAD", "CHF", "SEK", "NOK", "DKK",
            "ZAR", "THB", "MYR", "IDR", "PHP", "KRW"
        ]

        var scores: [String: Int] = [:]

        for line in lines {
            let upper = line.uppercased()

            for code in explicitCodes where upper.contains(code) {
                scores[code, default: 0] += 3
            }

            if line.contains("₹") || upper.contains(" INR ") || upper.contains("RS.") || upper.contains("RS ") {
                scores["INR", default: 0] += 2
            }
            if line.contains("د.إ") || upper.contains(" AED ") {
                scores["AED", default: 0] += 2
            }
            if line.contains("€") { scores["EUR", default: 0] += 1 }
            if line.contains("£") { scores["GBP", default: 0] += 1 }
            if line.contains("¥") { scores["JPY", default: 0] += 1 }
            if line.contains("$") { scores["USD", default: 0] += 1 }
        }

        return scores.max(by: { $0.value < $1.value })?.key
    }

    private func reconstructLinesStrict(from tokens: [(text: String, box: CGRect)]) -> [String] {
        let sortedTokens = tokens.sorted(by: { $0.box.midY > $1.box.midY })
        var groupedRows: [[(text: String, box: CGRect)]] = []
        
        for token in sortedTokens {
            var found = false
            for (idx, row) in groupedRows.enumerated() {
                let rowMidY = row.map { $0.box.midY }.reduce(0, +) / CGFloat(row.count)
                let rowHeight = row.map { $0.box.height }.max() ?? 0.02
                
                // Very strict tolerance to prevent merging lines (e.g., Grand Total & Cash)
                if abs(token.box.midY - rowMidY) < rowHeight * 0.3 {
                    groupedRows[idx].append(token)
                    found = true
                    break
                }
            }
            if !found {
                groupedRows.append([token])
            }
        }
        
        return groupedRows.map { row in
            row.sorted(by: { $0.box.minX < $1.box.minX })
               .map { $0.text }
               .joined(separator: " ")
        }
    }

    private func parseGrandTotal(tokens: [(text: String, box: CGRect)]) -> Double? {
        let skipKeywords = [
            "cash", "change", "tendered", "card", "credit", "tip", "gratuity", "rounding", "discount"
        ]

        // Normalize tokens for matching
        let normalizedTokens: [(text: String, box: CGRect, lower: String, compact: String)] = tokens.map {
            let lower = $0.text.lowercased()
            let compact = lower.replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
            return ($0.text, $0.box, lower, compact)
        }

        func tokensNearRow(of box: CGRect) -> [(text: String, box: CGRect, lower: String, compact: String)] {
            normalizedTokens.filter { token in
                let overlap = max(0, min(token.box.maxY, box.maxY) - max(token.box.minY, box.minY))
                let height = max(token.box.height, box.height)
                return overlap > height * 0.2 || abs(token.box.midY - box.midY) < height * 0.8
            }
        }

        func rowHasSkipKeywords(_ box: CGRect) -> Bool {
            let rowTokens = tokensNearRow(of: box)
            let rowText = rowTokens.map { $0.lower }.joined(separator: " ")
            return skipKeywords.contains(where: { rowText.contains($0) })
        }

        func findKeywordBoxes(isGrand: Bool) -> [CGRect] {
            let grandArabic = ["الإجمالي", "الإجمالي الكلي", "المجموع الكلي"]
            let totalArabic = ["المجموع", "الإجمالي"]

            var boxes: [CGRect] = []
            for token in normalizedTokens {
                if isGrand {
                    if grandArabic.contains(where: { token.lower.contains($0) }) {
                        boxes.append(token.box)
                        continue
                    }
                    if token.compact.contains("grandtotal") {
                        boxes.append(token.box)
                        continue
                    }
                    if token.compact.contains("grand") {
                        for other in normalizedTokens {
                            let overlap = max(0, min(token.box.maxY, other.box.maxY) - max(token.box.minY, other.box.minY))
                            let height = max(token.box.height, other.box.height)
                            if overlap > height * 0.2 || abs(token.box.midY - other.box.midY) < height * 0.6 {
                                if other.compact == "total" || other.compact.contains("total") {
                                    boxes.append(token.box.union(other.box))
                                }
                            }
                        }
                    }
                } else {
                    if totalArabic.contains(where: { token.lower.contains($0) }) {
                        boxes.append(token.box)
                        continue
                    }
                    if token.compact.contains("subtotal") || token.compact.contains("subtot") {
                        continue
                    }
                    if token.compact == "total" || token.compact.contains("total") {
                        boxes.append(token.box)
                        continue
                    }
                }
            }
            return boxes
        }

        func normalizeDigits(_ text: String) -> String {
            var result = ""
            for scalar in text.unicodeScalars {
                switch scalar.value {
                case 0x0660...0x0669: // Arabic-Indic digits
                    result.append(String(UnicodeScalar(scalar.value - 0x0660 + 0x0030)!))
                case 0x06F0...0x06F9: // Eastern Arabic-Indic digits
                    result.append(String(UnicodeScalar(scalar.value - 0x06F0 + 0x0030)!))
                default:
                    result.append(Character(scalar))
                }
            }
            return result
        }

        func normalizedAmount(from text: String) -> Double? {
            let cleaned = normalizeDigits(text)
                .replacingOccurrences(of: #"\b(\d{1,5})\s*\.\s*(\d{2})\b"#, with: "$1.$2", options: .regularExpression)
                .replacingOccurrences(of: #"(?<=\b\d{1,5})\s(?=\d{2}\b)"#, with: ".", options: .regularExpression)
                .replacingOccurrences(of: #"[₹$€£¥]|Rs\.?|AED|USD|INR|SAR|QAR|KWD|BHD|OMR|\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
                .replacingOccurrences(of: ",", with: ".")
            if let value = Double(cleaned) { return value }
            // Handle numbers with multiple dots (1.234.56)
            let parts = cleaned.components(separatedBy: ".")
            if parts.count > 2 {
                let whole = parts.dropLast().joined()
                let frac = parts.last!
                return Double("\(whole).\(frac)")
            }
            return nil
        }

        func horizontalGap(_ left: CGRect, _ right: CGRect) -> CGFloat {
            return max(0, right.minX - left.maxX)
        }

        func candidateAmounts(toRightOf keywordBox: CGRect) -> [(value: Double, box: CGRect)] {
            var candidates: [(Double, CGRect)] = []
            let rowTokens = normalizedTokens.filter { token in
                guard token.box.minX > keywordBox.maxX + 0.005 else { return false }
                let overlap = max(0, min(token.box.maxY, keywordBox.maxY) - max(token.box.minY, keywordBox.minY))
                let height = max(token.box.height, keywordBox.height)
                return overlap > height * 0.15 || abs(token.box.midY - keywordBox.midY) < height * 0.9
            }.sorted(by: { $0.box.minX < $1.box.minX })

            for (idx, token) in rowTokens.enumerated() {
                if let value = normalizedAmount(from: token.text) {
                    candidates.append((value, token.box))
                }

                // Try merging with up to two following tokens on the same row
                var mergedText = token.text
                var mergedBox = token.box
                for j in (idx + 1)..<min(idx + 3, rowTokens.count) {
                    let next = rowTokens[j]
                    if abs(next.box.midY - token.box.midY) > max(next.box.height, token.box.height) * 0.8 {
                        break
                    }
                    if horizontalGap(mergedBox, next.box) > max(mergedBox.width, next.box.width) * 0.8 {
                        break
                    }
                    mergedText += " \(next.text)"
                    mergedBox = mergedBox.union(next.box)
                    if let value = normalizedAmount(from: mergedText) {
                        candidates.append((value, mergedBox))
                    }
                }
            }
            return candidates
        }

        func pickClosestRightAmount(for keywordBox: CGRect) -> Double? {
            if rowHasSkipKeywords(keywordBox) { return nil }
            let candidates = candidateAmounts(toRightOf: keywordBox)
            guard let best = candidates.min(by: { $0.box.minX < $1.box.minX }) else { return nil }
            return best.value
        }

        func candidateAmountsBelow(keywordBox: CGRect) -> [(value: Double, box: CGRect)] {
            let keywordWidth = max(keywordBox.width, 0.001)
            let columnMinX = keywordBox.minX - keywordWidth * 0.2
            let columnMaxX = keywordBox.maxX + keywordWidth * 0.2
            let rowTokens = normalizedTokens.filter { token in
                guard token.box.minY > keywordBox.maxY else { return false }
                let overlapsColumn = token.box.midX >= columnMinX && token.box.midX <= columnMaxX
                let isNearBelow = token.box.minY - keywordBox.maxY < keywordBox.height * 3.0
                return overlapsColumn && isNearBelow
            }.sorted(by: { $0.box.minY < $1.box.minY })

            var candidates: [(Double, CGRect)] = []
            for (idx, token) in rowTokens.enumerated() {
                if let value = normalizedAmount(from: token.text) {
                    candidates.append((value, token.box))
                }

                // Try merging with up to two following tokens on the same row
                var mergedText = token.text
                var mergedBox = token.box
                for j in (idx + 1)..<min(idx + 3, rowTokens.count) {
                    let next = rowTokens[j]
                    if abs(next.box.midY - token.box.midY) > max(next.box.height, token.box.height) * 0.8 {
                        break
                    }
                    if horizontalGap(mergedBox, next.box) > max(mergedBox.width, next.box.width) * 0.8 {
                        break
                    }
                    mergedText += " \(next.text)"
                    mergedBox = mergedBox.union(next.box)
                    if let value = normalizedAmount(from: mergedText) {
                        candidates.append((value, mergedBox))
                    }
                }
            }
            return candidates
        }

        let grandBoxes = findKeywordBoxes(isGrand: true).sorted(by: { $0.minY < $1.minY })
        for box in grandBoxes {
            if let value = pickClosestRightAmount(for: box) {
                return value
            }
            // If no right-side amount, allow below-column for GRAND TOTAL only
            if !rowHasSkipKeywords(box) {
                let belowCandidates = candidateAmountsBelow(keywordBox: box)
                if let best = belowCandidates.min(by: { $0.box.minY < $1.box.minY }) {
                    return best.value
                }
            }
        }

        let totalBoxes = findKeywordBoxes(isGrand: false).sorted(by: { $0.minY < $1.minY })
        for box in totalBoxes {
            if let value = pickClosestRightAmount(for: box) {
                return value
            }
        }

        let allAmounts = tokens.flatMap { extractAllCurrencies(from: $0.text) }
        let plausible = allAmounts.filter { $0 >= 0.1 && $0 <= 100000 }
        return plausible.max()
    }

    private func normalizeOCRNumberSpacing(_ text: String) -> String {
        var normalized = text
        normalized = normalized.replacingOccurrences(
            of: #"\b(\d{1,5})\s*\.\s*(\d{2})\b"#,
            with: "$1.$2",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?<=\b\d{1,5})\s(?=\d{2}\b)"#,
            with: ".",
            options: .regularExpression
        )
        return normalized
    }

    // MARK: - Currency Parsing

    private func extractAllCurrencies(from text: String) -> [Double] {
        // Fix OCR spacing issues. Convert "3 26" to "3.26"
        let normalized = text
            .replacingOccurrences(of: #"\b(\d{1,5})\s*\.\s*(\d{2})\b"#, with: "$1.$2", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\b\d{1,5})\s(?=\d{2}\b)"#, with: ".", options: .regularExpression)

        let pattern = #"\b\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))

        var amounts: [Double] = []
        for match in matches {
            let matchStr = (normalized as NSString).substring(with: match.range)
            if let amount = parseCurrencyAmount(matchStr) {
                amounts.append(amount)
            }
        }

        let flatPattern = #"(?:[₹$€£¥]|Rs\.?|AED|USD)\s*(\d+)\b"#
        if let flatRegex = try? NSRegularExpression(pattern: flatPattern, options: .caseInsensitive) {
            let flatMatches = flatRegex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
            for match in flatMatches {
                if match.range(at: 1).location != NSNotFound {
                    let matchStr = (normalized as NSString).substring(with: match.range(at: 1))
                    if let amount = Double(matchStr) {
                        amounts.append(amount)
                    }
                }
            }
        }

        if amounts.isEmpty {
             let trailingIntPattern = #"\s(\d+)\b$"#
             if let trailRegex = try? NSRegularExpression(pattern: trailingIntPattern) {
                 if let match = trailRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                    match.range(at: 1).location != NSNotFound {
                     let matchStr = (text as NSString).substring(with: match.range(at: 1))
                     if let amount = Double(matchStr) {
                         amounts.append(amount)
                     }
                 }
             }
        }

        return amounts
    }

    private func parseCurrencyAmount(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: #"[₹$€£¥]|Rs\.?|AED|USD|INR|\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: ",", with: ".") 
        
        let parts = cleaned.components(separatedBy: ".")
        if parts.count > 2 {
            let whole = parts.dropLast().joined()
            let frac = parts.last!
            return Double("\(whole).\(frac)")
        }
        
        return Double(cleaned)
    }
    
    // MARK: - Secondary Parsers

    private func parseMerchantName(lines: [String]) -> String? {
        let limit = min(3, lines.count)
        let blacklist = [
            "tax", "invoice", "receipt", "vat", "gst", "bill", "order",
            "payment", "transaction", "table"
        ]
        for i in 0..<limit {
            let text = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 4 && text.count <= 40 else { continue }
            let lower = text.lowercased()
            guard !blacklist.contains(where: { lower.contains($0) }) else { continue }
            let hasAlpha = text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
            if hasAlpha { return text }
        }
        return nil
    }

    private func parseBillType(lines: [String], merchantName: String?) -> String? {
        let corpus = (lines + [merchantName ?? ""]).joined(separator: " ").lowercased()
        let rules: [(label: String, keywords: [String])] = [
            ("Restaurant", ["biryani", "paneer", "cafe", "food", "dine", "kot", "waiter", "table", "menu"]),
            ("Grocery", ["grocery", "supermarket", "mart", "vegetable", "fruit", "provision", "barcode", "lulu", "carrefour", "spinneys", "coop"]),
            ("Fuel", ["petrol", "diesel", "fuel", "hpcl", "bpcl", "pump", "enoc", "adnoc", "eppco"]),
            ("Pharmacy", ["medical", "chemist", "pharmacy", "drug", "tablet", "capsule", "aster", "life", "bin sina"]),
            ("Utility", ["electricity", "water", "recharge", "postpaid", "broadband"])
        ]
        
        var best: (label: String, score: Int)?
        for rule in rules {
            let score = rule.keywords.reduce(0) { $0 + (corpus.contains($1) ? 1 : 0) }
            if score > 0 && (best == nil || score > best!.score) { best = (rule.label, score) }
        }
        return best?.label
    }

    private func parseDate(from lines: [String]) -> (Date?, Bool) {
        let text = lines.joined(separator: " ")
        let pattern = #"\b(\d{1,2})[\/\-\.]([0-9]{1,2}|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[\/\-\.](\d{2,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return (nil, false) }
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        let matchStr = (text as NSString).substring(with: match.range).replacingOccurrences(of: ".", with: "/").replacingOccurrences(of: "-", with: "/")
        let parts = matchStr.split(separator: "/")
        let hasFourDigitYear = parts.last?.count == 4
        
        for format in ["dd/MM/yyyy", "dd/MMM/yy", "MM/dd/yyyy", "yyyy/MM/dd"] {
            df.dateFormat = format
            if let date = df.date(from: matchStr) { return (date, hasFourDigitYear) }
        }
        return (nil, false)
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
