import Foundation

public struct RecipeIngredientFilter: Codable, Equatable, Sendable {
    public let rawTerms: [String]
    public let normalizedTokens: [String]

    public init(rawTerms: [String] = [], normalizedTokens: [String]? = nil) {
        let sanitizedTerms = Self.sanitizedTerms(rawTerms)
        self.rawTerms = sanitizedTerms
        self.normalizedTokens = normalizedTokens ?? IngredientNormalizer.normalizedQueryTokens(from: sanitizedTerms)
    }

    public var isDefault: Bool {
        normalizedTokens.isEmpty
    }

    private static func sanitizedTerms(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continue
            }

            let normalized = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(normalized).inserted else {
                continue
            }

            result.append(trimmed)
        }

        return result
    }
}

public struct RecipeIngredientLine: Codable, Equatable, Sendable {
    public let lineNumber: Int
    public let sourceText: String
    public let normalizedText: String?
    public let normalizedTokens: [String]

    public init(
        lineNumber: Int,
        sourceText: String,
        normalizedText: String?,
        normalizedTokens: [String]
    ) {
        self.lineNumber = lineNumber
        self.sourceText = sourceText
        self.normalizedText = normalizedText
        self.normalizedTokens = normalizedTokens
    }
}

public struct RecipeIngredientIndex: Codable, Equatable, Sendable {
    public let uid: String
    public let sourceRemoteHash: String?
    public let derivedAt: Date
    public let lines: [RecipeIngredientLine]

    public init(
        uid: String,
        sourceRemoteHash: String?,
        derivedAt: Date,
        lines: [RecipeIngredientLine]
    ) {
        self.uid = uid
        self.sourceRemoteHash = sourceRemoteHash
        self.derivedAt = derivedAt
        self.lines = lines
    }

    public var normalizedTokenCount: Int {
        lines.reduce(into: 0) { partialResult, line in
            partialResult += line.normalizedTokens.count
        }
    }

    public func sourceHashMatches(_ currentSourceHash: String?) -> Bool? {
        guard let currentSourceHash, let sourceRemoteHash else {
            return nil
        }

        return currentSourceHash == sourceRemoteHash
    }
}

enum IngredientNormalizer {
    private static let fractionCharacters = CharacterSet(charactersIn: "¼½¾⅐⅑⅒⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞")
    private static let tokenExpression = try? NSRegularExpression(pattern: #"[a-z]+(?:'[a-z]+)?"#, options: [])
    private static let stopwords: Set<String> = [
        "a", "an", "and", "for", "from", "into", "of", "or", "plus", "the", "to", "with",
        "about", "approximately", "optional", "taste",
        "cup", "cups", "teaspoon", "teaspoons", "tsp", "tablespoon", "tablespoons", "tbsp",
        "ounce", "ounces", "oz", "pound", "pounds", "lb", "lbs", "gram", "grams", "g",
        "kilogram", "kilograms", "kg", "milligram", "milligrams", "mg",
        "milliliter", "milliliters", "ml", "liter", "liters", "l",
        "pint", "pints", "quart", "quarts", "gallon", "gallons",
        "can", "cans", "package", "packages", "packet", "packets", "pkg",
        "jar", "jars", "bottle", "bottles", "box", "boxes", "bag", "bags",
        "container", "containers", "bunch", "bunches", "sprig", "sprigs",
        "large", "small", "medium",
        "chopped", "diced", "minced", "sliced", "thinly", "finely", "roughly", "coarsely",
        "ground", "crushed", "grated", "shredded", "peeled", "seeded", "halved", "cubed",
        "softened", "melted", "drained", "rinsed", "divided", "beaten", "packed",
        "freshly"
    ]
    private static let irregularSingulars: [String: String] = [
        "tomatoes": "tomato",
        "potatoes": "potato"
    ]

    static func normalizedQueryTokens(from rawTerms: [String]) -> [String] {
        deduplicated(rawTerms.flatMap(normalizedTokens(from:)))
    }

    static func normalizeIngredientLines(
        recipeUID: String,
        sourceRemoteHash: String?,
        ingredients: String?,
        derivedAt: Date
    ) -> RecipeIngredientIndex? {
        guard let ingredients else {
            return nil
        }

        let lines = ingredients
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { offset, line in
                let tokens = normalizedTokens(from: line)
                return RecipeIngredientLine(
                    lineNumber: offset + 1,
                    sourceText: line,
                    normalizedText: tokens.isEmpty ? nil : tokens.joined(separator: " "),
                    normalizedTokens: tokens
                )
            }

        guard !lines.isEmpty else {
            return nil
        }

        return RecipeIngredientIndex(
            uid: recipeUID,
            sourceRemoteHash: sourceRemoteHash,
            derivedAt: derivedAt,
            lines: lines
        )
    }

    private static func normalizedTokens(from rawValue: String) -> [String] {
        let folded = rawValue
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let replacedFractions = folded.unicodeScalars.map { scalar -> String in
            fractionCharacters.contains(scalar) ? " " : String(scalar)
        }
        .joined()

        let stripped = replacedFractions.replacingOccurrences(
            of: #"[0-9]+"#,
            with: " ",
            options: .regularExpression
        )
        let tokenCandidates = extractedTokens(from: stripped)

        return deduplicated(
            tokenCandidates.compactMap { token in
                let singularized = singularizedToken(token)
                guard !stopwords.contains(singularized) else {
                    return nil
                }
                return singularized.count > 1 ? singularized : nil
            }
        )
    }

    private static func extractedTokens(from value: String) -> [String] {
        guard let tokenExpression else {
            return value
                .split(whereSeparator: { !$0.isLetter && $0 != "'" })
                .map(String.init)
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return tokenExpression.matches(in: value, options: [], range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: value) else {
                return nil
            }

            return String(value[tokenRange])
        }
    }

    private static func singularizedToken(_ token: String) -> String {
        if let irregular = irregularSingulars[token] {
            return irregular
        }

        guard token.count > 3 else {
            return token
        }

        if token.hasSuffix("ies"), token.count > 4 {
            return String(token.dropLast(3)) + "y"
        }

        if token.hasSuffix("oes"), token.count > 4 {
            return String(token.dropLast(2))
        }

        if token.hasSuffix("ches") || token.hasSuffix("shes") || token.hasSuffix("xes") || token.hasSuffix("zes") {
            return String(token.dropLast(2))
        }

        if token.hasSuffix("s"),
           token.count > 4,
           !token.hasSuffix("ss"),
           !token.hasSuffix("us"),
           !token.hasSuffix("is"),
           !token.hasSuffix("ous"),
           !token.hasSuffix("ves"),
           !token.hasSuffix("sses") {
            return String(token.dropLast())
        }

        return token
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result = [String]()

        for value in values {
            guard seen.insert(value).inserted else {
                continue
            }

            result.append(value)
        }

        return result
    }
}
