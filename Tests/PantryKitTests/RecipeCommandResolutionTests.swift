import Foundation
import XCTest
@testable import PantryKit

final class RecipeCommandResolutionTests: XCTestCase {
    func testResolveRecipePrefersUIDBeforeNameMatch() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "MATCH", name: "UID Winner", hash: "hash-match"),
                SourceRecipeStub(uid: "OTHER", name: "match", hash: "hash-other"),
            ],
            recipesByUID: [
                "MATCH": makeSourceRecipe(uid: "MATCH", name: "UID Winner"),
                "OTHER": makeSourceRecipe(uid: "OTHER", name: "match"),
            ]
        )

        let resolved = try BlockingAsync.run {
            try await service.resolveRecipe(selector: "MATCH")
        }

        XCTAssertEqual(resolved.uid, "MATCH")
        XCTAssertEqual(resolved.name, "UID Winner")
    }

    func testResolveRecipeFallsBackToExactCaseInsensitiveName() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Weeknight Soup"),
            ]
        )

        let resolved = try BlockingAsync.run {
            try await service.resolveRecipe(selector: "weeknight soup")
        }

        XCTAssertEqual(resolved.uid, "AAA")
    }

    func testResolveRecipeThrowsAmbiguityErrorForDuplicateNames() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Curry", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "curry", hash: "hash-bbb"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Curry"),
                "BBB": makeSourceRecipe(uid: "BBB", name: "curry"),
            ]
        )

        XCTAssertThrowsError(
            try BlockingAsync.run {
                try await service.resolveRecipe(selector: "CURRY")
            }
        ) { error in
            guard case let RecipeReadServiceError.ambiguousRecipeName(selector, matchingUIDs) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(selector, "CURRY")
            XCTAssertEqual(matchingUIDs, ["AAA", "BBB"])
        }
    }

    func testResolveRecipeThrowsNotFoundErrorWhenSelectorMisses() {
        let service = makeRecipeReadService(stubs: [], recipesByUID: [:])

        XCTAssertThrowsError(
            try BlockingAsync.run {
                try await service.resolveRecipe(selector: "missing")
            }
        ) { error in
            guard case let RecipeReadServiceError.recipeNotFound(selector) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(selector, "missing")
        }
    }

    func testListRecipesReadsActiveRecipesFromSourceAndResolvesCategoryNames() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", hash: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
                SourceRecipeCategory(uid: "CAT2", name: "Archived", isDeleted: true),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["CAT1", "CAT2", "MISSING"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true
                ),
            ]
        )

        let listed = try BlockingAsync.run {
            try await service.listRecipes()
        }

        XCTAssertEqual(
            listed,
            [
                RecipeSummary(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner", "CAT2", "MISSING"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true,
                    updatedAt: nil
                ),
            ]
        )
    }

    private func makeRecipeReadService(
        stubs: [SourceRecipeStub],
        categories: [SourceRecipeCategory] = [],
        recipesByUID: [String: SourceRecipe]
    ) -> RecipeReadService {
        RecipeReadService(
            source: InMemoryPantrySource(
                stubs: stubs,
                categories: categories,
                recipesByUID: recipesByUID
            )
        )
    }

    private func makeSourceRecipe(
        uid: String,
        name: String,
        categories: [String] = ["CAT1"],
        sourceName: String? = nil,
        starRating: Int? = nil,
        isFavorite: Bool = false
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: name,
            categoryReferences: categories,
            sourceName: sourceName,
            ingredients: nil,
            directions: nil,
            notes: nil,
            starRating: starRating,
            isFavorite: isFavorite,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: nil,
            createdAt: nil,
            updatedAt: nil,
            remoteHash: "hash-\(uid)",
            rawJSON: #"{"uid":"test"}"#
        )
    }
}
