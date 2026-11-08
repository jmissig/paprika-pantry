import Foundation

public struct PantryItemSummary: Codable, Equatable, Sendable {
    public let locationUID: String?
    public let locationName: String?
    public let notes: String?
    public let uid: String
    public let name: String
    public let quantity: String?
    public let aisleName: String?
    public let ingredientName: String?
    public let purchaseDate: String?
    public let expirationDate: String?
    public let hasExpiration: Bool
    public let isInStock: Bool

    public init(
        uid: String,
        name: String,
        quantity: String?,
        aisleName: String?,
        ingredientName: String?,
        purchaseDate: String?,
        expirationDate: String?,
        hasExpiration: Bool,
        isInStock: Bool,
        locationUID: String? = nil,
        locationName: String? = nil,
        notes: String? = nil
    ) {
        self.locationUID = locationUID
        self.locationName = locationName
        self.notes = notes
        self.uid = uid
        self.name = name
        self.quantity = quantity
        self.aisleName = aisleName
        self.ingredientName = ingredientName
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.hasExpiration = hasExpiration
        self.isInStock = isInStock
    }
}

public enum PantryItemReadServiceError: Error, LocalizedError, Equatable {
    case unsupportedSource

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "The configured pantry source does not support direct pantry-item reads yet."
        }
    }
}

public struct PantryItemReadService: Sendable {
    private let source: any PantryItemsReadablePantrySource

    public init(source: any PantrySource) throws {
        guard let pantryItemSource = source as? any PantryItemsReadablePantrySource else {
            throw PantryItemReadServiceError.unsupportedSource
        }

        self.source = pantryItemSource
    }

    public func listPantryItems() async throws -> [PantryItemSummary] {
        let pantryItems = try await source.listPantryItems()

        return pantryItems
            .filter { !$0.isDeleted }
            .map {
                PantryItemSummary(
                    uid: $0.uid,
                    name: $0.name,
                    quantity: $0.quantity,
                    aisleName: $0.aisleName,
                    ingredientName: $0.ingredientName,
                    purchaseDate: $0.purchaseDate,
                    expirationDate: $0.expirationDate,
                    hasExpiration: $0.hasExpiration,
                    isInStock: $0.isInStock,
                    locationUID: $0.locationUID, locationName: $0.locationName, notes: $0.notes
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.isInStock, rhs.isInStock) {
                case (true, false):
                    return true
                case (false, true):
                    return false
                default:
                    break
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
