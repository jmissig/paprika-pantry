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

public struct SourceRecipePhoto: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Equatable, Sendable {
        case primary
        case additional
    }

    public let kind: Kind
    public let uid: String?
    public let filename: String
    public let largeFilename: String?
    public let name: String?
    public let order: Int?
    public let photoHash: String?
    public let isDownloaded: Bool
    public let isUploaded: Bool
    public let localPath: String?
    public let largeLocalPath: String?

    public init(
        kind: Kind,
        uid: String?,
        filename: String,
        largeFilename: String?,
        name: String?,
        order: Int?,
        photoHash: String?,
        isDownloaded: Bool,
        isUploaded: Bool,
        localPath: String?,
        largeLocalPath: String?
    ) {
        self.kind = kind
        self.uid = uid
        self.filename = filename
        self.largeFilename = largeFilename
        self.name = name
        self.order = order
        self.photoHash = photoHash
        self.isDownloaded = isDownloaded
        self.isUploaded = isUploaded
        self.localPath = localPath
        self.largeLocalPath = largeLocalPath
    }
}

public struct SourceRecipe: Codable, Equatable, Sendable {
    public let collection: RecipeCollectionContext?
    public let uid: String
    public let name: String
    public let categoryReferences: [String]
    public let sourceName: String?
    public let ingredients: String?
    public let directions: String?
    public let description: String?
    public let notes: String?
    public let difficulty: String?
    public let nutrition: String?
    public let sourceURL: String?
    public let imageURL: String?
    public let photos: [SourceRecipePhoto]
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
        description: String?,
        notes: String?,
        difficulty: String?,
        nutrition: String?,
        sourceURL: String?,
        imageURL: String?,
        photos: [SourceRecipePhoto],
        starRating: Int?,
        isFavorite: Bool,
        prepTime: String?,
        cookTime: String?,
        totalTime: String?,
        servings: String?,
        createdAt: String?,
        updatedAt: String?,
        sourceFingerprint: String?,
        rawJSON: String,
        collection: RecipeCollectionContext? = nil
    ) {
        self.collection = collection
        self.uid = uid
        self.name = name
        self.categoryReferences = categoryReferences
        self.sourceName = sourceName
        self.ingredients = ingredients
        self.directions = directions
        self.description = description
        self.notes = notes
        self.difficulty = difficulty
        self.nutrition = nutrition
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.photos = photos
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

public struct SourceRecipeFieldCoverage: Codable, Equatable, Sendable {
    public let descriptionCount: Int
    public let notesCount: Int
    public let descriptionAndNotesCount: Int
    public let difficultyCount: Int
    public let nutritionCount: Int
    public let sourceURLCount: Int
    public let imageURLCount: Int
    public let primaryPhotoCount: Int
    public let recipesWithAdditionalPhotosCount: Int
    public let additionalPhotoCount: Int

    public init(
        descriptionCount: Int,
        notesCount: Int,
        descriptionAndNotesCount: Int,
        difficultyCount: Int,
        nutritionCount: Int,
        sourceURLCount: Int,
        imageURLCount: Int,
        primaryPhotoCount: Int,
        recipesWithAdditionalPhotosCount: Int,
        additionalPhotoCount: Int
    ) {
        self.descriptionCount = descriptionCount
        self.notesCount = notesCount
        self.descriptionAndNotesCount = descriptionAndNotesCount
        self.difficultyCount = difficultyCount
        self.nutritionCount = nutritionCount
        self.sourceURLCount = sourceURLCount
        self.imageURLCount = imageURLCount
        self.primaryPhotoCount = primaryPhotoCount
        self.recipesWithAdditionalPhotosCount = recipesWithAdditionalPhotosCount
        self.additionalPhotoCount = additionalPhotoCount
    }

    public init(recipes: [SourceRecipe]) {
        self.init(
            descriptionCount: recipes.count { Self.isNonblank($0.description) },
            notesCount: recipes.count { Self.isNonblank($0.notes) },
            descriptionAndNotesCount: recipes.count {
                Self.isNonblank($0.description) && Self.isNonblank($0.notes)
            },
            difficultyCount: recipes.count { Self.isNonblank($0.difficulty) },
            nutritionCount: recipes.count { Self.isNonblank($0.nutrition) },
            sourceURLCount: recipes.count { Self.isNonblank($0.sourceURL) },
            imageURLCount: recipes.count { Self.isNonblank($0.imageURL) },
            primaryPhotoCount: recipes.count { recipe in
                recipe.photos.contains { $0.kind == .primary }
            },
            recipesWithAdditionalPhotosCount: recipes.count { recipe in
                recipe.photos.contains { $0.kind == .additional }
            },
            additionalPhotoCount: recipes.reduce(into: 0) { count, recipe in
                count += recipe.photos.count { $0.kind == .additional }
            }
        )
    }

    private static func isNonblank(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

public struct SourceMeal: Codable, Equatable, Sendable {
    public let scale: String?
    public let isIngredient: Bool?
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
        isDeleted: Bool = false,
        scale: String? = nil,
        isIngredient: Bool? = nil
    ) {
        self.scale = scale
        self.isIngredient = isIngredient
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
    public let locationUID: String?
    public let locationName: String?
    public let notes: String?
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
        isDeleted: Bool = false,
        locationUID: String? = nil,
        locationName: String? = nil,
        notes: String? = nil
    ) {
        self.locationUID = locationUID
        self.locationName = locationName
        self.notes = notes
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
    func recipeFieldCoverage() async throws -> SourceRecipeFieldCoverage
}

public extension PantrySource {
    func recipeFieldCoverage() async throws -> SourceRecipeFieldCoverage {
        let activeStubs = try await listRecipeStubs().filter { !$0.isDeleted }
        var recipes = [SourceRecipe]()
        recipes.reserveCapacity(activeStubs.count)
        for stub in activeStubs {
            recipes.append(try await fetchRecipe(uid: stub.uid))
        }
        return SourceRecipeFieldCoverage(recipes: recipes)
    }
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

/// Narrow source-owned boundary for consistent index extraction.
protocol IndexablePantrySource: PantrySource {
    var indexContract: IndexSourceContract { get }
    func makeIndexSnapshot() throws -> any IndexablePantrySource
    func categoryDependencySignature() throws -> String
    func storedSourceState(observedAt: Date) -> PantryStoredSourceState
}
