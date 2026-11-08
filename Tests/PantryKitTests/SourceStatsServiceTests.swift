import Foundation
import XCTest
@testable import PantryKit

final class SourceStatsServiceTests: XCTestCase {
    func testMakeSnapshotReportsCountsAndSampleCoverage() async throws {
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

        let snapshot = try await service.makeSnapshot(sampleLimit: 5)

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

    func testMakeSnapshotCapturesSampleFailuresWithoutFailingWholeReport() async throws {
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

        let snapshot = try await service.makeSnapshot(sampleLimit: 1)

        XCTAssertEqual(snapshot.sampledRecipeCount, 1)
        XCTAssertEqual(snapshot.sampleFailureCount, 0)

        let failingSnapshot = try await service.makeSnapshot(sampleLimit: 2)

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

    func testMakeSnapshotReportsRecipeFieldCoverage() async throws {
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Both", sourceFingerprint: "hash-aaa"),
                SourceRecipeStub(uid: "CCC", name: "Description Only", sourceFingerprint: "hash-ccc"),
                SourceRecipeStub(uid: "DDD", name: "Notes Only", sourceFingerprint: "hash-ddd"),
                SourceRecipeStub(uid: "EEE", name: "Neither", sourceFingerprint: "hash-eee"),
            ],
            categories: [],
            recipesByUID: [
                "AAA": makeSourceRecipe(
                    uid: "AAA",
                    name: "Both",
                    description: "Description.",
                    notes: "Notes.",
                    difficulty: "Easy",
                    nutrition: "320 calories",
                    sourceURL: "https://example.test/recipe",
                    imageURL: "https://example.test/image.jpg",
                    photos: [
                        SourceRecipePhoto(
                            kind: .primary,
                            uid: nil,
                            filename: "primary.jpg",
                            largeFilename: nil,
                            name: nil,
                            order: nil,
                            photoHash: nil,
                            isDownloaded: true,
                            isUploaded: true,
                            localPath: "/tmp/primary.jpg",
                            largeLocalPath: nil
                        ),
                        SourceRecipePhoto(
                            kind: .additional,
                            uid: "PHOTO1",
                            filename: "one.jpg",
                            largeFilename: nil,
                            name: nil,
                            order: 1,
                            photoHash: nil,
                            isDownloaded: true,
                            isUploaded: true,
                            localPath: "/tmp/one.jpg",
                            largeLocalPath: nil
                        ),
                        SourceRecipePhoto(
                            kind: .additional,
                            uid: "PHOTO2",
                            filename: "two.jpg",
                            largeFilename: nil,
                            name: nil,
                            order: 2,
                            photoHash: nil,
                            isDownloaded: false,
                            isUploaded: true,
                            localPath: nil,
                            largeLocalPath: nil
                        ),
                    ]
                ),
                "CCC": makeSourceRecipe(uid: "CCC", name: "Description Only", description: "Description."),
                "DDD": makeSourceRecipe(uid: "DDD", name: "Notes Only", notes: "Notes."),
                "EEE": makeSourceRecipe(uid: "EEE", name: "Neither"),
            ]
        )
        let service = SourceStatsService(source: source)

        let snapshot = try await service.makeSnapshot(sampleLimit: 0)

        XCTAssertEqual(snapshot.recipeFieldCoverage.descriptionCount, 2)
        XCTAssertEqual(snapshot.recipeFieldCoverage.notesCount, 2)
        XCTAssertEqual(snapshot.recipeFieldCoverage.descriptionAndNotesCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.difficultyCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.nutritionCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.sourceURLCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.imageURLCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.primaryPhotoCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.recipesWithAdditionalPhotosCount, 1)
        XCTAssertEqual(snapshot.recipeFieldCoverage.additionalPhotoCount, 2)
    }

    private func makeSourceRecipe(
        uid: String,
        name: String,
        categories: [String] = ["CAT1"],
        description: String? = nil,
        notes: String? = nil,
        difficulty: String? = nil,
        nutrition: String? = nil,
        sourceURL: String? = nil,
        imageURL: String? = nil,
        photos: [SourceRecipePhoto] = []
    ) -> SourceRecipe {
        SourceRecipe(
            uid: uid,
            name: name,
            categoryReferences: categories,
            sourceName: nil,
            ingredients: nil,
            directions: nil,
            description: description,
            notes: notes,
            difficulty: difficulty,
            nutrition: nutrition,
            sourceURL: sourceURL,
            imageURL: imageURL,
            photos: photos,
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
