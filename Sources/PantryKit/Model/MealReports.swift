import Foundation

public struct MealsListReport: ConsoleRenderable, Equatable, Sendable {
    public let command: String
    public let mealCount: Int
    public let meals: [MealSummary]

    public init(meals: [MealSummary]) {
        self.command = "meals list"
        self.mealCount = meals.count
        self.meals = meals
    }

    public var humanDescription: String {
        var lines = ["\(command): \(mealCount) meals"]

        if meals.isEmpty {
            lines.append("No source meals found.")
            return lines.joined(separator: "\n")
        }

        for meal in meals {
            var fields = [meal.name, "[\(meal.uid)]"]

            if let scheduledAt = meal.scheduledAt {
                fields.append("date=\(scheduledAt)")
            }

            if let mealType = meal.mealType, !mealType.isEmpty {
                fields.append("type=\(mealType)")
            }

            if let recipeUID = meal.recipeUID {
                let label = meal.recipeName ?? meal.name
                fields.append("recipe=\(label) [\(recipeUID)]")
            }

            lines.append(fields.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }
}
