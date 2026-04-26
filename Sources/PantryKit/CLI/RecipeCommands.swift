import ArgumentParser
import Foundation

public struct RecipesCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "recipes",
        abstract: "Query canonical recipes and sidecar-backed recipe search/features/ingredient tokens.",
        subcommands: [
            RecipesListCommand.self,
            RecipesShowCommand.self,
            RecipesSearchCommand.self,
            RecipesFeaturesCommand.self,
            RecipesIngredientsCommand.self,
            RecipesPairingsCommand.self,
        ]
    )

    public init() {}
}

public struct RecipesListCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List recipes from the configured pantry source with canonical filters plus optional sidecar ingredient include/exclude filters and derived time constraints."
    )

    @Flag(name: .long, help: "Only include recipes marked favorite in Paprika.")
    public var favorite: Bool = false

    @Option(name: .long, help: "Require this canonical Paprika category/tag name. Repeat to require multiple categories.")
    public var category: [String] = []

    @Option(name: .long, help: "Only include recipes rated at least this many stars (1-5).")
    public var minRating: Int?

    @Option(name: .long, help: "Only include recipes rated at most this many stars (1-5).")
    public var maxRating: Int?

    @Option(name: .long, help: "Require this ingredient term from the sidecar ingredient index. Repeat to combine multiple included terms.")
    public var ingredient: [String] = []

    @Option(name: .long, help: "Exclude recipes matching this ingredient term from the sidecar ingredient index. Repeat to exclude multiple terms.")
    public var excludeIngredient: [String] = []

    @Option(name: .long, help: "How repeated --ingredient terms combine: \(RecipeIngredientMatchMode.allCases.map(\.rawValue).joined(separator: ", ")). Default: all.")
    public var ingredientMatch: RecipeIngredientMatchMode = .all

    @Option(name: .long, help: "Only include recipes whose derived total time is at least this many minutes.")
    public var minTotalTimeMinutes: Int?

    @Option(name: .long, help: "Only include recipes whose derived total time is at most this many minutes.")
    public var maxTotalTimeMinutes: Int?

    @Option(name: .long, help: "Only include recipes whose derived non-empty ingredient line count is at least this many lines.")
    public var minIngredientLines: Int?

    @Option(name: .long, help: "Only include recipes whose derived non-empty ingredient line count is at most this many lines.")
    public var maxIngredientLines: Int?

    @Option(name: .long, help: "Sort order for returned recipes: \(RecipeListSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: RecipeListSort = .name

    public init() {}

    public mutating func validate() throws {
        try validateRecipeQueryOptions(minRating: minRating, maxRating: maxRating, categories: category)
        try validateRecipeIngredientOptions(includedIngredients: ingredient, excludedIngredients: excludeIngredient)
        try validateRecipeDerivedQueryOptions(
            minTotalTimeMinutes: minTotalTimeMinutes,
            maxTotalTimeMinutes: maxTotalTimeMinutes,
            minIngredientLines: minIngredientLines,
            maxIngredientLines: maxIngredientLines
        )
    }

    public mutating func run() throws {
        let context = try makeContext()
        let recipeReadService = try context.makeRecipeReadService()
        let sort = self.sort
        let canonicalFilters = RecipeQueryFilters(
            favoritesOnly: favorite,
            minRating: minRating,
            maxRating: maxRating,
            categoryNames: category
        )
        let ingredientFilter = RecipeIngredientFilter(
            rawTerms: ingredient,
            excludeRawTerms: excludeIngredient,
            includeMode: ingredientMatch
        )
        let derivedConstraints = RecipeDerivedConstraints(
            minTotalTimeMinutes: minTotalTimeMinutes,
            maxTotalTimeMinutes: maxTotalTimeMinutes,
            minIngredientLineCount: minIngredientLines,
            maxIngredientLineCount: maxIngredientLines
        )
        let requiresDerivedFeatures = sort.requiresDerivedFeatures || !derivedConstraints.isDefault
        let store = try context.makeSidecarStore()
        let indexStats = try store.indexStats()
        let now = Date()
        let matchingRecipeUIDs: Set<String>?
        let derivedFeaturesByUID: [String: RecipeDerivedFeatures]
        let usageStatsByUID: [String: RecipeUsageStats]
        let derivedReadPath: String?

        if requiresDerivedFeatures {
            guard indexStats.recipeFeaturesReady else {
                throw ValidationError("Recipe feature index is required for derived constraints or sort. Run `paprika-pantry index rebuild` first.")
            }

            derivedFeaturesByUID = try store.fetchAllRecipeFeatures()
            derivedReadPath = "sidecar-derived"
        } else {
            derivedFeaturesByUID = [:]
            derivedReadPath = nil
        }

        if sort.requiresUsageStats && !indexStats.recipeUsageStatsReady {
            throw ValidationError("Recipe usage index is required for usage sort. Run `paprika-pantry index rebuild` first.")
        }

        if indexStats.recipeUsageStatsReady {
            usageStatsByUID = try store.fetchAllRecipeUsageStats()
        } else {
            usageStatsByUID = [:]
        }

        if ingredientFilter.isDefault {
            matchingRecipeUIDs = nil
        } else {
            guard indexStats.recipeIngredientIndexReady else {
                throw ValidationError("Recipe ingredient index is required for ingredient filters. Run `paprika-pantry index rebuild` first.")
            }

            matchingRecipeUIDs = try store.matchingRecipeUIDs(for: ingredientFilter)
        }

        let recipes = try BlockingAsync.run {
            try await recipeReadService.listRecipes(
                filters: canonicalFilters,
                derivedConstraints: derivedConstraints,
                sort: sort,
                derivedFeaturesByUID: derivedFeaturesByUID,
                usageStatsByUID: usageStatsByUID
            )
        }
        let filteredRecipes = matchingRecipeUIDs.map { requiredUIDs in
            recipes.filter { requiredUIDs.contains($0.uid) }
        } ?? recipes
        try context.write(
            RecipesListReport(
                recipes: filteredRecipes,
                canonicalFilters: canonicalFilters,
                ingredientFilter: ingredientFilter,
                derivedConstraints: derivedConstraints,
                sort: sort,
                derivedReadPath: derivedReadPath,
                ingredientReadPath: ingredientFilter.isDefault ? nil : "sidecar-ingredient-index",
                usageReadPath: indexStats.recipeUsageStatsReady ? "sidecar-derived" : nil,
                derivedLastSuccessAt: indexStats.lastSuccessfulRecipeFeatureRun.map { $0.finishedAt ?? $0.startedAt },
                derivedFreshnessSeconds: requiresDerivedFeatures ? renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeFeatureRun, now: now) : nil,
                ingredientLastSuccessAt: indexStats.lastSuccessfulRecipeIngredientRun.map { $0.finishedAt ?? $0.startedAt },
                ingredientFreshnessSeconds: ingredientFilter.isDefault ? nil : renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeIngredientRun, now: now),
                usageLastSuccessAt: indexStats.lastSuccessfulRecipeUsageRun.map { $0.finishedAt ?? $0.startedAt },
                usageFreshnessSeconds: indexStats.recipeUsageStatsReady ? renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeUsageRun, now: now) : nil
            )
        )
    }
}

