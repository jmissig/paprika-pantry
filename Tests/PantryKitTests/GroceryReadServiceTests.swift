import XCTest
@testable import PantryKit

final class GroceryReadServiceTests: XCTestCase {
    func testListGroceriesFiltersDeletedAndSortsUnpurchasedFirst() throws {
        let source = InMemoryPantrySource(
            stubs: [],
            categories: [],
            recipesByUID: [:],
            groceryItems: [
                SourceGroceryItem(
                    uid: "GROC2",
                    name: "Pasta",
                    quantity: "1 box",
                    instruction: nil,
                    groceryListName: "Main",
                    aisleName: "Pantry",
                    ingredientName: "pasta",
                    recipeName: "Pantry Pasta",
                    isPurchased: true
                ),
                SourceGroceryItem(
                    uid: "GROC3",
                    name: "Deleted Item",
                    quantity: nil,
                    instruction: nil,
                    groceryListName: "Main",
                    aisleName: nil,
                    ingredientName: nil,
                    recipeName: nil,
                    isPurchased: false,
                    isDeleted: true
                ),
                SourceGroceryItem(
                    uid: "GROC1",
                    name: "Avocados",
                    quantity: "2",
                    instruction: "ripe",
                    groceryListName: "Main",
                    aisleName: "Produce",
                    ingredientName: "avocado",
                    recipeName: nil,
                    isPurchased: false
                ),
            ]
        )
        let service = try GroceryReadService(source: source)

        let groceries = try BlockingAsync.run {
            try await service.listGroceries()
        }

        XCTAssertEqual(
            groceries,
            [
                GroceryItemSummary(
                    uid: "GROC1",
                    name: "Avocados",
                    quantity: "2",
                    instruction: "ripe",
                    groceryListName: "Main",
                    aisleName: "Produce",
                    ingredientName: "avocado",
                    recipeName: nil,
                    isPurchased: false
                ),
                GroceryItemSummary(
                    uid: "GROC2",
                    name: "Pasta",
                    quantity: "1 box",
                    instruction: nil,
                    groceryListName: "Main",
                    aisleName: "Pantry",
                    ingredientName: "pasta",
                    recipeName: "Pantry Pasta",
                    isPurchased: true
                ),
            ]
        )
    }

    func testInitRejectsSourcesWithoutGrocerySupport() {
        struct RecipeOnlySource: PantrySource {
            func listRecipeStubs() async throws -> [SourceRecipeStub] { [] }
            func listRecipeCategories() async throws -> [SourceRecipeCategory] { [] }
            func fetchRecipe(uid: String) async throws -> SourceRecipe {
                throw InMemoryPantrySourceError.missingFixture(uid)
            }
        }

        XCTAssertThrowsError(try GroceryReadService(source: RecipeOnlySource())) { error in
            XCTAssertEqual(error as? GroceryReadServiceError, .unsupportedSource)
        }
    }
}
