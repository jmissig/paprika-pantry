import Foundation
import XCTest
@testable import PantryKit

final class PantrySidecarStoreTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testRecipeIndexesRebuildSearchAndDerivedFeatures() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Pasta Salad", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Deleted", sourceFingerprint: "hash-ccc", isDeleted: true),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
                SourceRecipeCategory(uid: "CAT2", name: "Soup"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categoryReferences: ["CAT1", "CAT2"],
                    sourceName: "Serious Eats",
                    ingredients: "Broth\nBeans",
                    directions: nil,
                    notes: "Finish with lemon.",
                    starRating: 4,
                    isFavorite: true,
                    prepTime: "10 min",
                    cookTime: "20 min",
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
                "BBB": SourceRecipe(
                    uid: "BBB",
                    name: "Pasta Salad",
                    categoryReferences: ["CAT1"],
                    sourceName: "Smitten Kitchen",
                    ingredients: "Pasta\nHerbs",
                    directions: nil,
                    notes: "Good cold.",
                    starRating: 3,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-bbb",
                    rawJSON: "{}"
                ),
            ]
            ,
            meals: [
                SourceMeal(
                    uid: "MEAL1",
                    name: "Weeknight Soup",
                    scheduledAt: "2026-04-01 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                ),
                SourceMeal(
                    uid: "MEAL2",
                    name: "Weeknight Soup",
                    scheduledAt: "2026-04-07 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                ),
                SourceMeal(
                    uid: "MEAL3",
                    name: "Pasta Salad",
                    scheduledAt: nil,
                    mealType: "Lunch",
                    recipeUID: "BBB",
                    recipeName: "Pasta Salad"
                ),
                SourceMeal(
                    uid: "MEAL4",
                    name: "Loose Dinner",
                    scheduledAt: "2026-04-03 18:00:00",
                    mealType: "Dinner",
                    recipeUID: nil,
                    recipeName: nil
                ),
                SourceMeal(
                    uid: "MEAL5",
                    name: "Deleted Recipe Meal",
                    scheduledAt: "2026-04-05 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "CCC",
                    recipeName: "Deleted"
                ),
            ]
        )

        let summary = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                Date(timeIntervalSince1970: 1_712_736_000)
            }
        )

        XCTAssertEqual(summary.recipeSearchDocumentCount, 2)
        XCTAssertEqual(summary.recipeFeatureCount, 2)
        XCTAssertEqual(summary.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(summary.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertEqual(summary.recipeIngredientRecipeCount, 2)
        XCTAssertEqual(summary.recipeIngredientLineCount, 4)
        XCTAssertEqual(summary.recipeIngredientTokenCount, 4)
        XCTAssertEqual(summary.recipeUsageStatsCount, 2)
        XCTAssertEqual(summary.linkedMealCount, 3)

        let results = try store.searchRecipes(query: "lemon", limit: 20)
        XCTAssertEqual(results.map(\.uid), ["AAA"])
        XCTAssertEqual(results[0].categories, ["Dinner", "Soup"])
        XCTAssertTrue(results[0].isFavorite)

        let features = try store.fetchRecipeFeatures(uid: "AAA")
        XCTAssertEqual(features?.prepTimeMinutes, 10)
        XCTAssertEqual(features?.cookTimeMinutes, 20)
        XCTAssertEqual(features?.totalTimeMinutes, 30)
        XCTAssertEqual(features?.totalTimeBasis, .summedPrepAndCook)
        XCTAssertEqual(features?.ingredientLineCount, 2)
        XCTAssertEqual(features?.ingredientLineCountBasis, .nonEmptyLines)

        let ingredientIndex = try XCTUnwrap(store.fetchRecipeIngredientIndex(uid: "AAA"))
        XCTAssertEqual(ingredientIndex.lines.map(\.sourceText), ["Broth", "Beans"])
        XCTAssertEqual(ingredientIndex.lines.flatMap(\.normalizedTokens), ["broth", "bean"])

        let usageAAA = try XCTUnwrap(store.fetchRecipeUsageStats(uid: "AAA"))
        XCTAssertEqual(usageAAA.timesCooked, 2)
        XCTAssertEqual(usageAAA.lastCookedAt, "2026-04-07 18:00:00")

        let usageBBB = try XCTUnwrap(store.fetchRecipeUsageStats(uid: "BBB"))
        XCTAssertEqual(usageBBB.timesCooked, 1)
        XCTAssertNil(usageBBB.lastCookedAt)
        XCTAssertNil(try store.fetchRecipeUsageStats(uid: "CCC"))

        let stats = try store.indexStats()
        XCTAssertEqual(stats.recipeSearchDocumentCount, 2)
        XCTAssertEqual(stats.recipeFeatureCount, 2)
        XCTAssertEqual(stats.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(stats.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertEqual(stats.recipeIngredientRecipeCount, 2)
        XCTAssertEqual(stats.recipeIngredientLineCount, 4)
        XCTAssertEqual(stats.recipeIngredientTokenCount, 4)
        XCTAssertEqual(stats.recipeUsageStatsCount, 2)
        XCTAssertEqual(stats.recipeUsageStatsWithLastCookedCount, 1)
        XCTAssertTrue(stats.recipeSearchReady)
        XCTAssertTrue(stats.recipeFeaturesReady)
        XCTAssertTrue(stats.recipeIngredientIndexReady)
        XCTAssertTrue(stats.recipeUsageStatsReady)
        XCTAssertEqual(stats.lastRecipeSearchRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeSearchRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeIngredientRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeIngredientRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeUsageRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeUsageRun?.recipeCount, 2)
    }

    func testSearchNormalizesPlainQueriesForFTS() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Broth",
                    directions: nil,
                    notes: nil,
                    starRating: nil,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: nil,
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        XCTAssertEqual(try store.searchRecipes(query: "weeknight soup").map(\.uid), ["AAA"])
        XCTAssertEqual(try store.searchRecipes(query: "   ").count, 0)
    }

    func testSearchRecipesAppliesFavoriteAndRatingFiltersWithRatingSort() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Mushroom Risotto", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Lemon Risotto", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Tomato Risotto", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Unrated Risotto", sourceFingerprint: "hash-ddd"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Mushroom Risotto",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Rice\nMushroom",
                    directions: nil,
                    notes: "Stir often.",
                    starRating: 5,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
                "BBB": SourceRecipe(
                    uid: "BBB",
                    name: "Lemon Risotto",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Rice\nLemon",
                    directions: nil,
                    notes: "Bright finish.",
                    starRating: 5,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-bbb",
                    rawJSON: "{}"
                ),
                "CCC": SourceRecipe(
                    uid: "CCC",
                    name: "Tomato Risotto",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Rice\nTomato",
                    directions: nil,
                    notes: "Deep red.",
                    starRating: 4,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-ccc",
                    rawJSON: "{}"
                ),
                "DDD": SourceRecipe(
                    uid: "DDD",
                    name: "Unrated Risotto",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Rice",
                    directions: nil,
                    notes: "No rating yet.",
                    starRating: nil,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-ddd",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let favoriteResults = try store.searchRecipes(
            query: "risotto",
            filters: RecipeQueryFilters(favoritesOnly: true, minRating: 4),
            sort: .rating,
            limit: 20
        )
        XCTAssertEqual(favoriteResults.map(\.uid), ["AAA", "CCC"])

        let exactRatingResults = try store.searchRecipes(
            query: "risotto",
            filters: RecipeQueryFilters(minRating: 5, maxRating: 5),
            sort: .rating,
            limit: 20
        )
        XCTAssertEqual(exactRatingResults.map(\.uid), ["AAA", "BBB"])
    }

    func testSearchRecipesSupportsUsageAwareRankingAndTimesCookedSort() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Soup", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Tomato Soup", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Tomato Soup", sourceFingerprint: "hash-ccc"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeSourceRecipeForUsageTest(uid: "AAA", name: "Tomato Soup", starRating: 4, isFavorite: false),
                "BBB": makeSourceRecipeForUsageTest(uid: "BBB", name: "Tomato Soup", starRating: 5, isFavorite: false),
                "CCC": makeSourceRecipeForUsageTest(uid: "CCC", name: "Tomato Soup", starRating: 5, isFavorite: true),
            ],
            meals: [
                SourceMeal(uid: "MEAL1", name: "Tomato Soup", scheduledAt: "2026-04-01 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Soup"),
                SourceMeal(uid: "MEAL2", name: "Tomato Soup", scheduledAt: "2026-04-02 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Soup"),
                SourceMeal(uid: "MEAL3", name: "Tomato Soup", scheduledAt: "2026-04-03 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Soup"),
                SourceMeal(uid: "MEAL4", name: "Tomato Soup", scheduledAt: "2026-04-04 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Tomato Soup"),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let relevanceResults = try store.searchRecipes(
            query: "tomato soup",
            sort: .relevance,
            limit: 20
        )
        XCTAssertEqual(relevanceResults.map(\.uid), ["AAA", "BBB", "CCC"])
        XCTAssertEqual(relevanceResults[0].usageStats?.timesCooked, 3)
        XCTAssertEqual(relevanceResults[1].usageStats?.timesCooked, 1)
        XCTAssertNil(relevanceResults[2].usageStats)

        let usageResults = try store.searchRecipes(
            query: "tomato soup",
            sort: .timesCooked,
            limit: 20
        )
        XCTAssertEqual(usageResults.map(\.uid), ["AAA", "BBB", "CCC"])
    }

    func testIngredientNormalizationIndexesConservativeTokensPerLine() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Salad", sourceFingerprint: "hash-aaa"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Tomato Salad",
                    categoryReferences: [],
                    sourceName: nil,
                    ingredients: """
                    1 (14-ounce) can diced tomatoes, drained
                    2 cups fresh basil leaves, roughly chopped
                    kosher salt, to taste
                    """,
                    directions: nil,
                    notes: nil,
                    starRating: nil,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let ingredientIndex = try XCTUnwrap(store.fetchRecipeIngredientIndex(uid: "AAA"))
        XCTAssertEqual(ingredientIndex.lines.count, 3)
        XCTAssertEqual(ingredientIndex.lines[0].sourceText, "1 (14-ounce) can diced tomatoes, drained")
        XCTAssertEqual(ingredientIndex.lines[0].normalizedTokens, ["tomato"])
        XCTAssertEqual(ingredientIndex.lines[1].normalizedTokens, ["fresh", "basil", "leaves"])
        XCTAssertEqual(ingredientIndex.lines[2].normalizedTokens, ["kosher", "salt"])
    }

    func testListCookbookAggregatesGroupsTrimmedSourceNamesAndUnlabeledRows() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Soup A", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Soup B", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Soup C", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Soup D", sourceFingerprint: "hash-ddd"),
                SourceRecipeStub(uid: "EEE", name: "Soup E", sourceFingerprint: "hash-eee"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForAggregate(uid: "AAA", sourceName: " Serious Eats ", starRating: 5, isFavorite: true),
                "BBB": makeRecipeForAggregate(uid: "BBB", sourceName: "Serious Eats", starRating: 4, isFavorite: false),
                "CCC": makeRecipeForAggregate(uid: "CCC", sourceName: nil, starRating: nil, isFavorite: true),
                "DDD": makeRecipeForAggregate(uid: "DDD", sourceName: "   ", starRating: 3, isFavorite: false),
                "EEE": makeRecipeForAggregate(uid: "EEE", sourceName: "Smitten Kitchen", starRating: 5, isFavorite: true),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let aggregates = try store.listCookbookAggregates(sort: .name, limit: 20)

        XCTAssertEqual(aggregates.count, 3)
        XCTAssertEqual(aggregates[0].sourceName, "Serious Eats")
        XCTAssertFalse(aggregates[0].isUnlabeled)
        XCTAssertEqual(aggregates[0].recipeCount, 2)
        XCTAssertEqual(aggregates[0].ratedRecipeCount, 2)
        XCTAssertEqual(aggregates[0].favoriteRecipeCount, 1)
        XCTAssertEqual(try XCTUnwrap(aggregates[0].averageStarRating), 4.5, accuracy: 0.001)
        XCTAssertEqual(aggregates[0].ratingDistribution.fiveStarCount, 1)
        XCTAssertEqual(aggregates[0].ratingDistribution.fourStarCount, 1)

        XCTAssertEqual(aggregates[1].sourceName, "Smitten Kitchen")
        XCTAssertEqual(aggregates[1].recipeCount, 1)
        XCTAssertEqual(aggregates[1].ratedRecipeCount, 1)
        XCTAssertEqual(aggregates[1].favoriteRecipeCount, 1)

        XCTAssertNil(aggregates[2].sourceName)
        XCTAssertTrue(aggregates[2].isUnlabeled)
        XCTAssertEqual(aggregates[2].recipeCount, 2)
        XCTAssertEqual(aggregates[2].ratedRecipeCount, 1)
        XCTAssertEqual(aggregates[2].unratedRecipeCount, 1)
        XCTAssertEqual(aggregates[2].favoriteRecipeCount, 1)
        XCTAssertEqual(try XCTUnwrap(aggregates[2].averageStarRating), 3.0, accuracy: 0.001)
        XCTAssertEqual(aggregates[2].ratingDistribution.threeStarCount, 1)
    }

    func testListCookbookAggregatesSupportsMinimumRatedRecipesAndAverageRatingSort() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "A", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "B", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "C", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "D", sourceFingerprint: "hash-ddd"),
                SourceRecipeStub(uid: "EEE", name: "E", sourceFingerprint: "hash-eee"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForAggregate(uid: "AAA", sourceName: "Alpha", starRating: 5, isFavorite: true),
                "BBB": makeRecipeForAggregate(uid: "BBB", sourceName: "Alpha", starRating: 4, isFavorite: false),
                "CCC": makeRecipeForAggregate(uid: "CCC", sourceName: "Beta", starRating: 5, isFavorite: true),
                "DDD": makeRecipeForAggregate(uid: "DDD", sourceName: "Gamma", starRating: nil, isFavorite: false),
                "EEE": makeRecipeForAggregate(uid: "EEE", sourceName: "Gamma", starRating: nil, isFavorite: true),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let aggregates = try store.listCookbookAggregates(
            sort: .averageRating,
            limit: 20,
            minRecipeCount: 1,
            minRatedRecipeCount: 1
        )

        XCTAssertEqual(aggregates.map(\.sourceName), ["Beta", "Alpha"])
        XCTAssertEqual(aggregates[0].ratedRecipeCount, 1)
        XCTAssertEqual(try XCTUnwrap(aggregates[0].averageStarRating), 5.0, accuracy: 0.001)
        XCTAssertEqual(aggregates[1].ratedRecipeCount, 2)
        XCTAssertEqual(try XCTUnwrap(aggregates[1].averageStarRating), 4.5, accuracy: 0.001)
    }

    func testSearchRecipesAppliesCanonicalCategoryFiltersAfterFTSMatch() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Tomato Soup", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Weeknight Salad", sourceFingerprint: "hash-ccc"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
                SourceRecipeCategory(uid: "CAT2", name: "Soup"),
                SourceRecipeCategory(uid: "CAT3", name: "Side"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categoryReferences: ["CAT1", "CAT2"],
                    sourceName: nil,
                    ingredients: "Broth",
                    directions: nil,
                    notes: "Lemon finish.",
                    starRating: 4,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
                "BBB": SourceRecipe(
                    uid: "BBB",
                    name: "Tomato Soup",
                    categoryReferences: ["CAT2"],
                    sourceName: nil,
                    ingredients: "Tomato",
                    directions: nil,
                    notes: "Weeknight easy.",
                    starRating: 5,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-bbb",
                    rawJSON: "{}"
                ),
                "CCC": SourceRecipe(
                    uid: "CCC",
                    name: "Weeknight Salad",
                    categoryReferences: ["CAT3"],
                    sourceName: nil,
                    ingredients: "Lettuce",
                    directions: nil,
                    notes: nil,
                    starRating: 3,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-ccc",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let dinnerSoupResults = try store.searchRecipes(
            query: "weeknight",
            filters: RecipeQueryFilters(categoryNames: [" dinner ", "SOUP"]),
            sort: .rating,
            limit: 20
        )
        XCTAssertEqual(dinnerSoupResults.map(\.uid), ["AAA"])

        let sideResults = try store.searchRecipes(
            query: "weeknight",
            filters: RecipeQueryFilters(categoryNames: ["side"]),
            sort: .name,
            limit: 20
        )
        XCTAssertEqual(sideResults.map(\.uid), ["CCC"])
    }

    func testSearchRecipesAppliesIngredientTokenFilter() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Pasta", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Lemon Pasta", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Green Salad", sourceFingerprint: "hash-ccc"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Tomato Pasta",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Pasta\nTomatoes\nBasil",
                    directions: nil,
                    notes: "Weeknight favorite.",
                    starRating: 5,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
                "BBB": SourceRecipe(
                    uid: "BBB",
                    name: "Lemon Pasta",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Pasta\nLemon\nButter",
                    directions: nil,
                    notes: "Weeknight bright.",
                    starRating: 4,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-bbb",
                    rawJSON: "{}"
                ),
                "CCC": SourceRecipe(
                    uid: "CCC",
                    name: "Green Salad",
                    categoryReferences: ["CAT1"],
                    sourceName: nil,
                    ingredients: "Lettuce\nTomatoes\nCucumber",
                    directions: nil,
                    notes: "Fresh side.",
                    starRating: 3,
                    isFavorite: false,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-ccc",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let tomatoResults = try store.searchRecipes(
            query: "weeknight pasta",
            ingredientFilter: RecipeIngredientFilter(rawTerms: ["tomatoes"]),
            sort: .rating,
            limit: 20
        )
        XCTAssertEqual(tomatoResults.map(\.uid), ["AAA"])

        let pastaAndTomatoUIDs = try store.matchingRecipeUIDs(
            for: RecipeIngredientFilter(rawTerms: ["pasta", "tomato"])
        )
        XCTAssertEqual(pastaAndTomatoUIDs, Set(["AAA"]))

        let pastaOrTomatoUIDs = try store.matchingRecipeUIDs(
            for: RecipeIngredientFilter(
                rawTerms: ["pasta", "tomato"],
                includeMode: .any
            )
        )
        XCTAssertEqual(pastaOrTomatoUIDs, Set(["AAA", "BBB", "CCC"]))

        let pastaResults = try store.searchRecipes(
            query: "pasta",
            ingredientFilter: RecipeIngredientFilter(
                rawTerms: ["pasta", "tomato"],
                includeMode: .any
            ),
            sort: .rating,
            limit: 20
        )
        XCTAssertEqual(pastaResults.map(\.uid), ["AAA", "BBB"])

        let tomatoWithoutPastaUIDs = try store.matchingRecipeUIDs(
            for: RecipeIngredientFilter(
                rawTerms: ["tomato"],
                excludeRawTerms: ["pasta"]
            )
        )
        XCTAssertEqual(tomatoWithoutPastaUIDs, Set(["CCC"]))
    }

    func testDerivedFeaturesPreferSourceTotalTimeWhenAvailable() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Braise", sourceFingerprint: "hash-aaa"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Braise",
                    categoryReferences: [],
                    sourceName: nil,
                    ingredients: "\nBeef\n\nOnion\n",
                    directions: nil,
                    notes: nil,
                    starRating: nil,
                    isFavorite: false,
                    prepTime: "15 min",
                    cookTime: "1 hr",
                    totalTime: "1 hr 10 min",
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let features = try XCTUnwrap(store.fetchRecipeFeatures(uid: "AAA"))
        XCTAssertEqual(features.prepTimeMinutes, 15)
        XCTAssertEqual(features.cookTimeMinutes, 60)
        XCTAssertEqual(features.totalTimeMinutes, 70)
        XCTAssertEqual(features.totalTimeBasis, .sourceTotalTime)
        XCTAssertEqual(features.ingredientLineCount, 2)
    }

    func testSearchRecipesAppliesDerivedConstraintsAndFewestIngredientSort() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Quick Bean Soup", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Quick Tomato Soup", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Slow Tomato Soup", sourceFingerprint: "hash-ccc"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
                SourceRecipeCategory(uid: "CAT2", name: "Soup"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Quick Bean Soup",
                    categoryReferences: ["CAT1", "CAT2"],
                    sourceName: nil,
                    ingredients: "Beans\nBroth\nLemon",
                    directions: nil,
                    notes: "Weeknight fast.",
                    starRating: 4,
                    isFavorite: true,
                    prepTime: "10 min",
                    cookTime: "15 min",
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-aaa",
                    rawJSON: "{}"
                ),
                "BBB": SourceRecipe(
                    uid: "BBB",
                    name: "Quick Tomato Soup",
                    categoryReferences: ["CAT1", "CAT2"],
                    sourceName: nil,
                    ingredients: "Tomato\nBroth",
                    directions: nil,
                    notes: "Weeknight easy.",
                    starRating: 5,
                    isFavorite: false,
                    prepTime: "5 min",
                    cookTime: "15 min",
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-bbb",
                    rawJSON: "{}"
                ),
                "CCC": SourceRecipe(
                    uid: "CCC",
                    name: "Slow Tomato Soup",
                    categoryReferences: ["CAT1", "CAT2"],
                    sourceName: nil,
                    ingredients: "Tomato\nBroth\nCream",
                    directions: nil,
                    notes: "Still weeknight, but slower.",
                    starRating: 5,
                    isFavorite: true,
                    prepTime: "20 min",
                    cookTime: "25 min",
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: nil,
                    sourceFingerprint: "hash-ccc",
                    rawJSON: "{}"
                ),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(from: source)

        let results = try store.searchRecipes(
            query: "weeknight soup",
            filters: RecipeQueryFilters(categoryNames: ["soup"]),
            derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
            sort: .fewestIngredients,
            limit: 20
        )

        XCTAssertEqual(results.map(\.uid), ["BBB", "AAA"])
        XCTAssertEqual(results[0].derivedFeatures?.ingredientLineCount, 2)
        XCTAssertEqual(results[0].derivedFeatures?.totalTimeMinutes, 20)
        XCTAssertEqual(results[1].derivedFeatures?.ingredientLineCount, 3)
        XCTAssertEqual(results[1].derivedFeatures?.totalTimeMinutes, 25)
    }

    private func makeDatabase() throws -> PantrySidecarDatabase {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        return PantrySidecarDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
    }

    private func makeStore() throws -> PantrySidecarStore {
        let database = try makeDatabase()
        return PantrySidecarStore(dbQueue: try database.openQueue())
    }

    private func makeRecipeForAggregate(
        uid: String,
        sourceName: String?,
        starRating: Int?,
        isFavorite: Bool
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: uid,
            categoryReferences: [],
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
            rawJSON: "{}"
        )
    }

    private func makeSourceRecipeForUsageTest(
        uid: String,
        name: String,
        starRating: Int?,
        isFavorite: Bool
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: name,
            categoryReferences: [],
            sourceName: nil,
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
            rawJSON: "{}"
        )
    }
}
