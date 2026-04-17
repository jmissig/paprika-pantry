import XCTest
@testable import PantryKit

final class JSONOutputTests: XCTestCase {
    func testRenderProducesStructuredJSON() throws {
        let report = CommandReport(
            command: "groceries list",
            status: "stub",
            plannedPhase: "Later",
            message: "Direct grocery reads are intentionally deferred until after the first recipe read slice.",
            details: [:],
            paths: PantryPathReport(
                home: "/tmp/pantry",
                config: "/tmp/pantry/config.json",
                database: "/tmp/pantry/pantry.sqlite"
            )
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertTrue(rendered.contains("\"command\""))
        XCTAssertTrue(rendered.contains("\"groceries list\""))
        XCTAssertTrue(rendered.contains("\"paths\""))
        XCTAssertTrue(rendered.contains("\"database\""))
        XCTAssertFalse(rendered.contains("\\/"))
    }

    func testRenderRecipeReportsPreservesStructuredFields() throws {
        let recipesReport = RecipesListReport(
            recipes: [
                RecipeSummary(
                    uid: "AAA",
                    name: "Soup",
                    categories: ["Dinner", "Weeknight"],
                    sourceName: "Serious Eats",
                    starRating: 5,
                    isFavorite: true,
                    updatedAt: "2026-04-02 10:00:00"
                ),
            ]
        )

        let recipesRendered = try JSONOutput.render(recipesReport)
        XCTAssertTrue(recipesRendered.contains("\"readPath\""))
        XCTAssertTrue(recipesRendered.contains("\"direct-source\""))
        XCTAssertTrue(recipesRendered.contains("\"categories\""))
        XCTAssertTrue(recipesRendered.contains("\"Dinner\""))
        XCTAssertTrue(recipesRendered.contains("\"sourceName\""))
        XCTAssertTrue(recipesRendered.contains("\"Serious Eats\""))
        XCTAssertTrue(recipesRendered.contains("\"starRating\""))
        XCTAssertTrue(recipesRendered.contains("\"isFavorite\" : true"))
    }

    func testRenderDoctorReportIncludesStatusAndIndexFields() throws {
        let report = DoctorReport(
            sourceSnapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready for direct read-only Paprika access.",
                sourceKind: .paprikaSQLite,
                displayName: "default Paprika SQLite",
                implementation: "direct Paprika SQLite source",
                sourceLocation: "/Users/test/Paprika.sqlite"
            ),
            indexStats: PantryIndexStats(
                recipeSearchDocumentCount: 6,
                lastRecipeSearchRun: PantryIndexRun(
                    id: 1,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-search",
                    recipeCount: 6,
                    errorMessage: nil
                ),
                lastSuccessfulRecipeSearchRun: PantryIndexRun(
                    id: 1,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-search",
                    recipeCount: 6,
                    errorMessage: nil
                )
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            ),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.contains("\"status\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"sourceStatus\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"indexStatus\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"recipeSearchDocumentCount\" : 6"))
        XCTAssertTrue(rendered.contains("\"recipeSearchFreshnessSeconds\" : 60"))
    }
}
