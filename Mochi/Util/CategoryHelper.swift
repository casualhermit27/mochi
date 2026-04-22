import Foundation
import NaturalLanguage
#if canImport(FoundationModels)
import FoundationModels
#endif

struct TransactionCategory: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let legacyValue: String
    let symbolName: String
    let keywords: [String]
    let merchantAliases: [String]
    let semanticTerms: [String]

    var displayValue: String { legacyValue }
}

struct CategoryMatch: Sendable {
    let category: TransactionCategory
    let confidence: Double
    let source: Source

    enum Source: Sendable {
        case languageModel
        case merchantAlias
        case keyword
        case semanticEmbedding
        case fallback
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
private enum LanguageModelMochiCategory: String, CaseIterable {
    case food = "Food 🍔"
    case transport = "Transport 🚗"
    case shopping = "Shopping 🛍️"
    case utilities = "Utilities 💡"
    case entertainment = "Entertainment 🎬"
    case health = "Health 💊"
    case travel = "Travel ✈️"
    case subscriptions = "Subscriptions 🔄"
    case other = "Other 📦"
}
#endif

enum CategoryHelper {
    private static var embeddingCache: [String: [Float]]?
    private static var embeddingModel: NLEmbedding?

    static let otherCategory = TransactionCategory(
        id: "other",
        name: "Other",
        legacyValue: "Other 📦",
        symbolName: "shippingbox.fill",
        keywords: [],
        merchantAliases: [],
        semanticTerms: []
    )

