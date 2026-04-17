import Foundation
import GRDB

public enum PantryIndexRunStatus: String, Codable, Equatable, Sendable {
    case running
    case success
    case failed
}

public struct PantryIndexRun: Codable, Equatable, Sendable {
    public let id: Int64
    public let startedAt: Date
    public let finishedAt: Date?
    public let status: PantryIndexRunStatus
    public let indexName: String
    public let recipeCount: Int
    public let errorMessage: String?

    public init(
        id: Int64,
        startedAt: Date,
        finishedAt: Date?,
        status: PantryIndexRunStatus,
        indexName: String,
        recipeCount: Int,
        errorMessage: String?
    ) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.indexName = indexName
        self.recipeCount = recipeCount
        self.errorMessage = errorMessage
    }
}

public struct PantryIndexStats: Codable, Equatable, Sendable {
    public let recipeSearchDocumentCount: Int
    public let lastRecipeSearchRun: PantryIndexRun?
    public let lastSuccessfulRecipeSearchRun: PantryIndexRun?

    public init(
        recipeSearchDocumentCount: Int,
        lastRecipeSearchRun: PantryIndexRun?,
        lastSuccessfulRecipeSearchRun: PantryIndexRun?
    ) {
        self.recipeSearchDocumentCount = recipeSearchDocumentCount
        self.lastRecipeSearchRun = lastRecipeSearchRun
        self.lastSuccessfulRecipeSearchRun = lastSuccessfulRecipeSearchRun
    }

    public var recipeSearchReady: Bool {
        recipeSearchDocumentCount > 0 && lastSuccessfulRecipeSearchRun != nil
    }
}

public struct IndexedRecipeSearchResult: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let isFavorite: Bool
    public let starRating: Int?

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        isFavorite: Bool,
        starRating: Int?
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.isFavorite = isFavorite
        self.starRating = starRating
    }
}

public struct RecipeSearchIndexRebuildSummary: Codable, Equatable, Sendable {
    public let startedAt: Date
    public let finishedAt: Date
    public let recipeCount: Int

    public init(startedAt: Date, finishedAt: Date, recipeCount: Int) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.recipeCount = recipeCount
    }
}

public struct PantryStore: @unchecked Sendable {
    public let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func indexStats() throws -> PantryIndexStats {
        try dbQueue.read { db in
            PantryIndexStats(
                recipeSearchDocumentCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_search_documents") ?? 0,
                lastRecipeSearchRun: try latestIndexRun(named: Self.recipeSearchIndexName, db: db),
                lastSuccessfulRecipeSearchRun: try latestSuccessfulIndexRun(named: Self.recipeSearchIndexName, db: db)
            )
        }
    }

