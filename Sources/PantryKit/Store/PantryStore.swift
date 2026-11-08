import Foundation
import GRDB

public struct PantrySidecarStore: Sendable {
    public let dbQueue: DatabaseQueue

    enum Role: Sendable {
        case reader(IndexSourceContract)
        case writer
        case inspector(IndexSourceContract?)
        case fixture
    }
    let role: Role
    var expectedContract: IndexSourceContract? {
        switch role {
        case .reader(let contract): return contract
        case .inspector(let contract): return contract
        case .writer, .fixture: return nil
        }
    }
    public init(dbQueue: DatabaseQueue, expectedContract: IndexSourceContract) {
        self.dbQueue = dbQueue
        self.role = .reader(expectedContract)
    }
    init(fixtureQueue: DatabaseQueue) {
        self.dbQueue = fixtureQueue
        self.role = .fixture
    }
    init(dbQueue: DatabaseQueue, role: Role) {
        self.dbQueue = dbQueue
        self.role = role
    }

    static let recipeSearchIndexName = "recipe-search"
    static let recipeFeatureIndexName = "recipe-features"
    static let recipeIngredientIndexName = "recipe-ingredients"
    static let recipeUsageIndexName = "recipe-usage"
    static let ingredientPairIndexName = "ingredient-pairs"
    public static let ingredientPairEvidenceBasis = "recipe-token-cooccurrence-v1"
    static let recipeUsageSummaryKey = "current"

    static func sqlPlaceholders(count: Int) -> String {
        Array(repeating: "?", count: max(1, count)).joined(separator: ", ")
    }
}

public typealias PantryStore = PantrySidecarStore