    static let definitions: [TransactionCategory] = [
        TransactionCategory(
            id: "food",
            name: "Food",
            legacyValue: "Food 🍔",
            symbolName: "fork.knife",
            keywords: [
                "food", "dinner", "lunch", "breakfast", "brunch", "groceries", "grocery",
                "restaurant", "cafe", "coffee", "pizza", "burger", "snack", "drink",
                "bar", "pub", "bakery", "tea", "juice", "takeout", "delivery", "meal",
                "supermarket"
            ],
            merchantAliases: [
                "mcdonalds", "mcdonald's", "starbucks", "subway", "chipotle", "dominos",
                "domino's", "kfc", "taco bell", "doordash", "uber eats", "ubereats",
                "grubhub", "instacart", "swiggy", "zomato", "blinkit", "zepto",
                "bigbasket", "whole foods", "trader joes", "trader joe's"
            ],
            semanticTerms: [
                "restaurant meal groceries cafe coffee breakfast lunch dinner food delivery supermarket"
            ]
        ),
        TransactionCategory(
            id: "transport",
            name: "Transport",
            legacyValue: "Transport 🚗",
            symbolName: "car.fill",
            keywords: [
                "transport", "taxi", "cab", "gas", "fuel", "petrol", "diesel", "train",
                "bus", "subway", "metro", "parking", "toll", "car", "transit", "ride",
                "commute", "fare", "auto", "rickshaw"
            ],
            merchantAliases: [
                "uber", "lyft", "ola", "rapido", "bolt", "grab", "shell", "chevron",
                "exxon", "bp", "metrocard", "mta", "irctc"
            ],
            semanticTerms: [
                "taxi ride commute public transit car fuel parking train bus metro transport"
            ]
        ),
        TransactionCategory(
            id: "shopping",
            name: "Shopping",
            legacyValue: "Shopping 🛍️",
            symbolName: "bag.fill",
            keywords: [
                "shopping", "clothes", "clothing", "shoes", "mall", "store", "gift",
                "electronics", "hardware", "furniture", "book", "books", "makeup",
                "cosmetics", "accessories", "stationery"
            ],
            merchantAliases: [
                "amazon", "target", "walmart", "costco", "best buy", "ikea", "apple store",
                "flipkart", "myntra", "nykaa", "ajio", "meesho", "croma", "reliance digital",
                "h&m", "zara", "uniqlo"
            ],
            semanticTerms: [
                "retail purchase clothes electronics gifts furniture books shopping store"
            ]
        ),
        TransactionCategory(
            id: "utilities",
            name: "Utilities",
            legacyValue: "Utilities 💡",
            symbolName: "bolt.fill",
            keywords: [
                "utility", "electric", "electricity", "water", "gas bill", "internet",
                "wifi", "broadband", "phone", "mobile", "rent", "mortgage", "insurance",
                "bill", "recharge", "postpaid", "prepaid", "maintenance"
            ],
            merchantAliases: [
                "comcast", "xfinity", "verizon", "at&t", "tmobile", "t-mobile", "airtel",
                "jio", "vi", "vodafone", "bsnl", "act fibernet", "bescom", "pg&e"
            ],
            semanticTerms: [
                "monthly household bill electricity water gas internet phone rent insurance utilities"
            ]
        ),
        TransactionCategory(
            id: "entertainment",
            name: "Entertainment",
            legacyValue: "Entertainment 🎬",
            symbolName: "play.tv.fill",
            keywords: [
                "entertainment", "movie", "cinema", "game", "concert", "ticket", "club",
                "party", "show", "theatre", "theater", "bowling", "arcade", "museum",
                "event"
            ],
            merchantAliases: [
                "steam", "playstation", "xbox", "nintendo", "bookmyshow", "amc", "regal",
                "fandango", "ticketmaster"
            ],
            semanticTerms: [
                "movies games concerts tickets events shows cinema entertainment"
            ]
        ),
        TransactionCategory(
            id: "health",
            name: "Health",
            legacyValue: "Health 💊",
            symbolName: "cross.case.fill",
            keywords: [
                "health", "medical", "doctor", "pharmacy", "medicine", "meds", "gym",
                "fitness", "yoga", "dental", "dentist", "hospital", "clinic", "therapy",
                "therapist", "chemist", "prescription", "lab", "diagnostic"
            ],
            merchantAliases: [
                "cvs", "walgreens", "rite aid", "apollo pharmacy", "pharmeasy", "netmeds",
                "1mg", "cult fit", "cult.fit", "planet fitness", "one medical"
            ],
            semanticTerms: [
                "doctor pharmacy medicine hospital clinic dental fitness gym healthcare"
            ]
        ),
        TransactionCategory(
            id: "travel",
            name: "Travel",
            legacyValue: "Travel ✈️",
            symbolName: "airplane",
            keywords: [
                "travel", "hotel", "airbnb", "flight", "airline", "tour", "vacation",
                "trip", "resort", "luggage", "visa", "passport", "hostel", "booking"
            ],
            merchantAliases: [
                "airbnb", "booking.com", "expedia", "makemytrip", "goibibo", "cleartrip",
                "indigo", "delta", "united airlines", "american airlines", "southwest",
                "marriott", "hilton", "hyatt"
            ],
            semanticTerms: [
                "flights hotels vacation trip lodging airline resort travel booking"
            ]
        ),
        TransactionCategory(
            id: "subscriptions",
            name: "Subscriptions",
            legacyValue: "Subscriptions 🔄",
            symbolName: "arrow.triangle.2.circlepath",
            keywords: [
                "subscription", "membership", "monthly", "annual", "yearly", "renewal",
                "plan", "premium", "pro"
            ],
            merchantAliases: [
                "netflix", "spotify", "apple music", "hulu", "disney", "disney+",
                "prime", "amazon prime", "patreon", "youtube premium", "icloud",
                "google one", "dropbox", "notion", "github", "chatgpt", "openai",
                "adobe", "figma", "canva", "setapp"
            ],
            semanticTerms: [
                "recurring subscription membership monthly annual renewal streaming software plan"
            ]
        ),
        otherCategory
    ]

    static let categories: [String] = definitions.map(\.legacyValue)

    static var categoryKeywords: [String: [String]] {
        Dictionary(uniqueKeysWithValues: definitions.map { ($0.legacyValue, $0.keywords + $0.merchantAliases) })
    }

    static func categorize(note: String?) -> String {
        categorizeDetails(note: note).category.legacyValue
    }

    static func categorizeSmart(note: String?) async -> String {
        await categorizeSmartDetails(note: note).category.legacyValue
    }

    static func categorizeSmartDetails(note: String?) async -> CategoryMatch {
        let normalizedNote = normalize(note)
        guard !normalizedNote.isEmpty else {
            return CategoryMatch(category: otherCategory, confidence: 0, source: .fallback)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if let match = await languageModelMatch(note: normalizedNote) {
                return match
            }
        }
        #endif

        return categorizeDetails(note: note)
    }

