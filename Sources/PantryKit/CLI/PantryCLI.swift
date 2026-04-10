import ArgumentParser

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika mirror and query CLI.",
        discussion: "Phase 1 provides the package scaffold, managed path plumbing, and a coherent command tree without remote sync yet.",
        subcommands: [
            AuthCommand.self,
            SyncCommand.self,
            RecipesCommand.self,
            MealsCommand.self,
            GroceriesCommand.self,
            DBCommand.self,
            DoctorCommand.self,
        ]
    )

    @OptionGroup public var runtimeOptions: RuntimeOptions

    public init() {}

    public mutating func validate() throws {
        RuntimeConfiguration.setCurrent(runtimeOptions)
    }
}
