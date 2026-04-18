import XCTest
@testable import PantryKit

final class GroceryReportsTests: XCTestCase {
    func testGroceriesListReportIncludesStructuredFields() {
        let report = GroceriesListReport(
            groceries: [
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
                )
            ]
        )

        XCTAssertTrue(report.humanDescription.contains("groceries list: 1 groceries"))
        XCTAssertTrue(report.humanDescription.contains("quantity=2"))
        XCTAssertTrue(report.humanDescription.contains("list=Main"))
        XCTAssertTrue(report.humanDescription.contains("aisle=Produce"))
        XCTAssertTrue(report.humanDescription.contains("purchased=no"))
        XCTAssertTrue(report.humanDescription.contains("ingredient=avocado"))
        XCTAssertTrue(report.humanDescription.contains("instruction=ripe"))
    }
}
