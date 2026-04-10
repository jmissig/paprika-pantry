import XCTest
@testable import PantryKit

final class AuthStatusReportTests: XCTestCase {
    func testStatusReportForFirstRunWithoutLocalState() {
        let report = AuthStatusReport(
            state: PantryAuthState(config: nil, session: nil),
            paths: makePaths()
        )

        XCTAssertEqual(report.status, "not-authenticated")
        XCTAssertFalse(report.isAuthenticated)
        XCTAssertFalse(report.hasConfig)
        XCTAssertFalse(report.hasSession)
        XCTAssertEqual(report.message, "No local Paprika session is saved.")
        XCTAssertTrue(report.humanDescription.contains("config: absent"))
        XCTAssertTrue(report.humanDescription.contains("session: absent"))
        XCTAssertTrue(report.humanDescription.contains("next: paprika-pantry auth login"))
    }

    func testStatusReportUsesSessionDetailsWhenPresent() {
        let timestamp = Date(timeIntervalSince1970: 1_712_735_200)
        let report = AuthStatusReport(
            state: PantryAuthState(
                config: PantryConfig(
                    authStrategy: .simpleAccount,
                    lastEmailAddress: "config@example.com",
                    updatedAt: timestamp
                ),
                session: PantrySession(
                    emailAddress: "session@example.com",
                    token: "token-123",
                    createdAt: timestamp,
                    authStrategy: .simpleAccount
                )
            ),
            paths: makePaths()
        )

        XCTAssertEqual(report.status, "authenticated")
        XCTAssertTrue(report.isAuthenticated)
        XCTAssertTrue(report.hasConfig)
        XCTAssertTrue(report.hasSession)
        XCTAssertEqual(report.sessionEmailAddress, "session@example.com")
        XCTAssertEqual(report.sessionAuthStrategy, .simpleAccount)
        XCTAssertEqual(report.sessionCreatedAt, timestamp)
        XCTAssertTrue(report.humanDescription.contains("email: session@example.com"))
        XCTAssertFalse(report.humanDescription.contains("next: paprika-pantry auth login"))
    }

    private func makePaths() -> PantryPaths {
        PantryPaths(
            homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
            configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
            sessionFile: URL(fileURLWithPath: "/tmp/pantry/session.json"),
            databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
        )
    }
}
