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
    public let recipeUsageStatsCount: Int
    public let recipeUsageStatsWithLastMealAtCount: Int
    public let recipeUsageStatsWithGapArrayCount: Int
    public let recipeUsageTotalMealCount: Int
    public let ingredientPairSummaryCount: Int
    public let ingredientPairRecipeEvidenceCount: Int
    public let lastRecipeSearchRun: PantryIndexRun?
    public let lastSuccessfulRecipeSearchRun: PantryIndexRun?
    public let lastRecipeFeatureRun: PantryIndexRun?
    public let lastSuccessfulRecipeFeatureRun: PantryIndexRun?
    public let lastRecipeIngredientRun: PantryIndexRun?
    public let lastSuccessfulRecipeIngredientRun: PantryIndexRun?
    public let lastRecipeUsageRun: PantryIndexRun?
    public let lastSuccessfulRecipeUsageRun: PantryIndexRun?
    public let lastIngredientPairRun: PantryIndexRun?
    public let lastSuccessfulIngredientPairRun: PantryIndexRun?
    public let sourceState: PantryStoredSourceState?

    public init(
        recipeSearchDocumentCount: Int,
        recipeFeatureCount: Int,
        recipeFeaturesWithTotalTimeCount: Int,
        recipeFeaturesWithIngredientLineCountCount: Int,
        recipeIngredientRecipeCount: Int = 0,
        recipeIngredientLineCount: Int = 0,
        recipeIngredientTokenCount: Int = 0,
        recipeUsageStatsCount: Int = 0,
        recipeUsageStatsWithLastMealAtCount: Int = 0,
        recipeUsageStatsWithGapArrayCount: Int = 0,
        recipeUsageTotalMealCount: Int = 0,
        ingredientPairSummaryCount: Int = 0,
        ingredientPairRecipeEvidenceCount: Int = 0,
        lastRecipeSearchRun: PantryIndexRun?,
        lastSuccessfulRecipeSearchRun: PantryIndexRun?,
        lastRecipeFeatureRun: PantryIndexRun?,
        lastSuccessfulRecipeFeatureRun: PantryIndexRun?,
        lastRecipeIngredientRun: PantryIndexRun? = nil,
        lastSuccessfulRecipeIngredientRun: PantryIndexRun? = nil,
        lastRecipeUsageRun: PantryIndexRun? = nil,
        lastSuccessfulRecipeUsageRun: PantryIndexRun? = nil,
        lastIngredientPairRun: PantryIndexRun? = nil,
        lastSuccessfulIngredientPairRun: PantryIndexRun? = nil,
        sourceState: PantryStoredSourceState? = nil
    ) {
        self.recipeSearchDocumentCount = recipeSearchDocumentCount
        self.recipeFeatureCount = recipeFeatureCount
        self.recipeFeaturesWithTotalTimeCount = recipeFeaturesWithTotalTimeCount
        self.recipeFeaturesWithIngredientLineCountCount = recipeFeaturesWithIngredientLineCountCount
        self.recipeIngredientRecipeCount = recipeIngredientRecipeCount
        self.recipeIngredientLineCount = recipeIngredientLineCount
        self.recipeIngredientTokenCount = recipeIngredientTokenCount
        self.recipeUsageStatsCount = recipeUsageStatsCount
        self.recipeUsageStatsWithLastMealAtCount = recipeUsageStatsWithLastMealAtCount
        self.recipeUsageStatsWithGapArrayCount = recipeUsageStatsWithGapArrayCount
        self.recipeUsageTotalMealCount = recipeUsageTotalMealCount
        self.ingredientPairSummaryCount = ingredientPairSummaryCount
        self.ingredientPairRecipeEvidenceCount = ingredientPairRecipeEvidenceCount
        self.lastRecipeSearchRun = lastRecipeSearchRun
        self.lastSuccessfulRecipeSearchRun = lastSuccessfulRecipeSearchRun
        self.lastRecipeFeatureRun = lastRecipeFeatureRun
        self.lastSuccessfulRecipeFeatureRun = lastSuccessfulRecipeFeatureRun
        self.lastRecipeIngredientRun = lastRecipeIngredientRun
        self.lastSuccessfulRecipeIngredientRun = lastSuccessfulRecipeIngredientRun
        self.lastRecipeUsageRun = lastRecipeUsageRun
        self.lastSuccessfulRecipeUsageRun = lastSuccessfulRecipeUsageRun
        self.lastIngredientPairRun = lastIngredientPairRun
        self.lastSuccessfulIngredientPairRun = lastSuccessfulIngredientPairRun
        self.sourceState = sourceState
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

    public var recipeUsageStatsReady: Bool {
        lastSuccessfulRecipeUsageRun != nil
    }

    public var ingredientPairEvidenceReady: Bool {
        lastSuccessfulIngredientPairRun != nil
    }
}

