import ArgumentParser
import Foundation

public struct RecipeQueryFilters: Codable, Equatable, Sendable {
    public let favoritesOnly: Bool
    public let minRating: Int?
    public let maxRating: Int?

    public init(
        favoritesOnly: Bool = false,
        minRating: Int? = nil,
        maxRating: Int? = nil
    ) {
        self.favoritesOnly = favoritesOnly
        self.minRating = minRating
        self.maxRating = maxRating
    }

    public var isDefault: Bool {
        favoritesOnly == false && minRating == nil && maxRating == nil
    }

    public func matches(starRating: Int?, isFavorite: Bool) -> Bool {
        if favoritesOnly, !isFavorite {
            return false
        }

        if let minRating {
            guard let starRating, starRating >= minRating else {
                return false
            }
        }

        if let maxRating {
            guard let starRating, starRating <= maxRating else {
                return false
            }
        }

        return true
    }
}

public enum RecipeListSort: String, Codable, CaseIterable, ExpressibleByArgument, Sendable {
    case name
    case rating
}

public enum RecipeSearchSort: String, Codable, CaseIterable, ExpressibleByArgument, Sendable {
    case relevance
    case name
    case rating
}
