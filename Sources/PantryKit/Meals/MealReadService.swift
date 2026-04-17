import Foundation

public struct MealSummary: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let scheduledAt: String?
    public let mealType: String?
    public let recipeUID: String?
    public let recipeName: String?

    public init(
        uid: String,
        name: String,
        scheduledAt: String?,
        mealType: String?,
        recipeUID: String?,
        recipeName: String?
    ) {
        self.uid = uid
        self.name = name
        self.scheduledAt = scheduledAt
        self.mealType = mealType
        self.recipeUID = recipeUID
        self.recipeName = recipeName
    }
}

public enum MealReadServiceError: Error, LocalizedError, Equatable {
    case unsupportedSource

    public var errorDescription: String? {
        switch self {
        case .unsupportedSource:
            return "The configured pantry source does not support direct meal reads yet."
        }
    }
}

public struct MealReadService: Sendable {
    private let source: any MealsReadablePantrySource

    public init(source: any PantrySource) throws {
        guard let mealSource = source as? any MealsReadablePantrySource else {
            throw MealReadServiceError.unsupportedSource
        }

        self.source = mealSource
    }

    public func listMeals() async throws -> [MealSummary] {
        let meals = try await source.listMeals()

        return meals
            .filter { !$0.isDeleted }
            .map {
                MealSummary(
                    uid: $0.uid,
                    name: $0.name,
                    scheduledAt: $0.scheduledAt,
                    mealType: $0.mealType,
                    recipeUID: $0.recipeUID,
                    recipeName: $0.recipeName
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.scheduledAt, rhs.scheduledAt) {
                case let (left?, right?) where left != right:
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
                        return lhs.uid < rhs.uid
                    }

                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }
    }
}
