import ArgumentParser

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika mirror and query CLI.",
        discussion: "The current slice provides source-backed sync into a SQLite recipe mirror, mirror freshness/status commands, local recipe reads, and source diagnostics.",
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
