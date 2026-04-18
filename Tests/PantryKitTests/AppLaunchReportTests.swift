import Foundation
import XCTest
@testable import PantryKit

final class AppLaunchReportTests: XCTestCase {
    func testHumanDescriptionStaysClearThatLaunchIsNotDirectSync() {
        let report = AppLaunchReport(
            command: "source launch-app",
            status: "launched",
            message: "Launched the local Paprika app.",
            effect: "This does not trigger a direct sync command. It only opens Paprika, which may sync as part of normal app launch behavior.",
            appBundlePath: "/Applications/Paprika Recipe Manager 3.app",
            bundleIdentifier: "com.hindsightlabs.paprika.mac.v3",
            launchedVia: "open -a",
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            )
        )

        XCTAssertTrue(report.humanDescription.contains("source launch-app: Launched the local Paprika app."))
        XCTAssertTrue(report.humanDescription.contains("status: launched"))
        XCTAssertTrue(report.humanDescription.contains("effect: This does not trigger a direct sync command."))
        XCTAssertTrue(report.humanDescription.contains("app_bundle: /Applications/Paprika Recipe Manager 3.app"))
        XCTAssertTrue(report.humanDescription.contains("bundle_identifier: com.hindsightlabs.paprika.mac.v3"))
        XCTAssertTrue(report.humanDescription.contains("launched_via: open -a"))
    }
}
