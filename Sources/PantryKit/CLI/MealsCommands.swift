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
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List meals from the configured pantry source."
    )

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let mealReadService = try context.makeMealReadService()
        let meals = try BlockingAsync.run {
            try await mealReadService.listMeals()
        }
        try context.write(MealsListReport(meals: meals))
    }
}
