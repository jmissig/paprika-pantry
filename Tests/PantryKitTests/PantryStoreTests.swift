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
            XCTAssertTrue(indexes.contains("index_runs_on_started_at"))
            XCTAssertTrue(indexes.contains("index_runs_on_status"))
            XCTAssertTrue(indexes.contains("index_runs_on_index_name"))
            XCTAssertTrue(try db.tableExists("recipe_search_documents"))
            XCTAssertTrue(try db.tableExists("recipe_search_fts"))
            XCTAssertTrue(try db.tableExists("recipe_features"))
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

        let stats = try store.indexStats()
        XCTAssertEqual(stats.recipeSearchDocumentCount, 2)
        XCTAssertEqual(stats.recipeFeatureCount, 2)
        XCTAssertEqual(stats.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(stats.recipeFeaturesWithIngredientLineCountCount, 2)
        XCTAssertTrue(stats.recipeSearchReady)
        XCTAssertTrue(stats.recipeFeaturesReady)
        XCTAssertEqual(stats.lastRecipeSearchRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeSearchRun?.recipeCount, 2)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeFeatureRun?.recipeCount, 2)
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

    private func makeDatabase() throws -> PantryDatabase {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        return PantryDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
    }

    private func makeStore() throws -> PantryStore {
        let database = try makeDatabase()
        return PantryStore(dbQueue: try database.openQueue())
    }
}
