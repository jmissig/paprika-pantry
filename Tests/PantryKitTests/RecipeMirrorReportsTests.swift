import Foundation
import XCTest
@testable import PantryKit

final class RecipeMirrorReportsTests: XCTestCase {
    func testSyncRunReportIncludesMirrorCountsAndPaths() {
        let report = SyncRunReport(
            summary: SyncSummary(
                startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                status: .success,
                recipesSeen: 12,
                changedRecipeCount: 3,
                deletedRecipeCount: 1
            ),
            paths: makePaths()
        )

        XCTAssertEqual(report.status, "success")
        XCTAssertTrue(report.humanDescription.contains("recipes_seen: 12"))
        XCTAssertTrue(report.humanDescription.contains("recipes_changed: 3"))
        XCTAssertTrue(report.humanDescription.contains("recipes_deleted: 1"))
        XCTAssertTrue(report.humanDescription.contains("database: /tmp/pantry/pantry.sqlite"))
    }

    func testSyncStatusReportForNeverSyncedMirror() {
        let report = SyncStatusReport(
            snapshot: PantrySyncStatusSnapshot(
                lastAttempt: nil,
                lastSuccess: nil,
                totalRecipeCount: 0,
                activeRecipeCount: 0,
                deletedRecipeCount: 0
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_000)
        )

        XCTAssertEqual(report.status, "never-synced")
        XCTAssertFalse(report.hasSuccessfulSync)
        XCTAssertNil(report.freshnessSeconds)
        XCTAssertTrue(report.humanDescription.contains("freshness: never-synced"))
    }

    func testSyncStatusReportForFailedAttemptAfterPreviousSuccess() {
        let success = PantrySyncRun(
            id: 1,
            startedAt: Date(timeIntervalSince1970: 1_712_700_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_700_120),
            status: .success,
            recipesSeen: 5,
            recipesChanged: 2,
            recipesDeleted: 0,
            errorMessage: nil
        )
        let failure = PantrySyncRun(
            id: 2,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
            status: .failed,
            recipesSeen: 5,
            recipesChanged: 1,
            recipesDeleted: 0,
            errorMessage: "network unavailable"
        )

        let report = SyncStatusReport(
            snapshot: PantrySyncStatusSnapshot(
                lastAttempt: failure,
                lastSuccess: success,
                totalRecipeCount: 5,
                activeRecipeCount: 5,
                deletedRecipeCount: 0
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        XCTAssertEqual(report.status, "stale")
        XCTAssertEqual(report.freshnessSeconds, 36_000)
        XCTAssertTrue(report.humanDescription.contains("last_failure: network unavailable"))
    }

    func testSyncStatusReportForCurrentSuccessfulMirror() {
        let success = PantrySyncRun(
            id: 2,
            startedAt: Date(timeIntervalSince1970: 1_712_736_000),
            finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
            status: .success,
            recipesSeen: 8,
            recipesChanged: 2,
            recipesDeleted: 1,
            errorMessage: nil
        )

        let report = SyncStatusReport(
            snapshot: PantrySyncStatusSnapshot(
                lastAttempt: success,
                lastSuccess: success,
                totalRecipeCount: 8,
                activeRecipeCount: 7,
                deletedRecipeCount: 1
            ),
            paths: makePaths(),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        XCTAssertEqual(report.status, "current")
        XCTAssertEqual(report.freshnessSeconds, 60)
        XCTAssertTrue(report.humanDescription.contains("last_success_at:"))
        XCTAssertTrue(report.humanDescription.contains("freshness: 1m old"))
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

    func testDBStatsReportIncludesDatabaseCountsAndPaths() {
        let report = DBStatsReport(
            stats: PantryDatabaseStats(
                totalRecipeCount: 10,
                activeRecipeCount: 9,
                deletedRecipeCount: 1,
                favoriteRecipeCount: 4,
                categoryLinkCount: 18,
                syncRunCount: 2
            ),
            paths: makePaths()
        )

        XCTAssertTrue(report.humanDescription.contains("recipes_total: 10"))
        XCTAssertTrue(report.humanDescription.contains("recipes_active: 9"))
        XCTAssertTrue(report.humanDescription.contains("recipes_deleted: 1"))
        XCTAssertTrue(report.humanDescription.contains("recipes_favorite: 4"))
        XCTAssertTrue(report.humanDescription.contains("category_links: 18"))
        XCTAssertTrue(report.humanDescription.contains("sync_runs: 2"))
        XCTAssertTrue(report.humanDescription.contains("home: /tmp/pantry"))
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
