import XCTest
@testable import PantryKit

final class PantryItemReadServiceTests: XCTestCase {
    func testListPantryItemsFiltersDeletedAndSortsInStockFirst() throws {
        let source = InMemoryPantrySource(
            stubs: [],
            categories: [],
            recipesByUID: [:],
            pantryItems: [
                SourcePantryItem(
                    uid: "PANTRY2",
                    name: "Paprika",
                    quantity: "1 jar",
                    aisleName: "Spices",
                    ingredientName: "Paprika",
                    purchaseDate: "2026-04-05 09:00:00",
                    expirationDate: nil,
                    hasExpiration: false,
                    isInStock: false
                ),
                SourcePantryItem(
                    uid: "PANTRY3",
                    name: "Deleted Rice",
                    quantity: "1 bag",
                    aisleName: nil,
                    ingredientName: "Rice",
                    purchaseDate: nil,
                    expirationDate: nil,
                    hasExpiration: false,
                    isInStock: true,
                    isDeleted: true
                ),
                SourcePantryItem(
                    uid: "PANTRY1",
                    name: "Black Beans",
                    quantity: "2 cans",
                    aisleName: "Pantry",
                    ingredientName: "Black Beans",
                    purchaseDate: "2026-04-04 12:00:00",
                    expirationDate: "2026-05-01 00:00:00",
                    hasExpiration: true,
                    isInStock: true
                )
            ]
        )
        let service = try PantryItemReadService(source: source)

        let pantryItems = try BlockingAsync.run {
            try await service.listPantryItems()
        }

        XCTAssertEqual(
            pantryItems,
            [
                PantryItemSummary(
                    uid: "PANTRY1",
                    name: "Black Beans",
                    quantity: "2 cans",
                    aisleName: "Pantry",
                    ingredientName: "Black Beans",
                    purchaseDate: "2026-04-04 12:00:00",
                    expirationDate: "2026-05-01 00:00:00",
                    hasExpiration: true,
                    isInStock: true
                ),
                PantryItemSummary(
                    uid: "PANTRY2",
                    name: "Paprika",
                    quantity: "1 jar",
                    aisleName: "Spices",
                    ingredientName: "Paprika",
                    purchaseDate: "2026-04-05 09:00:00",
                    expirationDate: nil,
                    hasExpiration: false,
                    isInStock: false
                ),
            ]
        )
    }

    func testInitRejectsSourcesWithoutPantrySupport() {
        struct RecipeOnlySource: PantrySource {
            func listRecipeStubs() async throws -> [SourceRecipeStub] { [] }
            func listRecipeCategories() async throws -> [SourceRecipeCategory] { [] }
            func fetchRecipe(uid: String) async throws -> SourceRecipe {
                throw InMemoryPantrySourceError.missingFixture(uid)
            }
        }

        XCTAssertThrowsError(try PantryItemReadService(source: RecipeOnlySource())) { error in
            XCTAssertEqual(error as? PantryItemReadServiceError, .unsupportedSource)
        }
    }
}
