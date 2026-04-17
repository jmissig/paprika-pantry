import Foundation
import GRDB

public struct PantryDatabase {
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
                table.column("remote_hash", .text)
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

        return migrator
    }
}
