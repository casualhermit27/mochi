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
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                
                var allLines: [String] = []
                var rawTokens: [(text: String, box: CGRect)] = []
                
                for obs in observations {
                    if let topCandidate = obs.topCandidates(1).first {
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty {
                            allLines.append(text)
                            rawTokens.append((text: text, box: obs.boundingBox))
                        }
                    }
                }
                
                if allLines.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                    return
                }
                
                let result = self.parseReceipt(lines: allLines, tokens: rawTokens)
                continuation.resume(returning: result)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB", "ar-AE"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: image.cgImageOrientation, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Parsing Logic
    
    private func parseReceipt(lines: [String], tokens: [(text: String, box: CGRect)]) -> ReceiptScanResult {
        // Find Date
        let receiptDate = parseDate(from: lines)
        
        // Find Merchant Name (usually the first few lines)
        let merchantName = parseMerchantName(lines: lines)
        
        // Find Total
        let totalAmount = parseGrandTotal(lines: lines, tokens: tokens)
        
        // Extract Line Items
        var lineItems: [ReceiptLineItem] = []
        for line in lines {
            let lower = line.lowercased()
            if lower.contains("total") || lower.contains("net pay") || lower.contains("amount") || lower.contains("balance") || lower.contains("cash") || lower.contains("card") || lower.contains("visa") || lower.contains("change") || lower.contains("tax") || lower.contains("gst") {
                continue
            }
            if let item = tryExtractLineItem(from: line) {
                // Ignore items that match the total exactly to prevent duplicate entries
                if item.amount != totalAmount {
                    lineItems.append(item)
                }
            }
        }
        
        if let total = totalAmount {
            lineItems = lineItems.filter { $0.amount < total && $0.amount > 0 }
        }
        
        // Deduce bill type
        let billType = parseBillType(lines: lines, merchantName: merchantName)

        return ReceiptScanResult(
            rawLines: lines,
            merchantName: merchantName,
            billType: billType,
            totalAmount: totalAmount,
            lineItems: lineItems,
            receiptDate: receiptDate,
            extractionStatus: .ocrOnly
        )
    }

    private func parseGrandTotal(lines: [String], tokens: [(text: String, box: CGRect)]) -> Double? {
        var allAmounts: [Double] = []
        var keywordAmounts: [(amount: Double, offset: Int)] = [] 
        
        let totalKeywords = ["total", "amount payable", "net pay", "balance due", "grand total", "amount due", "payable"]
        let excludedKeywords = ["subtotal", "sub-total", "tax", "gst", "vat", "change", "cash tendered", "discount", "saved"]
        
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            
            let amountsOnLine = extractAllCurrencies(from: line)
            allAmounts.append(contentsOf: amountsOnLine)
            
            let hasTotalKeyword = totalKeywords.contains(where: { lowerLine.contains($0) })
            let hasExcludedKeyword = excludedKeywords.contains(where: { lowerLine.contains($0) })
            
            if hasTotalKeyword && !hasExcludedKeyword {
                if let maxOnLine = amountsOnLine.max() {
                    keywordAmounts.append((amount: maxOnLine, offset: 0))
                }
                
                let nextLinesMaxIndex = min(index + 3, lines.count - 1)
                if index < lines.count - 1 {
                    for i in (index + 1)...nextLinesMaxIndex {
                        let nextLineAmounts = extractAllCurrencies(from: lines[i])
                        if let maxNextLine = nextLineAmounts.max() {
                            keywordAmounts.append((amount: maxNextLine, offset: i - index))
                        }
                    }
                }
            }
        }
        
        if !keywordAmounts.isEmpty {
            let sorted = keywordAmounts.sorted {
                if $0.offset != $1.offset { 
                    return $0.offset < $1.offset 
                }
                return $0.amount > $1.amount
            }
            if let best = sorted.first {
                return best.amount
            }
        }
        
        let plausibleAmounts = allAmounts.filter { $0 > 0 && $0 < 500000 && $0 != 0 } // AED amounts usually max in tens of thousands
        return plausibleAmounts.max()
    }
    
    private func tryExtractLineItem(from line: String) -> ReceiptLineItem? {
        let pattern = #"(.*?)\s+([₹$€£¥]|Rs\.?|AED)?\s*(\d+[.,]\d{2})\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }
        
        let descRange = match.range(at: 1)
        let amountRange = match.range(at: 3)
        
        let desc = (line as NSString).substring(with: descRange).trimmingCharacters(in: .whitespacesAndNewlines)
        let amountStr = (line as NSString).substring(with: amountRange)
        
        guard let amount = parseCurrencyAmount(amountStr), desc.count > 2 else { return nil }
        
        let isJustNumbers = desc.range(of: #"^\d+$"#, options: .regularExpression) != nil
        if isJustNumbers { return nil }
        
        return ReceiptLineItem(description: desc, amount: amount, confidence: 0.8)
    }

    private func extractAllCurrencies(from text: String) -> [Double] {
        let pattern = #"\b\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        var amounts: [Double] = []
        for match in matches {
            let matchStr = (text as NSString).substring(with: match.range)
            if let amount = parseCurrencyAmount(matchStr) {
                amounts.append(amount)
            }
        }
        
        let flatPattern = #"(?:[₹$€£¥]|Rs\.?|AED|USD)\s*(\d+)\b"#
        if let flatRegex = try? NSRegularExpression(pattern: flatPattern, options: .caseInsensitive) {
            let flatMatches = flatRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in flatMatches {
                if match.range(at: 1).location != NSNotFound {
                    let matchStr = (text as NSString).substring(with: match.range(at: 1))
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
