import ArgumentParser

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika reader and query CLI.",
        discussion: "The current slice validates and reads from the real local Paprika SQLite database, keeps direct source diagnostics legible, and includes direct recipe, meal, grocery, and pantry-item reads plus sidecar-backed recipe search, derived recipe features, cookbook/source aggregate rollups, and conservative ingredient token indexing over canonical recipe fields.\n\nDefault output is compact human-readable text for operators. Prefer `--format json` for agents and scripts. `--json` remains available as shorthand for `--format json`. `--format csv` is currently limited to row-oriented list/search reports and cookbook aggregates; detail and diagnostic reports continue to support human and JSON output only.",
        subcommands: [
            SourceCommand.self,
            RecipesCommand.self,
            MealsCommand.self,
            GroceriesCommand.self,
            PantryCommand.self,
            IndexCommand.self,
            DoctorCommand.self,
        ]
    )

    @OptionGroup public var runtimeOptions: RuntimeOptions

    public init() {}

    public mutating func validate() throws {
        _ = try runtimeOptions.resolvedOutputFormat()
        RuntimeConfiguration.setCurrent(runtimeOptions)
    }
}
