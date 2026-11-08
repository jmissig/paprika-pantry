import ArgumentParser
import Foundation
import GRDB

extension PantrySidecarStore {
    public func indexStats() throws -> PantryIndexStats {
        try indexStats(afterProvenanceRead: nil)
    }

    func indexStats(afterProvenanceRead: (() throws -> Void)?) throws -> PantryIndexStats {
        try dbQueue.read { db in
            let provenance = try Self.indexProvenance(db)
            try afterProvenanceRead?()
            var compatibilityIssue: String?
            if let expectedContract {
                do { try Self.requireCompatible(expectedContract, families: Self.allFamilies, db: db) }
                catch { compatibilityIssue = error.localizedDescription }
            }
            let incompatibleFamilies = expectedContract.map { contract in
                Self.allFamilies.filter { family in !provenance.contains { $0.family == family && $0.contract == contract.encoded } }
            } ?? []
            return PantryIndexStats(
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
                recipeUsageStatsCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_usage_stats") ?? 0,
                recipeUsageStatsWithLastMealAtCount: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM recipe_usage_stats WHERE last_meal_at IS NOT NULL"
                ) ?? 0,
                recipeUsageStatsWithGapArrayCount: try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM recipe_usage_stats WHERE meal_gap_days_json IS NOT NULL"
                ) ?? 0,
                recipeUsageTotalMealCount: try Int.fetchOne(
                    db,
                    sql: """
                    SELECT total_meal_count
                    FROM recipe_usage_summary
                    WHERE summary_key = ?
                    LIMIT 1
                    """,
                    arguments: [Self.recipeUsageSummaryKey]
                ) ?? 0,
                ingredientPairSummaryCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ingredient_pair_summaries") ?? 0,
                ingredientPairRecipeEvidenceCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM ingredient_pair_recipe_evidence") ?? 0,
                lastRecipeSearchRun: try latestIndexRun(named: Self.recipeSearchIndexName, db: db),
                lastSuccessfulRecipeSearchRun: try latestSuccessfulIndexRun(named: Self.recipeSearchIndexName, db: db),
                lastRecipeFeatureRun: try latestIndexRun(named: Self.recipeFeatureIndexName, db: db),
                lastSuccessfulRecipeFeatureRun: try latestSuccessfulIndexRun(named: Self.recipeFeatureIndexName, db: db),
                lastRecipeIngredientRun: try latestIndexRun(named: Self.recipeIngredientIndexName, db: db),
                lastSuccessfulRecipeIngredientRun: try latestSuccessfulIndexRun(named: Self.recipeIngredientIndexName, db: db),
                lastRecipeUsageRun: try latestIndexRun(named: Self.recipeUsageIndexName, db: db),
                lastSuccessfulRecipeUsageRun: try latestSuccessfulIndexRun(named: Self.recipeUsageIndexName, db: db),
                lastIngredientPairRun: try latestIndexRun(named: Self.ingredientPairIndexName, db: db),
                lastSuccessfulIngredientPairRun: try latestSuccessfulIndexRun(named: Self.ingredientPairIndexName, db: db),
                sourceState: try fetchStoredSourceState(db: db),
                compatibilityIssue: compatibilityIssue, provenance: provenance, incompatibleFamilies: incompatibleFamilies, compatibilityChecked: expectedContract != nil
            )
        }
    }

    public func searchRecipes(
        query: String,
        filters: RecipeQueryFilters = RecipeQueryFilters(),
        ingredientFilter: RecipeIngredientFilter = RecipeIngredientFilter(),
        derivedConstraints: RecipeDerivedConstraints = RecipeDerivedConstraints(),
        usageConstraints: RecipeUsageConstraints = RecipeUsageConstraints(),
        sort: RecipeSearchSort = .relevance,
        limit: Int = 20,
        referenceDate: Date = Date()
    ) throws -> [IndexedRecipeSearchResult] {
        let normalizedQuery = Self.normalizedSearchQuery(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        return try readCompatible(["recipe-search", "recipe-features", "recipe-usage", "recipe-ingredients"]) { db in
            var arguments: StatementArguments = [normalizedQuery]
            var conditions = ["recipe_search_fts MATCH ?"]
            let applyCategoryFilterAfterRead = !filters.categoryNames.isEmpty || !usageConstraints.isDefault

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
                    recipe_search_documents.notes IS NOT NULL
                        AND LENGTH(TRIM(recipe_search_documents.notes)) > 0 AS has_notes,
                    recipe_search_documents.is_favorite,
                    recipe_search_documents.star_rating,
                    recipe_features.uid AS feature_uid,
                    recipe_features.source_fingerprint,
                    recipe_features.derived_at,
                    recipe_features.prep_time_minutes,
                    recipe_features.cook_time_minutes,
                    recipe_features.total_time_minutes,
                    recipe_features.total_time_basis,
                    recipe_features.ingredient_line_count,
                    recipe_features.ingredient_line_count_basis,
                    recipe_usage_stats.uid AS usage_uid,
                    recipe_usage_stats.derived_at AS usage_derived_at,
                    recipe_usage_stats.meal_count,
                    recipe_usage_stats.first_meal_at,
                    recipe_usage_stats.first_cooked_at,
                    recipe_usage_stats.last_meal_at,
                    recipe_usage_stats.meal_gap_days_json,
                    recipe_usage_stats.days_spanned_by_meals,
                    recipe_usage_stats.median_meal_gap_days,
                    recipe_usage_stats.meal_share,
                    recipe_usage_stats.times_cooked,
                    recipe_usage_stats.last_cooked_at
                FROM recipe_search_fts
                INNER JOIN recipe_search_documents
                    ON recipe_search_documents.uid = recipe_search_fts.uid
                LEFT JOIN recipe_features
                    ON recipe_features.uid = recipe_search_documents.uid
                LEFT JOIN recipe_usage_stats
                    ON recipe_usage_stats.uid = recipe_search_documents.uid
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
                    hasNotes: row["has_notes"],
                    derivedFeatures: Self.decodeRecipeDerivedFeatures(row: row),
                    usageStats: Self.decodeRecipeUsageStats(row: row)
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
                .filter { usageConstraints.matches(usageStats: $0.usageStats, referenceDate: referenceDate) }
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
        return try readCompatible(["recipe-search", "recipe-usage"]) { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                WITH usage_summary AS (
                    SELECT COALESCE((
                        SELECT total_meal_count
                        FROM recipe_usage_summary
                        WHERE summary_key = ?
                        LIMIT 1
                    ), 0) AS total_meal_count
                ),
                grouped AS (
                    SELECT
                        CASE
                            WHEN TRIM(COALESCE(recipe_search_documents.source_name, '')) = '' THEN NULL
                            ELSE TRIM(recipe_search_documents.source_name)
                        END AS source_name,
                        CASE
                            WHEN TRIM(COALESCE(recipe_search_documents.source_name, '')) = '' THEN 1
                            ELSE 0
                        END AS is_unlabeled,
                        COUNT(*) AS recipe_count,
                        COUNT(recipe_search_documents.star_rating) AS rated_recipe_count,
                        COUNT(*) - COUNT(recipe_search_documents.star_rating) AS unrated_recipe_count,
                        SUM(CASE WHEN recipe_search_documents.is_favorite THEN 1 ELSE 0 END) AS favorite_recipe_count,
                        SUM(CASE WHEN COALESCE(recipe_usage_stats.meal_count, 0) > 0 THEN 1 ELSE 0 END) AS used_recipe_count,
                        SUM(CASE WHEN COALESCE(recipe_usage_stats.meal_count, 0) = 0 THEN 1 ELSE 0 END) AS unused_recipe_count,
                        COALESCE(SUM(recipe_usage_stats.meal_count), 0) AS meal_count,
                        MIN(recipe_usage_stats.first_meal_at) AS first_meal_at,
                        MIN(recipe_usage_stats.first_cooked_at) AS first_cooked_at,
                        MAX(recipe_usage_stats.last_meal_at) AS last_meal_at,
                        AVG(CAST(recipe_search_documents.star_rating AS REAL)) AS average_star_rating,
                        SUM(CASE WHEN recipe_search_documents.star_rating = 1 THEN 1 ELSE 0 END) AS one_star_count,
                        SUM(CASE WHEN recipe_search_documents.star_rating = 2 THEN 1 ELSE 0 END) AS two_star_count,
                        SUM(CASE WHEN recipe_search_documents.star_rating = 3 THEN 1 ELSE 0 END) AS three_star_count,
                        SUM(CASE WHEN recipe_search_documents.star_rating = 4 THEN 1 ELSE 0 END) AS four_star_count,
                        SUM(CASE WHEN recipe_search_documents.star_rating = 5 THEN 1 ELSE 0 END) AS five_star_count
                    FROM recipe_search_documents
                    LEFT JOIN recipe_usage_stats
                        ON recipe_usage_stats.uid = recipe_search_documents.uid
                    GROUP BY CASE
                        WHEN TRIM(COALESCE(recipe_search_documents.source_name, '')) = '' THEN NULL
                        ELSE TRIM(recipe_search_documents.source_name)
                    END
                )
                SELECT
                    source_name,
                    is_unlabeled,
                    recipe_count,
                    rated_recipe_count,
                    unrated_recipe_count,
                    favorite_recipe_count,
                    used_recipe_count,
                    unused_recipe_count,
                    meal_count,
                    CASE
                        WHEN usage_summary.total_meal_count > 0 THEN CAST(meal_count AS REAL) / usage_summary.total_meal_count
                        ELSE 0
                    END AS meal_share,
                    first_meal_at,
                    first_cooked_at,
                    last_meal_at,
                    average_star_rating,
                    CAST(rated_recipe_count AS REAL) / recipe_count AS rated_recipe_share,
                    CAST(favorite_recipe_count AS REAL) / recipe_count AS favorite_recipe_share,
                    one_star_count,
                    two_star_count,
                    three_star_count,
                    four_star_count,
                    five_star_count
                FROM grouped
                CROSS JOIN usage_summary
                WHERE recipe_count >= ? AND rated_recipe_count >= ?
                ORDER BY \(Self.cookbookAggregateOrderClause(sort: sort))
                LIMIT ?
                """,
                arguments: [Self.recipeUsageSummaryKey, max(1, minRecipeCount), max(0, minRatedRecipeCount), max(1, limit)]
            )

            return rows.map { row in
                CookbookAggregateSummary(
                    sourceName: row["source_name"],
                    isUnlabeled: row["is_unlabeled"],
                    recipeCount: row["recipe_count"],
                    ratedRecipeCount: row["rated_recipe_count"],
                    unratedRecipeCount: row["unrated_recipe_count"],
                    favoriteRecipeCount: row["favorite_recipe_count"],
                    usedRecipeCount: row["used_recipe_count"],
                    unusedRecipeCount: row["unused_recipe_count"],
                    mealCount: row["meal_count"],
                    mealShare: row["meal_share"],
                    firstMealAt: row["first_meal_at"],
                    firstCookedAt: row["first_cooked_at"],
                    lastMealAt: row["last_meal_at"],
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
        return try readCompatible(["recipe-features"]) { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        uid,
                        source_fingerprint,
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

    public func fetchRecipeUsageStats(uid: String) throws -> RecipeUsageStats? {
        return try readCompatible(["recipe-usage"]) { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        uid,
                        derived_at,
                        meal_count,
                        first_meal_at,
                        first_cooked_at,
                        last_meal_at,
                        meal_gap_days_json,
                        days_spanned_by_meals,
                        median_meal_gap_days,
                        meal_share,
                        times_cooked,
                        last_cooked_at
                    FROM recipe_usage_stats
                    WHERE uid = ?
                    LIMIT 1
                    """,
                    arguments: [uid]
                )
            else {
                return nil
            }

            return Self.decodeRecipeUsageStats(row: row)
        }
    }

    public func fetchAllRecipeFeatures() throws -> [String: RecipeDerivedFeatures] {
        return try readCompatible(["recipe-features"]) { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    uid,
                    source_fingerprint,
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

    public func fetchAllRecipeUsageStats() throws -> [String: RecipeUsageStats] {
        return try readCompatible(["recipe-usage"]) { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    uid,
                    derived_at,
                    meal_count,
                    first_meal_at,
                    first_cooked_at,
                    last_meal_at,
                    meal_gap_days_json,
                    days_spanned_by_meals,
                    median_meal_gap_days,
                    meal_share,
                    times_cooked,
                    last_cooked_at
                FROM recipe_usage_stats
                """
            )

            return Dictionary(
                uniqueKeysWithValues: rows.compactMap { row in
                    guard let usageStats = Self.decodeRecipeUsageStats(row: row) else {
                        return nil
                    }

                    return (usageStats.uid, usageStats)
                }
            )
        }
    }

    public func fetchRecipeIngredientIndex(uid: String) throws -> RecipeIngredientIndex? {
        return try readCompatible(["recipe-ingredients"]) { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    recipe_ingredient_lines.recipe_uid,
                    recipe_ingredient_lines.source_fingerprint,
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
            let sourceFingerprint: String? = firstRow["source_fingerprint"]
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
                sourceFingerprint: sourceFingerprint,
                derivedAt: derivedAt,
                lines: orderedLineNumbers.compactMap { linesByNumber[$0] }
            )
        }
    }

    public func matchingRecipeUIDs(for ingredientFilter: RecipeIngredientFilter) throws -> Set<String> {
        guard !ingredientFilter.isDefault else {
            return []
        }

        return try readCompatible(["recipe-ingredients"]) { db in
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

    public func listIngredientPairEvidence(
        token: String? = nil,
        withToken: String? = nil,
        minRecipes: Int = 1,
        sort: IngredientPairEvidenceSort = .recipes,
        limit: Int = 20,
        evidenceLimit: Int = 3
    ) throws -> [IngredientPairEvidenceSummary] {
        let normalizedToken = token.flatMap(Self.normalizedSingleIngredientToken)
        let normalizedWithToken = withToken.flatMap(Self.normalizedSingleIngredientToken)
        let boundedLimit = max(1, limit)
        let boundedEvidenceLimit = max(0, evidenceLimit)
        if token != nil && normalizedToken == nil {
            return []
        }
        if withToken != nil && normalizedWithToken == nil {
            return []
        }

        return try readCompatible(["ingredient-pairs"]) { db in
            var conditions = [
                "basis = ?",
                "recipe_count >= ?",
            ]
            var arguments: StatementArguments = [
                Self.ingredientPairEvidenceBasis,
                max(1, minRecipes),
            ]

            if let normalizedToken, let normalizedWithToken {
                let ordered = Self.orderedPair(normalizedToken, normalizedWithToken)
                conditions.append("token_a = ?")
                conditions.append("token_b = ?")
                arguments += [ordered.0, ordered.1]
            } else if let normalizedToken {
                conditions.append("(token_a = ? OR token_b = ?)")
                arguments += [normalizedToken, normalizedToken]
            }

            arguments += [boundedLimit]
            let summaries = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    basis,
                    token_a,
                    token_b,
                    recipe_count,
                    cooked_recipe_count,
                    cooked_meal_count,
                    favorite_recipe_count,
                    rated_recipe_count,
                    average_star_rating,
                    first_meal_at,
                    last_meal_at
                FROM ingredient_pair_summaries
                WHERE \(conditions.joined(separator: " AND "))
                ORDER BY \(Self.ingredientPairOrderClause(sort: sort))
                LIMIT ?
                """,
                arguments: arguments
            ).map(Self.decodeIngredientPairSummary)

            guard boundedEvidenceLimit > 0 else {
                return summaries
            }

            return try summaries.map { summary in
                var summary = summary
                let evidence = try Self.fetchIngredientPairRecipeEvidence(
                    tokenA: summary.tokenA,
                    tokenB: summary.tokenB,
                    limit: boundedEvidenceLimit,
                    db: db
                )
                summary = IngredientPairEvidenceSummary(
                    basis: summary.basis,
                    tokenA: summary.tokenA,
                    tokenB: summary.tokenB,
                    recipeCount: summary.recipeCount,
                    cookedRecipeCount: summary.cookedRecipeCount,
                    cookedMealCount: summary.cookedMealCount,
                    favoriteRecipeCount: summary.favoriteRecipeCount,
                    ratedRecipeCount: summary.ratedRecipeCount,
                    averageStarRating: summary.averageStarRating,
                    firstMealAt: summary.firstMealAt,
                    lastMealAt: summary.lastMealAt,
                    recipeEvidence: evidence
                )
                return summary
            }
        }
    }

    private func fetchStoredSourceState(db: Database) throws -> PantryStoredSourceState? {
        guard
            let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    source_type,
                    source_location,
                    observed_at,
                    paprika_last_sync_at,
                    paprika_sync_signal_source,
                    paprika_sync_signal_location
                FROM source_state
                ORDER BY observed_at DESC
                LIMIT 1
                """
            )
        else {
            return nil
        }

        let paprikaLastSyncAt: String? = row["paprika_last_sync_at"]
        let paprikaSyncSignalSource: String? = row["paprika_sync_signal_source"]
        let paprikaSyncSignalLocation: String? = row["paprika_sync_signal_location"]
        let paprikaSync: PaprikaSyncDetails?
        if
            let paprikaLastSyncAt,
            let lastSyncAt = DatabaseTimestamp.decode(paprikaLastSyncAt),
            let paprikaSyncSignalSource,
            let paprikaSyncSignalLocation
        {
            paprikaSync = PaprikaSyncDetails(
                lastSyncAt: lastSyncAt,
                signalSource: paprikaSyncSignalSource,
                signalLocation: paprikaSyncSignalLocation
            )
        } else {
            paprikaSync = nil
        }

        return PantryStoredSourceState(
            sourceType: row["source_type"],
            sourceLocation: row["source_location"],
            observedAt: DatabaseTimestamp.decodeRequired(row["observed_at"]),
            paprikaSync: paprikaSync
        )
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

    func latestSuccessfulIndexRun(named indexName: String, db: Database) throws -> PantryIndexRun? {
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

    private static func recipeSearchOrderClause(sort: RecipeSearchSort) -> String {
        switch sort {
        case .relevance:
            return """
            bm25(recipe_search_fts) ASC,
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
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
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .timesCooked:
            return """
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .recent:
            return """
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            COALESCE(recipe_search_documents.star_rating, 0) DESC,
            recipe_search_documents.is_favorite DESC,
            recipe_search_documents.name COLLATE NOCASE ASC,
            recipe_search_documents.uid ASC
            """
        case .lapsed:
            return """
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at ASC,
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
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
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
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
            COALESCE(recipe_usage_stats.meal_count, 0) DESC,
            CASE WHEN recipe_usage_stats.last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            recipe_usage_stats.last_meal_at DESC,
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

    private static func ingredientPairOrderClause(sort: IngredientPairEvidenceSort) -> String {
        switch sort {
        case .recipes:
            return """
            recipe_count DESC,
            cooked_meal_count DESC,
            favorite_recipe_count DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            token_a COLLATE NOCASE ASC,
            token_b COLLATE NOCASE ASC
            """
        case .meals:
            return """
            cooked_meal_count DESC,
            cooked_recipe_count DESC,
            recipe_count DESC,
            CASE WHEN last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
            last_meal_at DESC,
            token_a COLLATE NOCASE ASC,
            token_b COLLATE NOCASE ASC
            """
        case .favorites:
            return """
            favorite_recipe_count DESC,
            recipe_count DESC,
            cooked_meal_count DESC,
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            token_a COLLATE NOCASE ASC,
            token_b COLLATE NOCASE ASC
            """
        case .rating:
            return """
            CASE WHEN rated_recipe_count = 0 THEN 1 ELSE 0 END ASC,
            average_star_rating DESC,
            rated_recipe_count DESC,
            favorite_recipe_count DESC,
            recipe_count DESC,
            token_a COLLATE NOCASE ASC,
            token_b COLLATE NOCASE ASC
            """
        case .name:
            return """
            token_a COLLATE NOCASE ASC,
            token_b COLLATE NOCASE ASC
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
            sourceFingerprint: row["source_fingerprint"],
            derivedAt: DatabaseTimestamp.decodeRequired(derivedAtValue),
            prepTimeMinutes: row["prep_time_minutes"],
            cookTimeMinutes: row["cook_time_minutes"],
            totalTimeMinutes: row["total_time_minutes"],
            totalTimeBasis: totalTimeBasisRaw.flatMap(RecipeTotalTimeBasis.init(rawValue:)),
            ingredientLineCount: row["ingredient_line_count"],
            ingredientLineCountBasis: ingredientLineCountBasisRaw.flatMap(RecipeIngredientLineCountBasis.init(rawValue:))
        )
    }

    private static func decodeRecipeUsageStats(row: Row) -> RecipeUsageStats? {
        let derivedAtValue: String? = row["usage_derived_at"] ?? row["derived_at"]
        let mealCount: Int? = row["meal_count"] ?? row["times_cooked"]
        guard let derivedAtValue, let mealCount else {
            return nil
        }

        return RecipeUsageStats(
            uid: row["usage_uid"] ?? row["uid"],
            derivedAt: DatabaseTimestamp.decodeRequired(derivedAtValue),
            mealCount: mealCount,
            firstMealAt: row["first_meal_at"],
            firstCookedAt: row["first_cooked_at"] ?? row["first_meal_at"],
            lastMealAt: row["last_meal_at"] ?? row["last_cooked_at"],
            mealGapDays: decodeIntArrayJSON(row["meal_gap_days_json"]),
            daysSpannedByMeals: row["days_spanned_by_meals"],
            medianMealGapDays: row["median_meal_gap_days"],
            mealShare: row["meal_share"]
        )
    }

    private static func decodeIngredientPairSummary(row: Row) -> IngredientPairEvidenceSummary {
        IngredientPairEvidenceSummary(
            basis: row["basis"],
            tokenA: row["token_a"],
            tokenB: row["token_b"],
            recipeCount: row["recipe_count"],
            cookedRecipeCount: row["cooked_recipe_count"],
            cookedMealCount: row["cooked_meal_count"],
            favoriteRecipeCount: row["favorite_recipe_count"],
            ratedRecipeCount: row["rated_recipe_count"],
            averageStarRating: row["average_star_rating"],
            firstMealAt: row["first_meal_at"],
            lastMealAt: row["last_meal_at"]
        )
    }

    private static func fetchIngredientPairRecipeEvidence(
        tokenA: String,
        tokenB: String,
        limit: Int,
        db: Database
    ) throws -> [IngredientPairRecipeEvidence] {
        try Row.fetchAll(
            db,
            sql: """
            SELECT
                recipe_uid,
                recipe_name,
                source_name,
                token_a_line_numbers_json,
                token_b_line_numbers_json,
                is_favorite,
                star_rating,
                meal_count,
                first_meal_at,
                last_meal_at
            FROM ingredient_pair_recipe_evidence
            WHERE basis = ?
                AND token_a = ?
                AND token_b = ?
            ORDER BY
                meal_count DESC,
                CASE WHEN last_meal_at IS NULL THEN 1 ELSE 0 END ASC,
                last_meal_at DESC,
                COALESCE(star_rating, 0) DESC,
                is_favorite DESC,
                recipe_name COLLATE NOCASE ASC,
                recipe_uid ASC
            LIMIT ?
            """,
            arguments: [
                ingredientPairEvidenceBasis,
                tokenA,
                tokenB,
                max(0, limit),
            ]
        ).map { row in
            IngredientPairRecipeEvidence(
                recipeUID: row["recipe_uid"],
                recipeName: row["recipe_name"],
                sourceName: row["source_name"],
                tokenALineNumbers: decodeIntArrayJSON(row["token_a_line_numbers_json"]) ?? [],
                tokenBLineNumbers: decodeIntArrayJSON(row["token_b_line_numbers_json"]) ?? [],
                isFavorite: row["is_favorite"],
                starRating: row["star_rating"],
                mealCount: row["meal_count"],
                firstMealAt: row["first_meal_at"],
                lastMealAt: row["last_meal_at"]
            )
        }
    }

    private static func normalizedSingleIngredientToken(_ rawValue: String) -> String? {
        let tokens = IngredientNormalizer.normalizedQueryTokens(from: [rawValue])
        return tokens.count == 1 ? tokens[0] : nil
    }

    private static func orderedPair(_ lhs: String, _ rhs: String) -> (String, String) {
        lhs <= rhs ? (lhs, rhs) : (rhs, lhs)
    }

    private static func normalizedSearchQuery(_ query: String) -> String {
        query
            .split(whereSeparator: \.isWhitespace)
            .map { "\"\($0.replacing("\"", with: "\"\""))\"" }
            .joined(separator: " ")
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

    private static func decodeCategories(_ value: String) -> [String] {
        value.split(separator: "\u{1F}").map(String.init)
    }

    private static func decodeIntArrayJSON(_ value: String?) -> [Int]? {
        guard let value, let data = value.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode([Int].self, from: data)
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

