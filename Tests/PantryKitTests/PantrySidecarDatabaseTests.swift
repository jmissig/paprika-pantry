import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class PantrySidecarDatabaseTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testMigrationCreatesCurrentSidecarTablesAndColumns() throws {
        let queue = try makeDatabase().openQueue()

        try queue.read { db in
            XCTAssertTrue(try db.tableExists("recipe_search_documents"))
            XCTAssertTrue(try db.tableExists("recipe_search_fts"))
            XCTAssertTrue(try db.tableExists("recipe_features"))
            XCTAssertTrue(try db.tableExists("recipe_ingredient_lines"))
            XCTAssertTrue(try db.tableExists("recipe_ingredient_tokens"))
            XCTAssertTrue(try db.tableExists("recipe_usage_stats"))
            XCTAssertTrue(try db.tableExists("recipe_usage_summary"))
            XCTAssertTrue(try db.tableExists("ingredient_pair_summaries"))
            XCTAssertTrue(try db.tableExists("ingredient_pair_recipe_evidence"))
            XCTAssertTrue(try db.tableExists("source_state"))
            XCTAssertTrue(try db.tableExists("index_runs"))

            XCTAssertFalse(try db.tableExists("recipes"))
            XCTAssertFalse(try db.tableExists("recipe_categories"))
            XCTAssertFalse(try db.tableExists("sync_runs"))

            XCTAssertTrue(try columns(in: "recipe_search_documents", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "recipe_features", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "recipe_ingredient_lines", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("meal_count"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("first_meal_at"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("last_meal_at"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("meal_gap_days_json"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("days_spanned_by_meals"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("median_meal_gap_days"))
            XCTAssertTrue(try columns(in: "recipe_usage_stats", db: db).contains("meal_share"))
            XCTAssertTrue(try columns(in: "ingredient_pair_summaries", db: db).contains("basis"))
            XCTAssertTrue(try columns(in: "ingredient_pair_summaries", db: db).contains("average_star_rating"))
            XCTAssertTrue(try columns(in: "ingredient_pair_recipe_evidence", db: db).contains("token_a_line_numbers_json"))
            XCTAssertTrue(try columns(in: "ingredient_pair_recipe_evidence", db: db).contains("token_b_line_numbers_json"))
            XCTAssertTrue(try columns(in: "source_state", db: db).contains("source_type"))
        }
    }

    func testRecipeUsageMigrationPromotesLegacyRowsIntoMealHistoryShape() throws {
        let database = try makeDatabase()
        try FileManager.default.createDirectory(
            at: database.path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: database.path.path)

        try PantrySidecarDatabase.migrator().migrate(queue, upTo: "recipe-usage-v1")

        try queue.write { db in
            try db.execute(
                sql: """
                INSERT INTO recipe_usage_stats (
                    uid,
                    derived_at,
                    times_cooked,
                    last_cooked_at
                ) VALUES (?, ?, ?, ?)
                """,
                arguments: [
                    "AAA",
                    "2026-04-10T00:00:00.000Z",
                    3,
                    "2026-04-07 18:00:00",
                ]
            )
        }

        let migratedQueue = try database.openQueue()
        try migratedQueue.read { db in
            let columns = try columns(in: "recipe_usage_stats", db: db)
            XCTAssertTrue(columns.contains("meal_count"))
            XCTAssertTrue(columns.contains("last_meal_at"))
            XCTAssertTrue(try db.tableExists("recipe_usage_summary"))

            let row = try XCTUnwrap(
                Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        times_cooked,
                        last_cooked_at,
                        meal_count,
                        first_meal_at,
                        last_meal_at,
                        meal_gap_days_json,
                        days_spanned_by_meals,
                        median_meal_gap_days,
                        meal_share
                    FROM recipe_usage_stats
                    WHERE uid = ?
                    """,
                    arguments: ["AAA"]
                )
            )
            XCTAssertEqual(row["times_cooked"], 3)
            XCTAssertEqual(row["last_cooked_at"], "2026-04-07 18:00:00")
            XCTAssertEqual(row["meal_count"], 3)
            XCTAssertNil(row["first_meal_at"] as String?)
            XCTAssertEqual(row["last_meal_at"], "2026-04-07 18:00:00")
            XCTAssertNil(row["meal_gap_days_json"] as String?)
            XCTAssertNil(row["days_spanned_by_meals"] as Int?)
            XCTAssertNil(row["median_meal_gap_days"] as Double?)
            XCTAssertNil(row["meal_share"] as Double?)

            XCTAssertEqual(
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_usage_summary WHERE summary_key = 'current'"),
                0
            )
        }
    }

    func testMigrationNormalizesLegacyLocalFirstColumnNames() throws {
        let database = try makeDatabase()
        try FileManager.default.createDirectory(
            at: database.path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: database.path.path)

        try PantrySidecarDatabase.migrator().migrate(queue, upTo: "source-state-v1")

        try queue.write { db in
            try db.execute(
                sql: "ALTER TABLE recipe_search_documents RENAME COLUMN source_fingerprint TO remote_hash"
            )
            try db.execute(
                sql: "ALTER TABLE recipe_features RENAME COLUMN source_fingerprint TO source_remote_hash"
            )
            try db.execute(
                sql: "ALTER TABLE recipe_ingredient_lines RENAME COLUMN source_fingerprint TO source_remote_hash"
            )
            try db.execute(
                sql: "ALTER TABLE source_state RENAME COLUMN source_type TO source_kind"
            )
        }

        let migratedQueue = try database.openQueue()
        try migratedQueue.read { db in
            XCTAssertFalse(try columns(in: "recipe_search_documents", db: db).contains("remote_hash"))
            XCTAssertFalse(try columns(in: "recipe_features", db: db).contains("source_remote_hash"))
            XCTAssertFalse(try columns(in: "recipe_ingredient_lines", db: db).contains("source_remote_hash"))
            XCTAssertFalse(try columns(in: "source_state", db: db).contains("source_kind"))

            XCTAssertTrue(try columns(in: "recipe_search_documents", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "recipe_features", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "recipe_ingredient_lines", db: db).contains("source_fingerprint"))
            XCTAssertTrue(try columns(in: "source_state", db: db).contains("source_type"))
        }
    }

    func testMigrationRemovesLegacyMirrorTables() throws {
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
            XCTAssertTrue(try db.tableExists("source_state"))
        }
    }

    func testMigrationIsIdempotent() throws {
        let database = try makeDatabase()
        _ = try database.openQueue()
        _ = try database.openQueue()
    }

    private func makeDatabase() throws -> PantrySidecarDatabase {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        return PantrySidecarDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
    }

    private func columns(in tableName: String, db: Database) throws -> Set<String> {
        Set(try db.columns(in: tableName).map(\.name))
    }
}
