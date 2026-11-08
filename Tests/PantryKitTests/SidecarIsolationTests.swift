import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class SidecarIsolationTests: XCTestCase {
    func testCanonicalCommandsSurviveUnavailableSidecarsWithoutMutation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.sqlite")
        let sourceQueue = try DatabaseQueue(path: source.path)
        try sourceQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (Z_PK INTEGER PRIMARY KEY, ZUID TEXT, ZNAME TEXT);
                INSERT INTO ZRECIPE VALUES (1, 'synthetic', 'Synthetic Soup');
                CREATE TABLE ZRECIPECATEGORY (Z_PK INTEGER PRIMARY KEY, ZUID TEXT, ZNAME TEXT);
                CREATE TABLE Z_12CATEGORIES (Z_12RECIPES INTEGER, Z_13CATEGORIES INTEGER);
                CREATE TABLE Z_METADATA (Z_UUID TEXT);
                INSERT INTO Z_METADATA VALUES ('synthetic-isolation');
                """)
        }
        try sourceQueue.close()
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let binary = repo.appendingPathComponent("build/debug/paprika-pantry")
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path), "Build CLI with make build before integration tests")
        for state in ["missing", "legacy", "incompatible", "future", "corrupt", "inaccessible"] {
            let sidecar = root.appendingPathComponent(state + ".sqlite")
            switch state {
            case "legacy", "future":
                let q = try DatabaseQueue(path: sidecar.path)
                try q.write { db in
                    try db.execute(sql: "CREATE TABLE grdb_migrations(identifier TEXT PRIMARY KEY)")
                    if state == "future" { try db.execute(sql: "INSERT INTO grdb_migrations VALUES ('future')") }
                }
                try q.close()
            case "incompatible":
                let q = try PantrySidecarDatabase(path: sidecar).openQueue()
                try q.write { db in
                    for family in PantrySidecarStore.allFamilies {
                        try db.execute(sql: "INSERT INTO index_provenance VALUES (?, 'different-source-contract', 'other-generation', '2026-01-01', NULL)", arguments: [family])
                    }
                }
                try q.close()
            case "corrupt": try Data("not a database".utf8).write(to: sidecar)
            case "inaccessible": try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: false)
            default: break
            }
            let before = try? Data(contentsOf: sidecar)
            for format in ["text", "json"] {
                for command in [["recipes", "list"], ["recipes", "show", "synthetic"], ["doctor"]] {
                    let (status, output) = try run(binary, root, source, sidecar, ["--format", format] + command)
                    XCTAssertEqual(status, 0, "\(state): \(output)")
                    if command.first == "recipes" {
                        XCTAssertTrue(output.contains("Synthetic Soup"), output)
                        XCTAssertTrue(output.contains(format == "json" ? "enrichmentIssue" : "enrichment_unavailable"), output)
                    } else { XCTAssertTrue(output.contains(format == "json" ? "\"sourceStatus\" : \"ready\"" : "source_status: ready"), output) }
                }
            }
            for command in [["recipes", "list", "--ingredient", "lemon"], ["recipes", "pairings"], ["recipes", "search", "soup"], ["recipes", "list", "--min-meal-count", "1"], ["recipes", "list", "--max-total-time-minutes", "30"]] {
                let (status, output) = try run(binary, root, source, sidecar, command)
                XCTAssertNotEqual(status, 0, "Must not discard indexed constraints")
                XCTAssertFalse(output.contains("Unknown option"), output)
                if ["missing", "legacy", "incompatible"].contains(state) { XCTAssertTrue(output.contains("index rebuild"), output) }
                if state == "future" { XCTAssertTrue(output.contains("newer paprika-pantry"), output) }
                if state == "corrupt" { XCTAssertTrue(output.contains("not a database"), output) }
                if state == "inaccessible" { XCTAssertTrue(output.contains("unable to open"), output) }
            }
            XCTAssertEqual(try? Data(contentsOf: sidecar), before, state)
            if state == "missing" { XCTAssertFalse(FileManager.default.fileExists(atPath: sidecar.path)) }
        }
    }

    private func run(_ binary: URL, _ root: URL, _ source: URL, _ sidecar: URL, _ args: [String]) throws -> (Int32, String) {
        let process = Process()
        process.executableURL = binary
        process.arguments = ["--home", root.appendingPathComponent("home").path, "--db-path", sidecar.path] + args
        var environment = ProcessInfo.processInfo.environment
        environment["PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB"] = source.path
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
