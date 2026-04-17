import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class PantryStoreTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testMigrationCreatesExpectedTablesAndIndexes() throws {
        let queue = try makeDatabase().openQueue()

        try queue.read { db in
            let indexes = try String.fetchAll(
                db,
                sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'index'
                ORDER BY name
                """
            )

            XCTAssertTrue(indexes.contains("recipe_search_documents_on_name"))
            XCTAssertTrue(indexes.contains("recipe_search_documents_on_indexed_at"))
            XCTAssertTrue(indexes.contains("recipe_features_on_derived_at"))
            XCTAssertTrue(indexes.contains("recipe_features_on_total_time_minutes"))
            XCTAssertTrue(indexes.contains("recipe_features_on_ingredient_line_count"))
            XCTAssertTrue(indexes.contains("recipe_ingredient_lines_on_recipe_uid"))
            XCTAssertTrue(indexes.contains("recipe_ingredient_lines_on_derived_at"))
            XCTAssertTrue(indexes.contains("recipe_ingredient_tokens_on_token"))
            XCTAssertTrue(indexes.contains("recipe_ingredient_tokens_on_recipe_uid"))
            XCTAssertTrue(indexes.contains("recipe_ingredient_tokens_on_recipe_uid_token"))
            XCTAssertTrue(indexes.contains("index_runs_on_started_at"))
            XCTAssertTrue(indexes.contains("index_runs_on_status"))
            XCTAssertTrue(indexes.contains("index_runs_on_index_name"))
            XCTAssertTrue(try db.tableExists("recipe_search_documents"))
            XCTAssertTrue(try db.tableExists("recipe_search_fts"))
            XCTAssertTrue(try db.tableExists("recipe_features"))
            XCTAssertTrue(try db.tableExists("recipe_ingredient_lines"))
            XCTAssertTrue(try db.tableExists("recipe_ingredient_tokens"))
            XCTAssertTrue(try db.tableExists("index_runs"))
            XCTAssertFalse(try db.tableExists("recipes"))
            XCTAssertFalse(try db.tableExists("recipe_categories"))
            XCTAssertFalse(try db.tableExists("sync_runs"))
        }
    }

    func testMigrationCleansUpLegacyMirrorTables() throws {
        let database = try makeDatabase()
        try FileManager.default.createDirectory(
            at: database.path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: database.path.path)

        try queue.write { db in
            try db.execute(sql: "CREATE TABLE recipes (uid TEXT PRIMARY KEY)")
            try db.execute(sql: "CREATE TABLE recipe_categories (recipe_uid TEXT, category_name TEXT)")
            try db.execute(sql: "CREATE TABLE sync_runs (id INTEGER PRIMARY KEY)")
        }

        let migratedQueue = try database.openQueue()
        try migratedQueue.read { db in
            XCTAssertFalse(try db.tableExists("recipes"))
            XCTAssertFalse(try db.tableExists("recipe_categories"))
            XCTAssertFalse(try db.tableExists("sync_runs"))
            XCTAssertTrue(try db.tableExists("recipe_search_documents"))
        }
    }

    func testMigrationIsIdempotent() throws {
        let database = try makeDatabase()
        _ = try database.openQueue()
        _ = try database.openQueue()
    }

    func testRecipeIndexesRebuildSearchAndDerivedFeatures() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Pasta Salad", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Deleted", hash: "hash-ccc", isDeleted: true),
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
                    remoteHash: "hash-aaa",
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
                    remoteHash: "hash-bbb",
                    rawJSON: "{}"
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

        let stats = try store.indexStats()
        XCTAssertEqual(stats.recipeSearchDocumentCount, 2)
        XCTAssertEqual(stats.recipeFeatureCount, 2)
        XCTAssertEqual(stats.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(stats.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertEqual(stats.recipeIngredientRecipeCount, 2)
        XCTAssertEqual(stats.recipeIngredientLineCount, 4)
        XCTAssertEqual(stats.recipeIngredientTokenCount, 4)
        XCTAssertTrue(stats.recipeSearchReady)
        XCTAssertTrue(stats.recipeFeaturesReady)
        XCTAssertTrue(stats.recipeIngredientIndexReady)
        XCTAssertEqual(stats.lastRecipeSearchRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeSearchRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeIngredientRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeIngredientRun?.recipeCount, 2)
    }

    func testSearchNormalizesPlainQueriesForFTS() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
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
                    remoteHash: nil,
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
                SourceRecipeStub(uid: "AAA", name: "Mushroom Risotto", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Lemon Risotto", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Tomato Risotto", hash: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Unrated Risotto", hash: "hash-ddd"),
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
                    remoteHash: "hash-aaa",
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
                    remoteHash: "hash-bbb",
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
                    remoteHash: "hash-ccc",
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
                    remoteHash: "hash-ddd",
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

    func testIngredientNormalizationIndexesConservativeTokensPerLine() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Tomato Salad", hash: "hash-aaa"),
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
                    remoteHash: "hash-aaa",
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
                SourceRecipeStub(uid: "AAA", name: "Soup A", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Soup B", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Soup C", hash: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Soup D", hash: "hash-ddd"),
                SourceRecipeStub(uid: "EEE", name: "Soup E", hash: "hash-eee"),
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
                SourceRecipeStub(uid: "AAA", name: "A", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "B", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "C", hash: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "D", hash: "hash-ddd"),
                SourceRecipeStub(uid: "EEE", name: "E", hash: "hash-eee"),
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
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Tomato Soup", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Weeknight Salad", hash: "hash-ccc"),
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
                    remoteHash: "hash-aaa",
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
                    remoteHash: "hash-bbb",
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
                    remoteHash: "hash-ccc",
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
                SourceRecipeStub(uid: "AAA", name: "Tomato Pasta", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Lemon Pasta", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Green Salad", hash: "hash-ccc"),
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
                    remoteHash: "hash-aaa",
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
                    remoteHash: "hash-bbb",
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
                    remoteHash: "hash-ccc",
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
    }

    func testDerivedFeaturesPreferSourceTotalTimeWhenAvailable() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Braise", hash: "hash-aaa"),
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
                    remoteHash: "hash-aaa",
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
                SourceRecipeStub(uid: "AAA", name: "Quick Bean Soup", hash: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Quick Tomato Soup", hash: "hash-bbb"),
                SourceRecipeStub(uid: "CCC", name: "Slow Tomato Soup", hash: "hash-ccc"),
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
                    remoteHash: "hash-aaa",
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
                    remoteHash: "hash-bbb",
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
                    remoteHash: "hash-ccc",
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

    private func makeDatabase() throws -> PantryDatabase {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        return PantryDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
    }

    private func makeStore() throws -> PantryStore {
        let database = try makeDatabase()
        return PantryStore(dbQueue: try database.openQueue())
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
            remoteHash: "hash-\(uid)",
            rawJSON: "{}"
        )
    }
}
