import ArgumentParser
import Foundation

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
    public let compatibilityChecked: Bool
    public let incompatibleFamilies: [String]
    public let compatibilityIssue: String?
    public let provenance: [IndexBuildProvenance]
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
        sourceState: PantryStoredSourceState? = nil,
        compatibilityIssue: String? = nil, provenance: [IndexBuildProvenance] = [], incompatibleFamilies: [String] = [], compatibilityChecked: Bool = false
    ) {
        self.compatibilityChecked = compatibilityChecked
        self.incompatibleFamilies = incompatibleFamilies
        self.compatibilityIssue = compatibilityIssue
        self.provenance = provenance
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

    public static func unavailable(_ reason: String) -> Self {
        Self(recipeSearchDocumentCount: 0, recipeFeatureCount: 0,
             recipeFeaturesWithTotalTimeCount: 0, recipeFeaturesWithIngredientLineCountCount: 0,
             lastRecipeSearchRun: nil, lastSuccessfulRecipeSearchRun: nil,
             lastRecipeFeatureRun: nil, lastSuccessfulRecipeFeatureRun: nil,
             compatibilityIssue: reason, incompatibleFamilies: PantrySidecarStore.allFamilies)
    }

    public var recipeSearchReady: Bool {
        !incompatibleFamilies.contains("recipe-search") && recipeSearchDocumentCount > 0 && lastSuccessfulRecipeSearchRun != nil
    }

    public var recipeFeaturesReady: Bool {
        !incompatibleFamilies.contains("recipe-features") && recipeFeatureCount > 0 && lastSuccessfulRecipeFeatureRun != nil
    }

    public var recipeIngredientIndexReady: Bool {
        !incompatibleFamilies.contains("recipe-ingredients") && lastSuccessfulRecipeIngredientRun != nil
    }

    public var recipeUsageStatsReady: Bool {
        !incompatibleFamilies.contains("recipe-usage") && lastSuccessfulRecipeUsageRun != nil
    }

    public var ingredientPairEvidenceReady: Bool {
        !incompatibleFamilies.contains("ingredient-pairs") && lastSuccessfulIngredientPairRun != nil
    }
}

public struct RecipeIndexPhaseTiming: Codable, Equatable, Sendable {
    public let phase: String
    public let durationMilliseconds: Int
    public let itemCount: Int?

    public init(phase: String, durationMilliseconds: Int, itemCount: Int? = nil) {
        self.phase = phase
        self.durationMilliseconds = durationMilliseconds
        self.itemCount = itemCount
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
    public let recipeTarget: PaprikaRecipeTarget
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
        self.recipeTarget = PaprikaRecipeTarget(uid: recipeUID, name: recipeName, sourceName: sourceName)
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
    public let target: PaprikaSourceTarget
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
    public let firstCookedAt: String?
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
        firstCookedAt: String? = nil,
        lastMealAt: String? = nil,
        averageStarRating: Double?,
        ratedRecipeShare: Double,
        favoriteRecipeShare: Double,
        ratingDistribution: CookbookRatingDistribution
    ) {
        self.sourceName = sourceName
        self.target = PaprikaSourceTarget(sourceName: sourceName, isUnlabeled: isUnlabeled)
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
        self.firstCookedAt = firstCookedAt ?? firstMealAt
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
    public let target: PaprikaRecipeTarget
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
        hasNotes: Bool? = nil,
        derivedFeatures: RecipeDerivedFeatures? = nil,
        usageStats: RecipeUsageStats? = nil
    ) {
        self.uid = uid
        self.name = name
        self.target = PaprikaRecipeTarget(uid: uid, name: name, sourceName: sourceName, hasNotes: hasNotes)
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
    public let changedRecipeCount: Int
    public let skippedRecipeCount: Int
    public let deletedRecipeCount: Int
    public let phaseTimings: [RecipeIndexPhaseTiming]
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
        changedRecipeCount: Int = 0,
        skippedRecipeCount: Int = 0,
        deletedRecipeCount: Int = 0,
        phaseTimings: [RecipeIndexPhaseTiming] = [],
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
        self.changedRecipeCount = changedRecipeCount
        self.skippedRecipeCount = skippedRecipeCount
        self.deletedRecipeCount = deletedRecipeCount
        self.phaseTimings = phaseTimings
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
    public let firstCookedAt: String?
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
        firstCookedAt: String? = nil,
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
        self.firstCookedAt = firstCookedAt ?? firstMealAt
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

