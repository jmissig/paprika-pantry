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

    func testPaprikaSQLiteSourceReadsRealSchemaRecipesCategoriesAndInspection() async throws {
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

        XCTAssertEqual(source.inspection.schemaFlavor, "paprika-3-core-data")
        XCTAssertEqual(source.inspection.accessMode, "read-only")
        XCTAssertTrue(source.inspection.queryOnly)
        XCTAssertEqual(source.inspection.journalMode, "wal")
        XCTAssertEqual(
            source.inspection.requiredTables,
            ["ZRECIPE", "ZRECIPECATEGORY", "Z_12CATEGORIES", "Z_METADATA"]
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
        XCTAssertEqual(recipe.cookTime, "30 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.servings, "4")
        XCTAssertEqual(recipe.createdAt, "2026-04-01 10:00:00")
        XCTAssertNil(recipe.updatedAt)
        XCTAssertEqual(recipe.remoteHash, "hash-aaa")
        XCTAssertTrue(recipe.rawJSON.contains("\"category_uids\":[\"CAT1\"]"))
        XCTAssertTrue(recipe.rawJSON.contains("\"created\":\"2026-04-01 10:00:00\""))
    }

    func testPaprikaSQLiteSourceRejectsIncompleteRealSchema() throws {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID TEXT,
                    ZNAME TEXT
                )
                """)
        }

        XCTAssertThrowsError(try PaprikaSQLiteSource(databaseURL: databaseURL)) { error in
            XCTAssertEqual(error as? PaprikaSQLiteSourceError, .missingTable("ZRECIPECATEGORY"))
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
        XCTAssertEqual(recipe.createdAt, "2026-04-01 10:00:00")
        XCTAssertNil(recipe.updatedAt)
    }

    func testRecipeReadServiceReadsListAndShowDirectlyFromPaprikaSQLiteSource() throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
        let service = RecipeReadService(source: source)

        let listed = try BlockingAsync.run {
            try await service.listRecipes()
        }
        let recipe = try BlockingAsync.run {
            try await service.resolveRecipe(selector: "weeknight soup")
        }

        XCTAssertEqual(
            listed,
            [
                RecipeSummary(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true,
                    updatedAt: nil
                ),
            ]
        )

        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categories, ["Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.remoteHash, "hash-aaa")
    }

    private func makePaprikaSourceDatabase() throws -> URL {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE Z_METADATA (
                    Z_VERSION INTEGER PRIMARY KEY,
                    Z_UUID TEXT,
                    Z_PLIST BLOB
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZINTRASH INTEGER,
                    ZONFAVORITES INTEGER,
                    ZRATING INTEGER,
                    ZCREATED TIMESTAMP,
                    ZCOOKTIME VARCHAR,
                    ZDESCRIPTIONTEXT VARCHAR,
                    ZDIRECTIONS VARCHAR,
                    ZINGREDIENTS VARCHAR,
                    ZNAME VARCHAR,
                    ZNOTES VARCHAR,
                    ZPREPTIME VARCHAR,
                    ZSERVINGS VARCHAR,
                    ZSOURCE VARCHAR,
                    ZSYNCHASH VARCHAR,
                    ZTOTALTIME VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPECATEGORY (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZPARENT INTEGER,
                    ZNAME VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE Z_12CATEGORIES (
                    Z_12RECIPES INTEGER,
                    Z_13CATEGORIES INTEGER,
                    PRIMARY KEY (Z_12RECIPES, Z_13CATEGORIES)
                )
                """)

            try db.execute(
                sql: """
                    INSERT INTO ZRECIPE (
                        Z_PK,
                        ZINTRASH,
                        ZONFAVORITES,
                        ZRATING,
                        ZCREATED,
                        ZCOOKTIME,
                        ZDESCRIPTIONTEXT,
                        ZDIRECTIONS,
                        ZINGREDIENTS,
                        ZNAME,
                        ZNOTES,
                        ZPREPTIME,
                        ZSERVINGS,
                        ZSOURCE,
                        ZSYNCHASH,
                        ZTOTALTIME,
                        ZUID
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    1,
                    0,
                    1,
                    4,
                    Self.appleReferenceSeconds(for: "2026-04-01 10:00:00"),
                    "30 min",
                    "",
                    "Simmer.",
                    "Broth\nBeans",
                    "Weeknight Soup",
                    "Finish with lemon.",
                    "10 min",
                    "4",
                    "Serious Eats",
                    "hash-aaa",
                    "40 min",
                    "AAA",
                ]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZRECIPE (
                        Z_PK,
                        ZINTRASH,
                        ZONFAVORITES,
                        ZRATING,
                        ZNAME,
                        ZSYNCHASH,
                        ZUID
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [2, 1, 0, 0, "Deleted Recipe", "hash-bbb", "BBB"]
            )
            try db.execute(
                sql: """
                    INSERT INTO ZRECIPECATEGORY (
                        Z_PK,
                        ZNAME,
                        ZSTATUS,
                        ZUID
                    ) VALUES (?, ?, ?, ?), (?, ?, ?, ?)
                    """,
                arguments: [1, "Dinner", "unmodified", "CAT1", 2, "Archive", "deleted", "CAT2"]
            )
            try db.execute(
                sql: """
                    INSERT INTO Z_12CATEGORIES (
                        Z_12RECIPES,
                        Z_13CATEGORIES
                    ) VALUES (?, ?)
                    """,
                arguments: [1, 1]
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

    private static func appleReferenceSeconds(for timestamp: String) -> TimeInterval {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let date = formatter.date(from: timestamp)!
        return date.timeIntervalSinceReferenceDate
    }
}
