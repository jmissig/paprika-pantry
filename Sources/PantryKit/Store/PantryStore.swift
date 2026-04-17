import ArgumentParser
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
    public let recipeFeatureCount: Int
    public let recipeFeaturesWithTotalTimeCount: Int
    public let recipeFeaturesWithIngredientLineCountCount: Int
    public let recipeIngredientRecipeCount: Int
    public let recipeIngredientLineCount: Int
    public let recipeIngredientTokenCount: Int
    public let lastRecipeSearchRun: PantryIndexRun?
    public let lastSuccessfulRecipeSearchRun: PantryIndexRun?
    public let lastRecipeFeatureRun: PantryIndexRun?
    public let lastSuccessfulRecipeFeatureRun: PantryIndexRun?
    public let lastRecipeIngredientRun: PantryIndexRun?
    public let lastSuccessfulRecipeIngredientRun: PantryIndexRun?

    public init(
        recipeSearchDocumentCount: Int,
        recipeFeatureCount: Int,
        recipeFeaturesWithTotalTimeCount: Int,
        recipeFeaturesWithIngredientLineCountCount: Int,
        recipeIngredientRecipeCount: Int = 0,
        recipeIngredientLineCount: Int = 0,
        recipeIngredientTokenCount: Int = 0,
        lastRecipeSearchRun: PantryIndexRun?,
        lastSuccessfulRecipeSearchRun: PantryIndexRun?,
        lastRecipeFeatureRun: PantryIndexRun?,
        lastSuccessfulRecipeFeatureRun: PantryIndexRun?,
        lastRecipeIngredientRun: PantryIndexRun? = nil,
        lastSuccessfulRecipeIngredientRun: PantryIndexRun? = nil
    ) {
        self.recipeSearchDocumentCount = recipeSearchDocumentCount
        self.recipeFeatureCount = recipeFeatureCount
        self.recipeFeaturesWithTotalTimeCount = recipeFeaturesWithTotalTimeCount
        self.recipeFeaturesWithIngredientLineCountCount = recipeFeaturesWithIngredientLineCountCount
        self.recipeIngredientRecipeCount = recipeIngredientRecipeCount
        self.recipeIngredientLineCount = recipeIngredientLineCount
        self.recipeIngredientTokenCount = recipeIngredientTokenCount
        self.lastRecipeSearchRun = lastRecipeSearchRun
        self.lastSuccessfulRecipeSearchRun = lastSuccessfulRecipeSearchRun
        self.lastRecipeFeatureRun = lastRecipeFeatureRun
        self.lastSuccessfulRecipeFeatureRun = lastSuccessfulRecipeFeatureRun
        self.lastRecipeIngredientRun = lastRecipeIngredientRun
        self.lastSuccessfulRecipeIngredientRun = lastSuccessfulRecipeIngredientRun
    }

    public var recipeSearchReady: Bool {
        recipeSearchDocumentCount > 0 && lastSuccessfulRecipeSearchRun != nil
    }

    public var recipeFeaturesReady: Bool {
        recipeFeatureCount > 0 && lastSuccessfulRecipeFeatureRun != nil
    }

    public var recipeIngredientIndexReady: Bool {
        lastSuccessfulRecipeIngredientRun != nil
    }
}

public enum CookbookAggregateSort: String, CaseIterable, Codable, Sendable, ExpressibleByArgument {
    case averageRating = "average-rating"
    case favoriteRate = "favorite-rate"
    case favorites
    case ratedRecipes = "rated-recipes"
    case recipes
    case name
}

public struct CookbookRatingDistribution: Codable, Equatable, Sendable {
    public let oneStarCount: Int
    public let twoStarCount: Int
    public let threeStarCount: Int
    public let fourStarCount: Int
    public let fiveStarCount: Int

    public init(
        oneStarCount: Int,
        twoStarCount: Int,
        threeStarCount: Int,
        fourStarCount: Int,
        fiveStarCount: Int
    ) {
        self.oneStarCount = oneStarCount
        self.twoStarCount = twoStarCount
        self.threeStarCount = threeStarCount
        self.fourStarCount = fourStarCount
        self.fiveStarCount = fiveStarCount
    }
}

public struct CookbookAggregateSummary: Codable, Equatable, Sendable {
    public let sourceName: String?
    public let isUnlabeled: Bool
    public let recipeCount: Int
    public let ratedRecipeCount: Int
    public let unratedRecipeCount: Int
    public let favoriteRecipeCount: Int
    public let averageStarRating: Double?
    public let ratedRecipeShare: Double
    public let favoriteRecipeShare: Double
    public let ratingDistribution: CookbookRatingDistribution

