import XCTest
@testable import PantryKit

final class JSONOutputTests: XCTestCase {
    func testRenderProducesStructuredJSON() throws {
        let report = CommandReport(
            command: "doctor",
            status: "stub",
            plannedPhase: "Later",
            message: "Doctor is intentionally deferred until sync and freshness signals exist.",
            details: [:],
            paths: PantryPathReport(
                home: "/tmp/pantry",
                config: "/tmp/pantry/config.json",
                session: "/tmp/pantry/session.json",
                database: "/tmp/pantry/pantry.sqlite"
            )
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertTrue(rendered.contains("\"command\""))
        XCTAssertTrue(rendered.contains("\"doctor\""))
        XCTAssertTrue(rendered.contains("\"paths\""))
        XCTAssertTrue(rendered.contains("\"database\""))
        XCTAssertFalse(rendered.contains("\\/"))
    }

    func testRenderRecipeMirrorReportsPreservesStructuredFields() throws {
        let recipesReport = RecipesListReport(
            recipes: [
                MirroredRecipeSummary(
                    uid: "AAA",
                    name: "Soup",
                    categories: ["Dinner", "Weeknight"],
                    sourceName: "Serious Eats",
                    starRating: 5,
                    isFavorite: true,
                    updatedAt: "2026-04-02 10:00:00",
                    lastSyncedAt: nil
                ),
            ]
        )

        let recipesRendered = try JSONOutput.render(recipesReport)
        XCTAssertTrue(recipesRendered.contains("\"categories\""))
        XCTAssertTrue(recipesRendered.contains("\"Dinner\""))
        XCTAssertTrue(recipesRendered.contains("\"sourceName\""))
        XCTAssertTrue(recipesRendered.contains("\"Serious Eats\""))
        XCTAssertTrue(recipesRendered.contains("\"starRating\""))
        XCTAssertTrue(recipesRendered.contains("\"isFavorite\" : true"))
    }

    func testRenderSyncStatusReportIncludesFreshnessAndCounts() throws {
        let success = PantrySyncRun(
            id: 1,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
            status: .success,
            recipesSeen: 6,
            recipesChanged: 2,
            recipesDeleted: 1,
            errorMessage: nil
        )
        let report = SyncStatusReport(
            snapshot: PantrySyncStatusSnapshot(
                lastAttempt: success,
                lastSuccess: success,
                totalRecipeCount: 6,
                activeRecipeCount: 5,
                deletedRecipeCount: 1
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                sessionFile: URL(fileURLWithPath: "/tmp/pantry/session.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            ),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.contains("\"freshnessSeconds\" : 60"))
        XCTAssertTrue(rendered.contains("\"totalRecipeCount\" : 6"))
        XCTAssertTrue(rendered.contains("\"activeRecipeCount\" : 5"))
        XCTAssertTrue(rendered.contains("\"deletedRecipeCount\" : 1"))
        XCTAssertTrue(rendered.contains("\"status\" : \"current\""))
    }
}
