import Foundation
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
            XCTAssertTrue(try db.tableExists("recipes"))
            XCTAssertTrue(try db.tableExists("recipe_categories"))
            XCTAssertTrue(try db.tableExists("sync_runs"))

            let indexes = try String.fetchAll(
                db,
                sql: """
                SELECT name
                FROM sqlite_master
                WHERE type = 'index'
                ORDER BY name
                """
            )

            XCTAssertTrue(indexes.contains("recipes_on_name"))
            XCTAssertTrue(indexes.contains("recipes_on_is_favorite"))
            XCTAssertTrue(indexes.contains("recipes_on_star_rating"))
            XCTAssertTrue(indexes.contains("recipes_on_is_deleted"))
            XCTAssertTrue(indexes.contains("recipes_on_last_synced_at"))
            XCTAssertTrue(indexes.contains("recipe_categories_on_category_name"))
            XCTAssertTrue(indexes.contains("recipe_categories_on_recipe_uid"))
            XCTAssertTrue(indexes.contains("sync_runs_on_started_at"))
            XCTAssertTrue(indexes.contains("sync_runs_on_status"))
        }
    }

    func testMigrationIsIdempotent() throws {
        let database = try makeDatabase()
        _ = try database.openQueue()
        _ = try database.openQueue()
    }

    func testUpsertRecipeWritesFieldsAndReplacesCategories() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(
            MirroredRecipeInput(
                uid: "AAA",
                name: "Weeknight Pasta",
                categories: ["Dinner", "Pasta", "Dinner"],
                sourceName: "Serious Eats",
                ingredients: "Pasta\nSauce",
                directions: "Boil.\nSauce.",
                notes: "Use good olive oil.",
                starRating: 4,
                isFavorite: true,
                prepTime: "10 min",
                cookTime: "20 min",
                totalTime: "30 min",
                servings: "4",
                createdAt: "2026-04-01T00:00:00Z",
                updatedAt: "2026-04-02T00:00:00Z",
                remoteHash: "hash-1",
                rawJSON: #"{"uid":"AAA","name":"Weeknight Pasta"}"#
            ),
            syncedAt: syncedAt
        )

        try store.upsertRecipe(
            MirroredRecipeInput(
                uid: "AAA",
                name: "Weeknight Pasta",
                categories: ["Comfort Food", "Dinner"],
                sourceName: "Serious Eats",
                ingredients: "Pasta\nSauce",
                directions: "Boil.\nSauce.",
                notes: "Updated note.",
                starRating: 5,
                isFavorite: false,
                prepTime: "10 min",
                cookTime: "20 min",
                totalTime: "30 min",
                servings: "4",
                createdAt: "2026-04-01T00:00:00Z",
                updatedAt: "2026-04-03T00:00:00Z",
                remoteHash: "hash-2",
                rawJSON: #"{"uid":"AAA","name":"Weeknight Pasta","updated":true}"#
            ),
            syncedAt: syncedAt
        )

        let recipe = try XCTUnwrap(store.fetchRecipe(uid: "AAA"))
        XCTAssertEqual(recipe.name, "Weeknight Pasta")
        XCTAssertEqual(recipe.categories, ["Comfort Food", "Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.notes, "Updated note.")
        XCTAssertEqual(recipe.starRating, 5)
        XCTAssertFalse(recipe.isFavorite)
        XCTAssertEqual(recipe.remoteHash, "hash-2")
        XCTAssertEqual(recipe.rawJSON, #"{"uid":"AAA","name":"Weeknight Pasta","updated":true}"#)
    }

    func testTombstoneMarksMissingRecipesDeletedWithoutDeletingRows() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(makeRecipe(uid: "AAA", name: "First"), syncedAt: syncedAt)
        try store.upsertRecipe(makeRecipe(uid: "BBB", name: "Second"), syncedAt: syncedAt)

        let deletedCount = try store.tombstoneRecipes(
            missingFrom: ["AAA"],
            syncedAt: Date(timeIntervalSince1970: 1_712_740_000)
        )

        XCTAssertEqual(deletedCount, 1)
        XCTAssertNil(try store.fetchRecipe(uid: "BBB"))

        let stats = try store.stats()
        XCTAssertEqual(stats.totalRecipeCount, 2)
        XCTAssertEqual(stats.activeRecipeCount, 1)
        XCTAssertEqual(stats.deletedRecipeCount, 1)
    }

    func testListAndNameLookupExcludeDeletedRecipes() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(makeRecipe(uid: "AAA", name: "Curry"), syncedAt: syncedAt)
        try store.upsertRecipe(makeRecipe(uid: "BBB", name: "Curry"), syncedAt: syncedAt)
        try store.upsertRecipe(makeRecipe(uid: "CCC", name: "Soup"), syncedAt: syncedAt)
        _ = try store.tombstoneRecipes(missingFrom: ["AAA", "BBB"], syncedAt: syncedAt)

        let listed = try store.listRecipes()
        XCTAssertEqual(listed.map(\.uid), ["AAA", "BBB"])

        let named = try store.fetchRecipes(namedExactlyCaseInsensitive: "cUrRy")
        XCTAssertEqual(named.map(\.uid), ["AAA", "BBB"])

        XCTAssertNil(try store.fetchRecipe(uid: "CCC"))
    }

    func testSyncRunsAndStatsReflectStoredHistory() throws {
        let store = try makeStore()
        let startedAt = Date(timeIntervalSince1970: 1_712_736_000)
        let finishedAt = Date(timeIntervalSince1970: 1_712_736_120)

        let runID = try store.startSyncRun(startedAt: startedAt)
        try store.finishSyncRun(
            id: runID,
            status: .success,
            finishedAt: finishedAt,
            recipesSeen: 10,
            recipesChanged: 4,
            recipesDeleted: 1,
            errorMessage: nil
        )

        let latestRun = try XCTUnwrap(store.latestSyncRun())
        XCTAssertEqual(latestRun.id, runID)
        XCTAssertEqual(latestRun.status, .success)
        XCTAssertEqual(latestRun.recipesSeen, 10)
        XCTAssertEqual(latestRun.recipesChanged, 4)
        XCTAssertEqual(latestRun.recipesDeleted, 1)
        XCTAssertEqual(latestRun.startedAt, startedAt)
        XCTAssertEqual(latestRun.finishedAt, finishedAt)

        let stats = try store.stats()
        XCTAssertEqual(stats.syncRunCount, 1)

        let syncStatus = try store.syncStatus()
        XCTAssertEqual(syncStatus.lastAttempt, latestRun)
        XCTAssertEqual(syncStatus.lastSuccess, latestRun)
        XCTAssertTrue(syncStatus.hasSuccessfulSync)
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

    private func makeRecipe(uid: String, name: String) -> MirroredRecipeInput {
        MirroredRecipeInput(
            uid: uid,
            name: name,
            categories: ["Dinner"],
            sourceName: "Test Kitchen",
            ingredients: nil,
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
            remoteHash: "hash-\(uid)",
            rawJSON: #"{"uid":"test"}"#
        )
    }
}
