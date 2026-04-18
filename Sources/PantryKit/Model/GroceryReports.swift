import Foundation

public struct GroceriesListReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command: String
    public let groceryCount: Int
    public let groceries: [GroceryItemSummary]

    public init(groceries: [GroceryItemSummary]) {
        self.command = "groceries list"
        self.groceryCount = groceries.count
        self.groceries = groceries
    }

    public var humanDescription: String {
        var lines = ["\(command): \(groceryCount) groceries"]

        if groceries.isEmpty {
            lines.append("No source grocery items found.")
            return lines.joined(separator: "\n")
        }

        for grocery in groceries {
            var fields = [grocery.name, "[\(grocery.uid)]"]

            if let quantity = grocery.quantity, !quantity.isEmpty {
                fields.append("quantity=\(quantity)")
            }

            if let groceryListName = grocery.groceryListName, !groceryListName.isEmpty {
                fields.append("list=\(groceryListName)")
            }

            if let aisleName = grocery.aisleName, !aisleName.isEmpty {
                fields.append("aisle=\(aisleName)")
            }

            fields.append("purchased=\(grocery.isPurchased ? "yes" : "no")")

            if let ingredientName = grocery.ingredientName, !ingredientName.isEmpty {
                fields.append("ingredient=\(ingredientName)")
            }

            if let recipeName = grocery.recipeName, !recipeName.isEmpty {
                fields.append("recipe=\(recipeName)")
            }

            if let instruction = grocery.instruction, !instruction.isEmpty {
                fields.append("instruction=\(instruction)")
            }

            lines.append(fields.joined(separator: " "))
        }

        return lines.joined(separator: "\n")
    }

    public var csvHeaders: [String] {
        [
            "uid",
            "name",
            "quantity",
            "instruction",
            "grocery_list_name",
            "aisle_name",
            "ingredient_name",
            "recipe_name",
            "is_purchased",
        ]
    }

    public var csvRows: [[String]] {
        groceries.map {
            [
                $0.uid,
                $0.name,
                $0.quantity ?? "",
                $0.instruction ?? "",
                $0.groceryListName ?? "",
                $0.aisleName ?? "",
                $0.ingredientName ?? "",
                $0.recipeName ?? "",
                $0.isPurchased ? "true" : "false",
            ]
        }
    }
}
