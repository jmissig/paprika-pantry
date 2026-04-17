import XCTest
@testable import PantryKit

final class MealReadServiceTests: XCTestCase {
    func testListMealsFiltersDeletedAndSortsNewestFirst() throws {
        let source = InMemoryPantrySource(
            stubs: [],
            categories: [],
            recipesByUID: [:],
            meals: [
                SourceMeal(
                    uid: "MEAL1",
                    name: "Older Dinner",
                    scheduledAt: "2026-04-04 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Older Dinner"
                ),
                SourceMeal(
                    uid: "MEAL3",
                    name: "Deleted Meal",
                    scheduledAt: "2026-04-06 12:00:00",
                    mealType: "Lunch",
                    recipeUID: nil,
                    recipeName: nil,
                    isDeleted: true
                ),
                SourceMeal(
                    uid: "MEAL2",
                    name: "Newest Lunch",
                    scheduledAt: "2026-04-05 12:00:00",
                    mealType: "Lunch",
                    recipeUID: nil,
                    recipeName: nil
                ),
            ]
        )
        let service = try MealReadService(source: source)

        let meals = try BlockingAsync.run {
            try await service.listMeals()
        }

        XCTAssertEqual(
            meals,
            [
                MealSummary(
                    uid: "MEAL2",
                    name: "Newest Lunch",
                    scheduledAt: "2026-04-05 12:00:00",
                    mealType: "Lunch",
                    recipeUID: nil,
                    recipeName: nil
                ),
                MealSummary(
                    uid: "MEAL1",
                    name: "Older Dinner",
                    scheduledAt: "2026-04-04 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Older Dinner"
                ),
            ]
        )
    }

    func testInitRejectsSourcesWithoutMealSupport() {
        struct RecipeOnlySource: PantrySource {
            func listRecipeStubs() async throws -> [SourceRecipeStub] { [] }
            func listRecipeCategories() async throws -> [SourceRecipeCategory] { [] }
            func fetchRecipe(uid: String) async throws -> SourceRecipe {
                throw InMemoryPantrySourceError.missingFixture(uid)
            }
        }

        XCTAssertThrowsError(try MealReadService(source: RecipeOnlySource())) { error in
            XCTAssertEqual(error as? MealReadServiceError, .unsupportedSource)
        }
    }
}