public struct RecipesShowCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show one source recipe by UID or name."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let recipeReadService = try context.makeRecipeReadService()
        let selector = self.selector
        let recipe = try BlockingAsync.run {
            try await recipeReadService.resolveRecipe(selector: selector)
        }
        let store = try context.makeSidecarStore()
        let derivedFeatures = try store.fetchRecipeFeatures(uid: recipe.uid)
        let usageStats = try store.fetchRecipeUsageStats(uid: recipe.uid)
        let indexStats = try store.indexStats()
        let now = Date()
        try context.write(
            RecipeShowReport(
                recipe: recipe,
                derivedFeatures: derivedFeatures,
                usageStats: usageStats,
                derivedLastSuccessAt: indexStats.lastSuccessfulRecipeFeatureRun.map { $0.finishedAt ?? $0.startedAt },
                derivedFreshnessSeconds: derivedFeatures == nil ? nil : renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeFeatureRun, now: now),
                usageLastSuccessAt: indexStats.lastSuccessfulRecipeUsageRun.map { $0.finishedAt ?? $0.startedAt },
                usageFreshnessSeconds: usageStats == nil ? nil : renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeUsageRun, now: now)
            )
        )
    }
}

public struct RecipesSearchCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search recipes through the owned sidecar index with canonical filters plus optional sidecar ingredient include/exclude filters and derived time constraints."
    )

    @Argument(help: "Search query.")
    public var query: String

    @Flag(name: .long, help: "Only include recipes marked favorite in Paprika.")
    public var favorite: Bool = false

    @Option(name: .long, help: "Require this canonical Paprika category/tag name. Repeat to require multiple categories.")
    public var category: [String] = []

    @Option(name: .long, help: "Only include recipes rated at least this many stars (1-5).")
    public var minRating: Int?

    @Option(name: .long, help: "Only include recipes rated at most this many stars (1-5).")
    public var maxRating: Int?

    @Option(name: .long, help: "Require this ingredient term from the sidecar ingredient index. Repeat to combine multiple included terms.")
    public var ingredient: [String] = []

    @Option(name: .long, help: "Exclude recipes matching this ingredient term from the sidecar ingredient index. Repeat to exclude multiple terms.")
    public var excludeIngredient: [String] = []

    @Option(name: .long, help: "How repeated --ingredient terms combine: \(RecipeIngredientMatchMode.allCases.map(\.rawValue).joined(separator: ", ")). Default: all.")
    public var ingredientMatch: RecipeIngredientMatchMode = .all

    @Option(name: .long, help: "Only include recipes whose derived total time is at least this many minutes.")
    public var minTotalTimeMinutes: Int?

    @Option(name: .long, help: "Only include recipes whose derived total time is at most this many minutes.")
    public var maxTotalTimeMinutes: Int?

    @Option(name: .long, help: "Only include recipes whose derived non-empty ingredient line count is at least this many lines.")
    public var minIngredientLines: Int?

    @Option(name: .long, help: "Only include recipes whose derived non-empty ingredient line count is at most this many lines.")
    public var maxIngredientLines: Int?

    @Option(name: .long, help: "Sort order for returned recipes: \(RecipeSearchSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: RecipeSearchSort = .relevance

    @Option(name: .long, help: "Maximum results to return.")
    public var limit: Int = 20

    public init() {}

    public mutating func validate() throws {
        try validateRecipeQueryOptions(minRating: minRating, maxRating: maxRating, categories: category)
        try validateRecipeIngredientOptions(includedIngredients: ingredient, excludedIngredients: excludeIngredient)
        try validateRecipeDerivedQueryOptions(
            minTotalTimeMinutes: minTotalTimeMinutes,
            maxTotalTimeMinutes: maxTotalTimeMinutes,
            minIngredientLines: minIngredientLines,
            maxIngredientLines: maxIngredientLines
        )
    }

    public mutating func run() throws {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            throw ValidationError("Search query must not be empty.")
        }

        guard limit > 0 else {
            throw ValidationError("--limit must be greater than zero.")
        }

        let context = try makeContext()
        let store = try context.makeSidecarStore()
        guard try store.indexStats().recipeSearchReady else {
            throw ValidationError("Recipe search index is not ready. Run `paprika-pantry index rebuild` first.")
        }

        let canonicalFilters = RecipeQueryFilters(
            favoritesOnly: favorite,
            minRating: minRating,
            maxRating: maxRating,
            categoryNames: category
        )
        let ingredientFilter = RecipeIngredientFilter(
            rawTerms: ingredient,
            excludeRawTerms: excludeIngredient,
            includeMode: ingredientMatch
        )
        let derivedConstraints = RecipeDerivedConstraints(
            minTotalTimeMinutes: minTotalTimeMinutes,
            maxTotalTimeMinutes: maxTotalTimeMinutes,
            minIngredientLineCount: minIngredientLines,
            maxIngredientLineCount: maxIngredientLines
        )
        let requiresDerivedFeatures = sort.requiresDerivedFeatures || !derivedConstraints.isDefault
        let indexStats = try store.indexStats()

        if requiresDerivedFeatures && !indexStats.recipeFeaturesReady {
            throw ValidationError("Recipe feature index is required for derived constraints or sort. Run `paprika-pantry index rebuild` first.")
        }

        if sort.requiresUsageStats && !indexStats.recipeUsageStatsReady {
            throw ValidationError("Recipe usage index is required for usage sort. Run `paprika-pantry index rebuild` first.")
        }

        if !ingredientFilter.isDefault && !indexStats.recipeIngredientIndexReady {
            throw ValidationError("Recipe ingredient index is required for ingredient filters. Run `paprika-pantry index rebuild` first.")
        }

        let results = try store.searchRecipes(
            query: query,
            filters: canonicalFilters,
            ingredientFilter: ingredientFilter,
            derivedConstraints: derivedConstraints,
            sort: sort,
            limit: limit
        )
        let now = Date()
        try context.write(
            RecipesSearchReport(
                query: query,
                canonicalFilters: canonicalFilters,
                ingredientFilter: ingredientFilter,
                derivedConstraints: derivedConstraints,
                sort: sort,
                results: results,
                paths: context.paths,
                derivedReadPath: requiresDerivedFeatures ? "sidecar-derived" : nil,
                ingredientReadPath: ingredientFilter.isDefault ? nil : "sidecar-ingredient-index",
                usageReadPath: indexStats.recipeUsageStatsReady ? "sidecar-derived" : nil,
                searchLastSuccessAt: indexStats.lastSuccessfulRecipeSearchRun.map { $0.finishedAt ?? $0.startedAt },
                searchFreshnessSeconds: renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeSearchRun, now: now),
                derivedLastSuccessAt: indexStats.lastSuccessfulRecipeFeatureRun.map { $0.finishedAt ?? $0.startedAt },
                derivedFreshnessSeconds: requiresDerivedFeatures ? renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeFeatureRun, now: now) : nil,
                ingredientLastSuccessAt: indexStats.lastSuccessfulRecipeIngredientRun.map { $0.finishedAt ?? $0.startedAt },
                ingredientFreshnessSeconds: ingredientFilter.isDefault ? nil : renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeIngredientRun, now: now),
                usageLastSuccessAt: indexStats.lastSuccessfulRecipeUsageRun.map { $0.finishedAt ?? $0.startedAt },
                usageFreshnessSeconds: indexStats.recipeUsageStatsReady ? renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeUsageRun, now: now) : nil
            )
        )
    }
}

