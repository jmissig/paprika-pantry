import XCTest
@testable import PantryKit

final class JSONOutputTests: XCTestCase {
    func testRenderProducesStructuredJSON() throws {
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

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertTrue(rendered.contains("\"command\""))
        XCTAssertTrue(rendered.contains("\"groceries list\""))
        XCTAssertTrue(rendered.contains("\"groceries\""))
        XCTAssertTrue(rendered.contains("\"groceryCount\" : 1"))
        XCTAssertTrue(rendered.contains("\"groceryListName\" : \"Main\""))
        XCTAssertFalse(rendered.contains("\\/"))
    }

    func testRenderRecipeReportsPreservesStructuredFields() throws {
        let recipesReport = RecipesListReport(
            recipes: [
                RecipeSummary(
                    uid: "AAA",
                    name: "Soup",
                    categories: ["Dinner", "Weeknight"],
                    sourceName: "Serious Eats",
                    starRating: 5,
                    isFavorite: true,
                    updatedAt: "2026-04-02 10:00:00",
                    derivedFeatures: RecipeDerivedFeatures(
                        uid: "AAA",
                        sourceFingerprint: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    ),
                    usageStats: RecipeUsageStats(
                        uid: "AAA",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        mealCount: 2,
                        firstMealAt: "2026-04-01 18:00:00",
                        lastMealAt: "2026-04-07 18:00:00",
                        mealGapDays: [6],
                        daysSpannedByMeals: 6,
                        medianMealGapDays: 6.0,
                        mealShare: 0.25
                    )
                ),
            ],
            canonicalFilters: RecipeQueryFilters(favoritesOnly: true, minRating: 4, categoryNames: ["Dinner"]),
            ingredientFilter: RecipeIngredientFilter(
                rawTerms: ["green onions", "basil"],
                excludeRawTerms: ["anchovy"],
                includeMode: .any
            ),
            derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
            sort: .fewestIngredients,
            derivedReadPath: "sidecar-derived",
            usageReadPath: "sidecar-derived",
            derivedLastSuccessAt: Date(timeIntervalSince1970: 1_712_736_120),
            derivedFreshnessSeconds: 60,
            usageFreshnessSeconds: 60
        )

        let recipesRendered = try JSONOutput.render(recipesReport)
        XCTAssertTrue(recipesRendered.contains("\"readPath\""))
        XCTAssertTrue(recipesRendered.contains("\"direct-source\""))
        XCTAssertTrue(recipesRendered.contains("\"derivedReadPath\""))
        XCTAssertTrue(recipesRendered.contains("\"sidecar-derived\""))
        XCTAssertTrue(recipesRendered.contains("\"derivedFreshnessSeconds\" : 60"))
        XCTAssertTrue(recipesRendered.contains("\"usageReadPath\""))
        XCTAssertTrue(recipesRendered.contains("\"usageFreshnessSeconds\" : 60"))
        XCTAssertTrue(recipesRendered.contains("\"canonicalFilters\""))
        XCTAssertTrue(recipesRendered.contains("\"ingredientFilter\""))
        XCTAssertTrue(recipesRendered.contains("\"includeMode\" : \"any\""))
        XCTAssertTrue(recipesRendered.contains("\"includeTerms\""))
        XCTAssertTrue(recipesRendered.contains("\"excludeTerms\""))
        XCTAssertTrue(recipesRendered.contains("\"derivedConstraints\""))
        XCTAssertTrue(recipesRendered.contains("\"favoritesOnly\" : true"))
        XCTAssertTrue(recipesRendered.contains("\"minRating\" : 4"))
        XCTAssertTrue(recipesRendered.contains("\"categoryNames\""))
        XCTAssertTrue(recipesRendered.contains("\"maxTotalTimeMinutes\" : 30"))
        XCTAssertTrue(recipesRendered.contains("\"sort\""))
        XCTAssertTrue(recipesRendered.contains("\"fewest-ingredients\""))
        XCTAssertTrue(recipesRendered.contains("\"categories\""))
        XCTAssertTrue(recipesRendered.contains("\"Dinner\""))
        XCTAssertTrue(recipesRendered.contains("\"sourceName\""))
        XCTAssertTrue(recipesRendered.contains("\"Serious Eats\""))
        XCTAssertTrue(recipesRendered.contains("\"starRating\""))
        XCTAssertTrue(recipesRendered.contains("\"isFavorite\" : true"))
        XCTAssertTrue(recipesRendered.contains("\"derivedFeatures\""))
        XCTAssertTrue(recipesRendered.contains("\"totalTimeMinutes\" : 30"))
        XCTAssertTrue(recipesRendered.contains("\"usageStats\""))
        XCTAssertTrue(recipesRendered.contains("\"mealCount\" : 2"))
    }

