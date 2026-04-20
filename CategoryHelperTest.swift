import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, *)
@Generable
enum MochiCategory: String, CaseIterable {
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

@available(iOS 18.0, macOS 15.0, *)
func testAI(input: String) async {
    let session = LanguageModelSession()
    let prompt = "Categorize this transaction note into one of the MochiCategory options: '\(input)'"
    do {
        let result = try await session.respond(to: prompt, generating: MochiCategory.self)
        print(result)
    } catch {
        print(error)
    }
}
#endif
