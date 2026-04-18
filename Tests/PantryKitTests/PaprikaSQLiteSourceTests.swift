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

        XCTAssertEqual(
            stubs,
            [
                SourceRecipeStub(uid: "BBB", name: "Deleted Recipe", hash: "hash-bbb", isDeleted: true),
                SourceRecipeStub(uid: "AAA", name: "Weeknight Soup", hash: "hash-aaa"),
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
        XCTAssertEqual(recipe.notes, "Finish with lemon.")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.prepTime, "10 min")
        XCTAssertEqual(recipe.cookTime, "30 min")
        XCTAssertEqual(recipe.totalTime, "40 min")
        XCTAssertEqual(recipe.servings, "4")
        XCTAssertEqual(recipe.createdAt, "2025-04-10 10:00:00")
        XCTAssertNil(recipe.updatedAt)
        XCTAssertEqual(recipe.remoteHash, "hash-aaa")
        XCTAssertTrue(recipe.rawJSON.contains("\"category_uids\":[\"CAT1\"]"))
        XCTAssertTrue(recipe.rawJSON.contains("\"created\":\"2025-04-10 10:00:00\""))
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
                    uid: "AAA",
                    name: "Weeknight Soup",
                    categories: ["Dinner"],
                    sourceName: "Serious Eats",
                    starRating: 4,
                    isFavorite: true,
                    updatedAt: nil
                ),
            ]
        )

        XCTAssertEqual(recipe.uid, "AAA")
        XCTAssertEqual(recipe.name, "Weeknight Soup")
        XCTAssertEqual(recipe.categories, ["Dinner"])
        XCTAssertEqual(recipe.sourceName, "Serious Eats")
        XCTAssertEqual(recipe.starRating, 4)
        XCTAssertTrue(recipe.isFavorite)
        XCTAssertEqual(recipe.remoteHash, "hash-aaa")
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

        XCTAssertEqual(summary.recipeSearchDocumentCount, 1)
        XCTAssertEqual(summary.recipeFeatureCount, 1)
        XCTAssertEqual(summary.recipeFeaturesWithTotalTimeCount, 1)
        XCTAssertEqual(summary.recipeFeaturesWithIngredientLineCountCount, 1)
        XCTAssertEqual(summary.sourceState?.sourceKind, .paprikaSQLite)
        XCTAssertEqual(summary.sourceState?.sourceLocation, source.databaseURL.path)
        XCTAssertEqual(summary.sourceState?.paprikaSync?.signalSource, "group-container-preferences")
        XCTAssertEqual(try store.searchRecipes(query: "lemon").map(\.uid), ["AAA"])
        XCTAssertEqual(try store.fetchRecipeFeatures(uid: "AAA")?.totalTimeMinutes, 40)
        XCTAssertEqual(try store.indexStats().sourceState?.paprikaSync?.signalSource, "group-container-preferences")
    }

    private func makeStore() throws -> PantryStore {
        let root = try makeTemporaryDirectory()
        let databaseURL = root.appendingPathComponent("pantry.sqlite")
        let database = PantryDatabase(path: databaseURL)
        return PantryStore(dbQueue: try database.openQueue())
    }

    private func makePaprikaSourceDatabase() throws -> URL {
        let root = try makeTemporaryDirectory()
        let groupContainerURL = root.appendingPathComponent("Library/Group Containers/test.container", isDirectory: true)
        let databaseDirectoryURL = groupContainerURL.appendingPathComponent("Data/Database", isDirectory: true)
        let preferencesDirectoryURL = groupContainerURL.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: preferencesDirectoryURL, withIntermediateDirectories: true)

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
                    ZDIRECTIONS VARCHAR,
                    ZINGREDIENTS VARCHAR,
                    ZNAME VARCHAR,
                    ZNOTES VARCHAR,
                    ZPREPTIME VARCHAR,
                    ZSERVINGS VARCHAR,
                    ZSOURCE VARCHAR,
                    ZSYNCHASH VARCHAR,
                    ZTOTALTIME VARCHAR,
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
                    ZDESCRIPTIONTEXT, ZDIRECTIONS, ZINGREDIENTS, ZNAME, ZNOTES,
                    ZPREPTIME, ZSERVINGS, ZSOURCE, ZSYNCHASH, ZTOTALTIME, ZUID
                ) VALUES
                    (1, 0, 1, 4, 765972000, '30 min', NULL, 'Simmer.', 'Broth\nBeans',
                     'Weeknight Soup', 'Finish with lemon.', '10 min', '4', 'Serious Eats',
                     'hash-aaa', '40 min', 'AAA'),
                    (2, 1, 0, 2, 765885600, NULL, 'Hidden', NULL, NULL,
                     'Deleted Recipe', NULL, NULL, NULL, NULL,
                     'hash-bbb', NULL, 'BBB')
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
