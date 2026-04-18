import XCTest
@testable import PantryKit

final class PantryItemReportsTests: XCTestCase {
    func testPantryItemsListReportIncludesStructuredFields() {
        let report = PantryItemsListReport(
            pantryItems: [
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
                )
            ]
        )

        XCTAssertTrue(report.humanDescription.contains("pantry list: 1 pantry items"))
        XCTAssertTrue(report.humanDescription.contains("quantity=2 cans"))
        XCTAssertTrue(report.humanDescription.contains("aisle=Pantry"))
        XCTAssertTrue(report.humanDescription.contains("in_stock=yes"))
        XCTAssertTrue(report.humanDescription.contains("ingredient=Black Beans"))
        XCTAssertTrue(report.humanDescription.contains("purchased=2026-04-04 12:00:00"))
        XCTAssertTrue(report.humanDescription.contains("expires=2026-05-01 00:00:00"))
    }
}
