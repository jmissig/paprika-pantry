import Foundation
import XCTest
@testable import PantryKit

final class SourceLastSyncReportTests: XCTestCase {
    func testHumanDescriptionIncludesObservedLastSyncTime() {
        let report = SourceLastSyncReport(
            snapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready for direct read-only Paprika access.",
                sourceType: PantrySourceType.paprikaSQLite,
                displayName: "default Paprika SQLite",
                implementation: "direct Paprika SQLite source",
                sourceLocation: "/Users/test/Paprika.sqlite",
                paprikaSync: PaprikaSyncDetails(
                    lastSyncAt: Date(timeIntervalSince1970: 1_712_736_060),
                    signalSource: "group-container-preferences",
                    signalLocation: "/Users/test/Library/Preferences/test.plist"
                )
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            ),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        XCTAssertTrue(report.humanDescription.contains("source last-sync-time: Loaded the last observed Paprika sync completion time from local metadata."))
        XCTAssertTrue(report.humanDescription.contains("status: ok"))
        XCTAssertTrue(report.humanDescription.contains("paprika_last_sync_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_060)))"))
        XCTAssertTrue(report.humanDescription.contains("paprika_sync_freshness: 1m old"))
    }
}
