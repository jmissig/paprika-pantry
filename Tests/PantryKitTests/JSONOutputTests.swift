import XCTest
@testable import PantryKit

final class JSONOutputTests: XCTestCase {
    func testRenderProducesStructuredJSON() throws {
        let report = CommandReport(
            command: "groceries list",
            status: "stub",
            plannedPhase: "Later",
            message: "Direct grocery reads are intentionally deferred until after the first recipe read slice.",
            details: [:],
            paths: PantryPathReport(
                home: "/tmp/pantry",
                config: "/tmp/pantry/config.json",
                database: "/tmp/pantry/pantry.sqlite"
            )
        )

        let rendered = try JSONOutput.render(report)

        XCTAssertTrue(rendered.hasSuffix("\n"))
        XCTAssertTrue(rendered.contains("\"command\""))
        XCTAssertTrue(rendered.contains("\"groceries list\""))
        XCTAssertTrue(rendered.contains("\"paths\""))
        XCTAssertTrue(rendered.contains("\"database\""))
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
                        sourceRemoteHash: "hash-aaa",
                        derivedAt: Date(timeIntervalSince1970: 1_712_736_060),
                        prepTimeMinutes: 10,
                        cookTimeMinutes: 20,
                        totalTimeMinutes: 30,
                        totalTimeBasis: .summedPrepAndCook,
                        ingredientLineCount: 5,
                        ingredientLineCountBasis: .nonEmptyLines
                    )
                ),
            ],
            canonicalFilters: RecipeQueryFilters(favoritesOnly: true, minRating: 4, categoryNames: ["Dinner"]),
            derivedConstraints: RecipeDerivedConstraints(maxTotalTimeMinutes: 30),
            sort: .fewestIngredients,
            derivedReadPath: "sidecar-derived"
        )

        let recipesRendered = try JSONOutput.render(recipesReport)
        XCTAssertTrue(recipesRendered.contains("\"readPath\""))
        XCTAssertTrue(recipesRendered.contains("\"direct-source\""))
        XCTAssertTrue(recipesRendered.contains("\"derivedReadPath\""))
        XCTAssertTrue(recipesRendered.contains("\"sidecar-derived\""))
        XCTAssertTrue(recipesRendered.contains("\"canonicalFilters\""))
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
    }

    func testRenderDoctorReportIncludesStatusAndIndexFields() throws {
        let report = DoctorReport(
            sourceSnapshot: PantrySourceDoctorSnapshot(
                status: .ready,
                message: "The configured pantry source is ready for direct read-only Paprika access.",
                sourceKind: .paprikaSQLite,
                displayName: "default Paprika SQLite",
                implementation: "direct Paprika SQLite source",
                sourceLocation: "/Users/test/Paprika.sqlite"
            ),
            indexStats: PantryIndexStats(
                recipeSearchDocumentCount: 6,
                recipeFeatureCount: 6,
                recipeFeaturesWithTotalTimeCount: 5,
                recipeFeaturesWithIngredientLineCountCount: 6,
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
        XCTAssertTrue(rendered.contains("\"recipeSearchFreshnessSeconds\" : 60"))
    }
}
