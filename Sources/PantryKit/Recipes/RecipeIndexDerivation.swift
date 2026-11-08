import Foundation

/// Pure recipe interpretation; no source or sidecar access.
enum RecipeIndexDerivation {
    static func makeRoutineRecipeIndexRows(
        from recipe: SourceRecipe,
        categoryNamesByUID: [String: String],
        derivedAt: Date
    ) -> RoutineRecipeIndexRows {
        RoutineRecipeIndexRows(
            document: RecipeSearchDocument(
                uid: recipe.uid,
                name: recipe.name,
                categories: resolvedCategories(
                    recipe.categoryReferences,
                    categoryNamesByUID: categoryNamesByUID
                ),
                sourceName: recipe.sourceName,
                ingredients: recipe.ingredients,
                description: recipe.description,
                notes: recipe.notes,
                sourceFingerprint: recipe.sourceFingerprint,
                isFavorite: recipe.isFavorite,
                starRating: recipe.starRating
            ),
            features: Self.deriveFeatures(
                from: recipe,
                derivedAt: derivedAt
            ),
            ingredientIndex: IngredientNormalizer.normalizeIngredientLines(
                recipeUID: recipe.uid,
                sourceFingerprint: recipe.sourceFingerprint,
                ingredients: recipe.ingredients,
                derivedAt: derivedAt
            )
        )
    }

    private static func resolvedCategories(
        _ references: [String],
        categoryNamesByUID: [String: String]
    ) -> [String] {
        references.map { categoryNamesByUID[$0] ?? $0 }
    }

