import ArgumentParser
import Foundation

public struct RecipeQueryFilters: Codable, Equatable, Sendable {
    public let favoritesOnly: Bool
    public let minRating: Int?
    public let maxRating: Int?
    public let categoryNames: [String]

    public init(
        favoritesOnly: Bool = false,
        minRating: Int? = nil,
        maxRating: Int? = nil,
        categoryNames: [String] = []
    ) {
        self.favoritesOnly = favoritesOnly
        self.minRating = minRating
        self.maxRating = maxRating
        self.categoryNames = Self.sanitizedCategoryNames(categoryNames)
    }

    public var isDefault: Bool {
        favoritesOnly == false && minRating == nil && maxRating == nil && categoryNames.isEmpty
    }

    public func matches(starRating: Int?, isFavorite: Bool, categories: [String]) -> Bool {
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

        if !categoryNames.isEmpty {
            let recipeCategories = Set(categories.map(Self.normalizedCategoryName))
            for categoryName in categoryNames.map(Self.normalizedCategoryName) {
                if !recipeCategories.contains(categoryName) {
                    return false
                }
            }
        }

        return true
    }

    private static func normalizedCategoryName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func sanitizedCategoryNames(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let normalized = normalizedCategoryName(trimmed)
            guard seen.insert(normalized).inserted else {
                continue
            }

            result.append(trimmed)
        }

        return result
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
