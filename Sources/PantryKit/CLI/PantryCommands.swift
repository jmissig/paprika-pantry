import ArgumentParser

public struct PantryCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "pantry",
        abstract: "Query local pantry item data.",
        subcommands: [
            PantryListCommand.self,
        ]
    )

    public init() {}
}

public struct PantryListCommand: PantryLeafCommand {
    @OptionGroup public var runtimeOptions: RuntimeOptions
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List pantry items from the configured pantry source."
    )

    public init() {}
    public mutating func run() async throws {
        let context = try makeContext()
        let pantryItemReadService = try context.makePantryItemReadService()
        let pantryItems = try await pantryItemReadService.listPantryItems()
        try context.write(PantryItemsListReport(pantryItems: pantryItems))
    }
}
