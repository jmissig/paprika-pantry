import ArgumentParser
import Foundation
import XCTest
@testable import PantryKit

final class OutputFormatTests: XCTestCase {
    func testResolvedOutputFormatDefaultsToHuman() throws {
        let options = try parseRuntimeOptions([])

        XCTAssertEqual(try options.resolvedOutputFormat(), .human)
    }

    func testResolvedOutputFormatUsesExplicitCSV() throws {
        let options = try parseRuntimeOptions(["--format", "csv"])

        XCTAssertEqual(try options.resolvedOutputFormat(), .csv)
    }

    func testResolvedOutputFormatUsesJSONShortcut() throws {
        let options = try parseRuntimeOptions(["--json"])

        XCTAssertEqual(try options.resolvedOutputFormat(), .json)
    }

    func testResolvedOutputFormatRejectsConflictingJSONAndFormat() throws {
        let options = try parseRuntimeOptions(["--format", "csv", "--json"])

        XCTAssertThrowsError(try options.resolvedOutputFormat()) { error in
            guard case let OutputFormatOptionsError.conflictingJSONAndFormat(format) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(format, .csv)
        }
    }

    func testCSVOutputEscapesDelimitedFields() {
        let rendered = CSVOutput.render(
            headers: ["name", "notes"],
            rows: [["Weeknight Soup", "lemon, \"extra\" herbs"]]
        )

        XCTAssertEqual(rendered, "name,notes\nWeeknight Soup,\"lemon, \"\"extra\"\" herbs\"\n")
    }

    func testRecipesListReportRendersCSVRows() {
        let report = RecipesListReport(
            recipes: [
                RecipeSummary(
                    uid: "AAA",
                    name: "Soup",
                    categories: ["Dinner", "Weeknight"],
                    sourceName: "Serious Eats",
                    starRating: 5,
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
                    ),
                    usageStats: RecipeUsageStats(
                        uid: "AAA",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        timesCooked: 2,
                        lastCookedAt: "2026-04-07 18:00:00"
                    )
                ),
            ]
        )

        XCTAssertEqual(
            report.csvDescription,
            """
            uid,name,categories,source_name,star_rating,is_favorite,updated_at,derived_total_time_minutes,derived_ingredient_line_count,times_cooked,last_cooked_at
            AAA,Soup,Dinner | Weeknight,Serious Eats,5,true,2026-04-02 10:00:00,30,5,2,2026-04-07 18:00:00

            """
        )
    }

    func testSourceCookbooksReportRendersCSVRows() {
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
            ],
            sort: .averageRating,
            limit: 10,
            minRecipeCount: 1,
            minRatedRecipeCount: 0,
            indexStats: PantryIndexStats(
                recipeSearchDocumentCount: 0,
                recipeFeatureCount: 0,
                recipeFeaturesWithTotalTimeCount: 0,
                recipeFeaturesWithIngredientLineCountCount: 0,
                lastRecipeSearchRun: nil,
                lastSuccessfulRecipeSearchRun: nil,
                lastRecipeFeatureRun: nil,
                lastSuccessfulRecipeFeatureRun: nil
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertTrue(report.csvDescription.contains("source_name,is_unlabeled,recipe_count"))
        XCTAssertTrue(report.csvDescription.contains("Serious Eats,false,4,3,1,2,4.33,0.75,0.50,2,0,1,0,0"))
    }

    func testConsoleOutputRejectsUnsupportedCSVForCommandReport() {
        let report = CommandReport.stub(
            command: "source stub",
            plannedPhase: "later",
            message: "Not implemented",
            details: [:],
            paths: makePaths()
        )

        XCTAssertThrowsError(
            try ConsoleOutput.write(report, format: .csv) { value in
                value.humanDescription
            }
        ) { error in
            guard case let ConsoleOutputError.unsupportedFormat(command, format) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(command, "source stub")
            XCTAssertEqual(format, .csv)
        }
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }

    private func parseRuntimeOptions(_ arguments: [String]) throws -> RuntimeOptions {
        try RuntimeOptionsHarness.parse(arguments).runtimeOptions
    }
}

private struct RuntimeOptionsHarness: ParsableCommand {
    @OptionGroup var runtimeOptions: RuntimeOptions
}