public struct RecipesFeaturesCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "features",
        abstract: "Show sidecar-derived recipe time and ingredient-line features for one recipe."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeSidecarStore()
        guard try store.indexStats().recipeFeaturesReady else {
            throw ValidationError("Recipe feature index is not ready. Run `paprika-pantry index rebuild` first.")
        }

        let recipeReadService = try context.makeRecipeReadService()
        let selector = self.selector
        let recipe = try BlockingAsync.run {
            try await recipeReadService.resolveRecipe(selector: selector)
        }

        guard let features = try store.fetchRecipeFeatures(uid: recipe.uid) else {
            throw ValidationError("No derived feature row exists for recipe `\(recipe.uid)`. Run `paprika-pantry index rebuild` first.")
        }

        let indexStats = try store.indexStats()
        let now = Date()
        try context.write(
            RecipeFeaturesReport(
                recipe: recipe,
                features: features,
                paths: context.paths,
                derivedLastSuccessAt: indexStats.lastSuccessfulRecipeFeatureRun.map { $0.finishedAt ?? $0.startedAt },
                derivedFreshnessSeconds: renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeFeatureRun, now: now)
            )
        )
    }
}

public struct RecipesIngredientsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ingredients",
        abstract: "Show source ingredient lines beside sidecar-normalized ingredient tokens for one recipe."
    )

    @Argument(help: "Recipe UID or name.")
    public var selector: String

    public init() {}
    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeSidecarStore()
        guard try store.indexStats().recipeIngredientIndexReady else {
            throw ValidationError("Recipe ingredient index is not ready. Run `paprika-pantry index rebuild` first.")
        }

        let recipeReadService = try context.makeRecipeReadService()
        let selector = self.selector
        let recipe = try BlockingAsync.run {
            try await recipeReadService.resolveRecipe(selector: selector)
        }
        let ingredientIndex = try store.fetchRecipeIngredientIndex(uid: recipe.uid)
        let indexStats = try store.indexStats()
        let now = Date()
        try context.write(
            RecipeIngredientsReport(
                recipe: recipe,
                ingredientIndex: ingredientIndex,
                paths: context.paths,
                ingredientLastSuccessAt: indexStats.lastSuccessfulRecipeIngredientRun.map { $0.finishedAt ?? $0.startedAt },
                ingredientFreshnessSeconds: renderedFreshnessSeconds(since: indexStats.lastSuccessfulRecipeIngredientRun, now: now)
            )
        )
    }
}