public enum IngredientPairEvidenceSort: String, CaseIterable, Codable, Sendable, ExpressibleByArgument {
    case recipes
    case meals
    case favorites
    case rating
    case name
}

public struct IngredientPairRecipeEvidence: Codable, Equatable, Sendable {
    public let recipeUID: String
    public let recipeName: String
    public let sourceName: String?
    public let tokenALineNumbers: [Int]
    public let tokenBLineNumbers: [Int]
    public let isFavorite: Bool
    public let starRating: Int?
    public let mealCount: Int
    public let firstMealAt: String?
    public let lastMealAt: String?

    public init(
        recipeUID: String,
        recipeName: String,
        sourceName: String?,
        tokenALineNumbers: [Int],
        tokenBLineNumbers: [Int],
        isFavorite: Bool,
        starRating: Int?,
        mealCount: Int,
        firstMealAt: String?,
        lastMealAt: String?
    ) {
        self.recipeUID = recipeUID
        self.recipeName = recipeName
        self.sourceName = sourceName
        self.tokenALineNumbers = tokenALineNumbers
        self.tokenBLineNumbers = tokenBLineNumbers
        self.isFavorite = isFavorite
        self.starRating = starRating
        self.mealCount = mealCount
        self.firstMealAt = firstMealAt
        self.lastMealAt = lastMealAt
    }
}

public struct IngredientPairEvidenceSummary: Codable, Equatable, Sendable {
    public let basis: String
    public let tokenA: String
    public let tokenB: String
    public let recipeCount: Int
    public let cookedRecipeCount: Int
    public let cookedMealCount: Int
    public let favoriteRecipeCount: Int
    public let ratedRecipeCount: Int
    public let averageStarRating: Double?
    public let firstMealAt: String?
    public let lastMealAt: String?
    public let recipeEvidence: [IngredientPairRecipeEvidence]

