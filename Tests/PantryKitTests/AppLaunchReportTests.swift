import Foundation
import XCTest
@testable import PantryKit

final class AppLaunchReportTests: XCTestCase {
    func testHumanDescriptionStaysClearThatLaunchIsNotDirectSync() {
        let report = AppLaunchReport(
            command: "source launch-app",
            status: "launched-and-sync-advanced",
            message: "Launched the local Paprika app and observed the Paprika last-sync timestamp advance.",
            effect: "This still does not call a direct sync API. It launches Paprika, then waits for the locally observed last-sync marker to move forward.",
            appBundlePath: "/Applications/Paprika Recipe Manager 3.app",
            bundleIdentifier: "com.hindsightlabs.paprika.mac.v3",
            launchedVia: "open -a",
            waitedForSync: true,
            waitTimeoutSeconds: 180,
            pollIntervalSeconds: 2,
            initialPaprikaSync: PaprikaSyncDetails(
                lastSyncAt: Date(timeIntervalSince1970: 1_712_736_000),
                signalSource: "group-container-preferences",
                signalLocation: "/Users/test/Library/Preferences/before.plist"
            ),
            observedPaprikaSync: PaprikaSyncDetails(
                lastSyncAt: Date(timeIntervalSince1970: 1_712_736_120),
                signalSource: "group-container-preferences",
                signalLocation: "/Users/test/Library/Preferences/after.plist"
            ),
            syncAdvanced: true,
            observedSyncFreshnessSeconds: 60,
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            )
        )

        XCTAssertTrue(report.humanDescription.contains("source launch-app: Launched the local Paprika app and observed the Paprika last-sync timestamp advance."))
        XCTAssertTrue(report.humanDescription.contains("status: launched-and-sync-advanced"))
        XCTAssertTrue(report.humanDescription.contains("effect: This still does not call a direct sync API."))
        XCTAssertTrue(report.humanDescription.contains("app_bundle: /Applications/Paprika Recipe Manager 3.app"))
        XCTAssertTrue(report.humanDescription.contains("bundle_identifier: com.hindsightlabs.paprika.mac.v3"))
        XCTAssertTrue(report.humanDescription.contains("launched_via: open -a"))
        XCTAssertTrue(report.humanDescription.contains("waited_for_sync: yes"))
        XCTAssertTrue(report.humanDescription.contains("wait_timeout_seconds: 180"))
        XCTAssertTrue(report.humanDescription.contains("poll_interval_seconds: 2"))
        XCTAssertTrue(report.humanDescription.contains("initial_paprika_last_sync_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_000)))"))
        XCTAssertTrue(report.humanDescription.contains("observed_paprika_last_sync_at: \(renderedTimestamp(Date(timeIntervalSince1970: 1_712_736_120)))"))
        XCTAssertTrue(report.humanDescription.contains("observed_paprika_sync_freshness: 1m old"))
        XCTAssertTrue(report.humanDescription.contains("observed_sync_advance: yes"))
    }
}
