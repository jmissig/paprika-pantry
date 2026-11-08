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
}
