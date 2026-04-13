import Foundation
import GRDB

public struct MirroredRecipeInput: Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let ingredients: String?
    public let directions: String?
    public let notes: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let prepTime: String?
    public let cookTime: String?
    public let totalTime: String?
    public let servings: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let remoteHash: String?
    public let rawJSON: String

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        ingredients: String?,
        directions: String?,
        notes: String?,
        starRating: Int?,
        isFavorite: Bool,
        prepTime: String?,
        cookTime: String?,
        totalTime: String?,
        servings: String?,
        createdAt: String?,
        updatedAt: String?,
        remoteHash: String?,
        rawJSON: String
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.ingredients = ingredients
        self.directions = directions
        self.notes = notes
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteHash = remoteHash
        self.rawJSON = rawJSON
    }
}

public struct RecipeMirrorIndexEntry: Equatable, Sendable {
    public let uid: String
    public let remoteHash: String?
    public let isDeleted: Bool

    public init(uid: String, remoteHash: String?, isDeleted: Bool) {
        self.uid = uid
        self.remoteHash = remoteHash
        self.isDeleted = isDeleted
    }
}

public struct MirroredRecipe: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let ingredients: String?
    public let directions: String?
    public let notes: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let prepTime: String?
    public let cookTime: String?
    public let totalTime: String?
    public let servings: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let remoteHash: String?
    public let isDeleted: Bool
    public let lastSyncedAt: Date?
    public let rawJSON: String

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        ingredients: String?,
        directions: String?,
        notes: String?,
        starRating: Int?,
        isFavorite: Bool,
        prepTime: String?,
        cookTime: String?,
        totalTime: String?,
        servings: String?,
        createdAt: String?,
        updatedAt: String?,
        remoteHash: String?,
        isDeleted: Bool,
        lastSyncedAt: Date?,
        rawJSON: String
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.ingredients = ingredients
        self.directions = directions
        self.notes = notes
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteHash = remoteHash
        self.isDeleted = isDeleted
        self.lastSyncedAt = lastSyncedAt
        self.rawJSON = rawJSON
    }
}

public struct MirroredRecipeSummary: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let updatedAt: String?
    public let lastSyncedAt: Date?

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        starRating: Int?,
        isFavorite: Bool,
        updatedAt: String?,
        lastSyncedAt: Date?
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
    }
}

public enum PantrySyncRunStatus: String, Codable, Equatable, Sendable {
    case running
    case success
    case failed
}

public struct PantrySyncRun: Codable, Equatable, Sendable {
    public let id: Int64
    public let startedAt: Date
    public let finishedAt: Date?
    public let status: PantrySyncRunStatus
    public let recipesSeen: Int
    public let recipesChanged: Int
    public let recipesDeleted: Int
    public let errorMessage: String?

    public init(
        id: Int64,
        startedAt: Date,
        finishedAt: Date?,
        status: PantrySyncRunStatus,
        recipesSeen: Int,
        recipesChanged: Int,
        recipesDeleted: Int,
        errorMessage: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.recipesSeen = recipesSeen
        self.recipesChanged = recipesChanged
        self.recipesDeleted = recipesDeleted
        self.errorMessage = errorMessage
    }
}

public struct PantrySyncStatusSnapshot: Codable, Equatable, Sendable {
    public let lastAttempt: PantrySyncRun?
    public let lastSuccess: PantrySyncRun?
    public let totalRecipeCount: Int
    public let activeRecipeCount: Int
    public let deletedRecipeCount: Int

    public init(
        lastAttempt: PantrySyncRun?,
        lastSuccess: PantrySyncRun?,
        totalRecipeCount: Int,
        activeRecipeCount: Int,
        deletedRecipeCount: Int
    ) {
        self.lastAttempt = lastAttempt
        self.lastSuccess = lastSuccess
        self.totalRecipeCount = totalRecipeCount
        self.activeRecipeCount = activeRecipeCount
        self.deletedRecipeCount = deletedRecipeCount
    }

    public var hasSuccessfulSync: Bool {
        lastSuccess != nil
    }
}

public struct PantryDatabaseStats: Codable, Equatable, Sendable {
    public let totalRecipeCount: Int
    public let activeRecipeCount: Int
    public let deletedRecipeCount: Int
    public let favoriteRecipeCount: Int
    public let categoryLinkCount: Int
    public let syncRunCount: Int

    public init(
        totalRecipeCount: Int,
        activeRecipeCount: Int,
        deletedRecipeCount: Int,
        favoriteRecipeCount: Int,
        categoryLinkCount: Int,
        syncRunCount: Int
    ) {
        self.totalRecipeCount = totalRecipeCount
        self.activeRecipeCount = activeRecipeCount
        self.deletedRecipeCount = deletedRecipeCount
        self.favoriteRecipeCount = favoriteRecipeCount
        self.categoryLinkCount = categoryLinkCount
        self.syncRunCount = syncRunCount
    }
}

