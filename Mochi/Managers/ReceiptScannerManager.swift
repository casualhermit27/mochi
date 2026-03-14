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
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        
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
        let receiptDate = parseDate(from: lines)
        
        // Find Merchant Name (usually the first few lines)
        let merchantName = parseMerchantName(lines: lines)
        
        // Find Total
        let totalAmount = parseGrandTotal(tokens: tokens)
        
        // Deduce bill type
        let billType = parseBillType(lines: lines, merchantName: merchantName)

        return ReceiptScanResult(
            rawLines: lines,
            merchantName: merchantName,
            billType: billType,
            totalAmount: totalAmount,
            receiptDate: receiptDate,
            extractionStatus: .ocrOnly
        )
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
        let lines = reconstructLinesStrict(from: tokens)

        // DEBUG: print all reconstructed lines so we can see what OCR produced
        print("=== RECEIPT OCR LINES ===")
        for (i, l) in lines.enumerated() { print("[\(i)] \(l)") }
        print("=========================")

        // Normalize all lines (fix OCR space-decimals like "184 28" -> "184.28")
        let normalizedLines = lines.map {
            $0.replacingOccurrences(of: #"(?<=\b\d{1,5})\s(?=\d{2}\b)"#, with: ".", options: .regularExpression)
        }

        // Exact keyword sets by priority
        let highPriorityKeywords = ["grand total", "net pay", "amount due", "amount payable", "tax inclusive"]
        let lowPriorityKeywords  = ["total", "balance due", "sub total", "subtotal"]
        let skipKeywords         = ["change", "cash", "credit", "card", "visa", "mastercard", "tendered", "discount", "vat"]

        // Helper: extract the last (rightmost) valid currency number from a line
        func extractLastAmount(_ line: String) -> Double? {
            let result = extractAllCurrencies(from: line).last
            print("  extractLastAmount('\(line)') = \(String(describing: result))")
            return result
        }

        // PASS 1 – High priority: scan ONLY the exact matching line
        for (i, line) in normalizedLines.enumerated() {
            let lower = line.lowercased()
            guard highPriorityKeywords.contains(where: { lower.contains($0) }) else { continue }
            if skipKeywords.contains(where: { lower.contains($0) }) { continue }

            print("PASS1 HIGH match line[\(i)]: \(line)")
            if let amount = extractLastAmount(line) {
                print("PASS1 returning \(amount) from line itself")
                return amount
            }

            if i + 1 < normalizedLines.count {
                let nextLine = normalizedLines[i + 1]
                let nextLower = nextLine.lowercased()
                print("PASS1 trying next line[\(i+1)]: \(nextLine)")
                if !skipKeywords.contains(where: { nextLower.contains($0) }),
                   let amount = extractLastAmount(nextLine) {
                    print("PASS1 returning \(amount) from next line")
                    return amount
                }
            }
        }

        // PASS 2 – Low priority total keyword: scan ONLY the exact matching line
        var lowCandidates: [Double] = []
        for (i, line) in normalizedLines.enumerated() {
            let lower = line.lowercased()
            guard lowPriorityKeywords.contains(where: { lower.contains($0) }) else { continue }
            if skipKeywords.contains(where: { lower.contains($0) }) { continue }

            print("PASS2 LOW match line[\(i)]: \(line)")
            if let amount = extractLastAmount(line) {
                lowCandidates.append(amount)
            } else if i + 1 < normalizedLines.count {
                let nextLine = normalizedLines[i + 1]
                let nextLower = nextLine.lowercased()
                if !skipKeywords.contains(where: { nextLower.contains($0) }),
                   let amount = extractLastAmount(nextLine) {
                    lowCandidates.append(amount)
                }
            }
        }
        if let best = lowCandidates.max() {
            print("PASS2 returning best lowCandidate: \(best)")
            return best
        }

        // PASS 3 – Absolute fallback: largest single currency value anywhere on the receipt
        let allAmounts = normalizedLines.flatMap { extractAllCurrencies(from: $0) }
        let fallback = allAmounts.filter { $0 > 0 && $0 < 500_000 }.max()
        print("PASS3 fallback returning: \(String(describing: fallback))")
        return fallback
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
