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
}
