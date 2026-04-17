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

    func testListRecipesAppliesCanonicalRatingAndFavoriteFilters() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Favorite Five", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Favorite Four", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Unrated Favorite", hash: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Rated Nonfavorite", hash: "hash-ddd"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Favorite Five", starRating: 5, isFavorite: true),
                "BBB": makeSourceRecipe(uid: "BBB", name: "Favorite Four", starRating: 4, isFavorite: true),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Unrated Favorite", starRating: nil, isFavorite: true),
                "DDD": makeSourceRecipe(uid: "DDD", name: "Rated Nonfavorite", starRating: 5, isFavorite: false),
            ]
        )

        let listed = try BlockingAsync.run {
            try await service.listRecipes(
                filters: RecipeQueryFilters(favoritesOnly: true, minRating: 4),
                sort: .rating
            )
        }

        XCTAssertEqual(listed.map(\.uid), ["AAA", "BBB"])
    }

    func testListRecipesSortsByRatingThenFavoriteThenName() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Alpha", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Beta", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Gamma", hash: "hash-ccc"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Alpha", starRating: 5, isFavorite: false),
                "BBB": makeSourceRecipe(uid: "BBB", name: "Beta", starRating: 5, isFavorite: true),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Gamma", starRating: 4, isFavorite: true),
            ]
        )

        let listed = try BlockingAsync.run {
            try await service.listRecipes(sort: .rating)
        }

        XCTAssertEqual(listed.map(\.uid), ["BBB", "AAA", "CCC"])
    }

    func testRecipeQueryCommandValidationRejectsInvalidRatingRanges() {
        XCTAssertThrowsError(
            try RecipesListCommand.parseAsRoot(["--min-rating", "0"])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--min-rating", "5", "--max-rating", "4"])
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
