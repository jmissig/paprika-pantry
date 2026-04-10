import XCTest
@testable import PantryKit

final class PantryAuthStoreTests: XCTestCase {
    func testSaveAndLoadConfigAndSession() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = makePaths(root: root)
        let store = PantryAuthStore(paths: paths)
        let timestamp = Date(timeIntervalSince1970: 1_712_735_200)
        let config = PantryConfig(
            authStrategy: .simpleAccount,
            lastEmailAddress: "cook@example.com",
            updatedAt: timestamp
        )
        let session = PantrySession(
            emailAddress: "cook@example.com",
            token: "token-123",
            createdAt: timestamp,
            authStrategy: .simpleAccount
        )

        try store.saveConfig(config)
        try store.saveSession(session)

        XCTAssertEqual(try store.loadConfig(), config)
        XCTAssertEqual(try store.loadSession(), session)
    }

    func testClearSessionRemovesOnlySessionFile() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let paths = makePaths(root: root)
        let store = PantryAuthStore(paths: paths)
        let timestamp = Date(timeIntervalSince1970: 1_712_735_200)

        try store.saveConfig(
            PantryConfig(
                authStrategy: .simpleAccount,
                lastEmailAddress: "cook@example.com",
                updatedAt: timestamp
            )
        )
        try store.saveSession(
            PantrySession(
                emailAddress: "cook@example.com",
                token: "token-123",
                createdAt: timestamp
            )
        )

        XCTAssertTrue(try store.clearSession())
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.sessionFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.configFile.path))
        XCTAssertNotNil(try store.loadConfig())
        XCTAssertNil(try store.loadSession())
        XCTAssertFalse(try store.clearSession())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func makePaths(root: URL) -> PantryPaths {
        PantryPaths(
            homeDirectory: root,
            configFile: root.appendingPathComponent("config.json"),
            sessionFile: root.appendingPathComponent("session.json"),
            databaseFile: root.appendingPathComponent("pantry.sqlite")
        )
    }
}
