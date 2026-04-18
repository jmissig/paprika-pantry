import Foundation
import XCTest
@testable import PantryKit

final class SourceStatsServiceTests: XCTestCase {
    func testMakeSnapshotReportsCountsAndSampleCoverage() throws {
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "CCC", name: "Zucchini Pasta", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", sourceFingerprint: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "AAA", name: "Apple Cake", sourceFingerprint: "hash-aaa"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT2", name: "Archived", isDeleted: true),
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Apple Cake", categories: ["CAT1"]),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Zucchini Pasta", categories: ["CAT2", "MISSING"]),
            ]
        )
        let service = SourceStatsService(source: source)

        let snapshot = try BlockingAsync.run {
            try await service.makeSnapshot(sampleLimit: 5)
        }

        XCTAssertEqual(snapshot.recipeStubCount, 3)
        XCTAssertEqual(snapshot.activeRecipeCount, 2)
        XCTAssertEqual(snapshot.deletedRecipeCount, 1)
        XCTAssertEqual(snapshot.categoryCount, 2)
        XCTAssertEqual(snapshot.activeCategoryCount, 1)
        XCTAssertEqual(snapshot.deletedCategoryCount, 1)
        XCTAssertEqual(snapshot.sampleLimit, 5)
        XCTAssertEqual(snapshot.sampledRecipeCount, 2)
        XCTAssertEqual(snapshot.sampleFailureCount, 0)
        XCTAssertEqual(
            snapshot.sampledRecipes,
            [
                SourceRecipeSample(uid: "AAA", name: "Apple Cake", categories: ["Dinner"]),
                SourceRecipeSample(uid: "CCC", name: "Zucchini Pasta", categories: ["CAT2", "MISSING"]),
            ]
        )
        XCTAssertTrue(snapshot.sampleFailures.isEmpty)
    }

    func testMakeSnapshotCapturesSampleFailuresWithoutFailingWholeReport() throws {
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Apple Cake", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "BBB", name: "Broken Recipe", sourceFingerprint: "hash-bbb"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeSourceRecipe(uid: "AAA", name: "Apple Cake"),
            ],
            fetchErrorsByUID: [
                "BBB": InMemoryPantrySourceError.missingFixture("BBB"),
            ]
        )
        let service = SourceStatsService(source: source)

        let snapshot = try BlockingAsync.run {
            try await service.makeSnapshot(sampleLimit: 1)
        }

        XCTAssertEqual(snapshot.sampledRecipeCount, 1)
        XCTAssertEqual(snapshot.sampleFailureCount, 0)

        let failingSnapshot = try BlockingAsync.run {
            try await service.makeSnapshot(sampleLimit: 2)
        }

        XCTAssertEqual(failingSnapshot.sampledRecipeCount, 1)
        XCTAssertEqual(failingSnapshot.sampleFailureCount, 1)
        XCTAssertEqual(
            failingSnapshot.sampleFailures,
            [
                SourceRecipeSampleFailure(
                    uid: "BBB",
                    name: "Broken Recipe",
                    message: "Missing recipe fixture for BBB."
                ),
            ]
        )
    }

    private func makeSourceRecipe(
        uid: String,
        name: String,
        categories: [String] = ["CAT1"]
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: name,
            categoryReferences: categories,
            sourceName: nil,
            ingredients: nil,
            directions: nil,
            notes: nil,
            starRating: nil,
            isFavorite: false,
            prepTime: nil,
            cookTime: nil,
            totalTime: nil,
            servings: nil,
            createdAt: nil,
            updatedAt: nil,
            sourceFingerprint: "hash-\(uid)",
            rawJSON: #"{"uid":"test"}"#
        )
    }
}