    public init(
        sourceName: String?,
        isUnlabeled: Bool,
        recipeCount: Int,
        ratedRecipeCount: Int,
        unratedRecipeCount: Int,
        favoriteRecipeCount: Int,
        averageStarRating: Double?,
        ratedRecipeShare: Double,
        favoriteRecipeShare: Double,
        ratingDistribution: CookbookRatingDistribution
    ) {
        self.sourceName = sourceName
        self.isUnlabeled = isUnlabeled
        self.recipeCount = recipeCount
        self.ratedRecipeCount = ratedRecipeCount
        self.unratedRecipeCount = unratedRecipeCount
        self.favoriteRecipeCount = favoriteRecipeCount
        self.averageStarRating = averageStarRating
        self.ratedRecipeShare = ratedRecipeShare
        self.favoriteRecipeShare = favoriteRecipeShare
        self.ratingDistribution = ratingDistribution
    }
}

public struct IndexedRecipeSearchResult: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categories: [String]
    public let sourceName: String?
    public let isFavorite: Bool
    public let starRating: Int?
    public let derivedFeatures: RecipeDerivedFeatures?

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        isFavorite: Bool,
        starRating: Int?,
        derivedFeatures: RecipeDerivedFeatures? = nil
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.isFavorite = isFavorite
        self.starRating = starRating
        self.derivedFeatures = derivedFeatures
    }
}

public struct RecipeIndexesRebuildSummary: Codable, Equatable, Sendable {
    public let startedAt: Date
    public let finishedAt: Date
    public let recipeSearchDocumentCount: Int
    public let recipeFeatureCount: Int
    public let recipeFeaturesWithTotalTimeCount: Int
    public let recipeFeaturesWithIngredientLineCountCount: Int
    public let recipeIngredientRecipeCount: Int
    public let recipeIngredientLineCount: Int
    public let recipeIngredientTokenCount: Int

    public init(
        startedAt: Date,
        finishedAt: Date,
        recipeSearchDocumentCount: Int,
        recipeFeatureCount: Int,
        recipeFeaturesWithTotalTimeCount: Int,
        recipeFeaturesWithIngredientLineCountCount: Int,
        recipeIngredientRecipeCount: Int = 0,
        recipeIngredientLineCount: Int = 0,
        recipeIngredientTokenCount: Int = 0
    ) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.recipeSearchDocumentCount = recipeSearchDocumentCount
        self.recipeFeatureCount = recipeFeatureCount
        self.recipeFeaturesWithTotalTimeCount = recipeFeaturesWithTotalTimeCount
        self.recipeFeaturesWithIngredientLineCountCount = recipeFeaturesWithIngredientLineCountCount
        self.recipeIngredientRecipeCount = recipeIngredientRecipeCount
        self.recipeIngredientLineCount = recipeIngredientLineCount
        self.recipeIngredientTokenCount = recipeIngredientTokenCount
    }
}

public enum RecipeTotalTimeBasis: String, Codable, Equatable, Sendable {
    case sourceTotalTime = "source-total-time"
    case summedPrepAndCook = "prep-plus-cook"
}

public enum RecipeIngredientLineCountBasis: String, Codable, Equatable, Sendable {
    case nonEmptyLines = "non-empty-ingredient-lines"
}

public struct RecipeDerivedFeatures: Codable, Equatable, Sendable {
    public let uid: String
    public let sourceRemoteHash: String?
    public let derivedAt: Date
    public let prepTimeMinutes: Int?
    public let cookTimeMinutes: Int?
    public let totalTimeMinutes: Int?
    public let totalTimeBasis: RecipeTotalTimeBasis?
    public let ingredientLineCount: Int?
    public let ingredientLineCountBasis: RecipeIngredientLineCountBasis?

    public init(
        uid: String,
        sourceRemoteHash: String?,
        derivedAt: Date,
        prepTimeMinutes: Int?,
        cookTimeMinutes: Int?,
        totalTimeMinutes: Int?,
        totalTimeBasis: RecipeTotalTimeBasis?,
        ingredientLineCount: Int?,
        ingredientLineCountBasis: RecipeIngredientLineCountBasis?
    ) {
        self.uid = uid
        self.sourceRemoteHash = sourceRemoteHash
        self.derivedAt = derivedAt
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = totalTimeMinutes
        self.totalTimeBasis = totalTimeBasis
        self.ingredientLineCount = ingredientLineCount
        self.ingredientLineCountBasis = ingredientLineCountBasis
    }

