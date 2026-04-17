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
                credentialSource: nil,
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
}
