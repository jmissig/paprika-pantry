import Foundation
import XCTest
@testable import PantryKit

final class QueryReportsTests: XCTestCase {
    func testIndexRebuildReportIncludesPhaseTimingsWhenPresent() {
        let report = IndexRebuildReport(
            command: "index rebuild",
            summary: RecipeIndexesRebuildSummary(
                startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                finishedAt: Date(timeIntervalSince1970: 1_712_736_002),
                recipeSearchDocumentCount: 2,
                recipeFeatureCount: 2,
                recipeFeaturesWithTotalTimeCount: 1,
                recipeFeaturesWithIngredientLineCountCount: 2,
                recipeIngredientRecipeCount: 2,
                recipeIngredientLineCount: 4,
                recipeIngredientTokenCount: 4,
                recipeUsageStatsCount: 1,
                linkedMealCount: 1,
                totalMealCount: 2,
                ingredientPairSummaryCount: 2,
                ingredientPairRecipeEvidenceCount: 2,
                phaseTimings: [
                    RecipeIndexPhaseTiming(phase: "source.recipe_stubs", durationMilliseconds: 12, itemCount: 3),
                    RecipeIndexPhaseTiming(phase: "derive.ingredient_pairs", durationMilliseconds: 34, itemCount: 2),
                ]
            ),
            paths: makePaths()
        )

        XCTAssertTrue(report.humanDescription.contains("duration_ms: 2000"))
        XCTAssertTrue(report.humanDescription.contains("phase_durations_ms: source.recipe_stubs=12(items=3), derive.ingredient_pairs=34(items=2)"))
    }

