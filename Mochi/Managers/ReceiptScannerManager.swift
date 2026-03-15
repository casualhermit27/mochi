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
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
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
            parameters: ["inputSaturation": 0.0, "inputContrast": 1.25, "inputBrightness": 0.0]
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
                
                // Relaxed vertical tolerance to account for wrinkled or skewed receipts
                if overlap > tokenHeight * 0.3 || abs(token.box.midY - (rowMinY + rowMaxY)/2) < tokenHeight * 0.8 {
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
            "cash", "change", "tendered", "credit", "credit note", "card", "visa", "mastercard",
            "subtotal", "sub total", "tax", "vat", "gst", "discount", "savings", "tip", "gratuity",
            "service", "round", "rounding"
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
                return overlap > height * 0.2 || abs(token.box.midY - box.midY) < height * 0.6
            }
        }

        func rowHasSkipKeywords(_ box: CGRect) -> Bool {
            let rowTokens = tokensNearRow(of: box)
            let rowText = rowTokens.map { $0.lower }.joined(separator: " ")
            return skipKeywords.contains(where: { rowText.contains($0) })
        }

        func findKeywordBox(isGrand: Bool) -> CGRect? {
            var best: CGRect? = nil
            for token in normalizedTokens {
                if isGrand {
                    if token.compact.contains("grandtotal") {
                        best = token.box
                        break
                    }
                    if token.compact.contains("grand") {
                        for other in normalizedTokens {
                            let overlap = max(0, min(token.box.maxY, other.box.maxY) - max(token.box.minY, other.box.minY))
                            let height = max(token.box.height, other.box.height)
                            if overlap > height * 0.2 || abs(token.box.midY - other.box.midY) < height * 0.6 {
                                if other.compact == "total" || other.compact.contains("total") {
                                    let union = token.box.union(other.box)
                                    if best == nil || union.minY > best!.minY {
                                        best = union
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if token.compact.contains("subtotal") || token.compact.contains("subtot") {
                        continue
                    }
                    if token.compact == "total" || token.compact.contains("total") {
                        best = token.box
                        break
                    }
                    // Handle "invoice total", "total inclusive", etc.
                    if token.compact.contains("total") {
                        best = token.box
                        break
                    }
                }
            }
            return best
        }

        func normalizedAmount(from text: String) -> Double? {
            let cleaned = text
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

        func candidateAmounts(toRightOf keywordBox: CGRect) -> [(value: Double, box: CGRect)] {
            var candidates: [(Double, CGRect)] = []
            for token in normalizedTokens {
                guard token.box.minX > keywordBox.maxX + 0.01 else { continue }
                let overlap = max(0, min(token.box.maxY, keywordBox.maxY) - max(token.box.minY, keywordBox.minY))
                let height = max(token.box.height, keywordBox.height)
                guard overlap > height * 0.2 || abs(token.box.midY - keywordBox.midY) < height * 0.6 else { continue }

                // Try direct parse
                if let value = normalizedAmount(from: token.text) {
                    candidates.append((value, token.box))
                    continue
                }

                // Try merge with immediate right token for space-decimals (e.g., "3" "26")
                let rightTokens = normalizedTokens.filter {
                    $0.box.minX > token.box.maxX &&
                    (abs($0.box.midY - token.box.midY) < max($0.box.height, token.box.height) * 0.6)
                }
                if let nearestRight = rightTokens.min(by: { $0.box.minX < $1.box.minX }) {
                    let merged = "\(token.text) \(nearestRight.text)"
                    if let value = normalizedAmount(from: merged) {
                        let mergedBox = token.box.union(nearestRight.box)
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

        if let grandBox = findKeywordBox(isGrand: true) {
            return pickClosestRightAmount(for: grandBox)
        }

        if let totalBox = findKeywordBox(isGrand: false) {
            return pickClosestRightAmount(for: totalBox)
        }

        return nil
    }

    // MARK: - Currency Parsing

    private func extractAllCurrencies(from text: String) -> [Double] {
        // Fix OCR spacing issues. Convert "3 26" to "3.26"
        let normalized = text.replacingOccurrences(of: #"(?<=\b\d{1,5})\s(?=\d{2}\b)"#, with: ".", options: .regularExpression)

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
        for i in 0..<limit {
            let text = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if text.count > 3 && text.count < 40 {
                let lower = text.lowercased()
                if !lower.contains("tax") && !lower.contains("invoice") && !lower.contains("receipt") {
                    return text
                }
            }
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
