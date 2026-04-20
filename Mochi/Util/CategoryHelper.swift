import Foundation
import NaturalLanguage

class CategoryHelper {
    
    static let categories: [String] = [
        "Food 🍔",
        "Transport 🚗",
        "Shopping 🛍️",
        "Utilities 💡",
        "Entertainment 🎬",
        "Health 💊",
        "Travel ✈️",
        "Subscriptions 🔄",
        "Other 📦"
    ]
    
    static let categoryKeywords: [String: [String]] = [
        "Food 🍔": ["food", "dinner", "lunch", "breakfast", "groceries", "restaurant", "cafe", "coffee", "mcdonalds", "starbucks", "pizza", "burger", "subway", "snack", "drink", "bar", "pub"],
        "Transport 🚗": ["transport", "uber", "lyft", "taxi", "gas", "fuel", "train", "bus", "subway", "flight", "parking", "toll", "car", "transit"],
        "Shopping 🛍️": ["shopping", "clothes", "shoes", "amazon", "mall", "store", "gift", "electronics", "apple", "target", "walmart"],
        "Utilities 💡": ["utility", "electric", "water", "gas bill", "internet", "wifi", "phone", "mobile", "rent", "mortgage", "insurance"],
        "Entertainment 🎬": ["entertainment", "movie", "cinema", "game", "steam", "playstation", "xbox", "concert", "ticket", "club", "party"],
        "Health 💊": ["health", "medical", "doctor", "pharmacy", "medicine", "gym", "fitness", "yoga", "dental", "hospital", "clinic"],
        "Travel ✈️": ["travel", "hotel", "airbnb", "flight", "tour", "vacation", "trip", "resort"],
        "Subscriptions 🔄": ["netflix", "spotify", "apple music", "hulu", "disney", "prime", "subscription", "gym membership", "patreon"]
    ]
    
    // Automatically categorizes a note using Natural Language semantic analysis
    static func categorize(note: String?) -> String {
        guard let note = note?.lowercased(), !note.isEmpty else {
            return "Other 📦"
        }
        
        // 1. Direct Keyword Match (Fast path)
        for (category, keywords) in categoryKeywords {
            for keyword in keywords {
                if note.contains(keyword) {
                    return category
                }
            }
        }
        
        // 2. Apple On-Device ML Semantic Fallback
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            var bestDistance: Double = Double.greatestFiniteMagnitude
            var bestCategory = "Other 📦"
            
            for (category, keywords) in categoryKeywords {
                // Determine vector distance between the note and the category context
                let categoryContext = keywords.joined(separator: " ")
                let distance = embedding.distance(between: note, and: categoryContext)
                
                // Typical semantic threshold: < 1.0 is a reasonable match for NLEmbeddings
                if distance < bestDistance && distance < 1.15 {
                    bestDistance = distance
                    bestCategory = category
                }
            }
            
            if bestCategory != "Other 📦" {
                return bestCategory
            }
        }
        
        return "Other 📦"
    }
}
