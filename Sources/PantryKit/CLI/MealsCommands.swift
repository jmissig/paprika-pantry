import ArgumentParser

public struct MealsCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "meals",
        abstract: "Query local meal data.",
        subcommands: [
            MealsListCommand.self,
        ]
    )

    public init() {}
}

public struct MealsListCommand: PantryLeafCommand {
    @OptionGroup public var runtimeOptions: RuntimeOptions
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List meals from the configured pantry source."
    )

    public init() {}
    public mutating func run() async throws {
        let context = try makeContext()
        let mealReadService = try context.makeMealReadService()
        let meals = try await mealReadService.listMeals()
        try context.write(MealsListReport(meals: meals))
    }
}
