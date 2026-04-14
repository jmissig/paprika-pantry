import Foundation
import XCTest
@testable import PantryKit

final class ConfiguredPantrySourceProviderTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testEnvironmentTokenProvidesReadyPaprikaSource() throws {
        let provider = ConfiguredPantrySourceProvider(
            paths: try makePaths(),
            environment: ["PAPRIKA_PANTRY_SOURCE_TOKEN": "token-123"]
        )

        let snapshot = try provider.diagnose()
        let source = try provider.makeSource()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.sourceKind, .paprikaToken)
        XCTAssertEqual(snapshot.credentialSource, "env:PAPRIKA_PANTRY_SOURCE_TOKEN")
        XCTAssertNotNil(source as? PaprikaTokenSource)
    }

    func testConfiguredPaprikaTokenSourceUsesConfiguredEnvironmentVariable() throws {
        let paths = try makePaths()
        try PantryConfigStore(paths: paths).saveConfig(
            PantryConfig(
                source: PantrySourceConfiguration(
                    kind: .paprikaToken,
                    displayName: "kitchen token",
                    paprikaToken: PaprikaTokenSourceConfiguration(
                        tokenEnvironmentVariable: "KITCHEN_TOKEN",
                        baseURL: "https://www.paprikaapp.com"
                    )
                ),
                updatedAt: Date(timeIntervalSince1970: 1_712_736_000)
            )
        )
        let provider = ConfiguredPantrySourceProvider(
            paths: paths,
            environment: ["KITCHEN_TOKEN": "token-456"]
        )

        let snapshot = try provider.diagnose()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.displayName, "kitchen token")
        XCTAssertEqual(snapshot.credentialSource, "env:KITCHEN_TOKEN")
        XCTAssertNotNil(try provider.makeSource() as? PaprikaTokenSource)
    }

    func testMissingSourceConfigurationReportsNotConfigured() throws {
        let provider = ConfiguredPantrySourceProvider(paths: try makePaths(), environment: [:])

        let snapshot = try provider.diagnose()

        XCTAssertEqual(snapshot.status, .notConfigured)
        XCTAssertThrowsError(try provider.makeSource()) { error in
            XCTAssertEqual(error as? PantrySourceProviderError, .notConfigured)
        }
    }

    func testKappariConfigurationReportsUnsupported() throws {
        let paths = try makePaths()
        try PantryConfigStore(paths: paths).saveConfig(
            PantryConfig(
                source: PantrySourceConfiguration(
                    kind: .kappari,
                    displayName: "kappari",
                    kappari: KappariSourceConfiguration(executable: "kappari")
                ),
                updatedAt: Date(timeIntervalSince1970: 1_712_736_000)
            )
        )
        let provider = ConfiguredPantrySourceProvider(paths: paths, environment: [:])

        let snapshot = try provider.diagnose()

        XCTAssertEqual(snapshot.status, .unsupported)
        XCTAssertEqual(snapshot.sourceKind, .kappari)
        XCTAssertThrowsError(try provider.makeSource()) { error in
            XCTAssertEqual(error as? PantrySourceProviderError, .unsupportedSource(.kappari))
        }
    }

    private func makePaths() throws -> PantryPaths {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = root
        return PantryPaths(
            homeDirectory: root,
            configFile: root.appendingPathComponent("config.json"),
            databaseFile: root.appendingPathComponent("pantry.sqlite")
        )
    }
}