public struct RecipesPairingsCommand: PantryLeafCommand {
    public static let configuration = CommandConfiguration(
        commandName: "pairings",
        abstract: "List sidecar-derived ingredient token co-occurrence evidence across recipes."
    )

    @Option(name: .long, help: "Only include pairs containing this normalized ingredient token after conservative normalization.")
    public var token: String?

    @Option(name: .customLong("with-token"), help: "Only include the pair between --token and this normalized ingredient token after conservative normalization.")
    public var withToken: String?

    @Option(name: .customLong("min-recipes"), help: "Only include token pairs that occur in at least this many recipes.")
    public var minRecipes: Int = 1

    @Option(name: .long, help: "Maximum token pairs to return.")
    public var limit: Int = 20

    @Option(name: .customLong("evidence-limit"), help: "Maximum recipe evidence rows to show for each token pair.")
    public var evidenceLimit: Int = 3

    @Option(name: .long, help: "Sort order for returned token pairs: \(IngredientPairEvidenceSort.allCases.map(\.rawValue).joined(separator: ", ")).")
    public var sort: IngredientPairEvidenceSort = .recipes

    public init() {}

    public mutating func validate() throws {
        if let token {
            try validateIngredientPairTokenOption(token, optionName: "--token")
        }

        if let withToken {
            try validateIngredientPairTokenOption(withToken, optionName: "--with-token")
        }

        if withToken != nil && token == nil {
            throw ValidationError("--with-token requires --token.")
        }

        if minRecipes < 1 {
            throw ValidationError("--min-recipes must be at least 1.")
        }

        if limit < 1 {
            throw ValidationError("--limit must be greater than zero.")
        }

        if evidenceLimit < 0 {
            throw ValidationError("--evidence-limit must be zero or greater.")
        }
    }

