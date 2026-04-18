import Foundation

public struct GroceryItemSummary: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let quantity: String?
    public let instruction: String?
    public let groceryListName: String?
    public let aisleName: String?
    public let ingredientName: String?
    public let recipeName: String?
    public let isPurchased: Bool

    public init(
        uid: String,
        name: String,
        quantity: String?,
        instruction: String?,
        groceryListName: String?,
        aisleName: String?,
        ingredientName: String?,
        recipeName: String?,
        isPurchased: Bool
    ) {
        self.uid = uid
        self.name = name
        self.quantity = quantity
        self.instruction = instruction
        self.groceryListName = groceryListName
        self.aisleName = aisleName
        self.ingredientName = ingredientName
        self.recipeName = recipeName
        self.isPurchased = isPurchased
    }
}

public enum GroceryReadServiceError: Error, LocalizedError, Equatable {
    case unsupportedSource

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "The configured pantry source does not support direct grocery reads yet."
        }
    }
}

public struct GroceryReadService: Sendable {
    private let source: any GroceriesReadablePantrySource

    public init(source: any PantrySource) throws {
        guard let grocerySource = source as? any GroceriesReadablePantrySource else {
            throw GroceryReadServiceError.unsupportedSource
        }

        self.source = grocerySource
    }

    public func listGroceries() async throws -> [GroceryItemSummary] {
        let groceryItems = try await source.listGroceryItems()

        return groceryItems
            .filter { !$0.isDeleted }
            .map {
                GroceryItemSummary(
                    uid: $0.uid,
                    name: $0.name,
                    quantity: $0.quantity,
                    instruction: $0.instruction,
                    groceryListName: $0.groceryListName,
                    aisleName: $0.aisleName,
                    ingredientName: $0.ingredientName,
                    recipeName: $0.recipeName,
                    isPurchased: $0.isPurchased
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.isPurchased, rhs.isPurchased) {
                case (false, true):
                    return true
                case (true, false):
                    return false
                default:
                    break
                }

                let leftList = lhs.groceryListName ?? ""
                let rightList = rhs.groceryListName ?? ""
                if leftList.localizedCaseInsensitiveCompare(rightList) != .orderedSame {
                    return leftList.localizedCaseInsensitiveCompare(rightList) == .orderedAscending
                }

                let leftAisle = lhs.aisleName ?? ""
                let rightAisle = rhs.aisleName ?? ""
                if leftAisle.localizedCaseInsensitiveCompare(rightAisle) != .orderedSame {
                    return leftAisle.localizedCaseInsensitiveCompare(rightAisle) == .orderedAscending
                }

                if lhs.name.localizedCaseInsensitiveCompare(rhs.name) != .orderedSame {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }

                return lhs.uid < rhs.uid
            }
    }
}