    func testIndexUpdateReportIncludesPartialUpdateCountsAndUsageRefreshNote() {
        let report = IndexRebuildReport(
            command: "index update",
            summary: RecipeIndexesRebuildSummary(
                startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                finishedAt: Date(timeIntervalSince1970: 1_712_736_001),
                recipeSearchDocumentCount: 3,
                recipeFeatureCount: 3,
                recipeFeaturesWithTotalTimeCount: 1,
                recipeFeaturesWithIngredientLineCountCount: 3,
                recipeIngredientRecipeCount: 3,
                recipeIngredientLineCount: 6,
                recipeIngredientTokenCount: 6,
                recipeUsageStatsCount: 1,
                refreshedIngredientPairEvidence: false,
                changedRecipeCount: 2,
                skippedRecipeCount: 1,
                deletedRecipeCount: 1
            ),
            paths: makePaths()
        )

        XCTAssertTrue(report.humanDescription.contains("routine_recipe_rows_changed: 2"))
        XCTAssertTrue(report.humanDescription.contains("routine_recipe_rows_skipped: 1"))
        XCTAssertTrue(report.humanDescription.contains("routine_recipe_rows_deleted: 1"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_refresh: full"))
    }

    func testRecipesListReportIncludesSummaryMetadata() {
        let report = RecipesListReport(
            recipes: [
                RecipeSummary(
                    uid: "AAA",
                    name: "Soup",
                    categories: ["Dinner"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true,
                    updatedAt: "2026-04-02 10:00:00",
                    derivedFeatures: RecipeDerivedFeatures(
                        uid: "AAA",
                        sourceFingerprint: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                    usageStats: RecipeUsageStats(
                        uid: "AAA",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        mealCount: 3,
                        firstMealAt: "2026-04-01 18:00:00",
                        lastMealAt: "2026-04-07 18:00:00",
                        mealGapDays: [3, 3],
                        daysSpannedByMeals: 6,
                        medianMealGapDays: 3.0,
                        mealShare: 0.375
                    )
                ),
            ],
            canonicalFilters: RecipeQueryFilters(favoritesOnly: true, minRating: 4, categoryNames: ["Side"]),
            ingredientFilter: RecipeIngredientFilter(rawTerms: ["tomatoes", "basil leaves"]),
            derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
            sort: .fewestIngredients,
            derivedReadPath: "sidecar-derived",
            ingredientReadPath: "sidecar-ingredient-index",
            usageReadPath: "sidecar-derived"
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_read_path: sidecar-ingredient-index"))
        XCTAssertTrue(report.humanDescription.contains("usage_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("canonical.favorite_only: yes"))
        XCTAssertTrue(report.humanDescription.contains("canonical.min_rating: 4"))
        XCTAssertTrue(report.humanDescription.contains("canonical.categories_all: Side"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_terms_all: tomatoes, basil leaves"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_term_tokens_all: tomatoes=tomato; basil leaves=basil, leaves"))
        XCTAssertTrue(report.humanDescription.contains("derived.max_total_time_minutes: 30"))
        XCTAssertTrue(report.humanDescription.contains("sort: fewest-ingredients"))
        XCTAssertTrue(report.humanDescription.contains("categories=Dinner"))
        XCTAssertTrue(report.humanDescription.contains("source=Serious Eats"))
        XCTAssertTrue(report.humanDescription.contains("rating=4"))
        XCTAssertTrue(report.humanDescription.contains("favorite=yes"))
        XCTAssertTrue(report.humanDescription.contains("derived_total_time_minutes=30"))
        XCTAssertTrue(report.humanDescription.contains("derived_ingredient_line_count=5"))
        XCTAssertTrue(report.humanDescription.contains("meal_count=3"))
        XCTAssertTrue(report.humanDescription.contains("first_cooked_at=2026-04-01 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("last_meal_at=2026-04-07 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("days_since_last_meal="))
        XCTAssertTrue(report.humanDescription.contains("days_spanned_by_meals=6"))
        XCTAssertTrue(report.humanDescription.contains("median_meal_gap_days=3.0"))
        XCTAssertTrue(report.humanDescription.contains("meal_share=0.375"))
    }

    func testRecipeShowReportIncludesRecipeMetadata() {
        let report = RecipeShowReport(
            recipe: RecipeDetail(
                uid: "AAA",
                name: "Soup",
                categories: ["Dinner", "Weeknight"],
                sourceName: "Serious Eats",
                ingredients: "Broth",
                directions: "Simmer.",
                notes: "Use lemon.",
                starRating: 5,
                isFavorite: true,
                prepTime: "10 min",
                cookTime: "20 min",
                totalTime: "30 min",
                servings: "4",
                createdAt: "2026-04-01 10:00:00",
                updatedAt: "2026-04-02 10:00:00",
                sourceFingerprint: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            derivedFeatures: RecipeDerivedFeatures(
                uid: "AAA",
                sourceFingerprint: "hash-1",
                derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                totalTimeMinutes: 30,
                totalTimeBasis: .sourceTotalTime,
                ingredientLineCount: 2,
                ingredientLineCountBasis: .nonEmptyLines
            ),
            usageStats: RecipeUsageStats(
                uid: "AAA",
                derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                mealCount: 4,
                firstMealAt: "2026-04-01 18:00:00",
                lastMealAt: "2026-04-08 18:00:00",
                mealGapDays: [2, 3, 2],
                daysSpannedByMeals: 7,
                medianMealGapDays: 2.0,
                mealShare: 0.5
            )
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("categories: Dinner, Weeknight"))
        XCTAssertTrue(report.humanDescription.contains("source_name: Serious Eats"))
        XCTAssertTrue(report.humanDescription.contains("star_rating: 5"))
        XCTAssertTrue(report.humanDescription.contains("favorite: yes"))
        XCTAssertTrue(report.humanDescription.contains("usage_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("meal_count: 4"))
        XCTAssertTrue(report.humanDescription.contains("first_meal_at: 2026-04-01 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("first_cooked_at: 2026-04-01 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("last_meal_at: 2026-04-08 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("days_since_last_meal:"))
        XCTAssertTrue(report.humanDescription.contains("meal_gap_days: [2, 3, 2]"))
        XCTAssertTrue(report.humanDescription.contains("days_spanned_by_meals: 7"))
        XCTAssertTrue(report.humanDescription.contains("median_meal_gap_days: 2.0"))
        XCTAssertTrue(report.humanDescription.contains("meal_share: 0.500"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("derived_total_time_minutes: 30"))
        XCTAssertTrue(report.humanDescription.contains("derived_ingredient_line_count_basis: non-empty-ingredient-lines"))
    }

    func testIndexStatsReportIncludesFreshnessAndCounts() {
        let searchRun = PantryIndexRun(
            id: 7,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_120),
            status: .success,
            indexName: "recipe-search",
            recipeCount: 12,
            errorMessage: nil
        )
        let featureRun = PantryIndexRun(
            id: 8,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_120),
            status: .success,
            indexName: "recipe-features",
            recipeCount: 12,
            errorMessage: nil
        )
        let report = IndexStatsReport(
            stats: PantryIndexStats(
                recipeSearchDocumentCount: 12,
                recipeFeatureCount: 12,
                recipeFeaturesWithTotalTimeCount: 9,
                recipeFeaturesWithIngredientLineCountCount: 11,
                recipeIngredientRecipeCount: 10,
                recipeIngredientLineCount: 42,
                recipeIngredientTokenCount: 77,
                recipeUsageStatsCount: 8,
                recipeUsageStatsWithLastMealAtCount: 6,
                recipeUsageStatsWithGapArrayCount: 5,
                recipeUsageTotalMealCount: 14,
                lastRecipeSearchRun: searchRun,
                lastSuccessfulRecipeSearchRun: searchRun,
                lastRecipeFeatureRun: featureRun,
                lastSuccessfulRecipeFeatureRun: featureRun,
                lastRecipeIngredientRun: featureRun,
                lastSuccessfulRecipeIngredientRun: featureRun,
                lastRecipeUsageRun: featureRun,
                lastSuccessfulRecipeUsageRun: featureRun,
                sourceState: PantryStoredSourceState(
                    sourceType: PantrySourceType.paprikaSQLite,
                    sourceLocation: "/Users/test/Paprika.sqlite",
                    observedAt: Date(timeIntervalSince1970: 1_712_736_120),
                    paprikaSync: PaprikaSyncDetails(
                        lastSyncAt: Date(timeIntervalSince1970: 1_712_736_060),
                        signalSource: "group-container-preferences",
                        signalLocation: "/Users/test/Library/Preferences/test.plist"
                    )
                )
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertTrue(report.humanDescription.contains("source_state_captured: yes"))
        XCTAssertTrue(report.humanDescription.contains("source_state_observed_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_120)))"))
        XCTAssertTrue(report.humanDescription.contains("captured_paprika_last_sync_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_060)))"))
        XCTAssertTrue(report.humanDescription.contains("captured_paprika_sync_freshness: 2m old"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_ready: yes"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_documents: 12"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_last_run_status: success"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("recipe_features_ready: yes"))
        XCTAssertTrue(report.humanDescription.contains("recipe_feature_rows: 12"))
        XCTAssertTrue(report.humanDescription.contains("recipe_features_with_total_time: 9"))
        XCTAssertTrue(report.humanDescription.contains("recipe_features_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("recipe_ingredient_index_ready: yes"))
        XCTAssertTrue(report.humanDescription.contains("recipe_ingredient_recipes: 10"))
        XCTAssertTrue(report.humanDescription.contains("recipe_ingredient_tokens: 77"))
        XCTAssertTrue(report.humanDescription.contains("recipe_ingredients_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_index_ready: yes"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_stat_rows: 8"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_rows_with_last_meal_at: 6"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_rows_with_gap_arrays: 5"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_total_meals: 14"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_freshness: 1m old"))
    }

    func testRecipesSearchReportIncludesMatches() {
        let searchLastSuccessAt = Date(timeIntervalSince1970: 1_712_736_120)
        let report = RecipesSearchReport(
            query: "lemon",
            canonicalFilters: RecipeQueryFilters(favoritesOnly: true, maxRating: 4, categoryNames: ["Soup"]),
            ingredientFilter: RecipeIngredientFilter(rawTerms: ["green onions"]),
            derivedConstraints: RecipeDerivedConstraints(maxIngredientLineCount: 6),
            sort: .fewestIngredients,
            results: [
                IndexedRecipeSearchResult(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner", "Soup"],
                    sourceName: "Serious Eats",
                    isFavorite: true,
                    starRating: 4,
                    derivedFeatures: RecipeDerivedFeatures(
                        uid: "AAA",
                        sourceFingerprint: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                    usageStats: RecipeUsageStats(
                        uid: "AAA",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        mealCount: 2,
                        firstMealAt: "2026-04-01 18:00:00",
                        lastMealAt: "2026-04-07 18:00:00",
                        mealGapDays: [6],
                        daysSpannedByMeals: 6,
                        medianMealGapDays: 6.0,
                        mealShare: 0.25
                    )
                )
            ],
            paths: makePaths(),
            derivedReadPath: "sidecar-derived",
            ingredientReadPath: "sidecar-ingredient-index",
            usageReadPath: "sidecar-derived",
            searchLastSuccessAt: searchLastSuccessAt,
            searchFreshnessSeconds: 60,
            derivedLastSuccessAt: searchLastSuccessAt,
            derivedFreshnessSeconds: 60,
            ingredientLastSuccessAt: searchLastSuccessAt,
            ingredientFreshnessSeconds: 60,
            usageLastSuccessAt: searchLastSuccessAt,
            usageFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("recipes search: 1 matches"))
        XCTAssertTrue(report.humanDescription.contains("read_path: sidecar-search-index"))
        XCTAssertTrue(report.humanDescription.contains("query: lemon"))
        XCTAssertTrue(report.humanDescription.contains("search_index_last_success_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_120)))"))
        XCTAssertTrue(report.humanDescription.contains("search_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("derived_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_read_path: sidecar-ingredient-index"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("usage_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("usage_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("canonical.favorite_only: yes"))
        XCTAssertTrue(report.humanDescription.contains("canonical.max_rating: 4"))
        XCTAssertTrue(report.humanDescription.contains("canonical.categories_all: Soup"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_terms_all: green onions"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_term_tokens_all: green onions=green, onion"))
        XCTAssertTrue(report.humanDescription.contains("derived.max_ingredient_line_count: 6"))
        XCTAssertTrue(report.humanDescription.contains("sort: fewest-ingredients"))
        XCTAssertTrue(report.humanDescription.contains("AAA  Weeknight Soup"))
        XCTAssertTrue(report.humanDescription.contains("categories=Dinner, Soup"))
        XCTAssertTrue(report.humanDescription.contains("favorite=yes"))
        XCTAssertTrue(report.humanDescription.contains("derived_ingredient_line_count=5"))
        XCTAssertTrue(report.humanDescription.contains("meal_count=2"))
        XCTAssertTrue(report.humanDescription.contains("first_cooked_at=2026-04-01 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("last_meal_at=2026-04-07 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("days_since_last_meal="))
    }

    func testRecipeUsageStatsComputesDaysSinceLastMealByCalendarDay() {
        let stats = RecipeUsageStats(
            uid: "AAA",
            derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
            mealCount: 2,
            firstMealAt: "2026-04-01 18:00:00",
            lastMealAt: "2026-04-07 23:30:00",
            mealGapDays: [6],
            daysSpannedByMeals: 6,
            medianMealGapDays: 6.0,
            mealShare: 0.25
        )

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = 2026
        components.month = 4
        components.day = 9
        components.hour = 1
        let referenceDate = components.date ?? Date(timeIntervalSince1970: 0)

        XCTAssertEqual(stats.daysSinceLastMeal(referenceDate: referenceDate), 2)
    }

    func testRecipeReportsRenderIngredientAnyAndExcludeSemantics() {
        let report = RecipesListReport(
            recipes: [],
            ingredientFilter: RecipeIngredientFilter(
                rawTerms: ["green onions", "basil"],
                excludeRawTerms: ["anchovy"],
                includeMode: .any
            ),
            ingredientReadPath: "sidecar-ingredient-index",
            ingredientLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            ingredientFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("ingredient_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_terms_any: green onions, basil"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.include_term_tokens_any: green onions=green, onion; basil=basil"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.exclude_terms_any: anchovy"))
        XCTAssertTrue(report.humanDescription.contains("ingredient.exclude_term_tokens_any: anchovy=anchovy"))
    }

    func testRecipeFeaturesReportIncludesSourceEvidenceAndDerivedMetrics() {
        let report = RecipeFeaturesReport(
            recipe: RecipeDetail(
                uid: "AAA",
                name: "Soup",
                categories: ["Dinner"],
                sourceName: "Serious Eats",
                ingredients: "Broth\nBeans",
                directions: nil,
                notes: nil,
                starRating: nil,
                isFavorite: false,
                prepTime: "10 min",
                cookTime: "20 min",
                totalTime: nil,
                servings: nil,
                createdAt: nil,
                updatedAt: nil,
                sourceFingerprint: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            features: RecipeDerivedFeatures(
                uid: "AAA",
                sourceFingerprint: "hash-1",
                derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                totalTimeMinutes: 30,
                totalTimeBasis: .summedPrepAndCook,
                ingredientLineCount: 2,
                ingredientLineCountBasis: .nonEmptyLines
            ),
            paths: makePaths(),
            derivedLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            derivedFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("source_read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("derived_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("source_prep_time: 10 min"))
        XCTAssertTrue(report.humanDescription.contains("total_time_basis: prep-plus-cook"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_line_count: 2"))
    }

    func testRecipeIngredientsReportShowsSourceLinesBesideNormalizedTokens() {
        let report = RecipeIngredientsReport(
            recipe: RecipeDetail(
                uid: "AAA",
                name: "Soup",
                categories: ["Dinner"],
                sourceName: "Serious Eats",
                ingredients: "1 can tomatoes\nfresh basil leaves",
                directions: nil,
                notes: nil,
                starRating: nil,
                isFavorite: false,
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                servings: nil,
                createdAt: nil,
                updatedAt: nil,
                sourceFingerprint: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            ingredientIndex: RecipeIngredientIndex(
                uid: "AAA",
                sourceFingerprint: "hash-1",
                derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                lines: [
                    RecipeIngredientLine(
                        lineNumber: 1,
                        sourceText: "1 can tomatoes",
                        normalizedText: "tomato",
                        normalizedTokens: ["tomato"]
                    ),
                    RecipeIngredientLine(
                        lineNumber: 2,
                        sourceText: "fresh basil leaves",
                        normalizedText: "fresh basil leaves",
                        normalizedTokens: ["fresh", "basil", "leaves"]
                    ),
                ]
            ),
            paths: makePaths(),
            ingredientLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            ingredientFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("source_read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_read_path: sidecar-ingredient-index"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("source_ingredients:"))
        XCTAssertTrue(report.humanDescription.contains("indexed_ingredient_lines: 2"))
        XCTAssertTrue(report.humanDescription.contains("1: source=\"1 can tomatoes\" | normalized_text=tomato | normalized_tokens=tomato"))
        XCTAssertTrue(report.humanDescription.contains("2: source=\"fresh basil leaves\" | normalized_text=fresh basil leaves | normalized_tokens=fresh, basil, leaves"))
    }

    func testRecipesPairingsReportShowsBasisAndCompactEvidence() throws {
        let report = RecipesPairingsReport(
            results: [
                IngredientPairEvidenceSummary(
                    basis: PantrySidecarStore.ingredientPairEvidenceBasis,
                    tokenA: "basil",
                    tokenB: "tomato",
                    recipeCount: 2,
                    cookedRecipeCount: 2,
                    cookedMealCount: 3,
                    favoriteRecipeCount: 1,
                    ratedRecipeCount: 2,
                    averageStarRating: 4.5,
                    firstMealAt: "2026-04-01 18:00:00",
                    lastMealAt: "2026-04-07 18:00:00",
                    recipeEvidence: [
                        IngredientPairRecipeEvidence(
                            recipeUID: "AAA",
                            recipeName: "Tomato Basil Pasta",
                            sourceName: "Test Kitchen",
                            tokenALineNumbers: [3],
                            tokenBLineNumbers: [1, 2],
                            isFavorite: true,
                            starRating: 5,
                            mealCount: 2,
                            firstMealAt: "2026-04-01 18:00:00",
                            lastMealAt: "2026-04-07 18:00:00"
                        ),
                    ]
                )
            ],
            token: "tomatoes",
            withToken: "basil",
            minRecipes: 2,
            limit: 10,
            evidenceLimit: 1,
            sort: .meals,
            paths: makePaths(),
            ingredientPairLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            routineIndexLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_100),
            ingredientPairFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("recipes pairings: 1 token pairs"))
        XCTAssertTrue(report.humanDescription.contains("read_path: sidecar-ingredient-pair-index"))
        XCTAssertTrue(report.humanDescription.contains("basis: recipe-token-cooccurrence-v1"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_pair_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("routine_index_last_success_at:"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_pair_evidence_may_be_stale: no"))
        XCTAssertTrue(report.humanDescription.contains("token: tomatoes"))
        XCTAssertTrue(report.humanDescription.contains("with_token: basil"))
        XCTAssertTrue(report.humanDescription.contains("sort: meals"))
        XCTAssertTrue(report.humanDescription.contains("basil + tomato | recipes=2 | cooked_recipes=2 | meals=3 | favorites=1 | rated=2 | avg_rating=4.50 | first_meal=2026-04-01 18:00:00 | last_meal=2026-04-07 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("evidence: AAA  Tomato Basil Pasta | basil_lines=3 | tomato_lines=1,2 | source=Test Kitchen | rating=5 | favorite=yes | meals=2 | last_meal=2026-04-07 18:00:00"))

        let rendered = try JSONOutput.render(report)
        XCTAssertTrue(rendered.contains("\"basis\" : \"recipe-token-cooccurrence-v1\""))
        XCTAssertTrue(rendered.contains("\"readPath\" : \"sidecar-ingredient-pair-index\""))
        XCTAssertTrue(rendered.contains("\"recipeEvidence\""))
        XCTAssertTrue(rendered.contains("\"tokenBLineNumbers\""))
        XCTAssertTrue(rendered.contains("\"ingredientPairEvidenceMayBeStale\" : false"))
    }

    func testRecipesPairingsReportWarnsWhenPairEvidenceIsOlderThanRoutineIndex() throws {
        let report = RecipesPairingsReport(
            results: [],
            token: "tomato",
            paths: makePaths(),
            ingredientPairLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_000),
            routineIndexLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            ingredientPairFreshnessSeconds: 120
        )

        XCTAssertTrue(report.ingredientPairEvidenceMayBeStale)
        XCTAssertTrue(report.humanDescription.contains("ingredient_pair_evidence_may_be_stale: yes"))
        XCTAssertTrue(report.humanDescription.contains("pairings were built before the latest routine index update"))
        XCTAssertTrue(report.humanDescription.contains("No ingredient token pairs matched in the built pairing index."))
        XCTAssertTrue(report.humanDescription.contains("run `paprika-pantry index rebuild` to refresh pairings"))

        let rendered = try JSONOutput.render(report)
        XCTAssertTrue(rendered.contains("\"ingredientPairEvidenceMayBeStale\" : true"))
    }

    func testSourceCookbooksReportIncludesAggregateEvidenceAndUnlabeledBucket() {
        let searchRun = PantryIndexRun(
            id: 9,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_120),
            status: .success,
            indexName: "recipe-search",
            recipeCount: 6,
            errorMessage: nil
        )
        let report = SourceCookbooksReport(
            aggregates: [
                CookbookAggregateSummary(
                    sourceName: "Serious Eats",
                    isUnlabeled: false,
                    recipeCount: 4,
                    ratedRecipeCount: 3,
                    unratedRecipeCount: 1,
                    favoriteRecipeCount: 2,
                    usedRecipeCount: 2,
                    unusedRecipeCount: 2,
                    mealCount: 5,
                    mealShare: 0.25,
                    firstMealAt: "2026-03-01 18:00:00",
                    lastMealAt: "2026-04-01 18:00:00",
                    averageStarRating: 4.33,
                    ratedRecipeShare: 0.75,
                    favoriteRecipeShare: 0.5,
                    ratingDistribution: CookbookRatingDistribution(
                        oneStarCount: 0,
                        twoStarCount: 0,
                        threeStarCount: 1,
                        fourStarCount: 0,
                        fiveStarCount: 2
                    )
                ),
                CookbookAggregateSummary(
                    sourceName: nil,
                    isUnlabeled: true,
                    recipeCount: 2,
                    ratedRecipeCount: 0,
                    unratedRecipeCount: 2,
                    favoriteRecipeCount: 1,
                    usedRecipeCount: 0,
                    unusedRecipeCount: 2,
                    mealCount: 0,
                    mealShare: 0,
                    averageStarRating: nil,
                    ratedRecipeShare: 0,
                    favoriteRecipeShare: 0.5,
                    ratingDistribution: CookbookRatingDistribution(
                        oneStarCount: 0,
                        twoStarCount: 0,
                        threeStarCount: 0,
                        fourStarCount: 0,
                        fiveStarCount: 0
                    )
                ),
            ],
            sort: .averageRating,
            limit: 20,
            minRecipeCount: 1,
            minRatedRecipeCount: 0,
            indexStats: PantryIndexStats(
                recipeSearchDocumentCount: 6,
                recipeFeatureCount: 6,
                recipeFeaturesWithTotalTimeCount: 0,
                recipeFeaturesWithIngredientLineCountCount: 0,
                lastRecipeSearchRun: searchRun,
                lastSuccessfulRecipeSearchRun: searchRun,
                lastRecipeFeatureRun: nil,
                lastSuccessfulRecipeFeatureRun: nil,
                lastRecipeUsageRun: searchRun,
                lastSuccessfulRecipeUsageRun: searchRun
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertTrue(report.humanDescription.contains("source cookbooks: 2 cookbook/source groups"))
        XCTAssertTrue(report.humanDescription.contains("read_path: sidecar-search-index"))
        XCTAssertTrue(report.humanDescription.contains("sort: average-rating"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("recipe_usage_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("Serious Eats | recipes=4 | rated=3 | unrated=1 | favorites=2 | used_recipes=2 | unused_recipes=2 | meals=5 | meal_share=0.25 | first_meal=2026-03-01 18:00:00 | first_cooked_at=2026-03-01 18:00:00 | last_meal=2026-04-01 18:00:00 | avg_rating=4.33 | ratings=5:2,3:1"))
        XCTAssertTrue(report.humanDescription.contains("(unlabeled source/cookbook) | recipes=2 | rated=0 | unrated=2 | favorites=1 | used_recipes=0 | unused_recipes=2 | meals=0 | meal_share=0.00 | avg_rating=unrated | is_unlabeled=yes"))
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
