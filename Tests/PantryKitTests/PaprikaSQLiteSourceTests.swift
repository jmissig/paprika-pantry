import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class PaprikaSQLiteSourceTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testPaprikaSQLiteSourceReadsRecipeStubsCategoriesAndDetails() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())

        let stubs = try await source.listRecipeStubs()
        let categories = try await source.listRecipeCategories()
        let recipe = try await source.fetchRecipe(uid: "AAA")

        XCTAssertEqual(
            stubs,
            [
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", hash: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
            ]
        )
        XCTAssertEqual(
            categories,
            [
                SourceRecipeCategory(uid: "CAT2", name: "Archive", isDeleted: true),
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ]
        )
        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categoryReferences, ["CAT1"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.ingredients, "Broth\nBeans")
        XCTAssertEqual(recipe.directions, "Simmer.")
        XCTAssertEqual(recipe.notes, "Finish with lemon.")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.prepTime, "10 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.servings, "4")
        XCTAssertEqual(recipe.createdAt, "2026-04-01 10:00:00")
        XCTAssertEqual(recipe.updatedAt, "2026-04-02 11:00:00")
        XCTAssertEqual(recipe.remoteHash, "hash-aaa")
        XCTAssertTrue(recipe.rawJSON.contains("\"category_uids\":[\"CAT1\"]"))
    }

    func testPaprikaSQLiteSourceRejectsIncompleteSchema() throws {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE recipes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uid TEXT NOT NULL,
                    name TEXT NOT NULL
                )
                """)
        }

        XCTAssertThrowsError(try PaprikaSQLiteSource(databaseURL: databaseURL)) { error in
            XCTAssertEqual(error as? PaprikaSQLiteSourceError, .missingTable("categories"))
        }
    }

    func testSyncEngineCanMirrorFromPaprikaSQLiteSource() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
        let store = try makeMirrorStore()
        let engine = RecipeMirrorSyncEngine(
            source: source,
            store: store,
            now: { Date(timeIntervalSince1970: 1_712_736_000) }
        )

        let summary = try await engine.run()

        XCTAssertEqual(summary.status, .success)
        XCTAssertEqual(summary.recipesSeen, 1)
        XCTAssertEqual(summary.changedRecipeCount, 1)
        XCTAssertEqual(summary.deletedRecipeCount, 0)

        let recipe = try XCTUnwrap(store.fetchRecipe(uid: "AAA"))
        XCTAssertEqual(recipe.categories, ["Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
    }

    private func makePaprikaSourceDatabase() throws -> URL {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE recipes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uid TEXT NOT NULL,
                    name TEXT NOT NULL,
                    ingredients TEXT,
                    directions TEXT,
                    notes TEXT,
                    source TEXT,
                    prep_time TEXT,
                    cook_time TEXT,
                    total_time TEXT,
                    servings TEXT,
                    rating INTEGER,
                    on_favorites INTEGER NOT NULL DEFAULT 0,
                    sync_hash TEXT,
                    in_trash INTEGER NOT NULL DEFAULT 0,
                    created REAL,
                    updated REAL
                )
                """)
            try db.execute(sql: """
                CREATE TABLE categories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uid TEXT NOT NULL,
                    name TEXT NOT NULL,
                    in_trash INTEGER NOT NULL DEFAULT 0
                )
                """)
            try db.execute(sql: """
                CREATE TABLE recipe_categories (
                    recipe_id INTEGER NOT NULL,
                    category_id INTEGER NOT NULL
                )
                """)

            try db.execute(
                sql: """
                    INSERT INTO recipes (
                        uid,
                        name,
                        ingredients,
                        directions,
                        notes,
                        source,
                        prep_time,
                        cook_time,
                        total_time,
                        servings,
                        rating,
                        on_favorites,
                        sync_hash,
                        in_trash,
                        created,
                        updated
                    ) VALUES (
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        ?,
                        julianday(?),
                        julianday(?)
                    )
                    """,
                arguments: [
                    "AAA",
                    "Weeknight Soup",
                    "Broth\nBeans",
                    "Simmer.",
                    "Finish with lemon.",
                    "Serious Eats",
                    "10 min",
                    "30 min",
                    "40 min",
                    "4",
                    4,
                    1,
                    "hash-aaa",
                    0,
                    "2026-04-01 10:00:00",
                    "2026-04-02 11:00:00",
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO recipes (
                        uid,
                        name,
                        sync_hash,
                        in_trash
                    ) VALUES (?, ?, ?, ?)
                    """,
                arguments: ["BBB", "Deleted Recipe", "hash-bbb", 1]
            )
            try db.execute(
                sql: """
                    INSERT INTO categories (
                        uid,
                        name,
                        in_trash
                    ) VALUES (?, ?, ?), (?, ?, ?)
                    """,
                arguments: ["CAT1", "Dinner", 0, "CAT2", "Archive", 1]
            )
            try db.execute(
                sql: """
                    INSERT INTO recipe_categories (
                        recipe_id,
                        category_id
                    ) VALUES (
                        (SELECT id FROM recipes WHERE uid = 'AAA'),
                        (SELECT id FROM categories WHERE uid = 'CAT1')
                    )
                    """
            )
        }

        return databaseURL
    }

    private func makeMirrorStore() throws -> PantryStore {
        let root = try makeTemporaryDirectory()
        let database = PantryDatabase(path: root.appendingPathComponent("pantry.sqlite"))
        return PantryStore(dbQueue: try database.openQueue())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryDirectoryURL = root
        return root
    }
}