    static func categorizeDetails(note: String?) -> CategoryMatch {
        let normalizedNote = normalize(note)
        guard !normalizedNote.isEmpty else {
            return CategoryMatch(category: otherCategory, confidence: 0, source: .fallback)
        }

        let candidates = definitions.filter { $0.id != otherCategory.id }

        if let merchantMatch = bestRuleMatch(
            note: normalizedNote,
            categories: candidates,
            terms: { $0.merchantAliases },
            termWeight: 12
        ) {
            return CategoryMatch(category: merchantMatch.category, confidence: merchantMatch.confidence, source: .merchantAlias)
        }

        if let keywordMatch = bestRuleMatch(
            note: normalizedNote,
            categories: candidates,
            terms: { $0.keywords },
            termWeight: 7
        ) {
            return CategoryMatch(category: keywordMatch.category, confidence: keywordMatch.confidence, source: .keyword)
        }

        return semanticMatch(note: normalizedNote, candidates: candidates)
    }

    static func category(for value: String?) -> TransactionCategory {
        guard let value else { return otherCategory }
        let normalizedValue = normalize(value)
        return definitions.first { category in
            normalize(category.legacyValue) == normalizedValue ||
            normalize(category.name) == normalizedValue ||
            category.id == normalizedValue
        } ?? otherCategory
    }

    static func displayName(for value: String?) -> String {
        category(for: value).name
    }

    static func symbolName(for value: String?) -> String {
        category(for: value).symbolName
    }

    static func storageValue(for value: String?) -> String {
        category(for: value).legacyValue
    }

    static func shouldRecategorize(category: String?, note: String?) -> Bool {
        let normalizedNote = normalize(note)
        guard !normalizedNote.isEmpty else { return false }

        guard let category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }

        let resolved = self.category(for: category)
        let normalizedCategory = normalize(category)
        let isKnown = definitions.contains {
            normalize($0.legacyValue) == normalizedCategory ||
            normalize($0.name) == normalizedCategory ||
            $0.id == normalizedCategory
        }

        return !isKnown || resolved.id == otherCategory.id
    }

    @discardableResult
    static func backfill(items: [Item]) -> Int {
        var updatedCount = 0

        for item in items where shouldRecategorize(category: item.category, note: item.note) {
            let match = categorizeDetails(note: item.note)
            guard match.category.id != otherCategory.id else { continue }

            item.category = match.category.legacyValue
            updatedCount += 1
        }

        return updatedCount
    }

    @MainActor
    @discardableResult
    static func backfillSmart(items: [Item]) async -> Int {
        var updatedCount = 0

        for item in items where shouldRecategorize(category: item.category, note: item.note) {
            let match = await categorizeSmartDetails(note: item.note)
            guard match.category.id != otherCategory.id else { continue }

            item.category = match.category.legacyValue
            updatedCount += 1
        }

        return updatedCount
    }

    @MainActor
    @discardableResult
    static func recategorizeAll(items: [Item]) async -> Int {
        var updatedCount = 0

        for item in items {
            let match = await categorizeSmartDetails(note: item.note)
            let oldCategory = item.category
            item.category = match.category.legacyValue

            if oldCategory != match.category.legacyValue {
                updatedCount += 1
            }
        }

        return updatedCount
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func languageModelMatch(note: String) async -> CategoryMatch? {
        let model = SystemLanguageModel(useCase: .contentTagging)
        guard model.isAvailable else { return nil }

        let categoryList = definitions.map { "\($0.name): \($0.legacyValue)" }.joined(separator: "\n")
        let prompt = """
        Categorize this spending transaction into exactly one category.

        Categories:
        \(categoryList)

        Examples:
        - Food: McDonald's, Starbucks, Uber Eats, grocery store, restaurant
        - Transport: Uber, gas station, parking, taxi, train ticket
        - Shopping: Amazon, clothing store, electronics, gifts, furniture
        - Utilities: electricity bill, internet, phone bill, rent, insurance
        - Entertainment: Netflix, movies, PS5, Xbox, concerts, gaming
        - Health: pharmacy, gym, doctor, dentist, medical supplies
        - Travel: hotel, flight, Airbnb, vacation, trip booking
        - Subscriptions: Spotify, Adobe, GitHub, subscription service
        - Other: only if truly cannot determine

        Transaction: "\(note)"
        """

        do {
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: LanguageModelMochiCategory.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 32)
            )
            let category = category(for: response.content.rawValue)
            return CategoryMatch(category: category, confidence: 0.9, source: .languageModel)
        } catch {
            return nil
        }
    }
    #endif