    public mutating func run() throws {
        let context = try makeContext()
        let store = try context.makeSidecarStore()
        let indexStats = try store.indexStats()
        guard indexStats.ingredientPairEvidenceReady else {
            throw ValidationError("Ingredient pair evidence index is not ready. No ingredient pairings have been built yet; run `paprika-pantry index rebuild` to build pairings.")
        }

        let results = try store.listIngredientPairEvidence(
            token: token,
            withToken: withToken,
            minRecipes: minRecipes,
            sort: sort,
            limit: limit,
            evidenceLimit: evidenceLimit
        )
        let now = Date()
        try context.write(
            RecipesPairingsReport(
                results: results,
                token: token,
                withToken: withToken,
                minRecipes: minRecipes,
                limit: limit,
                evidenceLimit: evidenceLimit,
                sort: sort,
                paths: context.paths,
                ingredientPairLastSuccessAt: indexStats.lastSuccessfulIngredientPairRun.map { $0.finishedAt ?? $0.startedAt },
                routineIndexLastSuccessAt: latestRoutineIndexSuccessDate(from: indexStats),
                ingredientPairFreshnessSeconds: renderedFreshnessSeconds(since: indexStats.lastSuccessfulIngredientPairRun, now: now)
            )
        )
    }
}

private func renderedFreshnessSeconds(since run: PantryIndexRun?, now: Date) -> Int? {
    guard let run else {
        return nil
    }

    return max(0, Int(now.timeIntervalSince(run.finishedAt ?? run.startedAt)))
}

