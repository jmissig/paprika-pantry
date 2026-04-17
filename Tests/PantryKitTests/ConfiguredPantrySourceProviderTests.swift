import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class ConfiguredPantrySourceProviderTests: XCTestCase {
    private var temporaryDirectories = [URL]()

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
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
        let sourceDatabaseURL = try makePaprikaSourceDatabase(at: "Paprika.sqlite")
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
        XCTAssertEqual(snapshot.schemaFlavor, "paprika-3-core-data")
        XCTAssertEqual(snapshot.accessMode, "read-only")
        XCTAssertEqual(snapshot.queryOnly, true)
        XCTAssertEqual(snapshot.journalMode, "wal")
        XCTAssertNotNil(source as? PaprikaSQLiteSource)
    }

    func testDefaultPaprikaSQLiteDiscoveryPrefersGroupContainerPath() throws {
        let paths = try makePaths()
        let providerFileManager = try makeProviderFileManager()
        let homeDirectory = providerFileManager.homeDirectoryForCurrentUser

        let groupContainerDatabaseURL = homeDirectory
            .appendingPathComponent("Library/Group Containers/72KVKW69K8.com.hindsightlabs.paprika.mac.v3/Data/Database/Paprika.sqlite")
        let legacyDatabaseURL = homeDirectory
            .appendingPathComponent("Library/Application Support/Paprika Recipe Manager 3/Paprika.sqlite")

        try makePaprikaSourceDatabase(at: groupContainerDatabaseURL.path)
        try makePaprikaSourceDatabase(at: legacyDatabaseURL.path)

        let provider = ConfiguredPantrySourceProvider(
            paths: paths,
            environment: [:],
            fileManager: providerFileManager
        )

        let snapshot = try provider.diagnose()

        XCTAssertEqual(snapshot.status, .ready)
        XCTAssertEqual(snapshot.sourceKind, .paprikaSQLite)
        XCTAssertEqual(snapshot.displayName, "default Paprika SQLite")
        XCTAssertEqual(snapshot.sourceLocation, groupContainerDatabaseURL.path)
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
        let root = try makeTemporaryDirectory()
        return PantryPaths(
            homeDirectory: root,
            configFile: root.appendingPathComponent("config.json"),
            databaseFile: root.appendingPathComponent("pantry.sqlite")
        )
    }

    private func makeProviderFileManager() throws -> FileManager {
        ProviderTestFileManager(homeDirectory: try makeTemporaryDirectory())
    }

    @discardableResult
    private func makePaprikaSourceDatabase(at path: String) throws -> URL {
        let databaseURL = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS Z_METADATA (
                    Z_VERSION INTEGER PRIMARY KEY,
                    Z_UUID TEXT,
                    Z_PLIST BLOB
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID TEXT,
                    ZNAME TEXT,
                    ZSYNCHASH TEXT
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPECATEGORY (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID TEXT,
                    ZNAME TEXT,
                    ZSTATUS TEXT
                )
                """)
            try db.execute(sql: """
                CREATE TABLE Z_12CATEGORIES (
                    Z_12RECIPES INTEGER,
                    Z_13CATEGORIES INTEGER,
                    PRIMARY KEY (Z_12RECIPES, Z_13CATEGORIES)
                )
                """)
        }

        return databaseURL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryDirectories.append(root)
        return root
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
