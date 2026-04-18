import Foundation
import XCTest
@testable import PantryKit

final class RecipeCommandResolutionTests: XCTestCase {
    func testResolveRecipePrefersUIDBeforeNameMatch() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "MATCH", name: "UID Winner", sourceFingerprint: "hash-match"),
                SourceRecipeStub(uid: "OTHER", name: "match", sourceFingerprint: "hash-other"),
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
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
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
                SourceRecipeStub(uid: "AAA", name: "Curry", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "curry", sourceFingerprint: "hash-bbb"),
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
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", sourceFingerprint: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
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
                SourceRecipeStub(uid: "AAA", name: "Favorite Five", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Favorite Four", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Unrated Favorite", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Rated Nonfavorite", sourceFingerprint: "hash-ddd"),
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

    func testListRecipesAppliesCanonicalCategoryFiltersCaseInsensitively() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Sheet Pan Salmon", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Salad", sourceFingerprint: "hash-ccc"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
                SourceRecipeCategory(uid: "CAT2", name: "Soup"),
                SourceRecipeCategory(uid: "CAT3", name: "Side"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Weeknight Soup", categories: ["CAT1", "CAT2"]),
                "BBB": makeSourceRecipe(uid: "BBB", name: "Sheet Pan Salmon", categories: ["CAT1"]),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Salad", categories: ["CAT3"]),
            ]
        )

        let listed = try BlockingAsync.run {
            try await service.listRecipes(
                filters: RecipeQueryFilters(categoryNames: [" dinner ", "SOUP"])
            )
        }

        XCTAssertEqual(listed.map(\.uid), ["AAA"])
    }

    func testListRecipesSortsByRatingThenFavoriteThenName() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Alpha", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Beta", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Gamma", sourceFingerprint: "hash-ccc"),
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

    func testListRecipesAppliesDerivedConstraintsAndFewestIngredientSort() throws {
        let service = makeRecipeReadService(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Longer", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Shorter", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Too Slow", sourceFingerprint: "hash-ccc"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Longer"),
                "BBB": makeSourceRecipe(uid: "BBB", name: "Shorter"),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Too Slow"),
            ]
        )

        let listed = try BlockingAsync.run {
            try await service.listRecipes(
                derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
                sort: .fewestIngredients,
                derivedFeaturesByUID: [
                    "AAA": RecipeDerivedFeatures(
                        uid: "AAA",
                        sourceFingerprint: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                    "BBB": RecipeDerivedFeatures(
                        uid: "BBB",
                        sourceFingerprint: "hash-bbb",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 5,
                        cookTimeMinutes: 15,
                        totalTimeMinutes: 20,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 3,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                    "CCC": RecipeDerivedFeatures(
                        uid: "CCC",
                        sourceFingerprint: "hash-ccc",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 15,
                        cookTimeMinutes: 30,
                        totalTimeMinutes: 45,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 2,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                ]
            )
        }

        XCTAssertEqual(listed.map(\.uid), ["BBB", "AAA"])
    }

    func testRecipeQueryCommandValidationRejectsInvalidRatingRanges() {
        XCTAssertThrowsError(
            try RecipesListCommand.parseAsRoot(["--min-rating", "0"])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--min-rating", "5", "--max-rating", "4"])
        )

        XCTAssertThrowsError(
            try RecipesListCommand.parseAsRoot(["--category", "  "])
        )

        XCTAssertThrowsError(
            try RecipesListCommand.parseAsRoot(["--ingredient", "  "])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--ingredient", "1 cup"])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--exclude-ingredient", "  "])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--exclude-ingredient", "1 cup"])
        )

        XCTAssertThrowsError(
            try RecipesListCommand.parseAsRoot(["--min-total-time-minutes", "40", "--max-total-time-minutes", "30"])
        )

        XCTAssertThrowsError(
            try RecipesSearchCommand.parseAsRoot(["risotto", "--max-ingredient-lines", "0"])
        )
    }

    func testRecipeQueryCommandParsingCapturesIngredientMatchAndExclusions() throws {
        let parsed = try RecipesSearchCommand.parseAsRoot([
            "risotto",
            "--ingredient", "green onions",
            "--ingredient", "basil",
            "--ingredient-match", "any",
            "--exclude-ingredient", "anchovy"
        ])
        let command = try XCTUnwrap(parsed as? RecipesSearchCommand)

        XCTAssertEqual(command.query, "risotto")
        XCTAssertEqual(command.ingredient, ["green onions", "basil"])
        XCTAssertEqual(command.excludeIngredient, ["anchovy"])
        XCTAssertEqual(command.ingredientMatch, .any)
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
            sourceFingerprint: "hash-\(uid)",
            rawJSON: #"{"uid":"test"}"#
        )
    }
}
