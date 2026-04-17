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
            XCTAssertTrue(indexes.contains("index_runs_on_started_at"))
            XCTAssertTrue(indexes.contains("index_runs_on_status"))
            XCTAssertTrue(indexes.contains("index_runs_on_index_name"))
            XCTAssertTrue(try db.tableExists("recipe_search_documents"))
            XCTAssertTrue(try db.tableExists("recipe_search_fts"))
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

    func testRecipeSearchIndexRebuildAndSearch() async throws {
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

        let summary = try await store.rebuildRecipeSearchIndex(
            from: source,
            now: {
                Date(timeIntervalSince1970: 1_712_736_000)
            }
        )

        XCTAssertEqual(summary.recipeCount, 2)

        let results = try store.searchRecipes(query: "lemon", limit: 20)
        XCTAssertEqual(results.map(\.uid), ["AAA"])
        XCTAssertEqual(results[0].categories, ["Dinner", "Soup"])
        XCTAssertTrue(results[0].isFavorite)

        let stats = try store.indexStats()
        XCTAssertEqual(stats.recipeSearchDocumentCount, 2)
        XCTAssertTrue(stats.recipeSearchReady)
        XCTAssertEqual(stats.lastRecipeSearchRun?.status, .success)
        XCTAssertEqual(stats.lastRecipeSearchRun?.recipeCount, 2)
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

        _ = try await store.rebuildRecipeSearchIndex(from: source)

        XCTAssertEqual(try store.searchRecipes(query: "weeknight soup").map(\.uid), ["AAA"])
        XCTAssertEqual(try store.searchRecipes(query: "   ").count, 0)
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
