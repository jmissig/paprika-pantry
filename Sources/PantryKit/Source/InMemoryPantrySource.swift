import Foundation

public enum InMemoryPantrySourceError: Error, LocalizedError, Equatable, Sendable {
    case missingFixture(String)

    public var errorDescription: String? {
        switch self {
        case .missingFixture(let uid):
            return "Missing recipe fixture for \(uid)."
        }
    }
}

public final class InMemoryPantrySource: MealsReadablePantrySource, GroceriesReadablePantrySource, PantryItemsReadablePantrySource, @unchecked Sendable {
    private let stubs: [SourceRecipeStub]
    private let categories: [SourceRecipeCategory]
    private let recipesByUID: [String: SourceRecipe]
    private let meals: [SourceMeal]
    private let groceryItems: [SourceGroceryItem]
    private let pantryItems: [SourcePantryItem]
    private let fetchErrorsByUID: [String: any Error]

    private let lock = NSLock()
    public private(set) var fetchedRecipeUIDs = [String]()

    public init(
        stubs: [SourceRecipeStub],
        categories: [SourceRecipeCategory],
        recipesByUID: [String: SourceRecipe],
        meals: [SourceMeal] = [],
        groceryItems: [SourceGroceryItem] = [],
        pantryItems: [SourcePantryItem] = [],
        fetchErrorsByUID: [String: any Error] = [:]
    ) {
        self.stubs = stubs
        self.categories = categories
        self.recipesByUID = recipesByUID
        self.meals = meals
        self.groceryItems = groceryItems
        self.pantryItems = pantryItems
        self.fetchErrorsByUID = fetchErrorsByUID
    }

    public func listRecipeStubs() async throws -> [SourceRecipeStub] {
        stubs
    }

    public func listRecipeCategories() async throws -> [SourceRecipeCategory] {
        categories
    }

    public func fetchRecipe(uid: String) async throws -> SourceRecipe {
        lock.withLock {
            fetchedRecipeUIDs.append(uid)
        }

        if let error = fetchErrorsByUID[uid] {
            throw error
        }

        guard let recipe = recipesByUID[uid] else {
            throw InMemoryPantrySourceError.missingFixture(uid)
        }

        return recipe
    }

    public func listMeals() async throws -> [SourceMeal] {
        meals
    }

    public func listGroceryItems() async throws -> [SourceGroceryItem] {
        groceryItems
    }

    public func listPantryItems() async throws -> [SourcePantryItem] {
        pantryItems
    }
}
