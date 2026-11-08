import XCTest
@testable import PantryKit

final class CommandShapeTests: XCTestCase {
    func testSourceContainsOnlyRealSourceCommands() {
        let names = SourceCommand.configuration.subcommands.map { $0.configuration.commandName }
        XCTAssertEqual(names, ["status", "last-sync-time", "stats", "launch-app"])
    }

    func testRecipesContainsCookbookAggregateCommand() {
        let names = RecipesCommand.configuration.subcommands.map { $0.configuration.commandName }
        XCTAssertEqual(names, ["list", "show", "search", "features", "ingredients", "pairings", "cookbooks", "collections"])
    }
    func testNativeAsyncParsingKeepsRuntimeOptionsCommandOwned() async throws {
        let first = try await PantryCLI.asyncParseAsRoot(["--home", "/tmp/pantry-first", "--format", "json", "recipes", "list"])
        let second = try await PantryCLI.asyncParseAsRoot(["recipes", "list", "--home", "/tmp/pantry-second", "--format", "csv"])
        let a = try XCTUnwrap(first as? RecipesListCommand)
        let b = try XCTUnwrap(second as? RecipesListCommand)
        XCTAssertEqual(try a.makeContext().paths.homeDirectory.path, "/tmp/pantry-first")
        XCTAssertEqual(try b.makeContext().paths.homeDirectory.path, "/tmp/pantry-second")
        XCTAssertEqual(try a.makeContext().outputFormat, .json)
        XCTAssertEqual(try b.makeContext().outputFormat, .csv)
    }

}
