import Foundation
import XCTest
@testable import PantryKit

final class PantryConfigStoreTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testSaveAndLoadSourceConfig() throws {
        let paths = try makePaths()
        let store = PantryConfigStore(paths: paths)
        let config = PantryConfig(
            source: PantrySourceConfiguration(
                kind: .paprikaSQLite,
                displayName: "local paprika",
                paprikaSQLite: PaprikaSQLiteSourceConfiguration(
                    databasePath: "/Users/test/Library/Group Containers/.../Paprika.sqlite"
                )
            ),
            updatedAt: Date(timeIntervalSince1970: 1_712_736_000)
        )

        try store.saveConfig(config)

        XCTAssertEqual(try store.loadConfig(), config)
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
