import Foundation
import GRDB

public enum PaprikaSQLiteSourceError: Error, LocalizedError, Equatable {
    case missingDatabase(URL)
    case unreadableDatabase(String)
    case missingTable(String)
    case missingColumn(table: String, column: String)
    case recipeNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .missingDatabase(let databaseURL):
            return "Paprika.sqlite was not found at \(databaseURL.path)."
        case .unreadableDatabase(let message):
            return "Paprika.sqlite could not be read: \(message)"
        case .missingTable(let table):
            return "Paprika.sqlite is missing the \(table) table."
        case .missingColumn(let table, let column):
            return "Paprika.sqlite is missing the \(column) column in \(table)."
        case .recipeNotFound(let uid):
            return "Paprika.sqlite does not contain recipe \(uid)."
        }
    }
}

public final class PaprikaSQLiteSource: PantrySource, @unchecked Sendable {
    public let databaseURL: URL

    private let dbQueue: DatabaseQueue
    private let schema: PaprikaSQLiteSchema

    public init(
        databaseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let databaseURL = databaseURL.standardizedFileURL
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw PaprikaSQLiteSourceError.missingDatabase(databaseURL)
        }

        do {
            var configuration = Configuration()
            configuration.readonly = true
            self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
            self.schema = try dbQueue.read(PaprikaSQLiteSchema.inspect)
            self.databaseURL = databaseURL
        } catch let error as PaprikaSQLiteSourceError {
            throw error
        } catch {
            throw PaprikaSQLiteSourceError.unreadableDatabase(error.localizedDescription)
        }
    }

    public func listRecipeStubs() async throws -> [SourceRecipeStub] {
        let sql = """
            SELECT
                uid,
                name,
                \(self.schema.recipeSyncHashExpression) AS remote_hash,
                \(self.schema.recipeDeletedExpression) AS is_deleted
            FROM recipes
            ORDER BY name COLLATE NOCASE, uid
            """

        return try await dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                \(sql)
                """
            ).map { row in
                SourceRecipeStub(
                    uid: row["uid"],
                    name: row["name"],
                    hash: row["remote_hash"],
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func listRecipeCategories() async throws -> [SourceRecipeCategory] {
        let sql = """
            SELECT
                uid,
                name,
                \(self.schema.categoryDeletedExpression) AS is_deleted
            FROM categories
            ORDER BY name COLLATE NOCASE, uid
            """

        return try await dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                \(sql)
                """
            ).map { row in
                SourceRecipeCategory(
                    uid: row["uid"],
                    name: row["name"],
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func fetchRecipe(uid: String) async throws -> SourceRecipe {
        let sql = """
            SELECT
                id,
                uid,
                name,
                \(self.schema.optionalTextExpression(column: "source")) AS source_name,
                \(self.schema.optionalTextExpression(column: "ingredients")) AS ingredients,
                \(self.schema.optionalTextExpression(column: "directions")) AS directions,
                \(self.schema.notesExpression) AS notes,
                \(self.schema.ratingExpression) AS star_rating,
                \(self.schema.favoriteExpression) AS is_favorite,
                \(self.schema.optionalTextExpression(column: "prep_time")) AS prep_time,
                \(self.schema.optionalTextExpression(column: "cook_time")) AS cook_time,
                \(self.schema.optionalTextExpression(column: "total_time")) AS total_time,
                \(self.schema.optionalTextExpression(column: "servings")) AS servings,
                \(self.schema.timestampExpression(column: "created")) AS created_at,
                \(self.schema.timestampExpression(column: "updated")) AS updated_at,
                \(self.schema.recipeSyncHashExpression) AS remote_hash,
                \(self.schema.recipeDeletedExpression) AS is_deleted
            FROM recipes
            WHERE uid = ?
            """

        return try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: sql,
                arguments: [uid]
            ) else {
                throw PaprikaSQLiteSourceError.recipeNotFound(uid)
            }

            let recipeID: Int64 = row["id"]
            let categoryReferences = try self.fetchCategoryReferences(recipeID: recipeID, db: db)
            let rawJSON = try self.makeRawJSON(row: row, categoryReferences: categoryReferences)

            return SourceRecipe(
                uid: row["uid"],
                name: row["name"],
                categoryReferences: categoryReferences,
                sourceName: row["source_name"],
                ingredients: row["ingredients"],
                directions: row["directions"],
                notes: row["notes"],
                starRating: Self.decodeRating(row["star_rating"]),
                isFavorite: Self.decodeBoolean(row["is_favorite"]),
                prepTime: row["prep_time"],
                cookTime: row["cook_time"],
                totalTime: row["total_time"],
                servings: row["servings"],
                createdAt: row["created_at"],
                updatedAt: row["updated_at"],
                remoteHash: row["remote_hash"],
                rawJSON: rawJSON
            )
        }
    }

    private func fetchCategoryReferences(recipeID: Int64, db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
                SELECT categories.uid
                FROM recipe_categories
                INNER JOIN categories ON categories.id = recipe_categories.category_id
                WHERE recipe_categories.recipe_id = ?
                ORDER BY categories.name COLLATE NOCASE, categories.uid
                """,
            arguments: [recipeID]
        )
    }

    private func makeRawJSON(row: Row, categoryReferences: [String]) throws -> String {
        let uid: String = row["uid"]
        let name: String = row["name"]
        let sourceName: String? = row["source_name"]
        let ingredients: String? = row["ingredients"]
        let directions: String? = row["directions"]
        let notes: String? = row["notes"]
        let prepTime: String? = row["prep_time"]
        let cookTime: String? = row["cook_time"]
        let totalTime: String? = row["total_time"]
        let servings: String? = row["servings"]
        let createdAt: String? = row["created_at"]
        let updatedAt: String? = row["updated_at"]
        let remoteHash: String? = row["remote_hash"]

        var object: [String: Any] = [
            "uid": uid,
            "name": name,
            "category_uids": categoryReferences,
            "is_deleted": Self.decodeBoolean(row["is_deleted"]),
            "is_favorite": Self.decodeBoolean(row["is_favorite"]),
        ]

        Self.setOptionalValue(in: &object, key: "source", value: sourceName)
        Self.setOptionalValue(in: &object, key: "ingredients", value: ingredients)
        Self.setOptionalValue(in: &object, key: "directions", value: directions)
        Self.setOptionalValue(in: &object, key: "notes", value: notes)
        Self.setOptionalValue(in: &object, key: "rating", value: Self.decodeRating(row["star_rating"]))
        Self.setOptionalValue(in: &object, key: "prep_time", value: prepTime)
        Self.setOptionalValue(in: &object, key: "cook_time", value: cookTime)
        Self.setOptionalValue(in: &object, key: "total_time", value: totalTime)
        Self.setOptionalValue(in: &object, key: "servings", value: servings)
        Self.setOptionalValue(in: &object, key: "created", value: createdAt)
        Self.setOptionalValue(in: &object, key: "updated", value: updatedAt)
        Self.setOptionalValue(in: &object, key: "hash", value: remoteHash)

        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let rawJSON = String(data: data, encoding: .utf8) else {
            throw PaprikaSQLiteSourceError.unreadableDatabase("Database row payload was not valid UTF-8.")
        }
        return rawJSON
    }

    private static func setOptionalValue(
        in object: inout [String: Any],
        key: String,
        value: Any?
    ) {
        guard let value else {
            return
        }
        object[key] = value
    }

    private static func decodeBoolean(_ databaseValue: DatabaseValue) -> Bool {
        if let value = Int64.fromDatabaseValue(databaseValue) {
            return value != 0
        }

        if let value = Bool.fromDatabaseValue(databaseValue) {
            return value
        }

        return false
    }

    private static func decodeRating(_ databaseValue: DatabaseValue) -> Int? {
        guard let value = Int.fromDatabaseValue(databaseValue), value > 0 else {
            return nil
        }

        return value
    }
}

private struct PaprikaSQLiteSchema: Sendable {
    let recipeColumns: Set<String>
    let categoryColumns: Set<String>

    static func inspect(_ db: Database) throws -> PaprikaSQLiteSchema {
        try requireTable("recipes", in: db)
        try requireTable("categories", in: db)
        try requireTable("recipe_categories", in: db)

        let recipeColumns = try Set(db.columns(in: "recipes").map(\.name))
        let categoryColumns = try Set(db.columns(in: "categories").map(\.name))
        let recipeCategoryColumns = try Set(db.columns(in: "recipe_categories").map(\.name))

        try requireColumn("id", in: "recipes", availableColumns: recipeColumns)
        try requireColumn("uid", in: "recipes", availableColumns: recipeColumns)
        try requireColumn("name", in: "recipes", availableColumns: recipeColumns)

        try requireColumn("id", in: "categories", availableColumns: categoryColumns)
        try requireColumn("uid", in: "categories", availableColumns: categoryColumns)
        try requireColumn("name", in: "categories", availableColumns: categoryColumns)

        try requireColumn("recipe_id", in: "recipe_categories", availableColumns: recipeCategoryColumns)
        try requireColumn("category_id", in: "recipe_categories", availableColumns: recipeCategoryColumns)

        return PaprikaSQLiteSchema(
            recipeColumns: recipeColumns,
            categoryColumns: categoryColumns
        )
    }

    var recipeSyncHashExpression: String {
        recipeColumns.contains("sync_hash") ? "sync_hash" : "NULL"
    }

    var recipeDeletedExpression: String {
        recipeColumns.contains("in_trash") ? "COALESCE(in_trash, 0)" : "0"
    }

    var categoryDeletedExpression: String {
        categoryColumns.contains("in_trash") ? "COALESCE(in_trash, 0)" : "0"
    }

    var notesExpression: String {
        switch (recipeColumns.contains("notes"), recipeColumns.contains("description")) {
        case (true, true):
            return "COALESCE(NULLIF(notes, ''), description)"
        case (true, false):
            return "notes"
        case (false, true):
            return "description"
        case (false, false):
            return "NULL"
        }
    }

    var ratingExpression: String {
        recipeColumns.contains("rating") ? "rating" : "NULL"
    }

    var favoriteExpression: String {
        recipeColumns.contains("on_favorites") ? "COALESCE(on_favorites, 0)" : "0"
    }

    func optionalTextExpression(column: String) -> String {
        recipeColumns.contains(column) ? column : "NULL"
    }

    func timestampExpression(column: String) -> String {
        recipeColumns.contains(column)
            ? "CASE WHEN \(column) IS NULL THEN NULL ELSE strftime('%Y-%m-%d %H:%M:%S', \(column)) END"
            : "NULL"
    }

    private static func requireTable(_ name: String, in db: Database) throws {
        guard try db.tableExists(name) else {
            throw PaprikaSQLiteSourceError.missingTable(name)
        }
    }

    private static func requireColumn(
        _ name: String,
        in table: String,
        availableColumns: Set<String>
    ) throws {
        guard availableColumns.contains(name) else {
            throw PaprikaSQLiteSourceError.missingColumn(table: table, column: name)
        }
    }
}
