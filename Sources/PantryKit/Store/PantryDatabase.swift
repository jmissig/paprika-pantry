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

        migrator.registerMigration("recipe-mirror-v1") { db in
            try db.create(table: "recipes") { table in
                table.column("uid", .text).notNull().primaryKey()
                table.column("name", .text).notNull()
                table.column("source_name", .text)
                table.column("ingredients", .text)
                table.column("directions", .text)
                table.column("notes", .text)
                table.column("star_rating", .integer)
                table.column("is_favorite", .boolean).notNull().defaults(to: false)
                table.column("prep_time", .text)
                table.column("cook_time", .text)
                table.column("total_time", .text)
                table.column("servings", .text)
                table.column("created_at", .text)
                table.column("updated_at", .text)
                table.column("remote_hash", .text)
                table.column("is_deleted", .boolean).notNull().defaults(to: false)
                table.column("last_synced_at", .text)
                table.column("raw_json", .text).notNull()
            }

            try db.create(index: "recipes_on_name", on: "recipes", columns: ["name"])
            try db.create(index: "recipes_on_is_favorite", on: "recipes", columns: ["is_favorite"])
            try db.create(index: "recipes_on_star_rating", on: "recipes", columns: ["star_rating"])
            try db.create(index: "recipes_on_is_deleted", on: "recipes", columns: ["is_deleted"])
            try db.create(index: "recipes_on_last_synced_at", on: "recipes", columns: ["last_synced_at"])

            try db.create(table: "recipe_categories") { table in
                table.column("recipe_uid", .text)
                    .notNull()
                    .references("recipes", column: "uid", onDelete: .cascade)
                table.column("category_name", .text).notNull()
                table.primaryKey(["recipe_uid", "category_name"])
            }

            try db.create(index: "recipe_categories_on_category_name", on: "recipe_categories", columns: ["category_name"])
            try db.create(index: "recipe_categories_on_recipe_uid", on: "recipe_categories", columns: ["recipe_uid"])

            try db.create(table: "sync_runs") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("started_at", .text).notNull()
                table.column("finished_at", .text)
                table.column("status", .text).notNull()
                table.column("recipes_seen", .integer).notNull().defaults(to: 0)
                table.column("recipes_changed", .integer).notNull().defaults(to: 0)
                table.column("recipes_deleted", .integer).notNull().defaults(to: 0)
                table.column("error_message", .text)
            }

            try db.create(index: "sync_runs_on_started_at", on: "sync_runs", columns: ["started_at"])
            try db.create(index: "sync_runs_on_status", on: "sync_runs", columns: ["status"])
        }

        return migrator
    }
}