    public func sourceHashMatches(_ currentSourceHash: String?) -> Bool? {
        guard let currentSourceHash, let sourceRemoteHash else {
            return nil
        }

        return currentSourceHash == sourceRemoteHash
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
                recipeFeatureCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_features") ?? 0,
                recipeFeaturesWithTotalTimeCount: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM recipe_features WHERE total_time_minutes IS NOT NULL"
                ) ?? 0,
                recipeFeaturesWithIngredientLineCountCount: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM recipe_features WHERE ingredient_line_count IS NOT NULL"
                ) ?? 0,
                recipeIngredientRecipeCount: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(DISTINCT recipe_uid) FROM recipe_ingredient_lines"
                ) ?? 0,
                recipeIngredientLineCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_ingredient_lines") ?? 0,
                recipeIngredientTokenCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_ingredient_tokens") ?? 0,
                lastRecipeSearchRun: try latestIndexRun(named: Self.recipeSearchIndexName, db: db),
                lastSuccessfulRecipeSearchRun: try latestSuccessfulIndexRun(named: Self.recipeSearchIndexName, db: db),
                lastRecipeFeatureRun: try latestIndexRun(named: Self.recipeFeatureIndexName, db: db),
                lastSuccessfulRecipeFeatureRun: try latestSuccessfulIndexRun(named: Self.recipeFeatureIndexName, db: db),
                lastRecipeIngredientRun: try latestIndexRun(named: Self.recipeIngredientIndexName, db: db),
                lastSuccessfulRecipeIngredientRun: try latestSuccessfulIndexRun(named: Self.recipeIngredientIndexName, db: db)
            )
        }
    }

    public func searchRecipes(
        query: String,
        filters: RecipeQueryFilters = RecipeQueryFilters(),
        ingredientFilter: RecipeIngredientFilter = RecipeIngredientFilter(),
        derivedConstraints: RecipeDerivedConstraints = RecipeDerivedConstraints(),
        sort: RecipeSearchSort = .relevance,
        limit: Int = 20
    ) throws -> [IndexedRecipeSearchResult] {
        let normalizedQuery = Self.normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return try dbQueue.read { db in
            var arguments: StatementArguments = [normalizedQuery]
            var conditions = ["recipe_search_fts MATCH ?"]
            let applyCategoryFilterAfterRead = !filters.categoryNames.isEmpty

            if !ingredientFilter.isDefault {
                Self.appendIngredientFilterSQL(
                    ingredientFilter,
                    recipeUIDColumn: "recipe_search_documents.uid",
                    conditions: &conditions,
                    arguments: &arguments
                )
            }

            if filters.favoritesOnly {
                conditions.append("recipe_search_documents.is_favorite = 1")
            }

            if let minRating = filters.minRating {
                conditions.append("recipe_search_documents.star_rating IS NOT NULL")
                conditions.append("recipe_search_documents.star_rating >= ?")
                arguments += [minRating]
            }

            if let maxRating = filters.maxRating {
                conditions.append("recipe_search_documents.star_rating IS NOT NULL")
                conditions.append("recipe_search_documents.star_rating <= ?")
                arguments += [maxRating]
            }

            if let minTotalTimeMinutes = derivedConstraints.minTotalTimeMinutes {
                conditions.append("recipe_features.total_time_minutes IS NOT NULL")
                conditions.append("recipe_features.total_time_minutes >= ?")
                arguments += [minTotalTimeMinutes]
            }

            if let maxTotalTimeMinutes = derivedConstraints.maxTotalTimeMinutes {
                conditions.append("recipe_features.total_time_minutes IS NOT NULL")
                conditions.append("recipe_features.total_time_minutes <= ?")
                arguments += [maxTotalTimeMinutes]
            }

            if let minIngredientLineCount = derivedConstraints.minIngredientLineCount {
                conditions.append("recipe_features.ingredient_line_count IS NOT NULL")
                conditions.append("recipe_features.ingredient_line_count >= ?")
                arguments += [minIngredientLineCount]
            }

            if let maxIngredientLineCount = derivedConstraints.maxIngredientLineCount {
                conditions.append("recipe_features.ingredient_line_count IS NOT NULL")
                conditions.append("recipe_features.ingredient_line_count <= ?")
                arguments += [maxIngredientLineCount]
            }

            let limitClause = applyCategoryFilterAfterRead ? "" : "LIMIT ?"
            if !applyCategoryFilterAfterRead {
                arguments += [max(1, limit)]
            }
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    recipe_search_documents.uid,
                    recipe_search_documents.name,
                    recipe_search_documents.categories,
                    recipe_search_documents.source_name,
                    recipe_search_documents.is_favorite,
                    recipe_search_documents.star_rating,
                    recipe_features.uid AS feature_uid,
                    recipe_features.source_remote_hash,
                    recipe_features.derived_at,
                    recipe_features.prep_time_minutes,
                    recipe_features.cook_time_minutes,
                    recipe_features.total_time_minutes,
                    recipe_features.total_time_basis,
                    recipe_features.ingredient_line_count,
                    recipe_features.ingredient_line_count_basis
                FROM recipe_search_fts
                INNER JOIN recipe_search_documents
                    ON recipe_search_documents.uid = recipe_search_fts.uid
                LEFT JOIN recipe_features
                    ON recipe_features.uid = recipe_search_documents.uid
                WHERE \(conditions.joined(separator: " AND "))
                ORDER BY \(Self.recipeSearchOrderClause(sort: sort))
                \(limitClause)
                """,
                arguments: arguments
            )

            let results = rows.map { row in
                IndexedRecipeSearchResult(
                    uid: row["uid"],
                    name: row["name"],
                    categories: Self.decodeCategories(row["categories"]),
                    sourceName: row["source_name"],
                    isFavorite: row["is_favorite"],
                    starRating: row["star_rating"],
                    derivedFeatures: Self.decodeRecipeDerivedFeatures(row: row)
                )
            }

            return results
                .filter {
                    filters.matches(
                        starRating: $0.starRating,
                        isFavorite: $0.isFavorite,
                        categories: $0.categories
                    )
                }
                .filter { derivedConstraints.matches(features: $0.derivedFeatures) }
                .prefix(max(1, limit))
                .map { $0 }
        }
    }

    public func listCookbookAggregates(
        sort: CookbookAggregateSort = .averageRating,
        limit: Int = 20,
        minRecipeCount: Int = 1,
        minRatedRecipeCount: Int = 0
    ) throws -> [CookbookAggregateSummary] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                WITH grouped AS (
                    SELECT
                        CASE
                            WHEN TRIM(COALESCE(source_name, '')) = '' THEN NULL
                            ELSE TRIM(source_name)
                        END AS source_name,
                        CASE
                            WHEN TRIM(COALESCE(source_name, '')) = '' THEN 1
                            ELSE 0
                        END AS is_unlabeled,
                        COUNT(*) AS recipe_count,
                        COUNT(star_rating) AS rated_recipe_count,
                        COUNT(*) - COUNT(star_rating) AS unrated_recipe_count,
                        SUM(CASE WHEN is_favorite THEN 1 ELSE 0 END) AS favorite_recipe_count,
                        AVG(CAST(star_rating AS REAL)) AS average_star_rating,
                        SUM(CASE WHEN star_rating = 1 THEN 1 ELSE 0 END) AS one_star_count,
                        SUM(CASE WHEN star_rating = 2 THEN 1 ELSE 0 END) AS two_star_count,
                        SUM(CASE WHEN star_rating = 3 THEN 1 ELSE 0 END) AS three_star_count,
                        SUM(CASE WHEN star_rating = 4 THEN 1 ELSE 0 END) AS four_star_count,
                        SUM(CASE WHEN star_rating = 5 THEN 1 ELSE 0 END) AS five_star_count
                    FROM recipe_search_documents
                    GROUP BY CASE
                        WHEN TRIM(COALESCE(source_name, '')) = '' THEN NULL
                        ELSE TRIM(source_name)
                    END
                )
                SELECT
                    source_name,
                    is_unlabeled,
                    recipe_count,
                    rated_recipe_count,
                    unrated_recipe_count,
                    favorite_recipe_count,
                    average_star_rating,
                    CAST(rated_recipe_count AS REAL) / recipe_count AS rated_recipe_share,
                    CAST(favorite_recipe_count AS REAL) / recipe_count AS favorite_recipe_share,
                    one_star_count,
                    two_star_count,
                    three_star_count,
                    four_star_count,
                    five_star_count
                FROM grouped
                WHERE recipe_count >= ? AND rated_recipe_count >= ?
                ORDER BY \(Self.cookbookAggregateOrderClause(sort: sort))
                LIMIT ?
                """,
                arguments: [max(1, minRecipeCount), max(0, minRatedRecipeCount), max(1, limit)]
            )

            return rows.map { row in
                CookbookAggregateSummary(
                    sourceName: row["source_name"],
                    isUnlabeled: row["is_unlabeled"],
                    recipeCount: row["recipe_count"],
                    ratedRecipeCount: row["rated_recipe_count"],
                    unratedRecipeCount: row["unrated_recipe_count"],
                    favoriteRecipeCount: row["favorite_recipe_count"],
                    averageStarRating: row["average_star_rating"],
                    ratedRecipeShare: row["rated_recipe_share"],
                    favoriteRecipeShare: row["favorite_recipe_share"],
                    ratingDistribution: CookbookRatingDistribution(
                        oneStarCount: row["one_star_count"],
                        twoStarCount: row["two_star_count"],
                        threeStarCount: row["three_star_count"],
                        fourStarCount: row["four_star_count"],
                        fiveStarCount: row["five_star_count"]
                    )
                )
            }
        }
    }

    public func fetchRecipeFeatures(uid: String) throws -> RecipeDerivedFeatures? {
        try dbQueue.read { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        uid,
                        source_remote_hash,
                        derived_at,
                        prep_time_minutes,
                        cook_time_minutes,
                        total_time_minutes,
                        total_time_basis,
                        ingredient_line_count,
                        ingredient_line_count_basis
                    FROM recipe_features
                    WHERE uid = ?
                    LIMIT 1
                    """,
                    arguments: [uid]
                )
            else {
                return nil
            }

            return Self.decodeRecipeDerivedFeatures(row: row)
        }
    }

    public func fetchAllRecipeFeatures() throws -> [String: RecipeDerivedFeatures] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    uid,
                    source_remote_hash,
                    derived_at,
                    prep_time_minutes,
                    cook_time_minutes,
                    total_time_minutes,
                    total_time_basis,
                    ingredient_line_count,
                    ingredient_line_count_basis
                FROM recipe_features
                """
            )

            return Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    guard let features = Self.decodeRecipeDerivedFeatures(row: row) else {
                        return nil
                    }

                    return (features.uid, features)
                }
            )
        }
    }

    public func fetchRecipeIngredientIndex(uid: String) throws -> RecipeIngredientIndex? {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    recipe_ingredient_lines.recipe_uid,
                    recipe_ingredient_lines.source_remote_hash,
                    recipe_ingredient_lines.derived_at,
                    recipe_ingredient_lines.line_number,
                    recipe_ingredient_lines.source_text,
                    recipe_ingredient_lines.normalized_text,
                    recipe_ingredient_tokens.token,
                    recipe_ingredient_tokens.token_position
                FROM recipe_ingredient_lines
                LEFT JOIN recipe_ingredient_tokens
                    ON recipe_ingredient_tokens.recipe_uid = recipe_ingredient_lines.recipe_uid
                    AND recipe_ingredient_tokens.line_number = recipe_ingredient_lines.line_number
                WHERE recipe_ingredient_lines.recipe_uid = ?
                ORDER BY recipe_ingredient_lines.line_number ASC, recipe_ingredient_tokens.token_position ASC
                """,
                arguments: [uid]
            )

            guard let firstRow = rows.first else {
                return nil
            }

            let derivedAt = DatabaseTimestamp.decodeRequired(firstRow["derived_at"])
            let sourceRemoteHash: String? = firstRow["source_remote_hash"]
            var linesByNumber = [Int: RecipeIngredientLine]()
            var orderedLineNumbers = [Int]()

            for row in rows {
                let lineNumber: Int = row["line_number"]
                let sourceText: String = row["source_text"]
                let normalizedText: String? = row["normalized_text"]
                let token: String? = row["token"]

                if linesByNumber[lineNumber] == nil {
                    orderedLineNumbers.append(lineNumber)
                    linesByNumber[lineNumber] = RecipeIngredientLine(
                        lineNumber: lineNumber,
                        sourceText: sourceText,
                        normalizedText: normalizedText,
                        normalizedTokens: []
                    )
                }

                if let token {
                    let existing = linesByNumber[lineNumber]!
                    linesByNumber[lineNumber] = RecipeIngredientLine(
                        lineNumber: existing.lineNumber,
                        sourceText: existing.sourceText,
                        normalizedText: existing.normalizedText,
                        normalizedTokens: existing.normalizedTokens + [token]
                    )
                }
            }

            return RecipeIngredientIndex(
                uid: uid,
                sourceRemoteHash: sourceRemoteHash,
                derivedAt: derivedAt,
                lines: orderedLineNumbers.compactMap { linesByNumber[$0] }
            )
        }
    }

    public func matchingRecipeUIDs(for ingredientFilter: RecipeIngredientFilter) throws -> Set<String> {
        guard !ingredientFilter.isDefault else {
            return []
        }

        return try dbQueue.read { db in
            var conditions = [String]()
            var arguments = StatementArguments()
            Self.appendIngredientFilterSQL(
                ingredientFilter,
                recipeUIDColumn: "recipe_search_documents.uid",
                conditions: &conditions,
                arguments: &arguments
            )
            let whereClause = conditions.isEmpty
                ? ""
                : "WHERE \(conditions.joined(separator: " AND "))"
            let recipeUIDs = try String.fetchAll(
                db,
                sql: """
                SELECT recipe_search_documents.uid
                FROM recipe_search_documents
                \(whereClause)
                """,
                arguments: arguments
            )

            return Set(recipeUIDs)
        }
    }

    public func rebuildRecipeIndexes(
        from source: any PantrySource,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> RecipeIndexesRebuildSummary {
        let startedAt = now()
        let searchRunID = try startIndexRun(named: Self.recipeSearchIndexName, startedAt: startedAt)
        let featureRunID = try startIndexRun(named: Self.recipeFeatureIndexName, startedAt: startedAt)
        let ingredientRunID = try startIndexRun(named: Self.recipeIngredientIndexName, startedAt: startedAt)

        do {
            let categoryNamesByUID = try await loadCategoryNamesByUID(from: source)
            let stubs = try await source.listRecipeStubs()
            let activeStubs = stubs.filter { !$0.isDeleted }

            var documents = [RecipeSearchDocument]()
            var features = [RecipeDerivedFeatures]()
            var ingredientIndexes = [RecipeIngredientIndex]()
            documents.reserveCapacity(activeStubs.count)
            features.reserveCapacity(activeStubs.count)
            ingredientIndexes.reserveCapacity(activeStubs.count)

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
                features.append(
                    Self.deriveFeatures(
                        from: recipe,
                        derivedAt: startedAt
                    )
                )
                if let ingredientIndex = IngredientNormalizer.normalizeIngredientLines(
                    recipeUID: recipe.uid,
                    sourceRemoteHash: recipe.remoteHash,
                    ingredients: recipe.ingredients,
                    derivedAt: startedAt
                ) {
                    ingredientIndexes.append(ingredientIndex)
                }
            }

            let finishedAt = now()
            let sortedDocuments = documents.sorted(by: Self.sortSearchDocuments)
            let sortedFeatures = features.sorted { $0.uid < $1.uid }
            let sortedIngredientIndexes = ingredientIndexes.sorted { $0.uid < $1.uid }
            let recipeSearchDocumentCount = sortedDocuments.count
            let recipeFeatureCount = sortedFeatures.count
            let recipeFeaturesWithTotalTimeCount = sortedFeatures.filter { $0.totalTimeMinutes != nil }.count
            let recipeFeaturesWithIngredientLineCountCount = sortedFeatures.filter { $0.ingredientLineCount != nil }.count
            let recipeIngredientRecipeCount = sortedIngredientIndexes.count
            let recipeIngredientLineCount = sortedIngredientIndexes.reduce(into: 0) { partialResult, index in
                partialResult += index.lines.count
            }
            let recipeIngredientTokenCount = sortedIngredientIndexes.reduce(into: 0) { partialResult, index in
                partialResult += index.normalizedTokenCount
            }
            try await dbQueue.write { db in
                try db.execute(sql: "DELETE FROM recipe_search_documents")
                try db.execute(sql: "DELETE FROM recipe_search_fts")
                try db.execute(sql: "DELETE FROM recipe_features")
                try db.execute(sql: "DELETE FROM recipe_ingredient_tokens")
                try db.execute(sql: "DELETE FROM recipe_ingredient_lines")

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

                for feature in sortedFeatures {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_features (
                            uid,
                            source_remote_hash,
                            derived_at,
                            prep_time_minutes,
                            cook_time_minutes,
                            total_time_minutes,
                            total_time_basis,
                            ingredient_line_count,
                            ingredient_line_count_basis
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            feature.uid,
                            feature.sourceRemoteHash,
                            DatabaseTimestamp.encode(finishedAt),
                            feature.prepTimeMinutes,
                            feature.cookTimeMinutes,
                            feature.totalTimeMinutes,
                            feature.totalTimeBasis?.rawValue,
                            feature.ingredientLineCount,
                            feature.ingredientLineCountBasis?.rawValue,
                        ]
                    )
                }

                for ingredientIndex in sortedIngredientIndexes {
                    for line in ingredientIndex.lines {
                        try db.execute(
                            sql: """
                            INSERT INTO recipe_ingredient_lines (
                                recipe_uid,
                                line_number,
                                source_text,
                                normalized_text,
                                source_remote_hash,
                                derived_at
                            ) VALUES (?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [
                                ingredientIndex.uid,
                                line.lineNumber,
                                line.sourceText,
                                line.normalizedText,
                                ingredientIndex.sourceRemoteHash,
                                DatabaseTimestamp.encode(finishedAt),
                            ]
                        )

                        for (offset, token) in line.normalizedTokens.enumerated() {
                            try db.execute(
                                sql: """
                                INSERT INTO recipe_ingredient_tokens (
                                    recipe_uid,
                                    line_number,
                                    token,
                                    token_position
                                ) VALUES (?, ?, ?, ?)
                                """,
                                arguments: [
                                    ingredientIndex.uid,
                                    line.lineNumber,
                                    token,
                                    offset + 1,
                                ]
                            )
                        }
                    }
                }

                try finishIndexRun(
                    id: searchRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: recipeSearchDocumentCount,
                    errorMessage: nil,
                    in: db
                )
                try finishIndexRun(
                    id: featureRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: recipeFeatureCount,
                    errorMessage: nil,
                    in: db
                )
                try finishIndexRun(
                    id: ingredientRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: recipeIngredientRecipeCount,
                    errorMessage: nil,
                    in: db
                )
            }

            return RecipeIndexesRebuildSummary(
                startedAt: startedAt,
                finishedAt: finishedAt,
                recipeSearchDocumentCount: recipeSearchDocumentCount,
                recipeFeatureCount: recipeFeatureCount,
                recipeFeaturesWithTotalTimeCount: recipeFeaturesWithTotalTimeCount,
                recipeFeaturesWithIngredientLineCountCount: recipeFeaturesWithIngredientLineCountCount,
                recipeIngredientRecipeCount: recipeIngredientRecipeCount,
                recipeIngredientLineCount: recipeIngredientLineCount,
                recipeIngredientTokenCount: recipeIngredientTokenCount
            )
        } catch {
            try finishIndexRun(
                id: searchRunID,
                status: .failed,
                finishedAt: now(),
                recipeCount: 0,
                errorMessage: String(describing: error)
            )
            try finishIndexRun(
                id: featureRunID,
                status: .failed,
                finishedAt: now(),
                recipeCount: 0,
                errorMessage: String(describing: error)
            )
            try finishIndexRun(
                id: ingredientRunID,
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
    private static let recipeFeatureIndexName = "recipe-features"
    private static let recipeIngredientIndexName = "recipe-ingredients"

    private static func sortSearchDocuments(lhs: RecipeSearchDocument, rhs: RecipeSearchDocument) -> Bool {
        if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
            return lhs.uid < rhs.uid
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func recipeSearchOrderClause(sort: RecipeSearchSort) -> String {
        switch sort {
        case .relevance:
            return """
            bm25(recipe_search_fts) ASC,
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .name:
            return """
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .rating:
            return """
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .totalTime:
            return """
            CASE WHEN recipe_features.total_time_minutes IS NULL THEN 1 ELSE 0 END ASC,
            recipe_features.total_time_minutes ASC,
            CASE WHEN recipe_features.ingredient_line_count IS NULL THEN 1 ELSE 0 END ASC,
            recipe_features.ingredient_line_count ASC,
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .fewestIngredients:
            return """
            CASE WHEN recipe_features.ingredient_line_count IS NULL THEN 1 ELSE 0 END ASC,
            recipe_features.ingredient_line_count ASC,
            CASE WHEN recipe_features.total_time_minutes IS NULL THEN 1 ELSE 0 END ASC,
            recipe_features.total_time_minutes ASC,
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        }
    }

    private static func cookbookAggregateOrderClause(sort: CookbookAggregateSort) -> String {
        switch sort {
        case .averageRating:
            return """
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            rated_recipe_count DESC,
            favorite_recipe_count DESC,
            recipe_count DESC,
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        case .favoriteRate:
            return """
            favorite_recipe_share DESC,
            favorite_recipe_count DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            recipe_count DESC,
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        case .favorites:
            return """
            favorite_recipe_count DESC,
            favorite_recipe_share DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            recipe_count DESC,
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        case .ratedRecipes:
            return """
            rated_recipe_count DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            favorite_recipe_count DESC,
            recipe_count DESC,
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        case .recipes:
            return """
            recipe_count DESC,
            rated_recipe_count DESC,
            favorite_recipe_count DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        case .name:
            return """
            is_unlabeled ASC,
            source_name COLLATE NOCASE ASC
            """
        }
    }

    private static func decodeRecipeDerivedFeatures(row: Row) -> RecipeDerivedFeatures? {
        let derivedAtValue: String? = row["derived_at"]
        guard let derivedAtValue else {
            return nil
        }

        let totalTimeBasisRaw: String? = row["total_time_basis"]
        let ingredientLineCountBasisRaw: String? = row["ingredient_line_count_basis"]

        return RecipeDerivedFeatures(
            uid: row["feature_uid"] ?? row["uid"],
            sourceRemoteHash: row["source_remote_hash"],
            derivedAt: DatabaseTimestamp.decodeRequired(derivedAtValue),
            prepTimeMinutes: row["prep_time_minutes"],
            cookTimeMinutes: row["cook_time_minutes"],
            totalTimeMinutes: row["total_time_minutes"],
            totalTimeBasis: totalTimeBasisRaw.flatMap(RecipeTotalTimeBasis.init(rawValue:)),
            ingredientLineCount: row["ingredient_line_count"],
            ingredientLineCountBasis: ingredientLineCountBasisRaw.flatMap(RecipeIngredientLineCountBasis.init(rawValue:))
        )
    }

    private static func normalizedSearchQuery(_ query: String) -> String {
        query
            .split(whereSeparator: \.isWhitespace)
            .map { "\"\($0.replacing("\"", with: "\"\""))\"" }
            .joined(separator: " ")
    }

    private static func sqlPlaceholders(count: Int) -> String {
        Array(repeating: "?", count: max(1, count)).joined(separator: ", ")
    }

    private static func appendIngredientFilterSQL(
        _ filter: RecipeIngredientFilter,
        recipeUIDColumn: String,
        conditions: inout [String],
        arguments: inout StatementArguments
    ) {
        let includeClauses = filter.queryableIncludeTerms.map { term in
            for token in term.normalizedTokens {
                arguments += [token]
            }
            arguments += [term.normalizedTokens.count]
            return ingredientTermExistsClause(tokenCount: term.normalizedTokens.count, recipeUIDColumn: recipeUIDColumn)
        }

        switch filter.includeMode {
        case .all:
            conditions.append(contentsOf: includeClauses)
        case .any:
            if !includeClauses.isEmpty {
                conditions.append("(\(includeClauses.joined(separator: " OR ")))")
            }
        }

        for term in filter.queryableExcludeTerms {
            for token in term.normalizedTokens {
                arguments += [token]
            }
            arguments += [term.normalizedTokens.count]
            conditions.append("NOT \(ingredientTermExistsClause(tokenCount: term.normalizedTokens.count, recipeUIDColumn: recipeUIDColumn))")
        }
    }

    private static func ingredientTermExistsClause(tokenCount: Int, recipeUIDColumn: String) -> String {
        let placeholders = sqlPlaceholders(count: tokenCount)
        return """
        EXISTS (
            SELECT 1
            FROM recipe_ingredient_tokens
            WHERE recipe_ingredient_tokens.recipe_uid = \(recipeUIDColumn)
                AND recipe_ingredient_tokens.token IN (\(placeholders))
            GROUP BY recipe_ingredient_tokens.recipe_uid
            HAVING COUNT(DISTINCT recipe_ingredient_tokens.token) = ?
        )
        """
    }

    private static func encodeCategories(_ categories: [String]) -> String {
        categories.joined(separator: "\u{1F}")
    }

    private static func decodeCategories(_ value: String) -> [String] {
        value.split(separator: "\u{1F}").map(String.init)
    }

    private static func deriveFeatures(from recipe: SourceRecipe, derivedAt: Date) -> RecipeDerivedFeatures {
        let prepTimeMinutes = parsedDurationMinutes(recipe.prepTime)
        let cookTimeMinutes = parsedDurationMinutes(recipe.cookTime)
        let sourceTotalTimeMinutes = parsedDurationMinutes(recipe.totalTime)

        let totalTimeMinutes: Int?
        let totalTimeBasis: RecipeTotalTimeBasis?
        if let sourceTotalTimeMinutes {
            totalTimeMinutes = sourceTotalTimeMinutes
            totalTimeBasis = .sourceTotalTime
        } else if let prepTimeMinutes, let cookTimeMinutes {
            totalTimeMinutes = prepTimeMinutes + cookTimeMinutes
            totalTimeBasis = .summedPrepAndCook
        } else {
            totalTimeMinutes = nil
            totalTimeBasis = nil
        }

        let ingredientLineCount = countedIngredientLines(recipe.ingredients)

        return RecipeDerivedFeatures(
            uid: recipe.uid,
            sourceRemoteHash: recipe.remoteHash,
            derivedAt: derivedAt,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            totalTimeMinutes: totalTimeMinutes,
            totalTimeBasis: totalTimeBasis,
            ingredientLineCount: ingredientLineCount,
            ingredientLineCountBasis: ingredientLineCount == nil ? nil : .nonEmptyLines
        )
    }

    private static func countedIngredientLines(_ ingredients: String?) -> Int? {
        guard let ingredients else {
            return nil
        }

        let count = ingredients
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count

        return count == 0 ? nil : count
    }

    private static func parsedDurationMinutes(_ rawValue: String?) -> Int? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()

        if let colonMinutes = parsedColonDurationMinutes(normalized) {
            return colonMinutes
        }

        let pattern = #"(\d+)\s*(hours?|hour|hrs?|hr|h|minutes?|minute|mins?|min|m)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: []) else {
            return Int(normalized)
        }

        let fullRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = expression.matches(in: normalized, options: [], range: fullRange)
        if !matches.isEmpty {
            var totalMinutes = 0

            for match in matches {
                guard
                    let valueRange = Range(match.range(at: 1), in: normalized),
                    let unitRange = Range(match.range(at: 2), in: normalized),
                    let value = Int(normalized[valueRange])
                else {
                    continue
                }

                let unit = String(normalized[unitRange])
                if unit.hasPrefix("h") {
                    totalMinutes += value * 60
                } else {
                    totalMinutes += value
                }
            }

            return totalMinutes == 0 ? nil : totalMinutes
        }

        return Int(normalized)
    }

    private static func parsedColonDurationMinutes(_ normalized: String) -> Int? {
        let parts = normalized.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else {
            return nil
        }

        guard minutes >= 0 && minutes < 60 else {
            return nil
        }

        return (hours * 60) + minutes
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