    func testRenderDoctorReportIncludesStatusAndIndexFields() throws {
        let report = DoctorReport(
            sourceSnapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready for direct read-only Paprika access.",
                sourceType: PantrySourceType.paprikaSQLite,
                displayName: "default Paprika SQLite",
                implementation: "direct Paprika SQLite source",
                sourceLocation: "/Users/test/Paprika.sqlite",
                schemaFlavor: "paprika-3-core-data",
                accessMode: "read-only",
                queryOnly: true,
                journalMode: "wal",
                hasWriteAheadLogFiles: true,
                paprikaSync: PaprikaSyncDetails(
                    lastSyncAt: Date(timeIntervalSince1970: 1_712_736_060),
                    signalSource: "group-container-preferences",
                    signalLocation: "/Users/test/Library/Preferences/test.plist"
                ),
                appInstallation: PaprikaAppInstallation(
                    appBundlePath: "/Applications/Paprika Recipe Manager 3.app",
                    bundleIdentifier: "com.hindsightlabs.paprika.mac.v3",
                    executablePath: "/Applications/Paprika Recipe Manager 3.app/Contents/MacOS/Paprika Recipe Manager 3",
                    executablePresent: true,
                    customURLSchemes: []
                )
            ),
            indexStats: PantryIndexStats(
                recipeSearchDocumentCount: 6,
                recipeFeatureCount: 6,
                recipeFeaturesWithTotalTimeCount: 5,
                recipeFeaturesWithIngredientLineCountCount: 6,
                recipeUsageStatsCount: 4,
                recipeUsageStatsWithLastMealAtCount: 3,
                recipeUsageStatsWithGapArrayCount: 2,
                recipeUsageTotalMealCount: 7,
                lastRecipeSearchRun: PantryIndexRun(
                    id: 1,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-search",
                    recipeCount: 6,
                    errorMessage: nil
                ),
                lastSuccessfulRecipeSearchRun: PantryIndexRun(
                    id: 1,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-search",
                    recipeCount: 6,
                    errorMessage: nil
                ),
                lastRecipeFeatureRun: PantryIndexRun(
                    id: 2,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-features",
                    recipeCount: 6,
                    errorMessage: nil
                ),
                lastSuccessfulRecipeFeatureRun: PantryIndexRun(
                    id: 2,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-features",
                    recipeCount: 6,
                    errorMessage: nil
                ),
                lastRecipeUsageRun: PantryIndexRun(
                    id: 3,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-usage",
                    recipeCount: 4,
                    errorMessage: nil
                ),
                lastSuccessfulRecipeUsageRun: PantryIndexRun(
                    id: 3,
                    startedAt: Date(timeIntervalSince1970: 1_712_736_000),
                    finishedAt: Date(timeIntervalSince1970: 1_712_736_060),
                    status: .success,
                    indexName: "recipe-usage",
                    recipeCount: 4,
                    errorMessage: nil
                )
            ),
            paths: PantryPaths(
                homeDirectory: URL(fileURLWithPath: "/tmp/pantry"),
                configFile: URL(fileURLWithPath: "/tmp/pantry/config.json"),
                databaseFile: URL(fileURLWithPath: "/tmp/pantry/pantry.sqlite")
            ),
            now: Date(timeIntervalSince1970: 1_712_736_120)
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.contains("\"status\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"sourceStatus\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"indexStatus\" : \"ready\""))
        XCTAssertTrue(rendered.contains("\"recipeSearchDocumentCount\" : 6"))
        XCTAssertTrue(rendered.contains("\"displayName\" : \"default Paprika SQLite\""))
        XCTAssertTrue(rendered.contains("\"schemaFlavor\" : \"paprika-3-core-data\""))
        XCTAssertTrue(rendered.contains("\"queryOnly\" : true"))
        XCTAssertTrue(rendered.contains("\"appInstallation\""))
        XCTAssertTrue(rendered.contains("\"paprikaSyncFreshnessSeconds\" : 60"))
        XCTAssertTrue(rendered.contains("\"recipeSearchFreshnessSeconds\" : 60"))
    }
}
