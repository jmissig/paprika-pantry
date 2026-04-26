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
        let referenceDate = mealHistoryReferenceDate()
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
                SourceMeal(
                    uid: "MEAL6",
                    name: "Future Weeknight Soup",
                    scheduledAt: "2026-04-15 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                ),
                SourceMeal(
                    uid: "MEAL7",
                    name: "Deleted Meal",
                    scheduledAt: "2026-04-06 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup",
                    isDeleted: true
                ),
            ]
        )

        let summary = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        XCTAssertEqual(summary.recipeSearchDocumentCount, 2)
        XCTAssertEqual(summary.recipeFeatureCount, 2)
        XCTAssertEqual(summary.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(summary.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertEqual(summary.recipeIngredientRecipeCount, 2)
        XCTAssertEqual(summary.recipeIngredientLineCount, 4)
        XCTAssertEqual(summary.recipeIngredientTokenCount, 4)
        XCTAssertEqual(summary.recipeUsageStatsCount, 1)
        XCTAssertEqual(summary.linkedMealCount, 2)

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
        XCTAssertEqual(usageAAA.mealCount, 2)
        XCTAssertEqual(usageAAA.firstMealAt, "2026-04-01 18:00:00")
        XCTAssertEqual(usageAAA.lastMealAt, "2026-04-07 18:00:00")
        XCTAssertEqual(usageAAA.mealGapDays, [6])
        XCTAssertEqual(usageAAA.daysSpannedByMeals, 6)
        XCTAssertEqual(try XCTUnwrap(usageAAA.medianMealGapDays), 6.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(usageAAA.mealShare), 0.5, accuracy: 0.001)

        XCTAssertNil(try store.fetchRecipeUsageStats(uid: "BBB"))
        XCTAssertNil(try store.fetchRecipeUsageStats(uid: "CCC"))

        let totalMealCount = try await store.dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT total_meal_count
                FROM recipe_usage_summary
                WHERE summary_key = 'current'
                """
            )
        }
        XCTAssertEqual(totalMealCount, 4)

        let stats = try store.indexStats()
        XCTAssertEqual(stats.recipeSearchDocumentCount, 2)
        XCTAssertEqual(stats.recipeFeatureCount, 2)
        XCTAssertEqual(stats.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(stats.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertEqual(stats.recipeIngredientRecipeCount, 2)
        XCTAssertEqual(stats.recipeIngredientLineCount, 4)
        XCTAssertEqual(stats.recipeIngredientTokenCount, 4)
        XCTAssertEqual(stats.recipeUsageStatsCount, 1)
        XCTAssertEqual(stats.recipeUsageStatsWithLastMealAtCount, 1)
        XCTAssertEqual(stats.recipeUsageStatsWithGapArrayCount, 1)
        XCTAssertEqual(stats.recipeUsageTotalMealCount, 4)
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
        XCTAssertEqual(stats.lastRecipeUsageRun?.recipeCount, 1)
    }

    func testRecipeIndexesRebuildDerivesOrderedMealHistoryFactsAndMedian() async throws {
        let store = try makeStore()
        let referenceDate = mealHistoryReferenceDate()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Soup A", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Soup B", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Soup C", sourceFingerprint: "hash-ccc"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeSourceRecipeForUsageTest(uid: "AAA", name: "Soup A", starRating: 5, isFavorite: true),
                "BBB": makeSourceRecipeForUsageTest(uid: "BBB", name: "Soup B", starRating: 4, isFavorite: false),
                "CCC": makeSourceRecipeForUsageTest(uid: "CCC", name: "Soup C", starRating: 3, isFavorite: false),
            ],
            meals: [
                SourceMeal(uid: "M1", name: "Soup A", scheduledAt: "2026-04-05 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M2", name: "Soup A", scheduledAt: "2026-04-01 12:00:00", mealType: "Lunch", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M3", name: "Soup A", scheduledAt: "2026-04-01 20:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M4", name: "Soup A", scheduledAt: "2026-04-03 12:00:00", mealType: "Lunch", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M5", name: "Soup B", scheduledAt: "2026-04-02 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Soup B"),
                SourceMeal(uid: "M6", name: "Soup B", scheduledAt: "2026-04-02 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Soup B"),
                SourceMeal(uid: "M7", name: "Soup B", scheduledAt: "2026-04-06 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Soup B"),
                SourceMeal(uid: "M8", name: "Soup C", scheduledAt: "2026-04-04 18:00:00", mealType: "Dinner", recipeUID: "CCC", recipeName: "Soup C"),
                SourceMeal(uid: "M9", name: "Loose Dinner", scheduledAt: "2026-04-07 18:00:00", mealType: "Dinner", recipeUID: nil, recipeName: nil),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        let usageAAA = try XCTUnwrap(store.fetchRecipeUsageStats(uid: "AAA"))
        XCTAssertEqual(usageAAA.mealCount, 4)
        XCTAssertEqual(usageAAA.firstMealAt, "2026-04-01 12:00:00")
        XCTAssertEqual(usageAAA.lastMealAt, "2026-04-05 18:00:00")
        XCTAssertEqual(usageAAA.mealGapDays, [0, 2, 2])
        XCTAssertEqual(usageAAA.daysSpannedByMeals, 4)
        XCTAssertEqual(try XCTUnwrap(usageAAA.medianMealGapDays), 2.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(usageAAA.mealShare), 4.0 / 9.0, accuracy: 0.0001)

        let usageBBB = try XCTUnwrap(store.fetchRecipeUsageStats(uid: "BBB"))
        XCTAssertEqual(usageBBB.mealCount, 3)
        XCTAssertEqual(usageBBB.mealGapDays, [0, 4])
        XCTAssertEqual(usageBBB.daysSpannedByMeals, 4)
        XCTAssertEqual(try XCTUnwrap(usageBBB.medianMealGapDays), 2.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(usageBBB.mealShare), 3.0 / 9.0, accuracy: 0.0001)

        let usageCCC = try XCTUnwrap(store.fetchRecipeUsageStats(uid: "CCC"))
        XCTAssertEqual(usageCCC.mealCount, 1)
        XCTAssertEqual(usageCCC.firstMealAt, "2026-04-04 18:00:00")
        XCTAssertEqual(usageCCC.lastMealAt, "2026-04-04 18:00:00")
        XCTAssertNil(usageCCC.mealGapDays)
        XCTAssertNil(usageCCC.daysSpannedByMeals)
        XCTAssertNil(usageCCC.medianMealGapDays)
        XCTAssertEqual(try XCTUnwrap(usageCCC.mealShare), 1.0 / 9.0, accuracy: 0.0001)
    }

    func testRecipeIndexesRebuildPersistsTotalMealCountWithoutLinkedUsageRows() async throws {
        let store = try makeStore()
        let referenceDate = mealHistoryReferenceDate()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Soup A", sourceFingerprint: "hash-aaa"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeSourceRecipeForUsageTest(uid: "AAA", name: "Soup A", starRating: nil, isFavorite: false),
            ],
            meals: [
                SourceMeal(uid: "M1", name: "Loose Dinner", scheduledAt: "2026-04-07 18:00:00", mealType: "Dinner", recipeUID: nil, recipeName: nil),
                SourceMeal(uid: "M2", name: "Future Dinner", scheduledAt: "2026-04-15 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M3", name: "Undated Dinner", scheduledAt: nil, mealType: "Dinner", recipeUID: "AAA", recipeName: "Soup A"),
                SourceMeal(uid: "M4", name: "Deleted Dinner", scheduledAt: "2026-04-06 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Soup A", isDeleted: true),
            ]
        )

        let summary = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        XCTAssertEqual(summary.recipeUsageStatsCount, 0)
        XCTAssertEqual(summary.linkedMealCount, 0)
        XCTAssertNil(try store.fetchRecipeUsageStats(uid: "AAA"))

        let totalMealCount = try await store.dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                SELECT total_meal_count
                FROM recipe_usage_summary
                WHERE summary_key = 'current'
                """
            )
        }
        XCTAssertEqual(totalMealCount, 1)
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
        XCTAssertEqual(relevanceResults[0].usageStats?.mealCount, 3)
        XCTAssertEqual(relevanceResults[1].usageStats?.mealCount, 1)
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

    func testIngredientPairEvidenceDerivesUnorderedPairsWithProvenanceAndAggregates() async throws {
        let store = try makeStore()
        let referenceDate = mealHistoryReferenceDate()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Basil Pasta", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Creamy Tomato Soup", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Tomato Cream Sauce", sourceFingerprint: "hash-ccc"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForPairEvidence(
                    uid: "AAA",
                    name: "Tomato Basil Pasta",
                    ingredients: "Tomatoes\nTomato paste\nBasil",
                    starRating: 5,
                    isFavorite: true
                ),
                "BBB": makeRecipeForPairEvidence(
                    uid: "BBB",
                    name: "Creamy Tomato Soup",
                    ingredients: "Tomato\nBasil\nCream",
                    starRating: 4,
                    isFavorite: false
                ),
                "CCC": makeRecipeForPairEvidence(
                    uid: "CCC",
                    name: "Tomato Cream Sauce",
                    ingredients: "Tomato\nCream",
                    starRating: nil,
                    isFavorite: true
                ),
            ],
            meals: [
                SourceMeal(uid: "M1", name: "A", scheduledAt: "2026-04-01 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Basil Pasta"),
                SourceMeal(uid: "M2", name: "A", scheduledAt: "2026-04-07 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Basil Pasta"),
                SourceMeal(uid: "M3", name: "B", scheduledAt: "2026-04-03 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Creamy Tomato Soup"),
            ]
        )

        let summary = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        XCTAssertEqual(summary.ingredientPairSummaryCount, 5)
        XCTAssertEqual(summary.ingredientPairRecipeEvidenceCount, 7)

        let stats = try store.indexStats()
        XCTAssertTrue(stats.ingredientPairEvidenceReady)
        XCTAssertEqual(stats.ingredientPairSummaryCount, 5)
        XCTAssertEqual(stats.ingredientPairRecipeEvidenceCount, 7)
        XCTAssertEqual(stats.lastIngredientPairRun?.status, .success)
        XCTAssertEqual(stats.lastIngredientPairRun?.recipeCount, 5)

        let allPairs = try store.listIngredientPairEvidence(sort: .name, limit: 20, evidenceLimit: 10)
        XCTAssertEqual(allPairs.map { "\($0.tokenA)+\($0.tokenB)" }, [
            "basil+cream",
            "basil+paste",
            "basil+tomato",
            "cream+tomato",
            "paste+tomato",
        ])
        XCTAssertFalse(allPairs.contains { $0.tokenA == $0.tokenB })

        let basilTomato = try XCTUnwrap(allPairs.first { $0.tokenA == "basil" && $0.tokenB == "tomato" })
        XCTAssertEqual(basilTomato.basis, PantrySidecarStore.ingredientPairEvidenceBasis)
        XCTAssertEqual(basilTomato.recipeCount, 2)
        XCTAssertEqual(basilTomato.cookedRecipeCount, 2)
        XCTAssertEqual(basilTomato.cookedMealCount, 3)
        XCTAssertEqual(basilTomato.favoriteRecipeCount, 1)
        XCTAssertEqual(basilTomato.ratedRecipeCount, 2)
        XCTAssertEqual(try XCTUnwrap(basilTomato.averageStarRating), 4.5, accuracy: 0.001)
        XCTAssertEqual(basilTomato.firstMealAt, "2026-04-01 18:00:00")
        XCTAssertEqual(basilTomato.lastMealAt, "2026-04-07 18:00:00")

        let aaaEvidence = try XCTUnwrap(basilTomato.recipeEvidence.first { $0.recipeUID == "AAA" })
        XCTAssertEqual(aaaEvidence.tokenALineNumbers, [3])
        XCTAssertEqual(aaaEvidence.tokenBLineNumbers, [1, 2])
        XCTAssertEqual(aaaEvidence.mealCount, 2)
        XCTAssertEqual(aaaEvidence.starRating, 5)
        XCTAssertTrue(aaaEvidence.isFavorite)
    }

    func testIngredientPairEvidenceQueryFiltersSortsAndLimits() async throws {
        let store = try makeStore()
        let referenceDate = mealHistoryReferenceDate()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Basil Pasta", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Creamy Tomato Soup", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Tomato Cream Sauce", sourceFingerprint: "hash-ccc"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForPairEvidence(uid: "AAA", name: "Tomato Basil Pasta", ingredients: "Tomatoes\nTomato paste\nBasil", starRating: 5, isFavorite: true),
                "BBB": makeRecipeForPairEvidence(uid: "BBB", name: "Creamy Tomato Soup", ingredients: "Tomato\nBasil\nCream", starRating: 4, isFavorite: false),
                "CCC": makeRecipeForPairEvidence(uid: "CCC", name: "Tomato Cream Sauce", ingredients: "Tomato\nCream", starRating: nil, isFavorite: true),
            ],
            meals: [
                SourceMeal(uid: "M1", name: "A", scheduledAt: "2026-04-01 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Basil Pasta"),
                SourceMeal(uid: "M2", name: "A", scheduledAt: "2026-04-07 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "Tomato Basil Pasta"),
                SourceMeal(uid: "M3", name: "B", scheduledAt: "2026-04-03 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "Creamy Tomato Soup"),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        let tomatoPairs = try store.listIngredientPairEvidence(token: "tomatoes", minRecipes: 2, sort: .meals, limit: 10, evidenceLimit: 1)
        XCTAssertEqual(tomatoPairs.map { "\($0.tokenA)+\($0.tokenB)" }, ["basil+tomato", "cream+tomato"])
        XCTAssertEqual(tomatoPairs[0].recipeEvidence.count, 1)
        XCTAssertEqual(tomatoPairs[0].recipeEvidence[0].recipeUID, "AAA")

        let exactPair = try store.listIngredientPairEvidence(token: "basil", withToken: "tomatoes", sort: .name, limit: 10, evidenceLimit: 10)
        XCTAssertEqual(exactPair.map { "\($0.tokenA)+\($0.tokenB)" }, ["basil+tomato"])

        let ratingSorted = try store.listIngredientPairEvidence(sort: .rating, limit: 2, evidenceLimit: 0)
        XCTAssertEqual(ratingSorted.map { "\($0.tokenA)+\($0.tokenB)" }, ["basil+paste", "paste+tomato"])
        XCTAssertTrue(ratingSorted.allSatisfy(\.recipeEvidence.isEmpty))
    }

    func testIndexUpdateSkipsAndPreservesIngredientPairEvidence() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Basil Pasta", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Creamy Tomato Soup", sourceFingerprint: "hash-bbb"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForPairEvidence(uid: "AAA", name: "Tomato Basil Pasta", ingredients: "Tomato\nBasil", starRating: 5, isFavorite: true),
                "BBB": makeRecipeForPairEvidence(uid: "BBB", name: "Creamy Tomato Soup", ingredients: "Tomato\nBasil\nCream", starRating: 4, isFavorite: false),
            ],
            meals: []
        )

        _ = try await store.rebuildRecipeIndexes(from: source)
        let initialStats = try store.indexStats()
        XCTAssertTrue(initialStats.ingredientPairEvidenceReady)
        XCTAssertEqual(initialStats.ingredientPairSummaryCount, 3)
        let initialPairRunID = initialStats.lastIngredientPairRun?.id

        let updateSource = InMemoryPantrySource(
            stubs: [SourceRecipeStub(uid: "DDD", name: "Solo Salt", sourceFingerprint: "hash-ddd")],
            categories: [],
            recipesByUID: [
                "DDD": makeRecipeForPairEvidence(uid: "DDD", name: "Solo Salt", ingredients: "Salt", starRating: nil, isFavorite: false),
            ],
            meals: []
        )
        let updateSummary = try await store.rebuildRecipeIndexes(from: updateSource, refreshIngredientPairEvidence: false)

        XCTAssertFalse(updateSummary.refreshedIngredientPairEvidence)
        XCTAssertEqual(updateSummary.ingredientPairSummaryCount, 0)
        XCTAssertEqual(updateSummary.recipeSearchDocumentCount, 1)

        let updatedStats = try store.indexStats()
        XCTAssertEqual(updatedStats.recipeSearchDocumentCount, 1)
        XCTAssertEqual(updatedStats.ingredientPairSummaryCount, initialStats.ingredientPairSummaryCount)
        XCTAssertEqual(updatedStats.ingredientPairRecipeEvidenceCount, initialStats.ingredientPairRecipeEvidenceCount)
        XCTAssertEqual(updatedStats.lastIngredientPairRun?.id, initialPairRunID)
        XCTAssertEqual(try store.listIngredientPairEvidence(token: "tomato", withToken: "basil").first?.recipeCount, 2)
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
        XCTAssertEqual(aggregates[0].usedRecipeCount, 0)
        XCTAssertEqual(aggregates[0].unusedRecipeCount, 2)
        XCTAssertEqual(aggregates[0].mealCount, 0)
        XCTAssertEqual(aggregates[0].mealShare, 0)
        XCTAssertNil(aggregates[0].firstMealAt)
        XCTAssertNil(aggregates[0].lastMealAt)
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

    func testListCookbookAggregatesIncludesMealUsageEvidence() async throws {
        let store = try makeStore()
        let referenceDate = mealHistoryReferenceDate()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "A", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "B", sourceFingerprint: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "C", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "D", sourceFingerprint: "hash-ddd"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeRecipeForAggregate(uid: "AAA", sourceName: "Serious Eats", starRating: 5, isFavorite: true),
                "BBB": makeRecipeForAggregate(uid: "BBB", sourceName: "Serious Eats", starRating: 4, isFavorite: false),
                "CCC": makeRecipeForAggregate(uid: "CCC", sourceName: "Smitten Kitchen", starRating: 5, isFavorite: true),
                "DDD": makeRecipeForAggregate(uid: "DDD", sourceName: "Serious Eats", starRating: nil, isFavorite: false),
            ],
            meals: [
                SourceMeal(uid: "M1", name: "A", scheduledAt: "2026-04-01 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "A"),
                SourceMeal(uid: "M2", name: "A", scheduledAt: "2026-04-07 18:00:00", mealType: "Dinner", recipeUID: "AAA", recipeName: "A"),
                SourceMeal(uid: "M3", name: "B", scheduledAt: "2026-04-03 18:00:00", mealType: "Dinner", recipeUID: "BBB", recipeName: "B"),
                SourceMeal(uid: "M4", name: "C", scheduledAt: "2026-04-05 18:00:00", mealType: "Dinner", recipeUID: "CCC", recipeName: "C"),
            ]
        )

        _ = try await store.rebuildRecipeIndexes(
            from: source,
            now: {
                referenceDate
            }
        )

        let aggregates = try store.listCookbookAggregates(sort: .name, limit: 20)
        let seriousEats = try XCTUnwrap(aggregates.first { $0.sourceName == "Serious Eats" })
        XCTAssertEqual(seriousEats.recipeCount, 3)
        XCTAssertEqual(seriousEats.usedRecipeCount, 2)
        XCTAssertEqual(seriousEats.unusedRecipeCount, 1)
        XCTAssertEqual(seriousEats.mealCount, 3)
        XCTAssertEqual(seriousEats.mealShare, 0.75, accuracy: 0.001)
        XCTAssertEqual(seriousEats.firstMealAt, "2026-04-01 18:00:00")
        XCTAssertEqual(seriousEats.lastMealAt, "2026-04-07 18:00:00")

        let smittenKitchen = try XCTUnwrap(aggregates.first { $0.sourceName == "Smitten Kitchen" })
        XCTAssertEqual(smittenKitchen.usedRecipeCount, 1)
        XCTAssertEqual(smittenKitchen.unusedRecipeCount, 0)
        XCTAssertEqual(smittenKitchen.mealCount, 1)
        XCTAssertEqual(smittenKitchen.mealShare, 0.25, accuracy: 0.001)
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

    private func makeRecipeForPairEvidence(
        uid: String,
        name: String,
        ingredients: String,
        starRating: Int?,
        isFavorite: Bool
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: name,
            categoryReferences: [],
            sourceName: "Test Kitchen",
            ingredients: ingredients,
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

    private func mealHistoryReferenceDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = 4
        components.day = 10
        components.hour = 12
        return components.date ?? Date(timeIntervalSince1970: 0)
    }
}
