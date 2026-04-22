//
//  MochiTests.swift
//  MochiTests
//
//  Created by Harsha on 16/02/26.
//

import Testing
@testable import Mochi
#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
struct MochiTests {

    @Test func categorizesCommonMerchantNotes() async throws {
        #expect(CategoryHelper.categorize(note: "Uber to airport") == "Transport 🚗")
        #expect(CategoryHelper.categorize(note: "Netflix monthly plan") == "Subscriptions 🔄")
        #expect(CategoryHelper.categorize(note: "Swiggy dinner") == "Food 🍔")
        #expect(CategoryHelper.categorize(note: "chemist medicine") == "Health 💊")
        #expect(CategoryHelper.categorize(note: "electricity bill") == "Utilities 💡")
    }

    @Test func leavesUnknownNotesAsOther() async throws {
        #expect(CategoryHelper.categorize(note: "qzxv plorb") == "Other 📦")
        #expect(CategoryHelper.categorize(note: nil) == "Other 📦")
    }

    @Test func backfillsMissingAndOtherCategoriesFromNotes() async throws {
        let missingCategory = Item(amount: 12, note: "Zomato lunch")
        let otherCategory = Item(amount: 8, note: "Spotify renewal", category: "Other 📦")
        let existingUserCategory = Item(amount: 20, note: "Uber ride", category: "Shopping 🛍️")

        let updatedCount = CategoryHelper.backfill(items: [missingCategory, otherCategory, existingUserCategory])

        #expect(updatedCount == 2)
        #expect(missingCategory.category == "Food 🍔")
        #expect(otherCategory.category == "Subscriptions 🔄")
        #expect(existingUserCategory.category == "Shopping 🛍️")
    }

    @Test func resolvesCleanDisplayMetadataForLegacyValues() async throws {
        #expect(CategoryHelper.displayName(for: "Food 🍔") == "Food")
        #expect(CategoryHelper.symbolName(for: "Subscriptions 🔄") == "arrow.triangle.2.circlepath")
        #expect(CategoryHelper.storageValue(for: "food") == "Food 🍔")
    }

    @Test func languageModelCategorizesMatchaWhenAvailable() async throws {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .contentTagging)
            guard model.isAvailable else { return }

            #expect(await CategoryHelper.categorizeSmart(note: "matcha") == "Food 🍔")
        }
        #endif
    }

}