private func latestRoutineIndexSuccessDate(from stats: PantryIndexStats) -> Date? {
    [
        stats.lastSuccessfulRecipeSearchRun,
        stats.lastSuccessfulRecipeFeatureRun,
        stats.lastSuccessfulRecipeIngredientRun,
        stats.lastSuccessfulRecipeUsageRun,
    ]
    .compactMap { $0?.finishedAt ?? $0?.startedAt }
    .max()
}

private func validateIngredientPairTokenOption(_ rawValue: String, optionName: String) throws {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw ValidationError("\(optionName) must not be empty.")
    }

    let tokens = IngredientNormalizer.normalizedQueryTokens(from: [trimmed])
    guard tokens.count == 1 else {
        throw ValidationError("\(optionName) must normalize to exactly one ingredient token.")
    }
}

private func validateRecipeQueryOptions(minRating: Int?, maxRating: Int?, categories: [String]) throws {
    if let minRating, !(1 ... 5).contains(minRating) {
        throw ValidationError("--min-rating must be between 1 and 5.")
    }

    if let maxRating, !(1 ... 5).contains(maxRating) {
        throw ValidationError("--max-rating must be between 1 and 5.")
    }

    if let minRating, let maxRating, minRating > maxRating {
        throw ValidationError("--min-rating must be less than or equal to --max-rating.")
    }

    if categories.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        throw ValidationError("--category must not be empty.")
    }
}

private func validateRecipeIngredientOptions(
    includedIngredients: [String],
    excludedIngredients: [String]
) throws {
    if includedIngredients.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        throw ValidationError("--ingredient must not be empty.")
    }

    if excludedIngredients.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
        throw ValidationError("--exclude-ingredient must not be empty.")
    }

    for term in includedIngredients {
        let filter = RecipeIngredientFilter(rawTerms: [term])
        if filter.queryableIncludeTerms.isEmpty {
            throw ValidationError("--ingredient must contain at least one queryable token after conservative normalization.")
        }
    }

    for term in excludedIngredients {
        let filter = RecipeIngredientFilter(excludeRawTerms: [term])
        if filter.queryableExcludeTerms.isEmpty {
            throw ValidationError("--exclude-ingredient must contain at least one queryable token after conservative normalization.")
        }
    }
}

private func validateRecipeDerivedQueryOptions(
    minTotalTimeMinutes: Int?,
    maxTotalTimeMinutes: Int?,
    minIngredientLines: Int?,
    maxIngredientLines: Int?
) throws {
    if let minTotalTimeMinutes, minTotalTimeMinutes < 1 {
        throw ValidationError("--min-total-time-minutes must be greater than zero.")
    }

    if let maxTotalTimeMinutes, maxTotalTimeMinutes < 1 {
        throw ValidationError("--max-total-time-minutes must be greater than zero.")
    }

    if let minTotalTimeMinutes, let maxTotalTimeMinutes, minTotalTimeMinutes > maxTotalTimeMinutes {
        throw ValidationError("--min-total-time-minutes must be less than or equal to --max-total-time-minutes.")
    }

    if let minIngredientLines, minIngredientLines < 1 {
        throw ValidationError("--min-ingredient-lines must be greater than zero.")
    }

    if let maxIngredientLines, maxIngredientLines < 1 {
        throw ValidationError("--max-ingredient-lines must be greater than zero.")
    }

    if let minIngredientLines, let maxIngredientLines, minIngredientLines > maxIngredientLines {
        throw ValidationError("--min-ingredient-lines must be less than or equal to --max-ingredient-lines.")
    }
}
