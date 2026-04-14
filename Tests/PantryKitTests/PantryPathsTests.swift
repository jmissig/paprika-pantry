import XCTest
@testable import PantryKit

final class PantryPathsTests: XCTestCase {
    func testResolveUsesManagedHomeByDefault() throws {
        let baseDirectories = PantryBaseDirectories(
            applicationSupportDirectory: URL(fileURLWithPath: "/tmp/Application Support")
        )

        let paths = try PantryPaths.resolve(
            baseDirectories: baseDirectories,
            environment: [:]
        )

        XCTAssertEqual(paths.homeDirectory.path, "/tmp/Application Support/paprika-pantry")
        XCTAssertEqual(paths.configFile.path, "/tmp/Application Support/paprika-pantry/config.json")
        XCTAssertEqual(paths.databaseFile.path, "/tmp/Application Support/paprika-pantry/pantry.sqlite")
    }

    func testResolveHonorsExplicitAndEnvironmentOverrides() throws {
        let baseDirectories = PantryBaseDirectories(
            applicationSupportDirectory: URL(fileURLWithPath: "/tmp/Application Support")
        )

        let paths = try PantryPaths.resolve(
            options: PantryPathOptions(
                homeDirectory: URL(fileURLWithPath: "/override/home"),
                databaseFile: URL(fileURLWithPath: "/override/data/pantry.db")
            ),
            baseDirectories: baseDirectories,
            environment: [
                "PAPRIKA_PANTRY_CONFIG": "/env/config.json",
            ]
        )

        XCTAssertEqual(paths.homeDirectory.path, "/override/home")
        XCTAssertEqual(paths.configFile.path, "/env/config.json")
        XCTAssertEqual(paths.databaseFile.path, "/override/data/pantry.db")
    }
}
