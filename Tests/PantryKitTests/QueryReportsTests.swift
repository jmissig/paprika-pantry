import Foundation
import XCTest
@testable import PantryKit

final class QueryReportsTests: XCTestCase {
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
                        sourceRemoteHash: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    )
                ),
            ],
            canonicalFilters: RecipeQueryFilters(favoritesOnly: true, minRating: 4, categoryNames: ["Side"]),
            ingredientFilter: RecipeIngredientFilter(rawTerms: ["tomatoes", "basil leaves"]),
            derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
            sort: .fewestIngredients,
            derivedReadPath: "sidecar-derived",
            ingredientReadPath: "sidecar-ingredient-index"
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_read_path: sidecar-ingredient-index"))
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
                remoteHash: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            derivedFeatures: RecipeDerivedFeatures(
                uid: "AAA",
                sourceRemoteHash: "hash-1",
                derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                prepTimeMinutes: 10,
                cookTimeMinutes: 20,
                totalTimeMinutes: 30,
                totalTimeBasis: .sourceTotalTime,
                ingredientLineCount: 2,
                ingredientLineCountBasis: .nonEmptyLines
            )
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("categories: Dinner, Weeknight"))
        XCTAssertTrue(report.humanDescription.contains("source_name: Serious Eats"))
        XCTAssertTrue(report.humanDescription.contains("star_rating: 5"))
        XCTAssertTrue(report.humanDescription.contains("favorite: yes"))
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
                lastRecipeSearchRun: searchRun,
                lastSuccessfulRecipeSearchRun: searchRun,
                lastRecipeFeatureRun: featureRun,
                lastSuccessfulRecipeFeatureRun: featureRun,
                lastRecipeIngredientRun: featureRun,
                lastSuccessfulRecipeIngredientRun: featureRun
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

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
                        sourceRemoteHash: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    )
                )
            ],
            paths: makePaths(),
            derivedReadPath: "sidecar-derived",
            ingredientReadPath: "sidecar-ingredient-index",
            searchLastSuccessAt: searchLastSuccessAt,
            searchFreshnessSeconds: 60,
            derivedLastSuccessAt: searchLastSuccessAt,
            derivedFreshnessSeconds: 60,
            ingredientLastSuccessAt: searchLastSuccessAt,
            ingredientFreshnessSeconds: 60
        )

        XCTAssertTrue(report.humanDescription.contains("recipes search: 1 matches"))
        XCTAssertTrue(report.humanDescription.contains("read_path: sidecar-search-index"))
        XCTAssertTrue(report.humanDescription.contains("query: lemon"))
        XCTAssertTrue(report.humanDescription.contains("search_index_last_success_at: 2024-04-10T08:02:00Z"))
        XCTAssertTrue(report.humanDescription.contains("search_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("derived_index_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_read_path: sidecar-ingredient-index"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_index_freshness: 1m old"))
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
                remoteHash: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            features: RecipeDerivedFeatures(
                uid: "AAA",
                sourceRemoteHash: "hash-1",
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
                remoteHash: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            ingredientIndex: RecipeIngredientIndex(
                uid: "AAA",
                sourceRemoteHash: "hash-1",
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
                lastSuccessfulRecipeFeatureRun: nil
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertTrue(report.humanDescription.contains("source cookbooks: 2 cookbook/source groups"))
        XCTAssertTrue(report.humanDescription.contains("read_path: sidecar-search-index"))
        XCTAssertTrue(report.humanDescription.contains("sort: average-rating"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("Serious Eats | recipes=4 | rated=3 | unrated=1 | favorites=2 | avg_rating=4.33 | ratings=5:2,3:1"))
        XCTAssertTrue(report.humanDescription.contains("(unlabeled source/cookbook) | recipes=2 | rated=0 | unrated=2 | favorites=1 | avg_rating=unrated | is_unlabeled=yes"))
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