    static func sortSearchDocuments(lhs: RecipeSearchDocument, rhs: RecipeSearchDocument) -> Bool {
        if lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedSame {
            return lhs.uid < rhs.uid
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func deriveFeatures(from recipe: SourceRecipe, derivedAt: Date) -> RecipeDerivedFeatures {
        let prepTimeMinutes = parsedDurationMinutes(recipe.prepTime)
        let cookTimeMinutes = parsedDurationMinutes(recipe.cookTime)
        let sourceTotalTimeMinutes = parsedDurationMinutes(recipe.totalTime)

        let totalTimeMinutes: Int?
        let totalTimeBasis: RecipeTotalTimeBasis?
        if let sourceTotalTimeMinutes {
            totalTimeMinutes = sourceTotalTimeMinutes
            totalTimeBasis = .sourceTotalTime
        } else if let prepTimeMinutes, let cookTimeMinutes {
            totalTimeMinutes = prepTimeMinutes + cookTimeMinutes
            totalTimeBasis = .summedPrepAndCook
        } else {
            totalTimeMinutes = nil
            totalTimeBasis = nil
        }

        let ingredientLineCount = countedIngredientLines(recipe.ingredients)

        return RecipeDerivedFeatures(
            uid: recipe.uid,
            sourceFingerprint: recipe.sourceFingerprint,
            derivedAt: derivedAt,
            prepTimeMinutes: prepTimeMinutes,
            cookTimeMinutes: cookTimeMinutes,
            totalTimeMinutes: totalTimeMinutes,
            totalTimeBasis: totalTimeBasis,
            ingredientLineCount: ingredientLineCount,
            ingredientLineCountBasis: ingredientLineCount == nil ? nil : .nonEmptyLines
        )
    }

    static func deriveUsageStats(
        from meals: [SourceMeal],
        activeRecipeUIDs: Set<String>,
        derivedAt: Date,
        referenceDate: Date
    ) -> RecipeUsageDerivation {
        let qualifyingMeals = meals.enumerated().compactMap { offset, meal -> QualifiedMealOccurrence? in
            guard !meal.isDeleted else {
                return nil
            }

            guard
                let scheduledAt = meal.scheduledAt?.trimmingCharacters(in: .whitespacesAndNewlines),
                !scheduledAt.isEmpty,
                let scheduledDate = MealHistoryDateSupport.parsedDate(from: scheduledAt),
                scheduledDate <= referenceDate
            else {
                return nil
            }

            return QualifiedMealOccurrence(
                inputOrder: offset,
                scheduledAt: scheduledAt,
                scheduledDate: scheduledDate,
                recipeUID: (meal.isIngredient == true ? nil : meal.recipeUID)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .nilIfEmpty
            )
        }

        let totalMealCount = qualifyingMeals.count
        var linkedMealCount = 0
        var mealsByRecipeUID = [String: [QualifiedMealOccurrence]]()

        for meal in qualifyingMeals {
            guard let recipeUID = meal.recipeUID, activeRecipeUIDs.contains(recipeUID) else {
                continue
            }

            linkedMealCount += 1
            mealsByRecipeUID[recipeUID, default: []].append(meal)
        }

        let stats = mealsByRecipeUID.map { recipeUID, recipeMeals in
            let sortedMeals = recipeMeals.sorted { lhs, rhs in
                if lhs.scheduledDate != rhs.scheduledDate {
                    return lhs.scheduledDate < rhs.scheduledDate
                }

                return lhs.inputOrder < rhs.inputOrder
            }

            let mealGapDays: [Int]? = sortedMeals.count < 2
                ? nil
                : zip(sortedMeals, sortedMeals.dropFirst()).map { earlier, later in
                    MealHistoryDateSupport.dayDistance(
                        from: earlier.scheduledDate,
                        to: later.scheduledDate
                    )
                }
            let firstMeal = sortedMeals.first
            let lastMeal = sortedMeals.last
            let daysSpannedByMeals = sortedMeals.count < 2
                ? nil
                : firstMeal.flatMap { firstMeal in
                    lastMeal.map { lastMeal in
                        MealHistoryDateSupport.dayDistance(
                            from: firstMeal.scheduledDate,
                            to: lastMeal.scheduledDate
                        )
                    }
                }

            return RecipeUsageStats(
                uid: recipeUID,
                derivedAt: derivedAt,
                mealCount: sortedMeals.count,
                firstMealAt: firstMeal?.scheduledAt,
                firstCookedAt: firstMeal?.scheduledAt,
                lastMealAt: lastMeal?.scheduledAt,
                mealGapDays: mealGapDays,
                daysSpannedByMeals: daysSpannedByMeals,
                medianMealGapDays: median(of: mealGapDays),
                mealShare: totalMealCount == 0 ? nil : Double(sortedMeals.count) / Double(totalMealCount)
            )
        }

        return RecipeUsageDerivation(
            stats: stats,
            linkedMealCount: linkedMealCount,
            totalMealCount: totalMealCount
        )
    }

    static func deriveIngredientPairEvidence(
        ingredientIndexes: [RecipeIngredientIndex],
        documents: [RecipeSearchDocument],
        usageStats: [RecipeUsageStats],
        derivedAt: Date
    ) -> IngredientPairDerivation {
        let documentsByUID = Dictionary(uniqueKeysWithValues: documents.map { ($0.uid, $0) })
        let usageStatsByUID = Dictionary(uniqueKeysWithValues: usageStats.map { ($0.uid, $0) })
        var evidenceRows = [IngredientPairRecipeEvidenceRow]()
        var aggregates = [IngredientPairKey: IngredientPairAggregate]()

        for ingredientIndex in ingredientIndexes {
            guard let document = documentsByUID[ingredientIndex.uid] else {
                continue
            }

            let lineNumbersByToken = ingredientIndex.lines.reduce(into: [String: Set<Int>]()) { partialResult, line in
                for token in line.normalizedTokens {
                    partialResult[token, default: []].insert(line.lineNumber)
                }
            }
            let tokens = lineNumbersByToken.keys.sorted()
            guard tokens.count > 1 else {
                continue
            }

            let usage = usageStatsByUID[ingredientIndex.uid]
            for firstIndex in tokens.indices.dropLast() {
                for secondIndex in tokens.index(after: firstIndex) ..< tokens.endIndex {
                    let tokenA = tokens[firstIndex]
                    let tokenB = tokens[secondIndex]
                    guard tokenA != tokenB else {
                        continue
                    }

                    let key = IngredientPairKey(tokenA: tokenA, tokenB: tokenB)
                    let evidence = IngredientPairRecipeEvidenceRow(
                        basis: PantrySidecarStore.ingredientPairEvidenceBasis,
                        tokenA: tokenA,
                        tokenB: tokenB,
                        recipeUID: ingredientIndex.uid,
                        recipeName: document.name,
                        sourceName: document.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                        tokenALineNumbers: (lineNumbersByToken[tokenA] ?? []).sorted(),
                        tokenBLineNumbers: (lineNumbersByToken[tokenB] ?? []).sorted(),
                        isFavorite: document.isFavorite,
                        starRating: document.starRating,
                        mealCount: usage?.mealCount ?? 0,
                        firstMealAt: usage?.firstMealAt,
                        lastMealAt: usage?.lastMealAt,
                        derivedAt: derivedAt
                    )
                    evidenceRows.append(evidence)
                    aggregates[key, default: IngredientPairAggregate(tokenA: tokenA, tokenB: tokenB)]
                        .add(evidence)
                }
            }
        }

        let summaries = aggregates.values.map { aggregate in
            aggregate.summary(basis: PantrySidecarStore.ingredientPairEvidenceBasis)
        }

        return IngredientPairDerivation(summaries: summaries, recipeEvidence: evidenceRows)
    }

    private static func median(of values: [Int]?) -> Double? {
        guard let values, !values.isEmpty else {
            return nil
        }

        let sortedValues = values.sorted()
        let middleIndex = sortedValues.count / 2
        if sortedValues.count.isMultiple(of: 2) {
            return Double(sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2.0
        }

        return Double(sortedValues[middleIndex])
    }

    private static func countedIngredientLines(_ ingredients: String?) -> Int? {
        guard let ingredients else {
            return nil
        }

        let count = ingredients
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count

        return count == 0 ? nil : count
    }

    private static func parsedDurationMinutes(_ rawValue: String?) -> Int? {
        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()

        if let colonMinutes = parsedColonDurationMinutes(normalized) {
            return colonMinutes
        }

        let pattern = #"(\d+)\s*(hours?|hour|hrs?|hr|h|minutes?|minute|mins?|min|m)\b"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: []) else {
            return Int(normalized)
        }

        let fullRange = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        let matches = expression.matches(in: normalized, options: [], range: fullRange)
        if !matches.isEmpty {
            var totalMinutes = 0

            for match in matches {
                guard
                    let valueRange = Range(match.range(at: 1), in: normalized),
                    let unitRange = Range(match.range(at: 2), in: normalized),
                    let value = Int(normalized[valueRange])
                else {
                    continue
                }

                let unit = String(normalized[unitRange])
                if unit.hasPrefix("h") {
                    totalMinutes += value * 60
                } else {
                    totalMinutes += value
                }
            }

            return totalMinutes == 0 ? nil : totalMinutes
        }

        return Int(normalized)
    }

    private static func parsedColonDurationMinutes(_ normalized: String) -> Int? {
        let parts = normalized.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else {
            return nil
        }

        guard minutes >= 0 && minutes < 60 else {
            return nil
        }

        return (hours * 60) + minutes
    }
}

struct RecipeSearchDocument: Equatable, Sendable {
    let uid: String
    let name: String
    let categories: [String]
    let sourceName: String?
    let ingredients: String?
    let description: String?
    let notes: String?
    let sourceFingerprint: String?
    let isFavorite: Bool
    let starRating: Int?
}

struct RoutineRecipeIndexRows: Sendable {
    let document: RecipeSearchDocument
    let features: RecipeDerivedFeatures
    let ingredientIndex: RecipeIngredientIndex?
}

private struct IngredientPairKey: Hashable, Sendable {
    let tokenA: String
    let tokenB: String
}

struct IngredientPairDerivation: Sendable {
    let summaries: [IngredientPairEvidenceSummary]
    let recipeEvidence: [IngredientPairRecipeEvidenceRow]
}

struct IngredientPairRecipeEvidenceRow: Equatable, Sendable {
    let basis: String
    let tokenA: String
    let tokenB: String
    let recipeUID: String
    let recipeName: String
    let sourceName: String?
    let tokenALineNumbers: [Int]
    let tokenBLineNumbers: [Int]
    let isFavorite: Bool
    let starRating: Int?
    let mealCount: Int
    let firstMealAt: String?
    let lastMealAt: String?
    let derivedAt: Date
}

private struct IngredientPairAggregate: Sendable {
    let tokenA: String
    let tokenB: String
    var recipeCount = 0
    var cookedRecipeCount = 0
    var cookedMealCount = 0
    var favoriteRecipeCount = 0
    var ratedRecipeCount = 0
    var starRatingTotal = 0
    var firstMealAt: String?
    var lastMealAt: String?

    mutating func add(_ evidence: IngredientPairRecipeEvidenceRow) {
        recipeCount += 1

        if evidence.mealCount > 0 {
            cookedRecipeCount += 1
            cookedMealCount += evidence.mealCount
        }

        if evidence.isFavorite {
            favoriteRecipeCount += 1
        }

        if let starRating = evidence.starRating {
            ratedRecipeCount += 1
            starRatingTotal += starRating
        }

        if let evidenceFirstMealAt = evidence.firstMealAt {
            if firstMealAt == nil || evidenceFirstMealAt < firstMealAt! {
                firstMealAt = evidenceFirstMealAt
            }
        }

        if let evidenceLastMealAt = evidence.lastMealAt {
            if lastMealAt == nil || evidenceLastMealAt > lastMealAt! {
                lastMealAt = evidenceLastMealAt
            }
        }
    }

    func summary(basis: String) -> IngredientPairEvidenceSummary {
        IngredientPairEvidenceSummary(
            basis: basis,
            tokenA: tokenA,
            tokenB: tokenB,
            recipeCount: recipeCount,
            cookedRecipeCount: cookedRecipeCount,
            cookedMealCount: cookedMealCount,
            favoriteRecipeCount: favoriteRecipeCount,
            ratedRecipeCount: ratedRecipeCount,
            averageStarRating: ratedRecipeCount == 0 ? nil : Double(starRatingTotal) / Double(ratedRecipeCount),
            firstMealAt: firstMealAt,
            lastMealAt: lastMealAt
        )
    }
}

struct RecipeUsageDerivation: Equatable, Sendable {
    let stats: [RecipeUsageStats]
    let linkedMealCount: Int
    let totalMealCount: Int
}

private struct QualifiedMealOccurrence: Equatable, Sendable {
    let inputOrder: Int
    let scheduledAt: String
    let scheduledDate: Date
    let recipeUID: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

