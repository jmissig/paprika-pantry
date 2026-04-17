import ArgumentParser

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika reader and query CLI.",
        discussion: "The current slice validates and reads from the real local Paprika SQLite database, keeps direct source diagnostics legible, and retains a transitional local cache path while sidecar/index work is still deferred.",
        subcommands: [
            SourceCommand.self,
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
