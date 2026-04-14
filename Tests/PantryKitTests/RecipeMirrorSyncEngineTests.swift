import Foundation
import XCTest
@testable import PantryKit

final class RecipeMirrorSyncEngineTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testInitialSyncInsertsRecipesAndCategories() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [
                SourceRecipeStub(uid: "AAA", name: "Soup", hash: "hash-1"),
            ],
            categories: [
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "Soup",
                    categoryReferences: ["CAT1"],
                    sourceName: "Serious Eats",
                    ingredients: "Broth",
                    directions: "Simmer.",
                    notes: "Add lemon.",
                    starRating: 5,
                    isFavorite: true,
                    prepTime: "10 min",
                    cookTime: "20 min",
                    totalTime: "30 min",
                    servings: "4",
                    createdAt: "2026-04-01 10:00:00",
                    updatedAt: "2026-04-02 10:00:00",
                    remoteHash: "hash-1",
                    rawJSON: #"{"uid":"AAA","name":"Soup"}"#
                ),
            ]
        )
        let engine = RecipeMirrorSyncEngine(
            source: source,
            store: store,
            now: makeClock(startingAt: 1_712_736_000)
        )

        let summary = try await engine.run()

        XCTAssertEqual(summary.status, .success)
        XCTAssertEqual(summary.recipesSeen, 1)
        XCTAssertEqual(summary.changedRecipeCount, 1)
        XCTAssertEqual(summary.deletedRecipeCount, 0)

        let recipe = try XCTUnwrap(store.fetchRecipe(uid: "AAA"))
        XCTAssertEqual(recipe.categories, ["Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertTrue(recipe.isFavorite)
    }

    func testSecondSyncSkipsUnchangedRecipeFetches() async throws {
        let store = try makeStore()
        try store.upsertRecipe(
            MirroredRecipeInput(
                uid: "AAA",
                name: "Soup",
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
                remoteHash: "hash-1",
                rawJSON: #"{"uid":"AAA"}"#
            ),
            syncedAt: Date(timeIntervalSince1970: 1_712_736_000)
        )

        let source = InMemoryPantrySource(
            stubs: [SourceRecipeStub(uid: "AAA", name: "Soup", hash: "hash-1")],
            categories: [SourceRecipeCategory(uid: "CAT1", name: "Dinner")],
            recipesByUID: [:]
        )
        let engine = RecipeMirrorSyncEngine(
            source: source,
            store: store,
            now: makeClock(startingAt: 1_712_740_000)
        )

        let summary = try await engine.run()

        XCTAssertEqual(summary.changedRecipeCount, 0)
        XCTAssertTrue(source.fetchedRecipeUIDs.isEmpty)
    }

    func testChangedHashUpdatesRecipeAndMissingRecipeBecomesDeleted() async throws {
        let store = try makeStore()
        let initialSyncAt = Date(timeIntervalSince1970: 1_712_736_000)

        try store.upsertRecipe(
            MirroredRecipeInput(
                uid: "AAA",
                name: "Old Soup",
                categories: ["Dinner"],
                sourceName: "Old Source",
                ingredients: nil,
                directions: nil,
                notes: nil,
                starRating: 2,
                isFavorite: false,
                prepTime: nil,
                cookTime: nil,
                totalTime: nil,
                servings: nil,
                createdAt: nil,
                updatedAt: nil,
                remoteHash: "old-hash",
                rawJSON: #"{"uid":"AAA","name":"Old Soup"}"#
            ),
            syncedAt: initialSyncAt
        )
        try store.upsertRecipe(
            MirroredRecipeInput(
                uid: "BBB",
                name: "Remove Me",
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
                remoteHash: "hash-bbb",
                rawJSON: #"{"uid":"BBB"}"#
            ),
            syncedAt: initialSyncAt
        )

        let source = InMemoryPantrySource(
            stubs: [SourceRecipeStub(uid: "AAA", name: "New Soup", hash: "new-hash")],
            categories: [SourceRecipeCategory(uid: "CAT1", name: "Comfort Food")],
            recipesByUID: [
                "AAA": SourceRecipe(
                    uid: "AAA",
                    name: "New Soup",
                    categoryReferences: ["CAT1"],
                    sourceName: "New Source",
                    ingredients: nil,
                    directions: nil,
                    notes: "Updated",
                    starRating: 4,
                    isFavorite: true,
                    prepTime: nil,
                    cookTime: nil,
                    totalTime: nil,
                    servings: nil,
                    createdAt: nil,
                    updatedAt: "2026-04-03 10:00:00",
                    remoteHash: "new-hash",
                    rawJSON: #"{"uid":"AAA","name":"New Soup"}"#
                ),
            ]
        )
        let engine = RecipeMirrorSyncEngine(
            source: source,
            store: store,
            now: makeClock(startingAt: 1_712_740_000)
        )

        let summary = try await engine.run()

        XCTAssertEqual(summary.changedRecipeCount, 1)
        XCTAssertEqual(summary.deletedRecipeCount, 1)

        let updatedRecipe = try XCTUnwrap(store.fetchRecipe(uid: "AAA"))
        XCTAssertEqual(updatedRecipe.name, "New Soup")
        XCTAssertEqual(updatedRecipe.sourceName, "New Source")
        XCTAssertEqual(updatedRecipe.categories, ["Comfort Food"])
        XCTAssertTrue(updatedRecipe.isFavorite)

        XCTAssertNil(try store.fetchRecipe(uid: "BBB"))
        XCTAssertEqual(try store.stats().deletedRecipeCount, 1)
    }

    func testFailedHydrationMarksSyncRunFailedAndAvoidsPartialWrites() async throws {
        let store = try makeStore()
        let source = InMemoryPantrySource(
            stubs: [SourceRecipeStub(uid: "AAA", name: "Soup", hash: "hash-1")],
            categories: [],
            recipesByUID: [:],
            fetchErrorsByUID: ["AAA": InMemoryPantrySourceError.missingFixture("AAA")]
        )
        let engine = RecipeMirrorSyncEngine(
            source: source,
            store: store,
            now: makeClock(startingAt: 1_712_736_000)
        )

        do {
            _ = try await engine.run()
            XCTFail("Expected sync to fail")
        } catch {
            let latestRun = try XCTUnwrap(store.latestSyncRun())
            XCTAssertEqual(latestRun.status, .failed)
            XCTAssertEqual(try store.stats().totalRecipeCount, 0)
        }
    }

    private func makeStore() throws -> PantryStore {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        temporaryDirectoryURL = directoryURL
        let database = PantryDatabase(path: directoryURL.appendingPathComponent("pantry.sqlite"))
        return PantryStore(dbQueue: try database.openQueue())
    }

    private func makeClock(startingAt timestamp: TimeInterval) -> @Sendable () -> Date {
        let state = ClockState(nextTimestamp: timestamp)
        return {
            state.nextDate()
        }
    }
}

private final class ClockState: @unchecked Sendable {
    private let lock = NSLock()
    private var nextTimestamp: TimeInterval

    init(nextTimestamp: TimeInterval) {
        self.nextTimestamp = nextTimestamp
    }

    func nextDate() -> Date {
        lock.withLock {
            defer { nextTimestamp += 60 }
            return Date(timeIntervalSince1970: nextTimestamp)
        }
    }
}