    public func searchRecipes(query: String, limit: Int = 20) throws -> [IndexedRecipeSearchResult] {
        let normalizedQuery = Self.normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT uid, name, categories, source_name, is_favorite, star_rating
                FROM recipe_search_documents
                WHERE uid IN (
                    SELECT uid
                    FROM recipe_search_fts
                    WHERE recipe_search_fts MATCH ?
                )
                ORDER BY name COLLATE NOCASE ASC, uid ASC
                LIMIT ?
                """,
                arguments: [normalizedQuery, max(1, limit)]
            )

            return rows.map { row in
                IndexedRecipeSearchResult(
                    uid: row["uid"],
                    name: row["name"],
                    categories: Self.decodeCategories(row["categories"]),
                    sourceName: row["source_name"],
                    isFavorite: row["is_favorite"],
                    starRating: row["star_rating"]
                )
            }
        }
    }

    public func rebuildRecipeSearchIndex(
        from source: any PantrySource,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> RecipeSearchIndexRebuildSummary {
        let startedAt = now()
        let runID = try startIndexRun(named: Self.recipeSearchIndexName, startedAt: startedAt)

        do {
            let categoryNamesByUID = try await loadCategoryNamesByUID(from: source)
            let stubs = try await source.listRecipeStubs()
            let activeStubs = stubs.filter { !$0.isDeleted }

            var documents = [RecipeSearchDocument]()
            documents.reserveCapacity(activeStubs.count)

            for stub in activeStubs {
                let recipe = try await source.fetchRecipe(uid: stub.uid)
                documents.append(
                    RecipeSearchDocument(
                        uid: recipe.uid,
                        name: recipe.name,
                        categories: resolvedCategories(
                            recipe.categoryReferences,
                            categoryNamesByUID: categoryNamesByUID
                        ),
                        sourceName: recipe.sourceName,
                        ingredients: recipe.ingredients,
                        notes: recipe.notes,
                        remoteHash: recipe.remoteHash,
                        isFavorite: recipe.isFavorite,
                        starRating: recipe.starRating
                    )
                )
            }

            let finishedAt = now()
            let sortedDocuments = documents.sorted(by: Self.sortSearchDocuments)
            let recipeCount = sortedDocuments.count
            try await dbQueue.write { db in
                try db.execute(sql: "DELETE FROM recipe_search_documents")
                try db.execute(sql: "DELETE FROM recipe_search_fts")

                for document in sortedDocuments {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_search_documents (
                            uid,
                            name,
                            categories,
                            source_name,
                            ingredients,
                            notes,
                            remote_hash,
                            indexed_at,
                            is_favorite,
                            star_rating
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            document.uid,
                            document.name,
                            Self.encodeCategories(document.categories),
                            document.sourceName,
                            document.ingredients,
                            document.notes,
                            document.remoteHash,
                            DatabaseTimestamp.encode(finishedAt),
                            document.isFavorite,
                            document.starRating,
                        ]
                    )

                    try db.execute(
                        sql: """
                        INSERT INTO recipe_search_fts (
                            uid,
                            name,
                            categories,
                            source_name,
                            ingredients,
                            notes
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            document.uid,
                            document.name,
                            document.categories.joined(separator: " "),
                            document.sourceName,
                            document.ingredients,
                            document.notes,
                        ]
                    )
                }

                try finishIndexRun(
                    id: runID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: recipeCount,
                    errorMessage: nil,
                    in: db
                )
            }

            return RecipeSearchIndexRebuildSummary(
                startedAt: startedAt,
                finishedAt: finishedAt,
                recipeCount: recipeCount
            )
        } catch {
            try finishIndexRun(
                id: runID,
                status: .failed,
                finishedAt: now(),
                recipeCount: 0,
                errorMessage: String(describing: error)
            )
            throw error
        }
    }

    private func latestIndexRun(named indexName: String, db: Database) throws -> PantryIndexRun? {
        try fetchIndexRun(
            db,
            sql: """
            SELECT *
            FROM index_runs
            WHERE index_name = ?
            ORDER BY started_at DESC, id DESC
            LIMIT 1
            """,
            arguments: [indexName]
        )
    }

    private func latestSuccessfulIndexRun(named indexName: String, db: Database) throws -> PantryIndexRun? {
        try fetchIndexRun(
            db,
            sql: """
            SELECT *
            FROM index_runs
            WHERE index_name = ? AND status = ?
            ORDER BY finished_at DESC, id DESC
            LIMIT 1
            """,
            arguments: [indexName, PantryIndexRunStatus.success.rawValue]
        )
    }

    private func fetchIndexRun(
        _ db: Database,
        sql: String,
        arguments: StatementArguments = StatementArguments()
    ) throws -> PantryIndexRun? {
        guard let row = try IndexRunRow.fetchOne(db, sql: sql, arguments: arguments) else {
            return nil
        }

        return PantryIndexRun(
            id: row.id,
            startedAt: DatabaseTimestamp.decodeRequired(row.startedAt),
            finishedAt: DatabaseTimestamp.decode(row.finishedAt),
            status: PantryIndexRunStatus(rawValue: row.status) ?? .failed,
            indexName: row.indexName,
            recipeCount: row.recipeCount,
            errorMessage: row.errorMessage
        )
    }

    private func startIndexRun(named indexName: String, startedAt: Date) throws -> Int64 {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO index_runs (
                    started_at,
                    status,
                    index_name
                ) VALUES (?, ?, ?)
                """,
                arguments: [
                    DatabaseTimestamp.encode(startedAt),
                    PantryIndexRunStatus.running.rawValue,
                    indexName,
                ]
            )
            return db.lastInsertedRowID
        }
    }

    private func finishIndexRun(
        id: Int64,
        status: PantryIndexRunStatus,
        finishedAt: Date,
        recipeCount: Int,
        errorMessage: String?
    ) throws {
        try dbQueue.write { db in
            try finishIndexRun(
                id: id,
                status: status,
                finishedAt: finishedAt,
                recipeCount: recipeCount,
                errorMessage: errorMessage,
                in: db
            )
        }
    }

    private func finishIndexRun(
        id: Int64,
        status: PantryIndexRunStatus,
        finishedAt: Date,
        recipeCount: Int,
        errorMessage: String?,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            UPDATE index_runs
            SET finished_at = ?,
                status = ?,
                recipe_count = ?,
                error_message = ?
            WHERE id = ?
            """,
            arguments: [
                DatabaseTimestamp.encode(finishedAt),
                status.rawValue,
                recipeCount,
                errorMessage,
                id,
            ]
        )
    }

    private func loadCategoryNamesByUID(from source: any PantrySource) async throws -> [String: String] {
        let categories = try await source.listRecipeCategories()
        return Dictionary(
            uniqueKeysWithValues: categories
                .filter { !$0.isDeleted }
                .map { ($0.uid, $0.name) }
        )
    }

    private func resolvedCategories(
        _ references: [String],
        categoryNamesByUID: [String: String]
    ) -> [String] {
        references.map { categoryNamesByUID[$0] ?? $0 }
    }

    private static let recipeSearchIndexName = "recipe-search"

    private static func sortSearchDocuments(lhs: RecipeSearchDocument, rhs: RecipeSearchDocument) -> Bool {
        if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
            return lhs.uid < rhs.uid
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func normalizedSearchQuery(_ query: String) -> String {
        query
            .split(whereSeparator: \.isWhitespace)
            .map { "\"\($0.replacing("\"", with: "\"\""))\"" }
            .joined(separator: " ")
    }

    private static func encodeCategories(_ categories: [String]) -> String {
        categories.joined(separator: "\u{1F}")
    }

    private static func decodeCategories(_ value: String) -> [String] {
        value.split(separator: "\u{1F}").map(String.init)
    }
}

private struct IndexRunRow: FetchableRecord, Decodable {
    let id: Int64
    let startedAt: String
    let finishedAt: String?
    let status: String
    let indexName: String
    let recipeCount: Int
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status
        case indexName = "index_name"
        case recipeCount = "recipe_count"
        case errorMessage = "error_message"
    }
}

private struct RecipeSearchDocument: Equatable, Sendable {
    let uid: String
    let name: String
    let categories: [String]
    let sourceName: String?
    let ingredients: String?
    let notes: String?
    let remoteHash: String?
    let isFavorite: Bool
    let starRating: Int?
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

        return decodeRequired(value)
    }

    static func decodeRequired(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
            ?? ISO8601DateFormatter().date(from: value)
            ?? Date(timeIntervalSince1970: 0)
    }
}
