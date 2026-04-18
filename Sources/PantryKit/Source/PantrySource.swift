import Foundation

public struct SourceRecipeStub: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let sourceFingerprint: String?
    public let isDeleted: Bool

    public init(uid: String, name: String, sourceFingerprint: String?, isDeleted: Bool = false) {
        self.uid = uid
        self.name = name
        self.sourceFingerprint = sourceFingerprint
        self.isDeleted = isDeleted
    }
}

public struct SourceRecipeCategory: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let isDeleted: Bool

    public init(uid: String, name: String, isDeleted: Bool = false) {
        self.uid = uid
        self.name = name
        self.isDeleted = isDeleted
    }
}

public struct SourceRecipe: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let categoryReferences: [String]
    public let sourceName: String?
    public let ingredients: String?
    public let directions: String?
    public let notes: String?
    public let starRating: Int?
    public let isFavorite: Bool
    public let prepTime: String?
    public let cookTime: String?
    public let totalTime: String?
    public let servings: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let sourceFingerprint: String?
    public let rawJSON: String

    public init(
        uid: String,
        name: String,
        categoryReferences: [String],
        sourceName: String?,
        ingredients: String?,
        directions: String?,
        notes: String?,
        starRating: Int?,
        isFavorite: Bool,
        prepTime: String?,
        cookTime: String?,
        totalTime: String?,
        servings: String?,
        createdAt: String?,
        updatedAt: String?,
        sourceFingerprint: String?,
        rawJSON: String
    ) {
        self.uid = uid
        self.name = name
        self.categoryReferences = categoryReferences
        self.sourceName = sourceName
        self.ingredients = ingredients
        self.directions = directions
        self.notes = notes
        self.starRating = starRating
        self.isFavorite = isFavorite
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceFingerprint = sourceFingerprint
        self.rawJSON = rawJSON
    }
}

public struct SourceMeal: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let scheduledAt: String?
    public let mealType: String?
    public let recipeUID: String?
    public let recipeName: String?
    public let isDeleted: Bool

    public init(
        uid: String,
        name: String,
        scheduledAt: String?,
        mealType: String?,
        recipeUID: String?,
        recipeName: String?,
        isDeleted: Bool = false
    ) {
        self.uid = uid
        self.name = name
        self.scheduledAt = scheduledAt
        self.mealType = mealType
        self.recipeUID = recipeUID
        self.recipeName = recipeName
        self.isDeleted = isDeleted
    }
}

public struct SourceGroceryItem: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let quantity: String?
    public let instruction: String?
    public let groceryListName: String?
    public let aisleName: String?
    public let ingredientName: String?
    public let recipeName: String?
    public let isPurchased: Bool
    public let isDeleted: Bool

    public init(
        uid: String,
        name: String,
        quantity: String?,
        instruction: String?,
        groceryListName: String?,
        aisleName: String?,
        ingredientName: String?,
        recipeName: String?,
        isPurchased: Bool,
        isDeleted: Bool = false
    ) {
        self.uid = uid
        self.name = name
        self.quantity = quantity
        self.instruction = instruction
        self.groceryListName = groceryListName
        self.aisleName = aisleName
        self.ingredientName = ingredientName
        self.recipeName = recipeName
        self.isPurchased = isPurchased
        self.isDeleted = isDeleted
    }
}

public struct SourcePantryItem: Codable, Equatable, Sendable {
    public let uid: String
    public let name: String
    public let quantity: String?
    public let aisleName: String?
    public let ingredientName: String?
    public let purchaseDate: String?
    public let expirationDate: String?
    public let hasExpiration: Bool
    public let isInStock: Bool
    public let isDeleted: Bool

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
        isDeleted: Bool = false
    ) {
        self.uid = uid
        self.name = name
        self.quantity = quantity
        self.aisleName = aisleName
        self.ingredientName = ingredientName
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.hasExpiration = hasExpiration
        self.isInStock = isInStock
        self.isDeleted = isDeleted
    }
}

public protocol PantrySource: Sendable {
    func listRecipeStubs() async throws -> [SourceRecipeStub]
    func listRecipeCategories() async throws -> [SourceRecipeCategory]
    func fetchRecipe(uid: String) async throws -> SourceRecipe
}

public protocol MealsReadablePantrySource: PantrySource {
    func listMeals() async throws -> [SourceMeal]
}

public protocol GroceriesReadablePantrySource: PantrySource {
    func listGroceryItems() async throws -> [SourceGroceryItem]
}

public protocol PantryItemsReadablePantrySource: PantrySource {
    func listPantryItems() async throws -> [SourcePantryItem]
}
