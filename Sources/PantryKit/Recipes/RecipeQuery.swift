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

public struct RecipeDerivedConstraints: Codable, Equatable, Sendable {
    public let minTotalTimeMinutes: Int?
    public let maxTotalTimeMinutes: Int?
    public let minIngredientLineCount: Int?
    public let maxIngredientLineCount: Int?

    public init(
        minTotalTimeMinutes: Int? = nil,
        maxTotalTimeMinutes: Int? = nil,
        minIngredientLineCount: Int? = nil,
        maxIngredientLineCount: Int? = nil
    ) {
        self.minTotalTimeMinutes = minTotalTimeMinutes
        self.maxTotalTimeMinutes = maxTotalTimeMinutes
        self.minIngredientLineCount = minIngredientLineCount
        self.maxIngredientLineCount = maxIngredientLineCount
    }

    public var isDefault: Bool {
        minTotalTimeMinutes == nil &&
            maxTotalTimeMinutes == nil &&
            minIngredientLineCount == nil &&
            maxIngredientLineCount == nil
    }

    public func matches(features: RecipeDerivedFeatures?) -> Bool {
        if let minTotalTimeMinutes {
            guard let totalTimeMinutes = features?.totalTimeMinutes, totalTimeMinutes >= minTotalTimeMinutes else {
                return false
            }
        }

        if let maxTotalTimeMinutes {
            guard let totalTimeMinutes = features?.totalTimeMinutes, totalTimeMinutes <= maxTotalTimeMinutes else {
                return false
            }
        }

        if let minIngredientLineCount {
            guard let ingredientLineCount = features?.ingredientLineCount, ingredientLineCount >= minIngredientLineCount else {
                return false
            }
        }

        if let maxIngredientLineCount {
            guard let ingredientLineCount = features?.ingredientLineCount, ingredientLineCount <= maxIngredientLineCount else {
                return false
            }
        }

        return true
    }
}

public enum RecipeListSort: String, Codable, CaseIterable, ExpressibleByArgument, Sendable {
    case name
    case rating
    case timesCooked = "times-cooked"
    case totalTime = "total-time"
    case fewestIngredients = "fewest-ingredients"

    public var requiresDerivedFeatures: Bool {
        switch self {
        case .name, .rating, .timesCooked:
            return false
        case .totalTime, .fewestIngredients:
            return true
        }
    }

    public var requiresUsageStats: Bool {
        switch self {
        case .timesCooked:
            return true
        case .name, .rating, .totalTime, .fewestIngredients:
            return false
        }
    }
}

public enum RecipeSearchSort: String, Codable, CaseIterable, ExpressibleByArgument, Sendable {
    case relevance
    case name
    case rating
    case timesCooked = "times-cooked"
    case totalTime = "total-time"
    case fewestIngredients = "fewest-ingredients"

    public var requiresDerivedFeatures: Bool {
        switch self {
        case .relevance, .name, .rating, .timesCooked:
            return false
        case .totalTime, .fewestIngredients:
            return true
        }
    }

    public var requiresUsageStats: Bool {
        switch self {
        case .timesCooked:
            return true
        case .relevance, .name, .rating, .totalTime, .fewestIngredients:
            return false
        }
    }
}