    public init(
        basis: String,
        tokenA: String,
        tokenB: String,
        recipeCount: Int,
        cookedRecipeCount: Int,
        cookedMealCount: Int,
        favoriteRecipeCount: Int,
        ratedRecipeCount: Int,
        averageStarRating: Double?,
        firstMealAt: String?,
        lastMealAt: String?,
        recipeEvidence: [IngredientPairRecipeEvidence] = []
    ) {
        self.basis = basis
        self.tokenA = tokenA
        self.tokenB = tokenB
        self.recipeCount = recipeCount
        self.cookedRecipeCount = cookedRecipeCount
        self.cookedMealCount = cookedMealCount
        self.favoriteRecipeCount = favoriteRecipeCount
        self.ratedRecipeCount = ratedRecipeCount
        self.averageStarRating = averageStarRating
        self.firstMealAt = firstMealAt
        self.lastMealAt = lastMealAt
        self.recipeEvidence = recipeEvidence
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
    public let usedRecipeCount: Int
    public let unusedRecipeCount: Int
    public let mealCount: Int
    public let mealShare: Double
    public let firstMealAt: String?
    public let lastMealAt: String?
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
        usedRecipeCount: Int = 0,
        unusedRecipeCount: Int? = nil,
        mealCount: Int = 0,
        mealShare: Double = 0,
        firstMealAt: String? = nil,
        lastMealAt: String? = nil,
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
        self.usedRecipeCount = usedRecipeCount
        self.unusedRecipeCount = unusedRecipeCount ?? max(0, recipeCount - usedRecipeCount)
        self.mealCount = mealCount
        self.mealShare = mealShare
        self.firstMealAt = firstMealAt
        self.lastMealAt = lastMealAt
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
    public let usageStats: RecipeUsageStats?

    public init(
        uid: String,
        name: String,
        categories: [String],
        sourceName: String?,
        isFavorite: Bool,
        starRating: Int?,
        derivedFeatures: RecipeDerivedFeatures? = nil,
        usageStats: RecipeUsageStats? = nil
    ) {
        self.uid = uid
        self.name = name
        self.categories = categories
        self.sourceName = sourceName
        self.isFavorite = isFavorite
        self.starRating = starRating
        self.derivedFeatures = derivedFeatures
        self.usageStats = usageStats
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
    public let recipeUsageStatsCount: Int
    public let recipeUsageStatsWithLastMealAtCount: Int
    public let recipeUsageStatsWithGapArrayCount: Int
    public let linkedMealCount: Int
    public let totalMealCount: Int
    public let refreshedIngredientPairEvidence: Bool
    public let ingredientPairSummaryCount: Int
    public let ingredientPairRecipeEvidenceCount: Int
    public let sourceState: PantryStoredSourceState?

    public init(
        startedAt: Date,
        finishedAt: Date,
        recipeSearchDocumentCount: Int,
        recipeFeatureCount: Int,
        recipeFeaturesWithTotalTimeCount: Int,
        recipeFeaturesWithIngredientLineCountCount: Int,
        recipeIngredientRecipeCount: Int = 0,
        recipeIngredientLineCount: Int = 0,
        recipeIngredientTokenCount: Int = 0,
        recipeUsageStatsCount: Int = 0,
        recipeUsageStatsWithLastMealAtCount: Int = 0,
        recipeUsageStatsWithGapArrayCount: Int = 0,
        linkedMealCount: Int = 0,
        totalMealCount: Int = 0,
        refreshedIngredientPairEvidence: Bool = true,
        ingredientPairSummaryCount: Int = 0,
        ingredientPairRecipeEvidenceCount: Int = 0,
        sourceState: PantryStoredSourceState? = nil
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
        self.recipeUsageStatsCount = recipeUsageStatsCount
        self.recipeUsageStatsWithLastMealAtCount = recipeUsageStatsWithLastMealAtCount
        self.recipeUsageStatsWithGapArrayCount = recipeUsageStatsWithGapArrayCount
        self.linkedMealCount = linkedMealCount
        self.totalMealCount = totalMealCount
        self.refreshedIngredientPairEvidence = refreshedIngredientPairEvidence
        self.ingredientPairSummaryCount = ingredientPairSummaryCount
        self.ingredientPairRecipeEvidenceCount = ingredientPairRecipeEvidenceCount
        self.sourceState = sourceState
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
    public let sourceFingerprint: String?
    public let derivedAt: Date
    public let prepTimeMinutes: Int?
    public let cookTimeMinutes: Int?
    public let totalTimeMinutes: Int?
    public let totalTimeBasis: RecipeTotalTimeBasis?
    public let ingredientLineCount: Int?
    public let ingredientLineCountBasis: RecipeIngredientLineCountBasis?

    public init(
        uid: String,
        sourceFingerprint: String?,
        derivedAt: Date,
        prepTimeMinutes: Int?,
        cookTimeMinutes: Int?,
        totalTimeMinutes: Int?,
        totalTimeBasis: RecipeTotalTimeBasis?,
        ingredientLineCount: Int?,
        ingredientLineCountBasis: RecipeIngredientLineCountBasis?
    ) {
        self.uid = uid
        self.sourceFingerprint = sourceFingerprint
        self.derivedAt = derivedAt
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.totalTimeMinutes = totalTimeMinutes
        self.totalTimeBasis = totalTimeBasis
        self.ingredientLineCount = ingredientLineCount
        self.ingredientLineCountBasis = ingredientLineCountBasis
    }

    public func sourceFingerprintMatches(_ currentSourceFingerprint: String?) -> Bool? {
        guard let currentSourceFingerprint, let sourceFingerprint else {
            return nil
        }

        return currentSourceFingerprint == sourceFingerprint
    }
}

public struct RecipeUsageStats: Codable, Equatable, Sendable {
    public let uid: String
    public let derivedAt: Date
    public let mealCount: Int
    public let firstMealAt: String?
    public let lastMealAt: String?
    public let mealGapDays: [Int]?
    public let daysSpannedByMeals: Int?
    public let medianMealGapDays: Double?
    public let mealShare: Double?

    public init(
        uid: String,
        derivedAt: Date,
        mealCount: Int,
        firstMealAt: String?,
        lastMealAt: String?,
        mealGapDays: [Int]?,
        daysSpannedByMeals: Int?,
        medianMealGapDays: Double?,
        mealShare: Double?
    ) {
        self.uid = uid
        self.derivedAt = derivedAt
        self.mealCount = mealCount
        self.firstMealAt = firstMealAt
        self.lastMealAt = lastMealAt
        self.mealGapDays = mealGapDays
        self.daysSpannedByMeals = daysSpannedByMeals
        self.medianMealGapDays = medianMealGapDays
        self.mealShare = mealShare
    }

    public init(
        uid: String,
        derivedAt: Date,
        timesCooked: Int,
        lastCookedAt: String?
    ) {
        self.init(
            uid: uid,
            derivedAt: derivedAt,
            mealCount: timesCooked,
            firstMealAt: nil,
            lastMealAt: lastCookedAt,
            mealGapDays: nil,
            daysSpannedByMeals: nil,
            medianMealGapDays: nil,
            mealShare: nil
        )
    }

    public var timesCooked: Int {
        mealCount
    }

    public var lastCookedAt: String? {
        lastMealAt
    }

    public func daysSinceLastMeal(referenceDate: Date = Date()) -> Int? {
        guard let lastMealAt, let lastMealDate = MealHistoryDateSupport.parsedDate(from: lastMealAt) else {
            return nil
        }

        return MealHistoryDateSupport.dayDistance(from: lastMealDate, to: referenceDate)
    }
}

public struct PantrySidecarStore: @unchecked Sendable {
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
                sourceState: try fetchStoredSourceState(db: db)
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
        try dbQueue.read { db in
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
        try dbQueue.read { db in
            guard
                let row = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT
                        uid,
                        derived_at,
                        meal_count,
                        first_meal_at,
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
        try dbQueue.read { db in
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
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    uid,
                    derived_at,
                    meal_count,
                    first_meal_at,
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
        try dbQueue.read { db in
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

        return try dbQueue.read { db in
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

    public func rebuildRecipeIndexes(
        from source: any PantrySource,
        refreshIngredientPairEvidence: Bool = true,
        now: @escaping @Sendable () -> Date = Date.init
    ) async throws -> RecipeIndexesRebuildSummary {
        let startedAt = now()
        let searchRunID = try startIndexRun(named: Self.recipeSearchIndexName, startedAt: startedAt)
        let featureRunID = try startIndexRun(named: Self.recipeFeatureIndexName, startedAt: startedAt)
        let ingredientRunID = try startIndexRun(named: Self.recipeIngredientIndexName, startedAt: startedAt)
        let usageRunID = try startIndexRun(named: Self.recipeUsageIndexName, startedAt: startedAt)
        let ingredientPairRunID = refreshIngredientPairEvidence
            ? try startIndexRun(named: Self.ingredientPairIndexName, startedAt: startedAt)
            : nil

        do {
            let categoryNamesByUID = try await loadCategoryNamesByUID(from: source)
            let stubs = try await source.listRecipeStubs()
            let activeStubs = stubs.filter { !$0.isDeleted }
            let activeRecipeUIDs = Set(activeStubs.map(\.uid))
            let meals: [SourceMeal]
            if let mealsSource = source as? any MealsReadablePantrySource {
                meals = try await mealsSource.listMeals()
            } else {
                meals = []
            }

            var documents = [RecipeSearchDocument]()
            var features = [RecipeDerivedFeatures]()
            var ingredientIndexes = [RecipeIngredientIndex]()
            let usageStats = Self.deriveUsageStats(
                from: meals,
                activeRecipeUIDs: activeRecipeUIDs,
                derivedAt: startedAt,
                referenceDate: startedAt
            )
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
                        sourceFingerprint: recipe.sourceFingerprint,
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
                    sourceFingerprint: recipe.sourceFingerprint,
                    ingredients: recipe.ingredients,
                    derivedAt: startedAt
                ) {
                    ingredientIndexes.append(ingredientIndex)
                }
            }

            let indexedAt = now()
            let indexedAtString = DatabaseTimestamp.encode(indexedAt)
            let sortedDocuments = documents.sorted(by: Self.sortSearchDocuments)
            let sortedFeatures = features.sorted { $0.uid < $1.uid }
            let sortedIngredientIndexes = ingredientIndexes.sorted { $0.uid < $1.uid }
            let sortedUsageStats = usageStats.stats.sorted { $0.uid < $1.uid }
            let sortedIngredientPairSummaries: [IngredientPairEvidenceSummary]
            let sortedIngredientPairEvidence: [IngredientPairRecipeEvidenceRow]
            if refreshIngredientPairEvidence {
                let ingredientPairDerivation = Self.deriveIngredientPairEvidence(
                    ingredientIndexes: sortedIngredientIndexes,
                    documents: sortedDocuments,
                    usageStats: sortedUsageStats,
                    derivedAt: indexedAt
                )
                sortedIngredientPairSummaries = ingredientPairDerivation.summaries.sorted {
                    if $0.tokenA != $1.tokenA {
                        return $0.tokenA < $1.tokenA
                    }

                    return $0.tokenB < $1.tokenB
                }
                sortedIngredientPairEvidence = ingredientPairDerivation.recipeEvidence.sorted {
                    if $0.tokenA != $1.tokenA {
                        return $0.tokenA < $1.tokenA
                    }

                    if $0.tokenB != $1.tokenB {
                        return $0.tokenB < $1.tokenB
                    }

                    return $0.recipeUID < $1.recipeUID
                }
            } else {
                sortedIngredientPairSummaries = []
                sortedIngredientPairEvidence = []
            }
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
            let recipeUsageStatsCount = sortedUsageStats.count
            let recipeUsageStatsWithLastMealAtCount = sortedUsageStats.reduce(into: 0) { count, stats in
                if stats.lastMealAt != nil {
                    count += 1
                }
            }
            let recipeUsageStatsWithGapArrayCount = sortedUsageStats.reduce(into: 0) { count, stats in
                if stats.mealGapDays != nil {
                    count += 1
                }
            }
            let linkedMealCount = usageStats.linkedMealCount
            let totalMealCount = usageStats.totalMealCount
            let ingredientPairSummaryCount = sortedIngredientPairSummaries.count
            let ingredientPairRecipeEvidenceCount = sortedIngredientPairEvidence.count
            let sourceState = Self.makeStoredSourceState(from: source, observedAt: indexedAt)
            let transactionFinishedAt = try await dbQueue.write { db in
                if refreshIngredientPairEvidence {
                    try Self.dropIngredientPairSecondaryIndexes(in: db)
                }

                try db.execute(sql: "DELETE FROM recipe_search_documents")
                try db.execute(sql: "DELETE FROM recipe_search_fts")
                try db.execute(sql: "DELETE FROM recipe_features")
                try db.execute(sql: "DELETE FROM recipe_ingredient_tokens")
                try db.execute(sql: "DELETE FROM recipe_ingredient_lines")
                try db.execute(sql: "DELETE FROM recipe_usage_stats")
                try db.execute(sql: "DELETE FROM recipe_usage_summary")
                if refreshIngredientPairEvidence {
                    try db.execute(sql: "DELETE FROM ingredient_pair_recipe_evidence")
                    try db.execute(sql: "DELETE FROM ingredient_pair_summaries")
                }
                try db.execute(sql: "DELETE FROM source_state")

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
                            source_fingerprint,
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
                            document.sourceFingerprint,
                            indexedAtString,
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
                            source_fingerprint,
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
                            feature.sourceFingerprint,
                            indexedAtString,
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
                                source_fingerprint,
                                derived_at
                            ) VALUES (?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [
                                ingredientIndex.uid,
                                line.lineNumber,
                                line.sourceText,
                                line.normalizedText,
                                ingredientIndex.sourceFingerprint,
                                indexedAtString,
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

                for usageStat in sortedUsageStats {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_usage_stats (
                            uid,
                            derived_at,
                            times_cooked,
                            last_cooked_at,
                            meal_count,
                            first_meal_at,
                            last_meal_at,
                            meal_gap_days_json,
                            days_spanned_by_meals,
                            median_meal_gap_days,
                            meal_share
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            usageStat.uid,
                            indexedAtString,
                            usageStat.mealCount,
                            usageStat.lastMealAt,
                            usageStat.mealCount,
                            usageStat.firstMealAt,
                            usageStat.lastMealAt,
                            Self.encodeIntArrayJSON(usageStat.mealGapDays),
                            usageStat.daysSpannedByMeals,
                            usageStat.medianMealGapDays,
                            usageStat.mealShare,
                        ]
                    )
                }

                try db.execute(
                    sql: """
                    INSERT INTO recipe_usage_summary (
                        summary_key,
                        derived_at,
                        total_meal_count
                    ) VALUES (?, ?, ?)
                    """,
                    arguments: [
                        Self.recipeUsageSummaryKey,
                        indexedAtString,
                        totalMealCount,
                    ]
                )

                if refreshIngredientPairEvidence {
                    let insertIngredientPairSummaryStatement = try db.makeStatement(
                        sql: """
                        INSERT INTO ingredient_pair_summaries (
                        basis,
                        token_a,
                        token_b,
                        derived_at,
                        recipe_count,
                        cooked_recipe_count,
                        cooked_meal_count,
                        favorite_recipe_count,
                        rated_recipe_count,
                        average_star_rating,
                        first_meal_at,
                        last_meal_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """
                    )

                    for summary in sortedIngredientPairSummaries {
                        try insertIngredientPairSummaryStatement.execute(arguments: [
                            summary.basis,
                            summary.tokenA,
                            summary.tokenB,
                            indexedAtString,
                            summary.recipeCount,
                            summary.cookedRecipeCount,
                            summary.cookedMealCount,
                            summary.favoriteRecipeCount,
                            summary.ratedRecipeCount,
                            summary.averageStarRating,
                            summary.firstMealAt,
                            summary.lastMealAt,
                        ])
                    }

                    let insertIngredientPairRecipeEvidenceStatement = try db.makeStatement(
                        sql: """
                        INSERT INTO ingredient_pair_recipe_evidence (
                        basis,
                        token_a,
                        token_b,
                        recipe_uid,
                        recipe_name,
                        source_name,
                        token_a_line_numbers_json,
                        token_b_line_numbers_json,
                        is_favorite,
                        star_rating,
                        meal_count,
                        first_meal_at,
                        last_meal_at,
                        derived_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """
                    )

                    for evidence in sortedIngredientPairEvidence {
                        try insertIngredientPairRecipeEvidenceStatement.execute(arguments: [
                            evidence.basis,
                            evidence.tokenA,
                            evidence.tokenB,
                            evidence.recipeUID,
                            evidence.recipeName,
                            evidence.sourceName,
                            Self.encodeIntArrayJSON(evidence.tokenALineNumbers),
                            Self.encodeIntArrayJSON(evidence.tokenBLineNumbers),
                            evidence.isFavorite,
                            evidence.starRating,
                            evidence.mealCount,
                            evidence.firstMealAt,
                            evidence.lastMealAt,
                            indexedAtString,
                        ])
                    }

                    try Self.createIngredientPairSecondaryIndexes(in: db)
                }

                if let sourceState {
                    try writeStoredSourceState(sourceState, in: db)
                }

                let finishedAt = now()
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
                try finishIndexRun(
                    id: usageRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: recipeUsageStatsCount,
                    errorMessage: nil,
                    in: db
                )
                if let ingredientPairRunID {
                    try finishIndexRun(
                        id: ingredientPairRunID,
                        status: .success,
                        finishedAt: finishedAt,
                        recipeCount: ingredientPairSummaryCount,
                        errorMessage: nil,
                        in: db
                    )
                }
                return finishedAt
            }
            let finishedAt = max(transactionFinishedAt, now())

            return RecipeIndexesRebuildSummary(
                startedAt: startedAt,
                finishedAt: finishedAt,
                recipeSearchDocumentCount: recipeSearchDocumentCount,
                recipeFeatureCount: recipeFeatureCount,
                recipeFeaturesWithTotalTimeCount: recipeFeaturesWithTotalTimeCount,
                recipeFeaturesWithIngredientLineCountCount: recipeFeaturesWithIngredientLineCountCount,
                recipeIngredientRecipeCount: recipeIngredientRecipeCount,
                recipeIngredientLineCount: recipeIngredientLineCount,
                recipeIngredientTokenCount: recipeIngredientTokenCount,
                recipeUsageStatsCount: recipeUsageStatsCount,
                recipeUsageStatsWithLastMealAtCount: recipeUsageStatsWithLastMealAtCount,
                recipeUsageStatsWithGapArrayCount: recipeUsageStatsWithGapArrayCount,
                linkedMealCount: linkedMealCount,
                totalMealCount: totalMealCount,
                refreshedIngredientPairEvidence: refreshIngredientPairEvidence,
                ingredientPairSummaryCount: ingredientPairSummaryCount,
                ingredientPairRecipeEvidenceCount: ingredientPairRecipeEvidenceCount,
                sourceState: sourceState
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
            try finishIndexRun(
                id: usageRunID,
                status: .failed,
                finishedAt: now(),
                recipeCount: 0,
                errorMessage: String(describing: error)
            )
            if let ingredientPairRunID {
                try finishIndexRun(
                    id: ingredientPairRunID,
                    status: .failed,
                    finishedAt: now(),
                    recipeCount: 0,
                    errorMessage: String(describing: error)
                )
            }
            throw error
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

    private static func makeStoredSourceState(
        from source: any PantrySource,
        observedAt: Date
    ) -> PantryStoredSourceState? {
        guard let source = source as? PaprikaSQLiteSource else {
            return nil
        }

        return PantryStoredSourceState(
            sourceType: PantrySourceType.paprikaSQLite,
            sourceLocation: source.databaseURL.path,
            observedAt: observedAt,
            paprikaSync: source.inspection.paprikaSync
        )
    }

    private func writeStoredSourceState(
        _ sourceState: PantryStoredSourceState,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO source_state (
                source_type,
                source_location,
                observed_at,
                paprika_last_sync_at,
                paprika_sync_signal_source,
                paprika_sync_signal_location
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                sourceState.sourceType,
                sourceState.sourceLocation,
                DatabaseTimestamp.encode(sourceState.observedAt),
                sourceState.paprikaSync.map { DatabaseTimestamp.encode($0.lastSyncAt) },
                sourceState.paprikaSync?.signalSource,
                sourceState.paprikaSync?.signalLocation,
            ]
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
    private static let recipeUsageIndexName = "recipe-usage"
    private static let ingredientPairIndexName = "ingredient-pairs"
    public static let ingredientPairEvidenceBasis = "recipe-token-cooccurrence-v1"
    private static let recipeUsageSummaryKey = "current"

    private static func dropIngredientPairSecondaryIndexes(in db: Database) throws {
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_token_a")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_token_b")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_recipe_count")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_cooked_meal_count")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_recipe_evidence_on_recipe_uid")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_recipe_evidence_on_pair")
    }

    private static func createIngredientPairSecondaryIndexes(in db: Database) throws {
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_token_a ON ingredient_pair_summaries(token_a)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_token_b ON ingredient_pair_summaries(token_b)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_recipe_count ON ingredient_pair_summaries(recipe_count)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_cooked_meal_count ON ingredient_pair_summaries(cooked_meal_count)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_recipe_evidence_on_recipe_uid ON ingredient_pair_recipe_evidence(recipe_uid)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_recipe_evidence_on_pair ON ingredient_pair_recipe_evidence(basis, token_a, token_b)")
    }

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

    private static func encodeIntArrayJSON(_ values: [Int]?) -> String? {
        guard let values else {
            return nil
        }

        return "[\(values.map(String.init).joined(separator: ","))]"
    }

    private static func decodeIntArrayJSON(_ value: String?) -> [Int]? {
        guard let value, let data = value.data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode([Int].self, from: data)
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
            sourceFingerprint: recipe.sourceFingerprint,
            derivedAt: derivedAt,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            totalTimeMinutes: totalTimeMinutes,
            totalTimeBasis: totalTimeBasis,
            ingredientLineCount: ingredientLineCount,
            ingredientLineCountBasis: ingredientLineCount == nil ? nil : .nonEmptyLines
        )
    }

    private static func deriveUsageStats(
        from meals: [SourceMeal],
        activeRecipeUIDs: Set<String>,
        derivedAt: Date,
        referenceDate: Date
    ) -> RecipeUsageDerivation {
        let qualifyingMeals = meals.enumerated().compactMap { offset, meal -> QualifiedMealOccurrence? in
            guard !meal.isDeleted else {
                return nil
            }

            guard
                let scheduledAt = meal.scheduledAt?.trimmingCharacters(in: .whitespacesAndNewlines),
                !scheduledAt.isEmpty,
                let scheduledDate = MealHistoryDateSupport.parsedDate(from: scheduledAt),
                scheduledDate <= referenceDate
            else {
                return nil
            }

            return QualifiedMealOccurrence(
                inputOrder: offset,
                scheduledAt: scheduledAt,
                scheduledDate: scheduledDate,
                recipeUID: meal.recipeUID?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
            )
        }

        let totalMealCount = qualifyingMeals.count
        var linkedMealCount = 0
        var mealsByRecipeUID = [String: [QualifiedMealOccurrence]]()

        for meal in qualifyingMeals {
            guard let recipeUID = meal.recipeUID, activeRecipeUIDs.contains(recipeUID) else {
                continue
            }

            linkedMealCount += 1
            mealsByRecipeUID[recipeUID, default: []].append(meal)
        }

        let stats = mealsByRecipeUID.map { recipeUID, recipeMeals in
            let sortedMeals = recipeMeals.sorted { lhs, rhs in
                if lhs.scheduledDate != rhs.scheduledDate {
                    return lhs.scheduledDate < rhs.scheduledDate
                }

                return lhs.inputOrder < rhs.inputOrder
            }

            let mealGapDays: [Int]? = sortedMeals.count < 2
                ? nil
                : zip(sortedMeals, sortedMeals.dropFirst()).map { earlier, later in
                    MealHistoryDateSupport.dayDistance(
                        from: earlier.scheduledDate,
                        to: later.scheduledDate
                    )
                }
            let firstMeal = sortedMeals.first
            let lastMeal = sortedMeals.last
            let daysSpannedByMeals = sortedMeals.count < 2
                ? nil
                : firstMeal.flatMap { firstMeal in
                    lastMeal.map { lastMeal in
                        MealHistoryDateSupport.dayDistance(
                            from: firstMeal.scheduledDate,
                            to: lastMeal.scheduledDate
                        )
                    }
                }

            return RecipeUsageStats(
                uid: recipeUID,
                derivedAt: derivedAt,
                mealCount: sortedMeals.count,
                firstMealAt: firstMeal?.scheduledAt,
                lastMealAt: lastMeal?.scheduledAt,
                mealGapDays: mealGapDays,
                daysSpannedByMeals: daysSpannedByMeals,
                medianMealGapDays: median(of: mealGapDays),
                mealShare: totalMealCount == 0 ? nil : Double(sortedMeals.count) / Double(totalMealCount)
            )
        }

        return RecipeUsageDerivation(
            stats: stats,
            linkedMealCount: linkedMealCount,
            totalMealCount: totalMealCount
        )
    }

    private static func deriveIngredientPairEvidence(
        ingredientIndexes: [RecipeIngredientIndex],
        documents: [RecipeSearchDocument],
        usageStats: [RecipeUsageStats],
        derivedAt: Date
    ) -> IngredientPairDerivation {
        let documentsByUID = Dictionary(uniqueKeysWithValues: documents.map { ($0.uid, $0) })
        let usageStatsByUID = Dictionary(uniqueKeysWithValues: usageStats.map { ($0.uid, $0) })
        var evidenceRows = [IngredientPairRecipeEvidenceRow]()
        var aggregates = [IngredientPairKey: IngredientPairAggregate]()

        for ingredientIndex in ingredientIndexes {
            guard let document = documentsByUID[ingredientIndex.uid] else {
                continue
            }

            let lineNumbersByToken = ingredientIndex.lines.reduce(into: [String: Set<Int>]()) { partialResult, line in
                for token in line.normalizedTokens {
                    partialResult[token, default: []].insert(line.lineNumber)
                }
            }
            let tokens = lineNumbersByToken.keys.sorted()
            guard tokens.count > 1 else {
                continue
            }

            let usage = usageStatsByUID[ingredientIndex.uid]
            for firstIndex in tokens.indices.dropLast() {
                for secondIndex in tokens.index(after: firstIndex) ..< tokens.endIndex {
                    let tokenA = tokens[firstIndex]
                    let tokenB = tokens[secondIndex]
                    guard tokenA != tokenB else {
                        continue
                    }

                    let key = IngredientPairKey(tokenA: tokenA, tokenB: tokenB)
                    let evidence = IngredientPairRecipeEvidenceRow(
                        basis: ingredientPairEvidenceBasis,
                        tokenA: tokenA,
                        tokenB: tokenB,
                        recipeUID: ingredientIndex.uid,
                        recipeName: document.name,
                        sourceName: document.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        tokenALineNumbers: (lineNumbersByToken[tokenA] ?? []).sorted(),
                        tokenBLineNumbers: (lineNumbersByToken[tokenB] ?? []).sorted(),
                        isFavorite: document.isFavorite,
                        starRating: document.starRating,
                        mealCount: usage?.mealCount ?? 0,
                        firstMealAt: usage?.firstMealAt,
                        lastMealAt: usage?.lastMealAt,
                        derivedAt: derivedAt
                    )
                    evidenceRows.append(evidence)
                    aggregates[key, default: IngredientPairAggregate(tokenA: tokenA, tokenB: tokenB)]
                        .add(evidence)
                }
            }
        }

        let summaries = aggregates.values.map { aggregate in
            aggregate.summary(basis: ingredientPairEvidenceBasis)
        }

        return IngredientPairDerivation(summaries: summaries, recipeEvidence: evidenceRows)
    }

    private static func median(of values: [Int]?) -> Double? {
        guard let values, !values.isEmpty else {
            return nil
        }

        let sortedValues = values.sorted()
        let middleIndex = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return Double(sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2.0
        }

        return Double(sortedValues[middleIndex])
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

public typealias PantryStore = PantrySidecarStore

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
    let sourceFingerprint: String?
    let isFavorite: Bool
    let starRating: Int?
}

private struct IngredientPairKey: Hashable, Sendable {
    let tokenA: String
    let tokenB: String
}

private struct IngredientPairDerivation: Sendable {
    let summaries: [IngredientPairEvidenceSummary]
    let recipeEvidence: [IngredientPairRecipeEvidenceRow]
}

private struct IngredientPairRecipeEvidenceRow: Equatable, Sendable {
    let basis: String
    let tokenA: String
    let tokenB: String
    let recipeUID: String
    let recipeName: String
    let sourceName: String?
    let tokenALineNumbers: [Int]
    let tokenBLineNumbers: [Int]
    let isFavorite: Bool
    let starRating: Int?
    let mealCount: Int
    let firstMealAt: String?
    let lastMealAt: String?
    let derivedAt: Date
}

private struct IngredientPairAggregate: Sendable {
    let tokenA: String
    let tokenB: String
    var recipeCount = 0
    var cookedRecipeCount = 0
    var cookedMealCount = 0
    var favoriteRecipeCount = 0
    var ratedRecipeCount = 0
    var starRatingTotal = 0
    var firstMealAt: String?
    var lastMealAt: String?

    mutating func add(_ evidence: IngredientPairRecipeEvidenceRow) {
        recipeCount += 1

        if evidence.mealCount > 0 {
            cookedRecipeCount += 1
            cookedMealCount += evidence.mealCount
        }

        if evidence.isFavorite {
            favoriteRecipeCount += 1
        }

        if let starRating = evidence.starRating {
            ratedRecipeCount += 1
            starRatingTotal += starRating
        }

        if let evidenceFirstMealAt = evidence.firstMealAt {
            if firstMealAt == nil || evidenceFirstMealAt < firstMealAt! {
                firstMealAt = evidenceFirstMealAt
            }
        }

        if let evidenceLastMealAt = evidence.lastMealAt {
            if lastMealAt == nil || evidenceLastMealAt > lastMealAt! {
                lastMealAt = evidenceLastMealAt
            }
        }
    }

    func summary(basis: String) -> IngredientPairEvidenceSummary {
        IngredientPairEvidenceSummary(
            basis: basis,
            tokenA: tokenA,
            tokenB: tokenB,
            recipeCount: recipeCount,
            cookedRecipeCount: cookedRecipeCount,
            cookedMealCount: cookedMealCount,
            favoriteRecipeCount: favoriteRecipeCount,
            ratedRecipeCount: ratedRecipeCount,
            averageStarRating: ratedRecipeCount == 0 ? nil : Double(starRatingTotal) / Double(ratedRecipeCount),
            firstMealAt: firstMealAt,
            lastMealAt: lastMealAt
        )
    }
}

private struct RecipeUsageDerivation: Equatable, Sendable {
    let stats: [RecipeUsageStats]
    let linkedMealCount: Int
    let totalMealCount: Int
}

private struct QualifiedMealOccurrence: Equatable, Sendable {
    let inputOrder: Int
    let scheduledAt: String
    let scheduledDate: Date
    let recipeUID: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private enum MealHistoryDateSupport {
    static func parsedDate(from value: String) -> Date? {
        formatter().date(from: value)
    }

    static func dayDistance(from earlier: Date, to later: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let earlierDay = calendar.startOfDay(for: earlier)
        let laterDay = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: earlierDay, to: laterDay).day ?? 0
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
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
