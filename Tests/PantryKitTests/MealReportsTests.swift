import XCTest
@testable import PantryKit

final class MealReportsTests: XCTestCase {
    func testMealsListReportIncludesMealDetails() {
        let report = MealsListReport(
            meals: [
                MealSummary(
                    uid: "MEAL1",
                    name: "Weeknight Soup",
                    scheduledAt: "2026-04-04 18:00:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                )
            ]
        )

        XCTAssertTrue(report.humanDescription.contains("meals list: 1 meals"))
        XCTAssertTrue(report.humanDescription.contains("date=2026-04-04 18:00:00"))
        XCTAssertTrue(report.humanDescription.contains("type=Dinner"))
        XCTAssertTrue(report.humanDescription.contains("recipe=Weeknight Soup [AAA]"))
    }
}