    private static func bestRuleMatch(
        note: String,
        categories: [TransactionCategory],
        terms: (TransactionCategory) -> [String],
        termWeight: Double
    ) -> (category: TransactionCategory, confidence: Double)? {
        var bestCategory: TransactionCategory?
        var bestScore = 0.0

        for category in categories {
            var score = 0.0

            for term in terms(category) {
                let normalizedTerm = normalize(term)
                guard !normalizedTerm.isEmpty else { continue }

                if containsTerm(normalizedTerm, in: note) {
                    let wordBonus = Double(normalizedTerm.split(separator: " ").count) * 0.75
                    score += termWeight + wordBonus
                }
            }

            if score > bestScore {
                bestScore = score
                bestCategory = category
            }
        }

        guard let bestCategory, bestScore >= termWeight else { return nil }
        let confidence = min(0.98, 0.7 + (bestScore / 60.0))
        return (bestCategory, confidence)
    }

    private static func containsTerm(_ term: String, in note: String) -> Bool {
        let noteTokens = Set(note.split(separator: " ").map(String.init))
        let termTokens = term.split(separator: " ").map(String.init)

        if termTokens.count == 1 {
            return noteTokens.contains(term)
        }

        return note.contains(term)
    }

    private static func ensureEmbeddingModel() {
        if embeddingModel == nil {
            embeddingModel = NLEmbedding.sentenceEmbedding(for: .english)
        }
    }

    private static func precomputeEmbeddings(candidates: [TransactionCategory]) {
        guard embeddingCache == nil else { return }
        ensureEmbeddingModel()
        guard let model = embeddingModel else { return }

        var cache: [String: [Float]] = [:]
        for category in candidates {
            let context = (category.keywords + category.merchantAliases + category.semanticTerms).joined(separator: " ")
            if let vector = model.vector(for: context) {
                cache[category.id] = vector.map { Float($0) }
            }
        }
        embeddingCache = cache
    }

    private static func cosineSimilarity(_ vectorA: [Double], _ vectorB: [Double]) -> Double {
        guard vectorA.count == vectorB.count, !vectorA.isEmpty else { return 0 }

        var dotProduct = 0.0
        var magnitudeA = 0.0
        var magnitudeB = 0.0

        for i in 0..<vectorA.count {
            dotProduct += vectorA[i] * vectorB[i]
            magnitudeA += vectorA[i] * vectorA[i]
            magnitudeB += vectorB[i] * vectorB[i]
        }

        let denominator = sqrt(magnitudeA) * sqrt(magnitudeB)
        guard denominator > 0 else { return 0 }

        return max(0, dotProduct / denominator)
    }

    private static func cosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Float {
        let doubleA = vectorA.map { Double($0) }
        let doubleB = vectorB.map { Double($0) }
        return Float(cosineSimilarity(doubleA, doubleB))
    }

    private static func semanticMatch(note: String, candidates: [TransactionCategory]) -> CategoryMatch {
        ensureEmbeddingModel()
        guard let model = embeddingModel else {
            return CategoryMatch(category: otherCategory, confidence: 0.1, source: .fallback)
        }

        precomputeEmbeddings(candidates: candidates)
        guard let cache = embeddingCache, !cache.isEmpty else {
            return CategoryMatch(category: otherCategory, confidence: 0.1, source: .fallback)
        }

        guard let noteVectorDouble = model.vector(for: note) else {
            return CategoryMatch(category: otherCategory, confidence: 0.1, source: .fallback)
        }

        let noteVector = noteVectorDouble.map { Float($0) }
        var bestSimilarity: Float = 0.0
        var bestCategory: TransactionCategory?

        for category in candidates {
            guard let categoryVector = cache[category.id] else { continue }
            let similarity = cosineSimilarity(noteVector, categoryVector)

            if similarity > bestSimilarity {
                bestSimilarity = similarity
                bestCategory = category
            }
        }

        guard let bestCategory else {
            return CategoryMatch(category: otherCategory, confidence: 0.1, source: .fallback)
        }

        if bestSimilarity < 0.35 {
            return CategoryMatch(category: otherCategory, confidence: 0.1, source: .fallback)
        }

        let confidence = Double(min(0.95, 0.6 + (bestSimilarity * 0.4)))
        return CategoryMatch(category: bestCategory, confidence: confidence, source: .semanticEmbedding)
    }

    private static func normalize(_ value: String?) -> String {
        guard let value else { return "" }

        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }

        return String(scalars)
            .split(separator: " ")
            .joined(separator: " ")
    }
}
