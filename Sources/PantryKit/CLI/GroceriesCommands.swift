import ArgumentParser

public struct GroceriesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "groceries",
        abstract: "Query local grocery data.",
        subcommands: [
            GroceriesListCommand.self,
        ]
    )

    public init() {}
}

public struct GroceriesListCommand: PantryLeafCommand {
    @OptionGroup public var runtimeOptions: RuntimeOptions
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List groceries from the configured pantry source."
    )

    public init() {}
    public mutating func run() async throws {
        let context = try makeContext()
        let groceryReadService = try context.makeGroceryReadService()
        let groceries = try await groceryReadService.listGroceries()
        try context.write(GroceriesListReport(groceries: groceries))
    }
}