public struct PantryStore: @unchecked Sendable {
    public let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func write(_ updates: (Database) throws -> Void) throws {
        try dbQueue.write(updates)
    }

    public func fetchRecipeIndex() throws -> [String: RecipeMirrorIndexEntry] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT uid, remote_hash, is_deleted
                FROM recipes
                """
            )

            return Dictionary(uniqueKeysWithValues: rows.map { row in
                let uid: String = row["uid"]
                let entry = RecipeMirrorIndexEntry(
                    uid: uid,
                    remoteHash: row["remote_hash"],
                    isDeleted: row["is_deleted"]
                )
                return (uid, entry)
            })
        }
    }

    public func upsertRecipe(_ recipe: MirroredRecipeInput, syncedAt: Date) throws {
        try dbQueue.write { db in
            try upsertRecipe(recipe, syncedAt: syncedAt, in: db)
        }
    }

    public func listRecipes() throws -> [MirroredRecipeSummary] {
        try dbQueue.read { db in
            let rows = try RecipeRow.fetchAll(
                db,
                sql: """
                SELECT *
                FROM recipes
                WHERE is_deleted = 0
                ORDER BY name COLLATE NOCASE ASC, uid ASC
                """
            )
            let categoriesByUID = try fetchCategoriesByRecipeUID(for: rows.map(\.uid), db: db)

            return rows.map { row in
                MirroredRecipeSummary(
                    uid: row.uid,
                    name: row.name,
                    categories: categoriesByUID[row.uid] ?? [],
                    sourceName: row.sourceName,
                    starRating: row.starRating,
                    isFavorite: row.isFavorite,
                    updatedAt: row.updatedAt,
                    lastSyncedAt: DatabaseTimestamp.decode(row.lastSyncedAt)
                )
            }
        }
    }

    public func fetchRecipe(uid: String) throws -> MirroredRecipe? {
        try dbQueue.read { db in
            guard let row = try RecipeRow.fetchOne(
                db,
                sql: """
                SELECT *
                FROM recipes
                WHERE uid = ? AND is_deleted = 0
                """,
                arguments: [uid]
            ) else {
                return nil
            }

            let categories = try fetchCategories(recipeUID: uid, db: db)
            return mirroredRecipe(from: row, categories: categories)
        }
    }

    public func fetchRecipes(namedExactlyCaseInsensitive name: String) throws -> [MirroredRecipe] {
        try dbQueue.read { db in
            let rows = try RecipeRow.fetchAll(
                db,
                sql: """
                SELECT *
                FROM recipes
                WHERE is_deleted = 0
                  AND lower(name) = lower(?)
                ORDER BY uid ASC
                """,
                arguments: [name]
            )
            let categoriesByUID = try fetchCategoriesByRecipeUID(for: rows.map(\.uid), db: db)
            return rows.map { mirroredRecipe(from: $0, categories: categoriesByUID[$0.uid] ?? []) }
        }
    }

    public func tombstoneRecipes(missingFrom remoteUIDs: Set<String>, syncedAt: Date) throws -> Int {
        try dbQueue.write { db in
            try tombstoneRecipes(missingFrom: remoteUIDs, syncedAt: syncedAt, in: db)
        }
    }

    public func startSyncRun(startedAt: Date) throws -> Int64 {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO sync_runs (
                    started_at,
                    status
                ) VALUES (?, ?)
                """,
                arguments: [
                    DatabaseTimestamp.encode(startedAt),
                    PantrySyncRunStatus.running.rawValue,
                ]
            )
            return db.lastInsertedRowID
        }
    }

    public func finishSyncRun(
        id: Int64,
        status: PantrySyncRunStatus,
        finishedAt: Date,
        recipesSeen: Int,
        recipesChanged: Int,
        recipesDeleted: Int,
        errorMessage: String?
    ) throws {
        try dbQueue.write { db in
            try finishSyncRun(
                id: id,
                status: status,
                finishedAt: finishedAt,
                recipesSeen: recipesSeen,
                recipesChanged: recipesChanged,
                recipesDeleted: recipesDeleted,
                errorMessage: errorMessage,
                in: db
            )
        }
    }

    public func latestSyncRun() throws -> PantrySyncRun? {
        try dbQueue.read { db in
            try fetchSyncRun(
                db,
                sql: """
                SELECT *
                FROM sync_runs
                ORDER BY started_at DESC, id DESC
                LIMIT 1
                """
            )
        }
    }

    public func latestSuccessfulSyncRun() throws -> PantrySyncRun? {
        try dbQueue.read { db in
            try fetchSyncRun(
                db,
                sql: """
                SELECT *
                FROM sync_runs
                WHERE status = ?
                ORDER BY finished_at DESC, id DESC
                LIMIT 1
                """,
                arguments: [PantrySyncRunStatus.success.rawValue]
            )
        }
    }

    public func syncStatus() throws -> PantrySyncStatusSnapshot {
        let stats = try stats()
        return PantrySyncStatusSnapshot(
            lastAttempt: try latestSyncRun(),
            lastSuccess: try latestSuccessfulSyncRun(),
            totalRecipeCount: stats.totalRecipeCount,
            activeRecipeCount: stats.activeRecipeCount,
            deletedRecipeCount: stats.deletedRecipeCount
        )
    }

    public func stats() throws -> PantryDatabaseStats {
        try dbQueue.read { db in
            PantryDatabaseStats(
                totalRecipeCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes") ?? 0,
                activeRecipeCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes WHERE is_deleted = 0") ?? 0,
                deletedRecipeCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes WHERE is_deleted = 1") ?? 0,
                favoriteRecipeCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipes WHERE is_deleted = 0 AND is_favorite = 1") ?? 0,
                categoryLinkCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_categories") ?? 0,
                syncRunCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sync_runs") ?? 0
            )
        }
    }

    func upsertRecipe(_ recipe: MirroredRecipeInput, syncedAt: Date, in db: Database) throws {
        try db.execute(
            sql: """
            INSERT INTO recipes (
                uid,
                name,
                source_name,
                ingredients,
                directions,
                notes,
                star_rating,
                is_favorite,
                prep_time,
                cook_time,
                total_time,
                servings,
                created_at,
                updated_at,
                remote_hash,
                is_deleted,
                last_synced_at,
                raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            ON CONFLICT(uid) DO UPDATE SET
                name = excluded.name,
                source_name = excluded.source_name,
                ingredients = excluded.ingredients,
                directions = excluded.directions,
                notes = excluded.notes,
                star_rating = excluded.star_rating,
                is_favorite = excluded.is_favorite,
                prep_time = excluded.prep_time,
                cook_time = excluded.cook_time,
                total_time = excluded.total_time,
                servings = excluded.servings,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                remote_hash = excluded.remote_hash,
                is_deleted = 0,
                last_synced_at = excluded.last_synced_at,
                raw_json = excluded.raw_json
            """,
            arguments: [
                recipe.uid,
                recipe.name,
                recipe.sourceName,
                recipe.ingredients,
                recipe.directions,
                recipe.notes,
                recipe.starRating,
                recipe.isFavorite,
                recipe.prepTime,
                recipe.cookTime,
                recipe.totalTime,
                recipe.servings,
                recipe.createdAt,
                recipe.updatedAt,
                recipe.remoteHash,
                DatabaseTimestamp.encode(syncedAt),
                recipe.rawJSON,
            ]
        )

        try replaceCategories(recipe.categories, forRecipeUID: recipe.uid, in: db)
    }

    func replaceCategories(_ categories: [String], forRecipeUID recipeUID: String, in db: Database) throws {
        try db.execute(
            sql: "DELETE FROM recipe_categories WHERE recipe_uid = ?",
            arguments: [recipeUID]
        )

        for category in normalizedCategories(categories) {
            try db.execute(
                sql: """
                INSERT INTO recipe_categories (
                    recipe_uid,
                    category_name
                ) VALUES (?, ?)
                """,
                arguments: [recipeUID, category]
            )
        }
    }

    func tombstoneRecipes(missingFrom remoteUIDs: Set<String>, syncedAt: Date, in db: Database) throws -> Int {
        let localUIDs = Set(try String.fetchAll(
            db,
            sql: """
            SELECT uid
            FROM recipes
            WHERE is_deleted = 0
            """
        ))

        let missingUIDs = localUIDs.subtracting(remoteUIDs)
        guard !missingUIDs.isEmpty else {
            return 0
        }

        let timestamp = DatabaseTimestamp.encode(syncedAt)
        for uid in missingUIDs.sorted() {
            try db.execute(
                sql: """
                UPDATE recipes
                SET is_deleted = 1,
                    last_synced_at = ?
                WHERE uid = ?
                """,
                arguments: [timestamp, uid]
            )
        }

        return missingUIDs.count
    }

    func finishSyncRun(
        id: Int64,
        status: PantrySyncRunStatus,
        finishedAt: Date,
        recipesSeen: Int,
        recipesChanged: Int,
        recipesDeleted: Int,
        errorMessage: String?,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            UPDATE sync_runs
            SET finished_at = ?,
                status = ?,
                recipes_seen = ?,
                recipes_changed = ?,
                recipes_deleted = ?,
                error_message = ?
            WHERE id = ?
            """,
            arguments: [
                DatabaseTimestamp.encode(finishedAt),
                status.rawValue,
                recipesSeen,
                recipesChanged,
                recipesDeleted,
                errorMessage,
                id,
            ]
        )
    }

    private func mirroredRecipe(from row: RecipeRow, categories: [String]) -> MirroredRecipe {
        MirroredRecipe(
            uid: row.uid,
            name: row.name,
            categories: categories,
            sourceName: row.sourceName,
            ingredients: row.ingredients,
            directions: row.directions,
            notes: row.notes,
            starRating: row.starRating,
            isFavorite: row.isFavorite,
            prepTime: row.prepTime,
            cookTime: row.cookTime,
            totalTime: row.totalTime,
            servings: row.servings,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
            remoteHash: row.remoteHash,
            isDeleted: row.isDeleted,
            lastSyncedAt: DatabaseTimestamp.decode(row.lastSyncedAt),
            rawJSON: row.rawJSON
        )
    }

    private func fetchCategories(recipeUID: String, db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
            SELECT category_name
            FROM recipe_categories
            WHERE recipe_uid = ?
            ORDER BY category_name COLLATE NOCASE ASC
            """,
            arguments: [recipeUID]
        )
    }

    private func fetchCategoriesByRecipeUID(for recipeUIDs: [String], db: Database) throws -> [String: [String]] {
        guard !recipeUIDs.isEmpty else {
            return [:]
        }

        let rows = try RecipeCategoryRow
            .filter(recipeUIDs.contains(Column("recipe_uid")))
            .order(Column("category_name").collating(.nocase))
            .fetchAll(db)

        return rows.reduce(into: [:]) { partialResult, row in
            partialResult[row.recipeUID, default: []].append(row.categoryName)
        }
    }

    private func fetchSyncRun(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments()
    ) throws -> PantrySyncRun? {
        guard let row = try SyncRunRow.fetchOne(db, sql: sql, arguments: arguments) else {
            return nil
        }

        return PantrySyncRun(
            id: row.id,
            startedAt: DatabaseTimestamp.decodeRequired(row.startedAt),
            finishedAt: DatabaseTimestamp.decode(row.finishedAt),
            status: PantrySyncRunStatus(rawValue: row.status) ?? .failed,
            recipesSeen: row.recipesSeen,
            recipesChanged: row.recipesChanged,
            recipesDeleted: row.recipesDeleted,
            errorMessage: row.errorMessage
        )
    }

    private func normalizedCategories(_ categories: [String]) -> [String] {
        Array(Set(categories.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

private struct RecipeRow: FetchableRecord, Decodable {
    let uid: String
    let name: String
    let sourceName: String?
    let ingredients: String?
    let directions: String?
    let notes: String?
    let starRating: Int?
    let isFavorite: Bool
    let prepTime: String?
    let cookTime: String?
    let totalTime: String?
    let servings: String?
    let createdAt: String?
    let updatedAt: String?
    let remoteHash: String?
    let isDeleted: Bool
    let lastSyncedAt: String?
    let rawJSON: String

    enum CodingKeys: String, CodingKey {
        case uid
        case name
        case sourceName = "source_name"
        case ingredients
        case directions
        case notes
        case starRating = "star_rating"
        case isFavorite = "is_favorite"
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case totalTime = "total_time"
        case servings
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case remoteHash = "remote_hash"
        case isDeleted = "is_deleted"
        case lastSyncedAt = "last_synced_at"
        case rawJSON = "raw_json"
    }
}

private struct RecipeCategoryRow: FetchableRecord, Decodable, TableRecord {
    static let databaseTableName = "recipe_categories"

    let recipeUID: String
    let categoryName: String

    enum CodingKeys: String, CodingKey {
        case recipeUID = "recipe_uid"
        case categoryName = "category_name"
    }
}

private struct SyncRunRow: FetchableRecord, Decodable {
    let id: Int64
    let startedAt: String
    let finishedAt: String?
    let status: String
    let recipesSeen: Int
    let recipesChanged: Int
    let recipesDeleted: Int
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status
        case recipesSeen = "recipes_seen"
        case recipesChanged = "recipes_changed"
        case recipesDeleted = "recipes_deleted"
        case errorMessage = "error_message"
    }
}

enum DatabaseTimestamp {
    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    static func decode(_ value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    static func decodeRequired(_ value: String) -> Date {
        decode(value) ?? Date(timeIntervalSince1970: 0)
    }
}
