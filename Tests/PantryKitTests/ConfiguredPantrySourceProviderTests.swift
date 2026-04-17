import Foundation
import GRDB
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
            environment: ["PAPRIKA_PANTRY_SOURCE_TOKEN": "token-123"],
            fileManager: try makeProviderFileManager()
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
            environment: ["KITCHEN_TOKEN": "token-456"],
            fileManager: try makeProviderFileManager()
        )

        let snapshot = try provider.diagnose()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.displayName, "kitchen token")
        XCTAssertEqual(snapshot.credentialSource, "env:KITCHEN_TOKEN")
        XCTAssertNotNil(try provider.makeSource() as? PaprikaTokenSource)
    }

    func testConfiguredPaprikaSQLiteSourceUsesConfiguredDatabasePath() throws {
        let paths = try makePaths()
        let sourceDatabaseURL = try makePaprikaSourceDatabase()
        try PantryConfigStore(paths: paths).saveConfig(
            PantryConfig(
                source: PantrySourceConfiguration(
                    kind: .paprikaSQLite,
                    displayName: "local paprika",
                    paprikaSQLite: PaprikaSQLiteSourceConfiguration(
                        databasePath: sourceDatabaseURL.path
                    )
                ),
                updatedAt: Date(timeIntervalSince1970: 1_712_736_000)
            )
        )
        let provider = ConfiguredPantrySourceProvider(
            paths: paths,
            environment: [:],
            fileManager: try makeProviderFileManager()
        )

        let snapshot = try provider.diagnose()
        let source = try provider.makeSource()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.sourceKind, .paprikaSQLite)
        XCTAssertEqual(snapshot.displayName, "local paprika")
        XCTAssertEqual(snapshot.sourceLocation, sourceDatabaseURL.path)
        XCTAssertNotNil(source as? PaprikaSQLiteSource)
    }

    func testMissingSourceConfigurationReportsNotConfigured() throws {
        let provider = ConfiguredPantrySourceProvider(
            paths: try makePaths(),
            environment: [:],
            fileManager: try makeProviderFileManager()
        )

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
        let provider = ConfiguredPantrySourceProvider(
            paths: paths,
            environment: [:],
            fileManager: try makeProviderFileManager()
        )

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
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryDirectoryURL = root
        return PantryPaths(
            homeDirectory: root,
            configFile: root.appendingPathComponent("config.json"),
            databaseFile: root.appendingPathComponent("pantry.sqlite")
        )
    }

    private func makeProviderFileManager() throws -> FileManager {
        ProviderTestFileManager(homeDirectory: try XCTUnwrap(temporaryDirectoryURL))
    }

    private func makePaprikaSourceDatabase() throws -> URL {
        let root = try XCTUnwrap(temporaryDirectoryURL)
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE recipes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uid TEXT NOT NULL,
                    name TEXT NOT NULL,
                    sync_hash TEXT,
                    in_trash INTEGER NOT NULL DEFAULT 0
                )
                """)
            try db.execute(sql: """
                CREATE TABLE categories (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uid TEXT NOT NULL,
                    name TEXT NOT NULL,
                    in_trash INTEGER NOT NULL DEFAULT 0
                )
                """)
            try db.execute(sql: """
                CREATE TABLE recipe_categories (
                    recipe_id INTEGER NOT NULL,
                    category_id INTEGER NOT NULL
                )
                """)
        }

        return databaseURL
    }
}

private final class ProviderTestFileManager: FileManager, @unchecked Sendable {
    private let overriddenHomeDirectory: URL

    init(homeDirectory: URL) {
        self.overriddenHomeDirectory = homeDirectory
        super.init()
    }

    override var homeDirectoryForCurrentUser: URL {
        overriddenHomeDirectory
    }
}
