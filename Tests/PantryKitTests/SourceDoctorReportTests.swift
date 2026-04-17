import Foundation
import XCTest
@testable import PantryKit

final class SourceDoctorReportTests: XCTestCase {
    func testSourceDoctorReportIncludesReadOnlySQLiteDetails() {
        let report = SourceDoctorReport(
            snapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready for direct read-only Paprika access.",
                sourceKind: .paprikaSQLite,
                displayName: "default Paprika SQLite",
                implementation: "direct Paprika SQLite source",
                sourceLocation: "/Users/test/Library/Group Containers/.../Paprika.sqlite",
                schemaFlavor: "paprika-3-core-data",
                accessMode: "read-only",
                queryOnly: true,
                journalMode: "wal",
                hasWriteAheadLogFiles: true
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            )
        )

        XCTAssertEqual(report.status, "ready")
        XCTAssertTrue(report.humanDescription.contains("kind: paprika-sqlite"))
        XCTAssertTrue(report.humanDescription.contains("schema: paprika-3-core-data"))
        XCTAssertTrue(report.humanDescription.contains("access_mode: read-only"))
        XCTAssertTrue(report.humanDescription.contains("query_only: yes"))
        XCTAssertTrue(report.humanDescription.contains("journal_mode: wal"))
        XCTAssertTrue(report.humanDescription.contains("wal_files: present"))
        XCTAssertTrue(report.humanDescription.contains("database: /tmp/pantry/pantry.sqlite"))
    }

    func testSourceStatsReportIncludesCountsAndSampleCoverage() {
        let report = SourceStatsReport(
            snapshot: SourceStatsSnapshot(
                recipeStubCount: 3,
                activeRecipeCount: 2,
                deletedRecipeCount: 1,
                categoryCount: 2,
                activeCategoryCount: 1,
                deletedCategoryCount: 1,
                sampleLimit: 5,
                sampledRecipeCount: 2,
                sampleFailureCount: 1,
                sampledRecipes: [
                    SourceRecipeSample(uid: "AAA", name: "Apple Cake", categories: ["Dessert"]),
                ],
                sampleFailures: [
                    SourceRecipeSampleFailure(
                        uid: "BBB",
                        name: "Broken Recipe",
                        message: "Missing recipe fixture for BBB."
                    ),
                ]
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            )
        )

        XCTAssertEqual(report.status, "partial")
        XCTAssertTrue(report.humanDescription.contains("recipes_total: 3"))
        XCTAssertTrue(report.humanDescription.contains("categories_deleted: 1"))
        XCTAssertTrue(report.humanDescription.contains("sample_recipe: Apple Cake [AAA] categories=Dessert"))
        XCTAssertTrue(report.humanDescription.contains("sample_failure: Broken Recipe [BBB] error=Missing recipe fixture for BBB."))
    }

    func testDoctorReportHighlightsMissingIndexBuild() {
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
                recipeSearchDocumentCount: 0,
                lastRecipeSearchRun: nil,
                lastSuccessfulRecipeSearchRun: nil
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            ),
            now: Date(timeIntervalSince1970: 1_712_736_180)
        )

        XCTAssertEqual(report.status, "needs-index")
        XCTAssertTrue(report.humanDescription.contains("index_status: missing"))
        XCTAssertTrue(report.humanDescription.contains("recipe_search_freshness: never-built"))
        XCTAssertTrue(report.humanDescription.contains("next_action: Run `paprika-pantry index rebuild`"))
    }
}
