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
            )
        )

        XCTAssertTrue(report.humanDescription.contains("read_path: direct-source"))
        XCTAssertTrue(report.humanDescription.contains("categories: Dinner, Weeknight"))
        XCTAssertTrue(report.humanDescription.contains("source_name: Serious Eats"))
        XCTAssertTrue(report.humanDescription.contains("star_rating: 5"))
        XCTAssertTrue(report.humanDescription.contains("favorite: yes"))
    }

    func testIndexStatsReportIncludesFreshnessAndCounts() {
        let run = PantryIndexRun(
            id: 7,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_120),
            status: .success,
            indexName: "recipe-search",
            recipeCount: 12,
            errorMessage: nil
        )
        let report = IndexStatsReport(
            stats: PantryIndexStats(
                recipeSearchDocumentCount: 12,
                lastRecipeSearchRun: run,
                lastSuccessfulRecipeSearchRun: run
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertTrue(report.humanDescription.contains("recipe_search_ready: yes"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_documents: 12"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_last_run_status: success"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_freshness: 1m old"))
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

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
