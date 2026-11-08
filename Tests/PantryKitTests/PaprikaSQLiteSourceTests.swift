import Foundation
import GRDB
import XCTest
@testable import PantryKit

final class PaprikaSQLiteSourceTests: XCTestCase {
    private var temporaryDirectoryURL: URL?

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
        temporaryDirectoryURL = nil
    }

    func testPaprikaSQLiteSourceReadsRealSchemaRecipesCategoriesAndInspection() async throws {
        let databaseURL = try makePaprikaSourceDatabase()
        let source = try PaprikaSQLiteSource(databaseURL: databaseURL)

        let stubs = try await source.listRecipeStubs()
        let categories = try await source.listRecipeCategories()
        let meals = try await source.listMeals()
        let groceryItems = try await source.listGroceryItems()
        let pantryItems = try await source.listPantryItems()
        let recipe = try await source.fetchRecipe(uid: "AAA")
        let recipeFieldCoverage = try await source.recipeFieldCoverage()

        XCTAssertEqual(
            stubs,
            [
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", sourceFingerprint: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "CCC", name: "Description Only", sourceFingerprint: nil),
                SourceRecipeStub(uid: "EEE", name: "Neither Field", sourceFingerprint: nil),
                SourceRecipeStub(uid: "DDD", name: "Notes Only", sourceFingerprint: nil),
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", sourceFingerprint: "hash-aaa"),
            ]
        )
        XCTAssertEqual(
            categories,
            [
                SourceRecipeCategory(uid: "CAT2", name: "Archive", isDeleted: true),
                SourceRecipeCategory(uid: "CAT1", name: "Dinner"),
            ]
        )
        XCTAssertEqual(
            meals,
            [
                SourceMeal(
                    uid: "MEAL2",
                    name: "Pantry Pasta",
                    scheduledAt: "2025-04-11 15:10:00",
                    mealType: "Lunch",
                    recipeUID: nil,
                    recipeName: nil
                ),
                SourceMeal(
                    uid: "MEAL1",
                    name: "Weeknight Soup",
                    scheduledAt: "2025-04-10 14:40:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                ),
                SourceMeal(
                    uid: "MEAL3",
                    name: "Deleted Meal",
                    scheduledAt: "2025-04-10 09:00:00",
                    mealType: "Dinner",
                    recipeUID: nil,
                    recipeName: nil,
                    isDeleted: true
                ),
            ]
        )
        XCTAssertEqual(
            groceryItems,
            [
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
                SourceGroceryItem(
                    uid: "GROC2",
                    name: "pasta",
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

        XCTAssertEqual(
            pantryItems,
            [
                SourcePantryItem(
                    uid: "PANTRY3",
                    name: "Old Rice",
                    quantity: "1 bag",
                    aisleName: nil,
                    ingredientName: "Old Rice",
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
                    purchaseDate: "2025-04-10 12:00:00",
                    expirationDate: "2025-04-24 00:00:00",
                    hasExpiration: true,
                    isInStock: true
                ),
                SourcePantryItem(
                    uid: "PANTRY2",
                    name: "Paprika",
                    quantity: "1 jar",
                    aisleName: "Spices",
                    ingredientName: "Paprika",
                    purchaseDate: "2025-04-09 12:00:00",
                    expirationDate: nil,
                    hasExpiration: false,
                    isInStock: false
                ),
            ]
        )

        XCTAssertEqual(source.inspection.schemaFlavor, "paprika-3-core-data")
        XCTAssertEqual(source.inspection.accessMode, "read-only")
        XCTAssertTrue(source.inspection.queryOnly)
        XCTAssertEqual(source.inspection.journalMode, "wal")
        XCTAssertEqual(source.inspection.paprikaSync?.signalSource, "group-container-preferences")
        XCTAssertEqual(
            source.inspection.paprikaSync?.signalLocation,
            databaseURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Library/Preferences/test.container.plist")
                .path
        )
        XCTAssertEqual(
            source.inspection.paprikaSync?.lastSyncAt,
            paprikaLocalSyncDate("2026-04-18 01:08:36")
        )
        XCTAssertEqual(
            source.inspection.requiredTables,
            ["ZRECIPE", "ZRECIPECATEGORY", "Z_12CATEGORIES", "Z_METADATA"]
        )

        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categoryReferences, ["CAT1"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.ingredients, "Broth\nBeans")
        XCTAssertEqual(recipe.directions, "Simmer.")
        XCTAssertEqual(recipe.description, "A bright bean soup.")
        XCTAssertEqual(recipe.notes, "Finish with lemon.")
        XCTAssertEqual(recipe.difficulty, "Easy")
        XCTAssertEqual(recipe.nutrition, "Per serving: 320 calories")
        XCTAssertEqual(recipe.sourceURL, "https://example.test/weeknight-soup")
        XCTAssertEqual(recipe.imageURL, "https://example.test/weeknight-soup.jpg")
        XCTAssertEqual(recipe.photos.map(\.kind), [.primary, .additional, .additional])
        XCTAssertEqual(recipe.photos.map(\.filename), ["primary.jpg", "step-1.jpg", "missing.jpg"])
        XCTAssertNil(recipe.photos[0].uid)
        XCTAssertEqual(recipe.photos[0].largeFilename, "primary-large.jpg")
        XCTAssertEqual(recipe.photos[0].photoHash, "primary-hash")
        XCTAssertTrue(recipe.photos[0].isDownloaded)
        XCTAssertTrue(recipe.photos[0].isUploaded)
        XCTAssertTrue(recipe.photos[0].localPath?.hasSuffix("Data/Photos/AAA/primary.jpg") == true)
        XCTAssertTrue(recipe.photos[0].largeLocalPath?.hasSuffix("Data/Photos/AAA/primary-large.jpg") == true)
        XCTAssertEqual(recipe.photos[1].uid, "PHOTO1")
        XCTAssertEqual(recipe.photos[1].name, "Step one")
        XCTAssertEqual(recipe.photos[1].order, 1)
        XCTAssertTrue(recipe.photos[1].localPath?.hasSuffix("Data/Photos/AAA/step-1.jpg") == true)
        XCTAssertEqual(recipe.photos[2].uid, "PHOTO2")
        XCTAssertNil(recipe.photos[2].localPath)
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.prepTime, "10 min")
        XCTAssertEqual(recipe.cookTime, "30 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.servings, "4")
        XCTAssertEqual(recipe.createdAt, "2025-04-10 10:00:00")
        XCTAssertNil(recipe.updatedAt)
        XCTAssertEqual(recipe.sourceFingerprint, "hash-aaa")
        XCTAssertTrue(recipe.rawJSON.contains("\"category_uids\":[\"CAT1\"]"))
        XCTAssertTrue(recipe.rawJSON.contains("\"created\":\"2025-04-10 10:00:00\""))
        XCTAssertTrue(recipe.rawJSON.contains("\"description\":\"A bright bean soup.\""))
        XCTAssertTrue(recipe.rawJSON.contains("\"notes\":\"Finish with lemon.\""))
        XCTAssertEqual(recipeFieldCoverage.descriptionCount, 2)
        XCTAssertEqual(recipeFieldCoverage.notesCount, 2)
        XCTAssertEqual(recipeFieldCoverage.descriptionAndNotesCount, 1)
        XCTAssertEqual(recipeFieldCoverage.difficultyCount, 1)
        XCTAssertEqual(recipeFieldCoverage.nutritionCount, 1)
        XCTAssertEqual(recipeFieldCoverage.sourceURLCount, 1)
        XCTAssertEqual(recipeFieldCoverage.imageURLCount, 1)
        XCTAssertEqual(recipeFieldCoverage.primaryPhotoCount, 1)
        XCTAssertEqual(recipeFieldCoverage.recipesWithAdditionalPhotosCount, 1)
        XCTAssertEqual(recipeFieldCoverage.additionalPhotoCount, 2)
    }

    func testPaprikaSQLiteSourceKeepsDescriptionAndNotesIndependent() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())

        let both = try await source.fetchRecipe(uid: "AAA")
        let descriptionOnly = try await source.fetchRecipe(uid: "CCC")
        let notesOnly = try await source.fetchRecipe(uid: "DDD")
        let neither = try await source.fetchRecipe(uid: "EEE")

        XCTAssertEqual(both.description, "A bright bean soup.")
        XCTAssertEqual(both.notes, "Finish with lemon.")
        XCTAssertEqual(descriptionOnly.description, "Description sentinel.")
        XCTAssertNil(descriptionOnly.notes)
        XCTAssertNil(notesOnly.description)
        XCTAssertEqual(notesOnly.notes, "Notes sentinel.")
        XCTAssertNil(neither.description)
        XCTAssertNil(neither.notes)

        let service = RecipeReadService(source: source)
        let bothDetail = try await service.resolveRecipe(selector: "AAA")
        let descriptionOnlyDetail = try await service.resolveRecipe(selector: "CCC")
        let notesOnlyDetail = try await service.resolveRecipe(selector: "DDD")
        let neitherDetail = try await service.resolveRecipe(selector: "EEE")
        XCTAssertEqual(bothDetail.target.hasNotes, true)
        XCTAssertEqual(descriptionOnlyDetail.target.hasNotes, false)
        XCTAssertEqual(notesOnlyDetail.target.hasNotes, true)
        XCTAssertEqual(neitherDetail.target.hasNotes, false)
    }

    func testPaprikaSQLiteSourceRejectsIncompleteRealSchema() throws {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID TEXT,
                    ZNAME TEXT
                )
                """)
        }

        XCTAssertThrowsError(try PaprikaSQLiteSource(databaseURL: databaseURL)) { error in
            XCTAssertEqual(error as? PaprikaSQLiteSourceError, .missingTable("ZRECIPECATEGORY"))
        }
    }

    func testPaprikaSQLiteSourceAllowsSchemasWithoutPhotoSupport() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabaseWithoutPhotos())

        let recipe = try await source.fetchRecipe(uid: "AAA")

        XCTAssertEqual(recipe.photos, [])
    }

    func testRecipeReadServiceReadsListAndShowDirectlyFromPaprikaSQLiteSource() throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
        let service = RecipeReadService(source: source)

        let listed = try BlockingAsync.run {
            try await service.listRecipes()
        }
        let recipe = try BlockingAsync.run {
            try await service.resolveRecipe(selector: "weeknight soup")
        }

        XCTAssertEqual(
            listed,
            [
                RecipeSummary(
                    uid: "CCC",
                    name: "Description Only",
                    categories: [],
                    sourceName: nil,
                    starRating: nil,
                    isFavorite: false,
                    updatedAt: nil,
                    hasNotes: false
                ),
                RecipeSummary(
                    uid: "EEE",
                    name: "Neither Field",
                    categories: [],
                    sourceName: nil,
                    starRating: nil,
                    isFavorite: false,
                    updatedAt: nil,
                    hasNotes: false
                ),
                RecipeSummary(
                    uid: "DDD",
                    name: "Notes Only",
                    categories: [],
                    sourceName: nil,
                    starRating: nil,
                    isFavorite: false,
                    updatedAt: nil,
                    hasNotes: true
                ),
                RecipeSummary(
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true,
                    updatedAt: nil,
                    hasNotes: true
                ),
            ]
        )

        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categories, ["Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.sourceFingerprint, "hash-aaa")
    }

    func testMealReadServiceListsMealsDirectlyFromPaprikaSQLiteSource() throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
        let service = try MealReadService(source: source)

        let meals = try BlockingAsync.run {
            try await service.listMeals()
        }

        XCTAssertEqual(
            meals,
            [
                MealSummary(
                    uid: "MEAL2",
                    name: "Pantry Pasta",
                    scheduledAt: "2025-04-11 15:10:00",
                    mealType: "Lunch",
                    recipeUID: nil,
                    recipeName: nil
                ),
                MealSummary(
                    uid: "MEAL1",
                    name: "Weeknight Soup",
                    scheduledAt: "2025-04-10 14:40:00",
                    mealType: "Dinner",
                    recipeUID: "AAA",
                    recipeName: "Weeknight Soup"
                ),
            ]
        )
    }

    func testGroceryReadServiceListsGroceriesDirectlyFromPaprikaSQLiteSource() throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
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
                    name: "pasta",
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

    func testPantryItemReadServiceListsPantryItemsDirectlyFromPaprikaSQLiteSource() throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
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
                    purchaseDate: "2025-04-10 12:00:00",
                    expirationDate: "2025-04-24 00:00:00",
                    hasExpiration: true,
                    isInStock: true
                ),
                PantryItemSummary(
                    uid: "PANTRY2",
                    name: "Paprika",
                    quantity: "1 jar",
                    aisleName: "Spices",
                    ingredientName: "Paprika",
                    purchaseDate: "2025-04-09 12:00:00",
                    expirationDate: nil,
                    hasExpiration: false,
                    isInStock: false
                ),
            ]
        )
    }

    func testRecipeIndexesRebuildUsesDirectPaprikaSQLiteSource() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: try makePaprikaSourceDatabase())
        let store = try makeStore()

        let summary = try await store.rebuildRecipeIndexes(
            from: source,
            now: { Date(timeIntervalSince1970: 1_712_736_000) }
        )

        XCTAssertEqual(summary.recipeSearchDocumentCount, 4)
        XCTAssertEqual(summary.recipeFeatureCount, 4)
        XCTAssertEqual(summary.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(summary.recipeFeaturesWithIngredientLineCountCount, 1)
        XCTAssertEqual(summary.sourceState?.sourceType, PantrySourceType.paprikaSQLite)
        XCTAssertEqual(summary.sourceState?.sourceLocation, source.databaseURL.path)
        XCTAssertEqual(summary.sourceState?.paprikaSync?.signalSource, "group-container-preferences")
        XCTAssertEqual(try store.searchRecipes(query: "lemon").map(\.uid), ["AAA"])
        XCTAssertEqual(try store.fetchRecipeFeatures(uid: "AAA")?.totalTimeMinutes, 40)
        XCTAssertEqual(try store.indexStats().sourceState?.paprikaSync?.signalSource, "group-container-preferences")
    }

    private func upgradeFixtureToV4(_ url: URL) throws {
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { db in
            try db.execute(sql: """
                ALTER TABLE Z_12CATEGORIES RENAME TO Z_15CATEGORIES;
                ALTER TABLE Z_15CATEGORIES RENAME COLUMN Z_12RECIPES TO Z_15RECIPES;
                ALTER TABLE Z_15CATEGORIES RENAME COLUMN Z_13CATEGORIES TO Z_16CATEGORIES;
                CREATE TABLE ZCOOKBOOK (Z_PK INTEGER PRIMARY KEY, ZUID TEXT, ZNAME TEXT, ZISDEFAULT INTEGER, ZSTATUS TEXT);
                INSERT INTO ZCOOKBOOK VALUES (1, 'collection-default', 'Everyday', 1, 'normal');
                INSERT INTO ZCOOKBOOK VALUES (2, 'collection-other', 'Baking', 0, 'normal');
                ALTER TABLE ZRECIPE ADD COLUMN ZCOOKBOOK INTEGER;
                UPDATE ZRECIPE SET ZCOOKBOOK=2 WHERE ZUID='AAA';
                ALTER TABLE ZRECIPECATEGORY ADD COLUMN ZCOOKBOOK INTEGER;
                ALTER TABLE ZMEAL ADD COLUMN ZSCALE TEXT;
                ALTER TABLE ZMEAL ADD COLUMN ZISINGREDIENT INTEGER;
                UPDATE ZMEAL SET ZSCALE='2', ZISINGREDIENT=1;
                CREATE TABLE ZPANTRYLOCATION (Z_PK INTEGER PRIMARY KEY, ZUID TEXT, ZNAME TEXT, ZSTATUS TEXT);
                INSERT INTO ZPANTRYLOCATION VALUES (1, 'freezer', 'Freezer', 'normal');
                ALTER TABLE ZPANTRYITEM ADD COLUMN ZLOCATION INTEGER;
                ALTER TABLE ZPANTRYITEM ADD COLUMN ZNOTES TEXT;
                UPDATE ZPANTRYITEM SET ZLOCATION=1, ZNOTES='Use soon';
                """)
        }
    }

    private func memorySidecar() throws -> PantrySidecarStore {
        let queue = try DatabaseQueue()
        try PantrySidecarDatabase.migrator().migrate(queue)
        return PantrySidecarStore(dbQueue: queue)
    }

    func testV4ReadsCollectionsMealsAndPantryWithoutInventingDefaultMembership() async throws {
        let url = try makePaprikaSourceDatabase()
        try upgradeFixtureToV4(url)
        let source = try PaprikaSQLiteSource(databaseURL: url)
        XCTAssertEqual(source.inspection.schemaFlavor, "paprika-4-core-data")
        XCTAssertTrue(source.inspection.capabilities.contains("collections"))
        XCTAssertEqual(try source.listCollections().count, 2)
        let recipe = try await source.fetchRecipe(uid: "AAA")
        XCTAssertEqual(recipe.collection?.uid, "collection-other")
        XCTAssertEqual(recipe.collection?.name, "Baking")
        XCTAssertFalse(recipe.categoryReferences.isEmpty)
        let unassigned = try await source.fetchRecipe(uid: "CCC")
        XCTAssertEqual(unassigned.collection?.resolution, "null-reference")
        XCTAssertNil(unassigned.collection?.uid)
        let meals = try await MealReadService(source: source).listMeals()
        XCTAssertEqual(meals.first?.scale, "2")
        XCTAssertEqual(meals.first?.isIngredient, true)
        let pantry = try await PantryItemReadService(source: source).listPantryItems()
        XCTAssertEqual(pantry.first?.locationName, "Freezer")
        XCTAssertEqual(pantry.first?.notes, "Use soon")
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        XCTAssertEqual(try store.fetchRecipeUsageStats(uid: "AAA")?.mealCount ?? 0, 0)
        let detail = try await RecipeReadService(source: source).resolveRecipe(selector: "AAA")
        XCTAssertEqual(detail.collection, recipe.collection)
    }

    func testAmbiguousOrMalformedCategoryLayoutsFailClosed() throws {
        let url = try makePaprikaSourceDatabase()
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { try $0.execute(sql: "CREATE TABLE Z_15CATEGORIES (Z_15RECIPES INTEGER, Z_16CATEGORIES INTEGER)") }
        XCTAssertThrowsError(try PaprikaSQLiteSource(databaseURL: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("exactly one"))
        }
        try queue.write { db in
            try db.execute(sql: "DROP TABLE Z_12CATEGORIES; ALTER TABLE Z_15CATEGORIES RENAME COLUMN Z_16CATEGORIES TO unexpected")
        }
        XCTAssertThrowsError(try PaprikaSQLiteSource(databaseURL: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Z_16CATEGORIES"))
        }
    }

    func testSnapshotStaysConsistentWhileOriginalChangesAndAdditiveColumnsDoNotInvalidate() async throws {
        let url = try makePaprikaSourceDatabase()
        let source = try PaprikaSQLiteSource(databaseURL: url)
        let frozen = try source.snapshot()
        let before = try await frozen.fetchRecipe(uid: "AAA")
        let queue = try DatabaseQueue(path: url.path)
        try await queue.write { try $0.execute(sql: "UPDATE ZRECIPE SET ZNAME='Changed after snapshot' WHERE ZUID='AAA'; ALTER TABLE ZRECIPE ADD COLUMN ZFUTURE_UNUSED TEXT") }
        let after = try await frozen.fetchRecipe(uid: "AAA")
        XCTAssertEqual(after.name, before.name)
        let reopened = try PaprikaSQLiteSource(databaseURL: url)
        let live = try await reopened.fetchRecipe(uid: "AAA")
        XCTAssertEqual(live.name, "Changed after snapshot")
        XCTAssertEqual(source.indexContract, reopened.indexContract)
        XCTAssertNotEqual(source.inspection.structuralDigest, reopened.inspection.structuralDigest)
        XCTAssertTrue(frozen.inspection.queryOnly)
    }

    func testTransitionRequiresRebuildDespiteUnchangedRecipeHashes() async throws {
        let url = try makePaprikaSourceDatabase()
        let v3 = try PaprikaSQLiteSource(databaseURL: url)
        let store = try memorySidecar()
        do {
            _ = try await store.rebuildRecipeIndexes(from: v3, refreshIngredientPairEvidence: false)
            XCTFail("Legacy/missing provenance must require a rebuild")
        } catch { XCTAssertTrue(error.localizedDescription.contains("rebuild")) }
        _ = try await store.rebuildRecipeIndexes(from: v3)
        let originalProvenance = try store.indexProvenance()
        try store.requireCompatible(v3.indexContract)
        try upgradeFixtureToV4(url)
        let v4 = try PaprikaSQLiteSource(databaseURL: url)
        XCTAssertThrowsError(try store.requireCompatible(v4.indexContract))
        do {
            _ = try await store.rebuildRecipeIndexes(from: v4, refreshIngredientPairEvidence: false)
            XCTFail("Transition must not skip unchanged recipes")
        } catch { XCTAssertTrue(error.localizedDescription.contains("rebuild")) }
        XCTAssertEqual(try store.indexProvenance(), originalProvenance)
        let bound = PantrySidecarStore(dbQueue: store.dbQueue, expectedContract: v4.indexContract)
        XCTAssertThrowsError(try bound.searchRecipes(query: "soup"))
        XCTAssertThrowsError(try bound.fetchRecipeFeatures(uid: "AAA"))
        XCTAssertThrowsError(try bound.fetchRecipeUsageStats(uid: "AAA"))
        XCTAssertThrowsError(try bound.fetchAllRecipeFeatures())
        XCTAssertThrowsError(try bound.fetchAllRecipeUsageStats())
        XCTAssertThrowsError(try bound.fetchRecipeIngredientIndex(uid: "AAA"))
        XCTAssertThrowsError(try bound.matchingRecipeUIDs(for: RecipeIngredientFilter(rawTerms: ["lemon"])))
        XCTAssertThrowsError(try bound.listCookbookAggregates())
        XCTAssertThrowsError(try bound.listIngredientPairEvidence())
        XCTAssertFalse(try bound.indexStats().recipeSearchReady)
        XCTAssertNotNil(try bound.indexStats().compatibilityIssue)
        _ = try await store.rebuildRecipeIndexes(from: v4)
        try store.requireCompatible(v4.indexContract)
        XCTAssertThrowsError(try store.requireCompatible(v3.indexContract))
        var future = v4.indexContract
        future.derivationVersion += 1
        XCTAssertThrowsError(try store.requireCompatible(future))
    }

    func testCategoryDependencyRefreshAndPairingProvenanceRemainSeparate() async throws {
        let url = try makePaprikaSourceDatabase()
        let source = try PaprikaSQLiteSource(databaseURL: url)
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        let pairBefore = try store.indexProvenance().first { $0.family == "ingredient-pairs" }
        let queue = try DatabaseQueue(path: url.path)
        try await queue.write { try $0.execute(sql: "UPDATE ZRECIPECATEGORY SET ZNAME='RenamedCategory' WHERE ZUID IS NOT NULL") }
        let summary = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: false)
        XCTAssertGreaterThan(summary.changedRecipeCount, 0)
        XCTAssertFalse(try store.searchRecipes(query: "RenamedCategory").isEmpty)
        XCTAssertEqual(try store.indexProvenance().first { $0.family == "ingredient-pairs" }, pairBefore)
        let routine = try store.indexProvenance().first { $0.family == "recipe-search" }
        XCTAssertNotEqual(routine?.generation, pairBefore?.generation)
        // Missing lines must be repaired even when a Paprika recipe hash has not changed.
        try await store.dbQueue.write { try $0.execute(sql: "DELETE FROM recipe_ingredient_lines WHERE recipe_uid='AAA'") }
        _ = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: false)
        XCTAssertFalse(try XCTUnwrap(store.fetchRecipeIngredientIndex(uid: "AAA")).lines.isEmpty)
        try await store.dbQueue.write { try $0.execute(sql: "DELETE FROM recipe_ingredient_tokens WHERE recipe_uid='AAA'") }
        _ = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: false)
        XCTAssertFalse(try XCTUnwrap(store.fetchRecipeIngredientIndex(uid: "AAA")).lines.flatMap(\.normalizedTokens).isEmpty)
        // A dependency-triggered full routine refresh must also evict removed recipes.
        try await queue.write { try $0.execute(sql: "UPDATE ZRECIPE SET ZINTRASH=1 WHERE ZUID='AAA'; DELETE FROM Z_12CATEGORIES WHERE Z_12RECIPES IN (SELECT Z_PK FROM ZRECIPE WHERE ZUID='AAA')") }
        _ = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: false)
        XCTAssertNil(try store.fetchRecipeFeatures(uid: "AAA"))
        XCTAssertFalse(try store.searchRecipes(query: "soup").contains { $0.uid == "AAA" })

    }

    func testFailedRebuildRollsBackRowsAndProvenance() async throws {
        let url = try makePaprikaSourceDatabase()
        let source = try PaprikaSQLiteSource(databaseURL: url)
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        let before = try store.indexProvenance()
        let count = try store.indexStats().recipeSearchDocumentCount
        try await store.dbQueue.write { db in
            try db.execute(sql: "CREATE TRIGGER fail_rebuild BEFORE INSERT ON recipe_features BEGIN SELECT RAISE(ABORT, 'injected failure'); END")
        }
        do {
            _ = try await store.rebuildRecipeIndexes(from: source)
            XCTFail("Expected injected write failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("injected failure")) }
        XCTAssertEqual(try store.indexProvenance(), before)
        XCTAssertEqual(try store.indexStats().recipeSearchDocumentCount, count)
        XCTAssertEqual(try store.indexStats().lastRecipeSearchRun?.status, .failed)
    }

    func testConcurrentPartialUpdateDoesNotOverwriteAnotherGeneration() async throws {
        let url = try makePaprikaSourceDatabase()
        let source = try PaprikaSQLiteSource(databaseURL: url)
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        let count = try store.indexStats().recipeSearchDocumentCount
        try await store.dbQueue.write { db in
            // Deterministically simulate another writer publishing after we captured the base.
            try db.execute(sql: "CREATE TRIGGER competing_writer AFTER INSERT ON index_runs BEGIN UPDATE index_provenance SET generation='other-writer' WHERE family='recipe-search'; END")
        }
        do {
            _ = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: false)
            XCTFail("Concurrent generation must abort the partial write")
        } catch { XCTAssertTrue(error.localizedDescription.contains("changed while")) }
        XCTAssertEqual(try store.indexStats().recipeSearchDocumentCount, count)
        XCTAssertEqual(try store.indexProvenance().first { $0.family == "recipe-search" }?.generation, "other-writer")
    }

    func testStoreIdentitySurvivesMoveButNotReplacement() throws {
        let url = try makePaprikaSourceDatabase()
        let queue = try DatabaseQueue(path: url.path)
        try queue.write { try $0.execute(sql: "INSERT INTO Z_METADATA (Z_VERSION, Z_UUID) VALUES (1, 'synthetic-store-one')") }
        let original = try PaprikaSQLiteSource(databaseURL: url)
        let movedURL = url.deletingLastPathComponent().appendingPathComponent("moved.sqlite")
        let movedQueue = try DatabaseQueue(path: movedURL.path)
        try queue.backup(to: movedQueue)
        // Make the destination a self-contained fixture (not a WAL header without companions).
        try movedQueue.writeWithoutTransaction { try $0.execute(sql: "PRAGMA journal_mode = DELETE") }
        try movedQueue.close()
        let moved = try PaprikaSQLiteSource(databaseURL: movedURL)
        XCTAssertEqual(original.indexContract, moved.indexContract)
        let replacementQueue = try DatabaseQueue(path: movedURL.path)
        try replacementQueue.write { try $0.execute(sql: "UPDATE Z_METADATA SET Z_UUID='synthetic-store-two'") }
        XCTAssertNotEqual(original.indexContract, try PaprikaSQLiteSource(databaseURL: movedURL).indexContract)
    }

    func testFutureSidecarMigrationIsRejectedWithoutMutation() throws {
        let root = try makeTemporaryDirectory()
        let database = PantrySidecarDatabase(path: root.appendingPathComponent("future.sqlite"))
        let queue = try database.openQueue()
        try queue.write { try $0.execute(sql: "INSERT INTO grdb_migrations VALUES ('future-version')") }
        let before = try queue.read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier") }
        XCTAssertThrowsError(try database.openQueue())
        let after = try queue.read { try String.fetchAll($0, sql: "SELECT identifier FROM grdb_migrations ORDER BY identifier") }
        XCTAssertEqual(before, after)
    }

    func testAllBuildModesRejectCompetingPublication() async throws {
        for winnerFull in [true, false] {
        for full in [true, false] {
            for beforeExtraction in [true, false] {
                let url = try makePaprikaSourceDatabase()
                let source = try PaprikaSQLiteSource(databaseURL: url)
                let store = try memorySidecar()
                _ = try await store.rebuildRecipeIndexes(from: source)
                let queue = try DatabaseQueue(path: url.path)
                let recorder = ProvenanceRecorder()
                let compete: @Sendable () async throws -> Void = {
                    try await queue.write { try $0.execute(sql: "UPDATE ZRECIPE SET ZNAME='WinnerNewName', ZSYNCHASH='winner' WHERE ZUID='AAA'") }
                    _ = try await store.rebuildRecipeIndexes(from: source, refreshIngredientPairEvidence: winnerFull)
                    await recorder.save(try store.indexProvenance())
                }
                var hooks = IndexBuildHooks()
                if beforeExtraction { hooks.afterBaseline = compete } else { hooks.beforePublication = compete }
                do {
                    _ = try await store.buildRecipeIndexes(from: source, refreshIngredientPairEvidence: full, hooks: hooks)
                    XCTFail("Overlapping build must fail")
                } catch {
                    XCTAssertTrue(error.localizedDescription.contains("changed while"), "\(error)")
                }
                XCTAssertEqual(try store.searchRecipes(query: "WinnerNewName").first?.uid, "AAA")
                let running = try await store.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM index_runs WHERE status='running'") }
                XCTAssertEqual(running, 0)
                let expected = await recorder.value
                XCTAssertEqual(try store.indexProvenance(), expected)
                if !beforeExtraction {
                    let failed = try await store.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM index_runs WHERE status='failed'") }
                    XCTAssertEqual(failed, full ? 5 : 4)
                }
            }
        }
        }
    }

    func testPartialBuildCannotAdoptCompetingSourceContract() async throws {
        let url = try makePaprikaSourceDatabase()
        let queue = try DatabaseQueue(path: url.path)
        try await queue.write { try $0.execute(sql: "INSERT INTO Z_METADATA (Z_VERSION, Z_UUID) VALUES (1, 'first-source')") }
        let source = try PaprikaSQLiteSource(databaseURL: url)
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        let hooks = IndexBuildHooks(afterBaseline: {
            try await queue.write { try $0.execute(sql: "UPDATE Z_METADATA SET Z_UUID='replacement-source'") }
            _ = try await store.rebuildRecipeIndexes(from: PaprikaSQLiteSource(databaseURL: url))
        })
        do {
            _ = try await store.buildRecipeIndexes(from: source, refreshIngredientPairEvidence: false, hooks: hooks)
            XCTFail("Must reject changed source baseline")
        } catch { XCTAssertTrue(error.localizedDescription.contains("rebuild") || error.localizedDescription.contains("changed while")) }
        try store.requireCompatible(PaprikaSQLiteSource(databaseURL: url).indexContract)
        XCTAssertThrowsError(try store.requireCompatible(source.indexContract))
    }

    func testAttemptSetupFailureIsAtomic() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: makePaprikaSourceDatabase())
        let store = try memorySidecar()
        _ = try await store.rebuildRecipeIndexes(from: source)
        let before = try store.indexProvenance()
        let beforeRuns = try await store.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM index_runs") }
        try await store.dbQueue.write { try $0.execute(sql: "CREATE TRIGGER reject_attempt BEFORE UPDATE OF source_contract ON index_runs BEGIN SELECT RAISE(ABORT, 'setup-failure'); END") }
        do {
            _ = try await store.rebuildRecipeIndexes(from: source)
            XCTFail("Must reject metadata failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("setup-failure")) }
        XCTAssertEqual(try store.indexProvenance(), before)
        let afterRuns = try await store.dbQueue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM index_runs") }
        XCTAssertEqual(afterRuns, beforeRuns)
    }

    func testDiagnosticsUseOneReadSnapshot() async throws {
        let source = try PaprikaSQLiteSource(databaseURL: makePaprikaSourceDatabase())
        let root = try makeTemporaryDirectory()
        let path = root.appendingPathComponent("diagnostics.sqlite")
        let queue = try PantrySidecarDatabase(path: path).openQueue()
        try await queue.writeWithoutTransaction { try $0.execute(sql: "PRAGMA journal_mode=WAL") }
        let store = PantrySidecarStore(dbQueue: queue, expectedContract: source.indexContract)
        _ = try await store.rebuildRecipeIndexes(from: source)
        let before = try store.indexStats()
        let writer = try DatabaseQueue(path: path.path)
        let during = try store.indexStats(afterProvenanceRead: {
            try writer.write { db in
                try db.execute(sql: "DELETE FROM recipe_search_documents; UPDATE index_provenance SET contract='competing-contract', generation='competing-generation'")
            }
        })
        XCTAssertEqual(during, before)
        let after = try store.indexStats()
        XCTAssertEqual(after.recipeSearchDocumentCount, 0)
        XCTAssertFalse(after.recipeSearchReady)
        XCTAssertNotNil(after.compatibilityIssue)
    }

    private func makeStore() throws -> PantrySidecarStore {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("pantry.sqlite")
        let database = PantrySidecarDatabase(path: databaseURL)
        return PantrySidecarStore(dbQueue: try database.openQueue())
    }

    private func makePaprikaSourceDatabase() throws -> URL {
        let root = try makeTemporaryDirectory()
        let groupContainerURL = root.appendingPathComponent("Library/Group Containers/test.container", isDirectory: true)
        let databaseDirectoryURL = groupContainerURL.appendingPathComponent("Data/Database", isDirectory: true)
        let preferencesDirectoryURL = groupContainerURL.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preferencesDirectoryURL, withIntermediateDirectories: true)
        let recipePhotosURL = groupContainerURL.appendingPathComponent("Data/Photos/AAA", isDirectory: true)
        try FileManager.default.createDirectory(at: recipePhotosURL, withIntermediateDirectories: true)
        try Data().write(to: recipePhotosURL.appendingPathComponent("primary.jpg"))
        try Data().write(to: recipePhotosURL.appendingPathComponent("primary-large.jpg"))
        try Data().write(to: recipePhotosURL.appendingPathComponent("step-1.jpg"))

        let preferencesURL = preferencesDirectoryURL.appendingPathComponent("test.container.plist")
        let preferences = ["LastSyncedDate": "2026-04-18 01:08:36"]
        let preferencesData = try PropertyListSerialization.data(
            fromPropertyList: preferences,
            format: .binary,
            options: 0
        )
        try preferencesData.write(to: preferencesURL)

        let databaseURL = databaseDirectoryURL.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }

        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE Z_METADATA (
                    Z_VERSION INTEGER PRIMARY KEY,
                    Z_UUID TEXT,
                    Z_PLIST BLOB
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZINTRASH INTEGER,
                    ZONFAVORITES INTEGER,
                    ZRATING INTEGER,
                    ZCREATED TIMESTAMP,
                    ZCOOKTIME VARCHAR,
                    ZDESCRIPTIONTEXT VARCHAR,
                    ZDIFFICULTY VARCHAR,
                    ZDIRECTIONS VARCHAR,
                    ZIMAGEURL VARCHAR,
                    ZINGREDIENTS VARCHAR,
                    ZNAME VARCHAR,
                    ZNOTES VARCHAR,
                    ZNUTRITIONALINFO VARCHAR,
                    ZPHOTO VARCHAR,
                    ZPHOTOHASH VARCHAR,
                    ZPHOTOISDOWNLOADED INTEGER,
                    ZPHOTOISUPLOADED INTEGER,
                    ZPHOTOLARGE VARCHAR,
                    ZPREPTIME VARCHAR,
                    ZSERVINGS VARCHAR,
                    ZSOURCE VARCHAR,
                    ZSOURCEURL VARCHAR,
                    ZSYNCHASH VARCHAR,
                    ZTOTALTIME VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPEPHOTO (
                    Z_PK INTEGER PRIMARY KEY,
                    ZISDOWNLOADED INTEGER,
                    ZISUPLOADED INTEGER,
                    ZORDERFLAG INTEGER,
                    ZRECIPE INTEGER,
                    ZFILENAME VARCHAR,
                    ZNAME VARCHAR,
                    ZPHOTOHASH VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPECATEGORY (
                    Z_PK INTEGER PRIMARY KEY,
                    Z_ENT INTEGER,
                    Z_OPT INTEGER,
                    ZPARENT INTEGER,
                    ZNAME VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE Z_12CATEGORIES (
                    Z_12RECIPES INTEGER,
                    Z_13CATEGORIES INTEGER,
                    PRIMARY KEY (Z_12RECIPES, Z_13CATEGORIES)
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZMEAL (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID VARCHAR,
                    ZNAME VARCHAR,
                    ZDATE TIMESTAMP,
                    ZTYPE INTEGER,
                    ZRECIPE INTEGER,
                    ZSTATUS VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZMEALTYPE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZNAME VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZGROCERYLIST (
                    Z_PK INTEGER PRIMARY KEY,
                    ZISDEFAULT INTEGER,
                    ZNAME VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZGROCERYAISLE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZNAME VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZGROCERYITEM (
                    Z_PK INTEGER PRIMARY KEY,
                    ZPURCHASED INTEGER,
                    ZAISLE INTEGER,
                    ZLIST INTEGER,
                    ZAISLENAME VARCHAR,
                    ZINGREDIENT VARCHAR,
                    ZINSTRUCTION VARCHAR,
                    ZNAME VARCHAR,
                    ZQUANTITY VARCHAR,
                    ZRECIPENAME VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZPANTRYITEM (
                    Z_PK INTEGER PRIMARY KEY,
                    ZHASEXPIRATION INTEGER,
                    ZINSTOCK INTEGER,
                    ZAISLE INTEGER,
                    ZEXPIRATIONDATE TIMESTAMP,
                    ZPURCHASEDATE TIMESTAMP,
                    ZAISLENAME VARCHAR,
                    ZINGREDIENT VARCHAR,
                    ZQUANTITY VARCHAR,
                    ZSTATUS VARCHAR,
                    ZUID VARCHAR
                )
                """)

            try db.execute(sql: """
                INSERT INTO ZRECIPECATEGORY (Z_PK, ZNAME, ZSTATUS, ZUID)
                VALUES
                    (1, 'Dinner', '', 'CAT1'),
                    (2, 'Archive', 'deleted', 'CAT2')
                """)
            try db.execute(sql: """
                INSERT INTO ZRECIPE (
                    Z_PK, ZINTRASH, ZONFAVORITES, ZRATING, ZCREATED, ZCOOKTIME,
                    ZDESCRIPTIONTEXT, ZDIFFICULTY, ZDIRECTIONS, ZIMAGEURL, ZINGREDIENTS,
                    ZNAME, ZNOTES, ZNUTRITIONALINFO, ZPHOTO, ZPHOTOHASH,
                    ZPHOTOISDOWNLOADED, ZPHOTOISUPLOADED, ZPHOTOLARGE, ZPREPTIME,
                    ZSERVINGS, ZSOURCE, ZSOURCEURL, ZSYNCHASH, ZTOTALTIME, ZUID
                ) VALUES
                    (1, 0, 1, 4, 765972000, '30 min', 'A bright bean soup.', 'Easy',
                     'Simmer.', 'https://example.test/weeknight-soup.jpg', 'Broth\nBeans',
                     'Weeknight Soup', 'Finish with lemon.', 'Per serving: 320 calories',
                     'primary.jpg', 'primary-hash', 1, 1, 'primary-large.jpg', '10 min',
                     '4', 'Serious Eats', 'https://example.test/weeknight-soup', 'hash-aaa',
                     '40 min', 'AAA'),
                    (2, 1, 0, 2, 765885600, NULL, 'Hidden', NULL, NULL, NULL, NULL,
                     'Deleted Recipe', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     NULL, NULL, NULL,
                     'hash-bbb', NULL, 'BBB'),
                    (3, 0, 0, NULL, NULL, NULL, 'Description sentinel.', NULL, NULL, NULL, NULL,
                     'Description Only', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     NULL, NULL, NULL, NULL, 'CCC'),
                    (4, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     'Notes Only', 'Notes sentinel.', NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     NULL, NULL, NULL, NULL, NULL, 'DDD'),
                    (5, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     'Neither Field', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                     NULL, NULL, NULL, NULL, 'EEE')
                """)
            try db.execute(sql: """
                INSERT INTO ZRECIPEPHOTO (
                    Z_PK, ZISDOWNLOADED, ZISUPLOADED, ZORDERFLAG, ZRECIPE,
                    ZFILENAME, ZNAME, ZPHOTOHASH, ZUID
                ) VALUES
                    (1, 1, 1, 1, 1, 'step-1.jpg', 'Step one', 'step-hash', 'PHOTO1'),
                    (2, 0, 1, 2, 1, 'missing.jpg', 'Missing', 'missing-hash', 'PHOTO2')
                """)
            try db.execute(sql: """
                INSERT INTO Z_12CATEGORIES (Z_12RECIPES, Z_13CATEGORIES)
                VALUES (1, 1), (2, 2)
                """)
            try db.execute(sql: """
                INSERT INTO ZMEALTYPE (Z_PK, ZNAME)
                VALUES (1, 'Dinner'), (2, 'Lunch')
                """)
            try db.execute(sql: """
                INSERT INTO ZMEAL (Z_PK, ZUID, ZNAME, ZDATE, ZTYPE, ZRECIPE, ZSTATUS)
                VALUES
                    (1, 'MEAL1', '', 765988800, 1, 1, ''),
                    (2, 'MEAL2', 'Pantry Pasta', 766077000, 2, NULL, ''),
                    (3, 'MEAL3', 'Deleted Meal', 765968400, 1, NULL, 'deleted')
                """)
            try db.execute(sql: """
                INSERT INTO ZGROCERYLIST (Z_PK, ZISDEFAULT, ZNAME, ZSTATUS, ZUID)
                VALUES (1, 1, 'Main', '', 'LIST1')
                """)
            try db.execute(sql: """
                INSERT INTO ZGROCERYAISLE (Z_PK, ZNAME, ZSTATUS, ZUID)
                VALUES
                    (1, 'Produce', '', 'AISLE1'),
                    (2, 'Pantry', '', 'AISLE2'),
                    (3, 'Spices', '', 'AISLE3')
                """)
            try db.execute(sql: """
                INSERT INTO ZGROCERYITEM (Z_PK, ZPURCHASED, ZAISLE, ZLIST, ZAISLENAME, ZINGREDIENT, ZINSTRUCTION, ZNAME, ZQUANTITY, ZRECIPENAME, ZSTATUS, ZUID)
                VALUES
                    (1, 0, 1, 1, '', 'avocado', 'ripe', 'Avocados', '2', NULL, '', 'GROC1'),
                    (2, 1, 2, 1, '', 'pasta', NULL, '', '1 box', 'Pantry Pasta', '', 'GROC2'),
                    (3, 0, NULL, 1, NULL, NULL, NULL, 'Deleted Item', NULL, NULL, 'deleted', 'GROC3')
                """)
            try db.execute(sql: """
                INSERT INTO ZPANTRYITEM (Z_PK, ZHASEXPIRATION, ZINSTOCK, ZAISLE, ZEXPIRATIONDATE, ZPURCHASEDATE, ZAISLENAME, ZINGREDIENT, ZQUANTITY, ZSTATUS, ZUID)
                VALUES
                    (1, 1, 1, 2, 767145600, 765979200, '', 'Black Beans', '2 cans', '', 'PANTRY1'),
                    (2, 0, 0, 3, NULL, 765892800, '', 'Paprika', '1 jar', '', 'PANTRY2'),
                    (3, 0, 1, NULL, NULL, NULL, NULL, 'Old Rice', '1 bag', 'deleted', 'PANTRY3')
                """)
        }

        return databaseURL
    }

    private func makePaprikaSourceDatabaseWithoutPhotos() throws -> URL {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("Paprika.sqlite")
        let queue = try DatabaseQueue(path: databaseURL.path)

        try queue.write { db in
            try db.execute(sql: "CREATE TABLE Z_METADATA (Z_VERSION INTEGER PRIMARY KEY)")
            try db.execute(sql: """
                CREATE TABLE ZRECIPE (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID VARCHAR,
                    ZNAME VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE ZRECIPECATEGORY (
                    Z_PK INTEGER PRIMARY KEY,
                    ZUID VARCHAR,
                    ZNAME VARCHAR
                )
                """)
            try db.execute(sql: """
                CREATE TABLE Z_12CATEGORIES (
                    Z_12RECIPES INTEGER,
                    Z_13CATEGORIES INTEGER
                )
                """)
            try db.execute(sql: "INSERT INTO ZRECIPE (Z_PK, ZUID, ZNAME) VALUES (1, 'AAA', 'No Photo Recipe')")
        }

        return databaseURL
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        temporaryDirectoryURL = root
        return root
    }

    private func paprikaLocalSyncDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: value)
    }
}

private actor ProvenanceRecorder {
    var value: [IndexBuildProvenance] = []
    func save(_ value: [IndexBuildProvenance]) { self.value = value }
}
