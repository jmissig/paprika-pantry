import ArgumentParser

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika reader and query CLI.",
        discussion: "The current slice validates and reads from the real local Paprika SQLite database, keeps direct source diagnostics legible, and includes sidecar-backed recipe search, derived recipe features, cookbook/source aggregate rollups, and conservative ingredient token indexing over canonical recipe fields.",
        subcommands: [
            SourceCommand.self,
            RecipesCommand.self,
            MealsCommand.self,
            GroceriesCommand.self,
            IndexCommand.self,
            DoctorCommand.self,
        ]
    )

    @OptionGroup public var runtimeOptions: RuntimeOptions

    public init() {}

    public mutating func validate() throws {
        RuntimeConfiguration.setCurrent(runtimeOptions)
    }
}
