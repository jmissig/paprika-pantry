import Foundation

public struct PantryItemsListReport: ConsoleRenderable, CSVRenderable, Equatable, Sendable {
    public let command: String
    public let pantryItemCount: Int
    public let pantryItems: [PantryItemSummary]

    public init(pantryItems: [PantryItemSummary]) {
        self.command = "pantry list"
        self.pantryItemCount = pantryItems.count
        self.pantryItems = pantryItems
    }

    public var humanDescription: String {
        var lines = ["\(command): \(pantryItemCount) pantry items"]

        if pantryItems.isEmpty {
            lines.append("No source pantry items found.")
            return lines.joined(separator: "\n")
        }

        for pantryItem in pantryItems {
            var fields = [pantryItem.name, "[\(pantryItem.uid)]"]

            if let quantity = pantryItem.quantity, !quantity.isEmpty {
                fields.append("quantity=\(quantity)")
            }

            if let aisleName = pantryItem.aisleName, !aisleName.isEmpty {
                fields.append("aisle=\(aisleName)")
            }

            fields.append("in_stock=\(pantryItem.isInStock ? "yes" : "no")")

            if let ingredientName = pantryItem.ingredientName, !ingredientName.isEmpty {
                fields.append("ingredient=\(ingredientName)")
            }

            if let purchaseDate = pantryItem.purchaseDate, !purchaseDate.isEmpty {
                fields.append("purchased=\(purchaseDate)")
            }

            if pantryItem.hasExpiration {
                if let expirationDate = pantryItem.expirationDate, !expirationDate.isEmpty {
                    fields.append("expires=\(expirationDate)")
                } else {
                    fields.append("expires=tracked")
                }
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
            "aisle_name",
            "ingredient_name",
            "is_in_stock",
            "purchase_date",
            "has_expiration",
            "expiration_date",
        ]
    }

    public var csvRows: [[String]] {
        pantryItems.map {
            [
                $0.uid,
                $0.name,
                $0.quantity ?? "",
                $0.aisleName ?? "",
                $0.ingredientName ?? "",
                $0.isInStock ? "true" : "false",
                $0.purchaseDate ?? "",
                $0.hasExpiration ? "true" : "false",
                $0.expirationDate ?? "",
            ]
        }
    }
}
