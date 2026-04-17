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
                    updatedAt: "2026-04-02 10:00:00"
                ),
            ]
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("categories=Dinner"))
        XCTAssertTrue(report.humanDescription.contains("source=Serious Eats"))
        XCTAssertTrue(report.humanDescription.contains("rating=4"))
        XCTAssertTrue(report.humanDescription.contains("favorite=yes"))
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
                lastRecipeSearchRun: searchRun,
                lastSuccessfulRecipeSearchRun: searchRun,
                lastRecipeFeatureRun: featureRun,
                lastSuccessfulRecipeFeatureRun: featureRun
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
    }

    func testRecipesSearchReportIncludesMatches() {
        let report = RecipesSearchReport(
            query: "lemon",
            results: [
                IndexedRecipeSearchResult(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner", "Soup"],
                    sourceName: "Serious Eats",
                    isFavorite: true,
                    starRating: 4
                )
            ],
            paths: makePaths()
        )

        XCTAssertTrue(report.humanDescription.contains("recipes search: 1 matches"))
        XCTAssertTrue(report.humanDescription.contains("query: lemon"))
        XCTAssertTrue(report.humanDescription.contains("AAA  Weeknight Soup"))
        XCTAssertTrue(report.humanDescription.contains("categories=Dinner, Soup"))
        XCTAssertTrue(report.humanDescription.contains("favorite=yes"))
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
            paths: makePaths()
        )

        XCTAssertTrue(report.humanDescription.contains("source_read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("derived_read_path: sidecar-derived"))
        XCTAssertTrue(report.humanDescription.contains("source_prep_time: 10 min"))
        XCTAssertTrue(report.humanDescription.contains("total_time_basis: prep-plus-cook"))
        XCTAssertTrue(report.humanDescription.contains("ingredient_line_count: 2"))
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
