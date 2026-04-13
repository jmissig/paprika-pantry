import Foundation
import XCTest
@testable import PantryKit

final class RecipeCommandResolutionTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testResolveRecipePrefersUIDBeforeNameMatch() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(
            makeRecipe(uid: "MATCH", name: "UID Winner"),
            syncedAt: syncedAt
        )
        try store.upsertRecipe(
            makeRecipe(uid: "OTHER", name: "match"),
            syncedAt: syncedAt
        )

        let resolved = try resolveRecipe(selector: "MATCH", store: store)
        XCTAssertEqual(resolved.uid, "MATCH")
        XCTAssertEqual(resolved.name, "UID Winner")
    }

    func testResolveRecipeFallsBackToExactCaseInsensitiveName() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(
            makeRecipe(uid: "AAA", name: "Weeknight Soup"),
            syncedAt: syncedAt
        )

        let resolved = try resolveRecipe(selector: "weeknight soup", store: store)
        XCTAssertEqual(resolved.uid, "AAA")
    }

    func testResolveRecipeThrowsAmbiguityErrorForDuplicateNames() throws {
        let store = try makeStore()
        let syncedAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(makeRecipe(uid: "AAA", name: "Curry"), syncedAt: syncedAt)
        try store.upsertRecipe(makeRecipe(uid: "BBB", name: "curry"), syncedAt: syncedAt)

        XCTAssertThrowsError(try resolveRecipe(selector: "CURRY", store: store)) { error in
            guard case let RecipesCommandError.ambiguousRecipeName(selector, matchingUIDs) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(selector, "CURRY")
            XCTAssertEqual(matchingUIDs, ["AAA", "BBB"])
        }
    }

    func testResolveRecipeThrowsNotFoundErrorWhenSelectorMisses() throws {
        let store = try makeStore()

        XCTAssertThrowsError(try resolveRecipe(selector: "missing", store: store)) { error in
            guard case let RecipesCommandError.recipeNotFound(selector) = error else {
                return XCTFail("Unexpected error: \(error)")
            }

            XCTAssertEqual(selector, "missing")
        }
    }

    private func makeStore() throws -> PantryStore {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        let database = PantryDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
        return PantryStore(dbQueue: try database.openQueue())
    }

    private func makeRecipe(uid: String, name: String) -> MirroredRecipeInput {
        MirroredRecipeInput(
            uid: uid,
            name: name,
            categories: ["Dinner"],
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
            remoteHash: "hash-\(uid)",
            rawJSON: #"{"uid":"test"}"#
        )
    }
}
