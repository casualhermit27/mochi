import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 18.0, macOS 15.0, *)
@Generable
enum MochiTestMacro: String, CaseIterable {
    case food = "Food 🍔"
}
#endif
