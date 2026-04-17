import Foundation
import XCTest
@testable import PantryKit

final class SourceDoctorReportTests: XCTestCase {
    func testSourceDoctorReportIncludesKindAndCredentialSource() {
        let report = SourceDoctorReport(
            snapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready.",
                sourceKind: .paprikaToken,
                displayName: "legacy token",
                implementation: "direct Paprika token source",
                credentialSource: "env:PAPRIKA_PANTRY_SOURCE_TOKEN",
                sourceLocation: nil
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            )
        )

        XCTAssertEqual(report.status, "ready")
        XCTAssertTrue(report.humanDescription.contains("kind: paprika-token"))
        XCTAssertTrue(report.humanDescription.contains("credential_source: env:PAPRIKA_PANTRY_SOURCE_TOKEN"))
        XCTAssertTrue(report.humanDescription.contains("database: /tmp/pantry/pantry.sqlite"))
    }
}
