import Foundation
import GRDB

public struct PantrySidecarDatabase {
    public let path: URL

    public init(path: URL) {
        self.path = path
    }

    public func openQueue(fileManager: FileManager = .default) throws -> DatabaseQueue {
        try fileManager.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        var configuration = Configuration()
        configuration.foreignKeysEnabled = true

        let queue = try DatabaseQueue(path: path.path, configuration: configuration)
        try Self.migrator().migrate(queue)
        return queue
    }

    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("recipe-search-v1") { db in
            try db.create(table: "recipe_search_documents") { table in
                table.column("uid", .text).notNull().primaryKey()
                table.column("name", .text).notNull()
                table.column("categories", .text).notNull().defaults(to: "")
                table.column("source_name", .text)
                table.column("ingredients", .text)
                table.column("notes", .text)
                table.column("source_fingerprint", .text)
                table.column("indexed_at", .text).notNull()
            }

            try db.create(index: "recipe_search_documents_on_name", on: "recipe_search_documents", columns: ["name"])
            try db.create(index: "recipe_search_documents_on_indexed_at", on: "recipe_search_documents", columns: ["indexed_at"])

            try db.create(virtualTable: "recipe_search_fts", using: FTS5()) { table in
                table.column("uid").notIndexed()
                table.column("name")
                table.column("categories")
                table.column("source_name")
                table.column("ingredients")
                table.column("notes")
                table.tokenizer = .unicode61()
            }

            try db.create(table: "index_runs") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("started_at", .text).notNull()
                table.column("finished_at", .text)
                table.column("status", .text).notNull()
                table.column("index_name", .text).notNull()
                table.column("recipe_count", .integer).notNull().defaults(to: 0)
                table.column("error_message", .text)
            }

