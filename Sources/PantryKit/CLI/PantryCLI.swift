import ArgumentParser

// VERSION-SYNC-START
private let pantryCLIVersion = "1.0.0"
// VERSION-SYNC-END

public struct PantryCLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "paprika-pantry",
        abstract: "Local-first Paprika reader and query CLI.",
        discussion: "The current slice validates and reads from the real local Paprika SQLite database, keeps direct source diagnostics legible, and includes direct recipe, meal, grocery, and pantry-item reads plus recipe search powered by paprika-pantry's local index, derived recipe features, cookbook/source aggregate rollups, conservative ingredient token indexing, and token-pair co-occurrence evidence over canonical recipe fields.\n\nDefault output is compact human-readable text for operators. Prefer `--format json` for agents and scripts. `--json` remains available as shorthand for `--format json`. `--format csv` is currently limited to row-oriented list/search reports and cookbook aggregates; detail and diagnostic reports continue to support human and JSON output only.",
        version: pantryCLIVersion,
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