            try db.create(index: "index_runs_on_started_at", on: "index_runs", columns: ["started_at"])
            try db.create(index: "index_runs_on_status", on: "index_runs", columns: ["status"])
            try db.create(index: "index_runs_on_index_name", on: "index_runs", columns: ["index_name"])
        }

        migrator.registerMigration("recipe-search-v2") { db in
            try db.alter(table: "recipe_search_documents") { table in
                table.add(column: "is_favorite", .boolean).notNull().defaults(to: false)
                table.add(column: "star_rating", .integer)
            }
        }

        migrator.registerMigration("legacy-sidecar-cleanup-v1") { db in
            if try db.tableExists("recipe_categories") {
                try db.drop(table: "recipe_categories")
            }

            if try db.tableExists("recipes") {
                try db.drop(table: "recipes")
            }

            if try db.tableExists("sync_runs") {
                try db.drop(table: "sync_runs")
            }
        }

        migrator.registerMigration("recipe-features-v1") { db in
            try db.create(table: "recipe_features") { table in
                table.column("uid", .text).notNull().primaryKey()
                table.column("source_fingerprint", .text)
                table.column("derived_at", .text).notNull()
                table.column("prep_time_minutes", .integer)
                table.column("cook_time_minutes", .integer)
                table.column("total_time_minutes", .integer)
                table.column("total_time_basis", .text)
                table.column("ingredient_line_count", .integer)
                table.column("ingredient_line_count_basis", .text)
            }

            try db.create(index: "recipe_features_on_derived_at", on: "recipe_features", columns: ["derived_at"])
            try db.create(index: "recipe_features_on_total_time_minutes", on: "recipe_features", columns: ["total_time_minutes"])
            try db.create(index: "recipe_features_on_ingredient_line_count", on: "recipe_features", columns: ["ingredient_line_count"])
        }

        migrator.registerMigration("recipe-ingredients-v1") { db in
            try db.create(table: "recipe_ingredient_lines") { table in
                table.column("recipe_uid", .text).notNull()
                table.column("line_number", .integer).notNull()
                table.column("source_text", .text).notNull()
                table.column("normalized_text", .text)
                table.column("source_fingerprint", .text)
                table.column("derived_at", .text).notNull()
                table.primaryKey(["recipe_uid", "line_number"])
            }

            try db.create(index: "recipe_ingredient_lines_on_recipe_uid", on: "recipe_ingredient_lines", columns: ["recipe_uid"])
            try db.create(index: "recipe_ingredient_lines_on_derived_at", on: "recipe_ingredient_lines", columns: ["derived_at"])

            try db.create(table: "recipe_ingredient_tokens") { table in
                table.column("recipe_uid", .text).notNull()
                table.column("line_number", .integer).notNull()
                table.column("token", .text).notNull()
                table.column("token_position", .integer).notNull()
                table.primaryKey(["recipe_uid", "line_number", "token_position"])
            }

            try db.create(index: "recipe_ingredient_tokens_on_token", on: "recipe_ingredient_tokens", columns: ["token"])
            try db.create(index: "recipe_ingredient_tokens_on_recipe_uid", on: "recipe_ingredient_tokens", columns: ["recipe_uid"])
            try db.create(index: "recipe_ingredient_tokens_on_recipe_uid_token", on: "recipe_ingredient_tokens", columns: ["recipe_uid", "token"])
        }

        migrator.registerMigration("recipe-usage-v1") { db in
            try db.create(table: "recipe_usage_stats") { table in
                table.column("uid", .text).notNull().primaryKey()
                table.column("derived_at", .text).notNull()
                table.column("times_cooked", .integer).notNull()
                table.column("last_cooked_at", .text)
            }

            try db.create(index: "recipe_usage_stats_on_derived_at", on: "recipe_usage_stats", columns: ["derived_at"])
            try db.create(index: "recipe_usage_stats_on_times_cooked", on: "recipe_usage_stats", columns: ["times_cooked"])
            try db.create(index: "recipe_usage_stats_on_last_cooked_at", on: "recipe_usage_stats", columns: ["last_cooked_at"])
        }

        migrator.registerMigration("recipe-usage-v2") { db in
            try db.alter(table: "recipe_usage_stats") { table in
                table.add(column: "meal_count", .integer).notNull().defaults(to: 0)
                table.add(column: "first_meal_at", .text)
                table.add(column: "last_meal_at", .text)
                table.add(column: "meal_gap_days_json", .text)
                table.add(column: "days_spanned_by_meals", .integer)
                table.add(column: "median_meal_gap_days", .double)
                table.add(column: "meal_share", .double)
            }

            try db.execute(
                sql: """
                UPDATE recipe_usage_stats
                SET meal_count = times_cooked,
                    last_meal_at = last_cooked_at
                """
            )

            try db.create(index: "recipe_usage_stats_on_meal_count", on: "recipe_usage_stats", columns: ["meal_count"])
            try db.create(index: "recipe_usage_stats_on_last_meal_at", on: "recipe_usage_stats", columns: ["last_meal_at"])

            try db.create(table: "recipe_usage_summary") { table in
                table.column("summary_key", .text).notNull().primaryKey()
                table.column("derived_at", .text).notNull()
                table.column("total_meal_count", .integer).notNull()
            }

            try db.create(index: "recipe_usage_summary_on_derived_at", on: "recipe_usage_summary", columns: ["derived_at"])
        }

        migrator.registerMigration("source-state-v1") { db in
            try db.create(table: "source_state") { table in
                table.column("source_type", .text).notNull().primaryKey()
                table.column("source_location", .text)
                table.column("observed_at", .text).notNull()
                table.column("paprika_last_sync_at", .text)
                table.column("paprika_sync_signal_source", .text)
                table.column("paprika_sync_signal_location", .text)
            }

            try db.create(index: "source_state_on_observed_at", on: "source_state", columns: ["observed_at"])
        }

        migrator.registerMigration("sidecar-local-source-naming-v1") { db in
            if try Self.table("recipe_search_documents", hasColumn: "remote_hash", db: db) {
                try db.execute(
                    sql: "ALTER TABLE recipe_search_documents RENAME COLUMN remote_hash TO source_fingerprint"
                )
            }

            if try Self.table("recipe_features", hasColumn: "source_remote_hash", db: db) {
                try db.execute(
                    sql: "ALTER TABLE recipe_features RENAME COLUMN source_remote_hash TO source_fingerprint"
                )
            }

            if try Self.table("recipe_ingredient_lines", hasColumn: "source_remote_hash", db: db) {
                try db.execute(
                    sql: "ALTER TABLE recipe_ingredient_lines RENAME COLUMN source_remote_hash TO source_fingerprint"
                )
            }

            if try Self.table("source_state", hasColumn: "source_kind", db: db) {
                try db.execute(
                    sql: "ALTER TABLE source_state RENAME COLUMN source_kind TO source_type"
                )
            }
        }

        migrator.registerMigration("ingredient-pairs-v1") { db in
            try db.create(table: "ingredient_pair_summaries") { table in
                table.column("basis", .text).notNull()
                table.column("token_a", .text).notNull()
                table.column("token_b", .text).notNull()
                table.column("derived_at", .text).notNull()
                table.column("recipe_count", .integer).notNull()
                table.column("cooked_recipe_count", .integer).notNull()
                table.column("cooked_meal_count", .integer).notNull()
                table.column("favorite_recipe_count", .integer).notNull()
                table.column("rated_recipe_count", .integer).notNull()
                table.column("average_star_rating", .double)
                table.column("first_meal_at", .text)
                table.column("last_meal_at", .text)
                table.primaryKey(["basis", "token_a", "token_b"])
            }

            try db.create(index: "ingredient_pair_summaries_on_token_a", on: "ingredient_pair_summaries", columns: ["token_a"])
            try db.create(index: "ingredient_pair_summaries_on_token_b", on: "ingredient_pair_summaries", columns: ["token_b"])
            try db.create(index: "ingredient_pair_summaries_on_recipe_count", on: "ingredient_pair_summaries", columns: ["recipe_count"])
            try db.create(index: "ingredient_pair_summaries_on_cooked_meal_count", on: "ingredient_pair_summaries", columns: ["cooked_meal_count"])

            try db.create(table: "ingredient_pair_recipe_evidence") { table in
                table.column("basis", .text).notNull()
                table.column("token_a", .text).notNull()
                table.column("token_b", .text).notNull()
                table.column("recipe_uid", .text).notNull()
                table.column("recipe_name", .text).notNull()
                table.column("source_name", .text)
                table.column("token_a_line_numbers_json", .text).notNull()
                table.column("token_b_line_numbers_json", .text).notNull()
                table.column("is_favorite", .boolean).notNull()
                table.column("star_rating", .integer)
                table.column("meal_count", .integer).notNull()
                table.column("first_meal_at", .text)
                table.column("last_meal_at", .text)
                table.column("derived_at", .text).notNull()
                table.primaryKey(["basis", "token_a", "token_b", "recipe_uid"])
            }

            try db.create(index: "ingredient_pair_recipe_evidence_on_recipe_uid", on: "ingredient_pair_recipe_evidence", columns: ["recipe_uid"])
            try db.create(index: "ingredient_pair_recipe_evidence_on_pair", on: "ingredient_pair_recipe_evidence", columns: ["basis", "token_a", "token_b"])
        }

        migrator.registerMigration("recipe-usage-first-cooked-at-v1") { db in
            try db.alter(table: "recipe_usage_stats") { table in
                table.add(column: "first_cooked_at", .text)
            }

            try db.execute(
                sql: """
                UPDATE recipe_usage_stats
                SET first_cooked_at = first_meal_at
                """
            )
        }

        return migrator
    }

    private static func table(
        _ tableName: String,
        hasColumn columnName: String,
        db: Database
    ) throws -> Bool {
        guard try db.tableExists(tableName) else {
            return false
        }

        return try db.columns(in: tableName).contains { $0.name == columnName }
    }
}

public typealias PantryDatabase = PantrySidecarDatabase
