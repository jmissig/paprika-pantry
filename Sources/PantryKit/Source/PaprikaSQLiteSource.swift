import Foundation
import GRDB

public enum PaprikaSQLiteSourceError: Error, LocalizedError, Equatable {
    case missingDatabase(URL)
    case unreadableDatabase(String)
    case missingTable(String)
    case missingColumn(table: String, column: String)
    case readOnlyGuardFailed(String)
    case recipeNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .missingDatabase(let databaseURL):
            return "Paprika.sqlite was not found at \(databaseURL.path)."
        case .unreadableDatabase(let message):
            return "Paprika.sqlite could not be read: \(message)"
        case .missingTable(let table):
            return "Paprika.sqlite is missing the \(table) table."
        case .missingColumn(let table, let column):
            return "Paprika.sqlite is missing the \(column) column in \(table)."
        case .readOnlyGuardFailed(let message):
            return "Paprika.sqlite did not open with the required read-only guard: \(message)"
        case .recipeNotFound(let uid):
            return "Paprika.sqlite does not contain recipe \(uid)."
        }
    }
}

public struct PaprikaSQLiteSourceInspection: Equatable, Sendable {
    public let schemaFlavor: String
    public let requiredTables: [String]
    public let accessMode: String
    public let queryOnly: Bool
    public let journalMode: String
    public let hasWriteAheadLogFiles: Bool
    public let paprikaSync: PaprikaSyncDetails?
    public let appInstallation: PaprikaAppInstallation?

    public init(
        schemaFlavor: String,
        requiredTables: [String],
        accessMode: String,
        queryOnly: Bool,
        journalMode: String,
        hasWriteAheadLogFiles: Bool,
        paprikaSync: PaprikaSyncDetails? = nil,
        appInstallation: PaprikaAppInstallation? = nil
    ) {
        self.schemaFlavor = schemaFlavor
        self.requiredTables = requiredTables
        self.accessMode = accessMode
        self.queryOnly = queryOnly
        self.journalMode = journalMode
        self.hasWriteAheadLogFiles = hasWriteAheadLogFiles
        self.paprikaSync = paprikaSync
        self.appInstallation = appInstallation
    }
}

public final class PaprikaSQLiteSource: MealsReadablePantrySource, GroceriesReadablePantrySource, PantryItemsReadablePantrySource, @unchecked Sendable {
    public let databaseURL: URL
    public let inspection: PaprikaSQLiteSourceInspection

    private let dbQueue: DatabaseQueue
    private let schema: PaprikaSQLiteSchema

    public init(
        databaseURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let databaseURL = databaseURL.standardizedFileURL
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw PaprikaSQLiteSourceError.missingDatabase(databaseURL)
        }

        do {
            let dbQueue = try Self.openReadOnlyQueue(databaseURL: databaseURL)
            let schema = try dbQueue.read(PaprikaSQLiteSchema.inspect)
            let inspection = try dbQueue.read { db in
                try schema.makeInspection(
                    db: db,
                    databaseURL: databaseURL,
                    fileManager: fileManager
                )
            }

            self.dbQueue = dbQueue
            self.schema = schema
            self.databaseURL = databaseURL
            self.inspection = inspection
        } catch let error as PaprikaSQLiteSourceError {
            throw error
        } catch {
            throw PaprikaSQLiteSourceError.unreadableDatabase(error.localizedDescription)
        }
    }

    public func listRecipeStubs() async throws -> [SourceRecipeStub] {
        let sql = """
            SELECT
                ZUID AS uid,
                ZNAME AS name,
                \(self.schema.recipeSyncHashExpression) AS source_fingerprint,
                \(self.schema.recipeDeletedExpression) AS is_deleted
            FROM ZRECIPE
            WHERE ZUID IS NOT NULL
              AND ZNAME IS NOT NULL
            ORDER BY ZNAME COLLATE NOCASE, ZUID
            """

        return try await dbQueue.read { db in
            try Row.fetchAll(db, sql: sql).map { row in
                SourceRecipeStub(
                    uid: row["uid"],
                    name: row["name"],
                    sourceFingerprint: row["source_fingerprint"],
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func listRecipeCategories() async throws -> [SourceRecipeCategory] {
        let sql = """
            SELECT
                ZUID AS uid,
                ZNAME AS name,
                \(self.schema.categoryDeletedExpression) AS is_deleted
            FROM ZRECIPECATEGORY
            WHERE ZUID IS NOT NULL
              AND ZNAME IS NOT NULL
            ORDER BY ZNAME COLLATE NOCASE, ZUID
            """

        return try await dbQueue.read { db in
            try Row.fetchAll(db, sql: sql).map { row in
                SourceRecipeCategory(
                    uid: row["uid"],
                    name: row["name"],
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func listMeals() async throws -> [SourceMeal] {
        let sql = """
            SELECT
                meals.ZUID AS uid,
                COALESCE(NULLIF(meals.ZNAME, ''), recipe.ZNAME) AS name,
                \(self.schema.mealTimestampExpression) AS scheduled_at,
                meal_type.ZNAME AS meal_type,
                recipe.ZUID AS recipe_uid,
                recipe.ZNAME AS recipe_name,
                \(self.schema.mealDeletedExpression) AS is_deleted
            FROM ZMEAL meals
            LEFT JOIN ZMEALTYPE meal_type
                ON meal_type.Z_PK = meals.ZTYPE
            LEFT JOIN ZRECIPE recipe
                ON recipe.Z_PK = meals.ZRECIPE
            WHERE meals.ZUID IS NOT NULL
              AND COALESCE(NULLIF(meals.ZNAME, ''), recipe.ZNAME) IS NOT NULL
            ORDER BY scheduled_at DESC, name COLLATE NOCASE, uid
            """

        return try await dbQueue.read { db in
            try self.schema.requireMealSupport()
            return try Row.fetchAll(db, sql: sql).map { row in
                SourceMeal(
                    uid: row["uid"],
                    name: row["name"],
                    scheduledAt: row["scheduled_at"],
                    mealType: row["meal_type"],
                    recipeUID: row["recipe_uid"],
                    recipeName: row["recipe_name"],
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func listGroceryItems() async throws -> [SourceGroceryItem] {
        let sql = """
            SELECT
                items.ZUID AS uid,
                COALESCE(NULLIF(items.ZNAME, ''), NULLIF(items.ZINGREDIENT, ''), NULLIF(items.ZRECIPENAME, '')) AS name,
                \(self.schema.optionalTextExpression(column: "ZQUANTITY", from: self.schema.groceryItemColumns, tableAlias: "items")) AS quantity,
                \(self.schema.optionalTextExpression(column: "ZINSTRUCTION", from: self.schema.groceryItemColumns, tableAlias: "items")) AS instruction,
                \(self.schema.groceryListNameExpression) AS grocery_list_name,
                \(self.schema.groceryAisleNameExpression) AS aisle_name,
                \(self.schema.optionalTextExpression(column: "ZINGREDIENT", from: self.schema.groceryItemColumns, tableAlias: "items")) AS ingredient_name,
                \(self.schema.optionalTextExpression(column: "ZRECIPENAME", from: self.schema.groceryItemColumns, tableAlias: "items")) AS recipe_name,
                \(self.schema.groceryPurchasedExpression) AS is_purchased,
                \(self.schema.groceryDeletedExpression) AS is_deleted
            FROM ZGROCERYITEM items
            LEFT JOIN ZGROCERYLIST grocery_list
                ON grocery_list.Z_PK = items.ZLIST
            LEFT JOIN ZGROCERYAISLE grocery_aisle
                ON grocery_aisle.Z_PK = items.ZAISLE
            WHERE items.ZUID IS NOT NULL
              AND COALESCE(NULLIF(items.ZNAME, ''), NULLIF(items.ZINGREDIENT, ''), NULLIF(items.ZRECIPENAME, '')) IS NOT NULL
            ORDER BY is_purchased ASC, grocery_list_name COLLATE NOCASE, aisle_name COLLATE NOCASE, name COLLATE NOCASE, uid
            """

        return try await dbQueue.read { db in
            try self.schema.requireGrocerySupport()
            return try Row.fetchAll(db, sql: sql).map { row in
                SourceGroceryItem(
                    uid: row["uid"],
                    name: row["name"],
                    quantity: row["quantity"],
                    instruction: row["instruction"],
                    groceryListName: row["grocery_list_name"],
                    aisleName: row["aisle_name"],
                    ingredientName: row["ingredient_name"],
                    recipeName: row["recipe_name"],
                    isPurchased: Self.decodeBoolean(row["is_purchased"]),
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func listPantryItems() async throws -> [SourcePantryItem] {
        let sql = """
            SELECT
                items.ZUID AS uid,
                COALESCE(NULLIF(items.ZINGREDIENT, ''), NULLIF(items.ZQUANTITY, '')) AS name,
                \(self.schema.optionalTextExpression(column: "ZQUANTITY", from: self.schema.pantryItemColumns, tableAlias: "items")) AS quantity,
                \(self.schema.pantryAisleNameExpression) AS aisle_name,
                \(self.schema.optionalTextExpression(column: "ZINGREDIENT", from: self.schema.pantryItemColumns, tableAlias: "items")) AS ingredient_name,
                \(self.schema.timestampExpression(column: "ZPURCHASEDATE", from: self.schema.pantryItemColumns, tableAlias: "items")) AS purchase_date,
                \(self.schema.timestampExpression(column: "ZEXPIRATIONDATE", from: self.schema.pantryItemColumns, tableAlias: "items")) AS expiration_date,
                \(self.schema.pantryHasExpirationExpression) AS has_expiration,
                \(self.schema.pantryInStockExpression) AS is_in_stock,
                \(self.schema.pantryDeletedExpression) AS is_deleted
            FROM ZPANTRYITEM items
            LEFT JOIN ZGROCERYAISLE grocery_aisle
                ON grocery_aisle.Z_PK = items.ZAISLE
            WHERE items.ZUID IS NOT NULL
              AND COALESCE(NULLIF(items.ZINGREDIENT, ''), NULLIF(items.ZQUANTITY, '')) IS NOT NULL
            ORDER BY is_in_stock DESC, aisle_name COLLATE NOCASE, name COLLATE NOCASE, uid
            """

        return try await dbQueue.read { db in
            try self.schema.requirePantrySupport()
            return try Row.fetchAll(db, sql: sql).map { row in
                SourcePantryItem(
                    uid: row["uid"],
                    name: row["name"],
                    quantity: row["quantity"],
                    aisleName: row["aisle_name"],
                    ingredientName: row["ingredient_name"],
                    purchaseDate: row["purchase_date"],
                    expirationDate: row["expiration_date"],
                    hasExpiration: Self.decodeBoolean(row["has_expiration"]),
                    isInStock: Self.decodeBoolean(row["is_in_stock"]),
                    isDeleted: Self.decodeBoolean(row["is_deleted"])
                )
            }
        }
    }

    public func fetchRecipe(uid: String) async throws -> SourceRecipe {
        let sql = """
            SELECT
                Z_PK AS id,
                ZUID AS uid,
                ZNAME AS name,
                \(self.schema.optionalTextExpression(column: "ZSOURCE")) AS source_name,
                \(self.schema.optionalTextExpression(column: "ZINGREDIENTS")) AS ingredients,
                \(self.schema.optionalTextExpression(column: "ZDIRECTIONS")) AS directions,
                \(self.schema.notesExpression) AS notes,
                \(self.schema.ratingExpression) AS star_rating,
                \(self.schema.favoriteExpression) AS is_favorite,
                \(self.schema.optionalTextExpression(column: "ZPREPTIME")) AS prep_time,
                \(self.schema.optionalTextExpression(column: "ZCOOKTIME")) AS cook_time,
                \(self.schema.optionalTextExpression(column: "ZTOTALTIME")) AS total_time,
                \(self.schema.optionalTextExpression(column: "ZSERVINGS")) AS servings,
                \(self.schema.coreDataTimestampExpression(column: "ZCREATED")) AS created_at,
                NULL AS updated_at,
                \(self.schema.recipeSyncHashExpression) AS source_fingerprint,
                \(self.schema.recipeDeletedExpression) AS is_deleted
            FROM ZRECIPE
            WHERE ZUID = ?
            LIMIT 1
            """

        return try await dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: sql,
                arguments: [uid]
            ) else {
                throw PaprikaSQLiteSourceError.recipeNotFound(uid)
            }

            let recipeID: Int64 = row["id"]
            let categoryReferences = try self.fetchCategoryReferences(recipeID: recipeID, db: db)
            let rawJSON = try self.makeRawJSON(row: row, categoryReferences: categoryReferences)

            return SourceRecipe(
                uid: row["uid"],
                name: row["name"],
                categoryReferences: categoryReferences,
                sourceName: row["source_name"],
                ingredients: row["ingredients"],
                directions: row["directions"],
                notes: row["notes"],
                starRating: Self.decodeRating(row["star_rating"]),
                isFavorite: Self.decodeBoolean(row["is_favorite"]),
                prepTime: row["prep_time"],
                cookTime: row["cook_time"],
                totalTime: row["total_time"],
                servings: row["servings"],
                createdAt: row["created_at"],
                updatedAt: row["updated_at"],
                sourceFingerprint: row["source_fingerprint"],
                rawJSON: rawJSON
            )
        }
    }

    private static func openReadOnlyQueue(databaseURL: URL) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.readonly = true
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA query_only = 1")
        }

        return try DatabaseQueue(path: databaseURL.path, configuration: configuration)
    }

    private func fetchCategoryReferences(recipeID: Int64, db: Database) throws -> [String] {
        try String.fetchAll(
            db,
            sql: """
                SELECT categories.ZUID
                FROM Z_12CATEGORIES links
                INNER JOIN ZRECIPECATEGORY categories
                    ON categories.Z_PK = links.Z_13CATEGORIES
                WHERE links.Z_12RECIPES = ?
                  AND categories.ZUID IS NOT NULL
                ORDER BY categories.ZNAME COLLATE NOCASE, categories.ZUID
                """,
            arguments: [recipeID]
        )
    }

    private func makeRawJSON(row: Row, categoryReferences: [String]) throws -> String {
        let uid: String = row["uid"]
        let name: String = row["name"]
        let sourceName: String? = row["source_name"]
        let ingredients: String? = row["ingredients"]
        let directions: String? = row["directions"]
        let notes: String? = row["notes"]
        let prepTime: String? = row["prep_time"]
        let cookTime: String? = row["cook_time"]
        let totalTime: String? = row["total_time"]
        let servings: String? = row["servings"]
        let createdAt: String? = row["created_at"]
        let updatedAt: String? = row["updated_at"]
        let sourceFingerprint: String? = row["source_fingerprint"]

        var object: [String: Any] = [
            "uid": uid,
            "name": name,
            "category_uids": categoryReferences,
            "is_deleted": Self.decodeBoolean(row["is_deleted"]),
            "is_favorite": Self.decodeBoolean(row["is_favorite"]),
        ]

        Self.setOptionalValue(in: &object, key: "source", value: sourceName)
        Self.setOptionalValue(in: &object, key: "ingredients", value: ingredients)
        Self.setOptionalValue(in: &object, key: "directions", value: directions)
        Self.setOptionalValue(in: &object, key: "notes", value: notes)
        Self.setOptionalValue(in: &object, key: "rating", value: Self.decodeRating(row["star_rating"]))
        Self.setOptionalValue(in: &object, key: "prep_time", value: prepTime)
        Self.setOptionalValue(in: &object, key: "cook_time", value: cookTime)
        Self.setOptionalValue(in: &object, key: "total_time", value: totalTime)
        Self.setOptionalValue(in: &object, key: "servings", value: servings)
        Self.setOptionalValue(in: &object, key: "created", value: createdAt)
        Self.setOptionalValue(in: &object, key: "updated", value: updatedAt)
        Self.setOptionalValue(in: &object, key: "hash", value: sourceFingerprint)

        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        guard let rawJSON = String(data: data, encoding: .utf8) else {
            throw PaprikaSQLiteSourceError.unreadableDatabase("Database row payload was not valid UTF-8.")
        }
        return rawJSON
    }

    private static func setOptionalValue(
        in object: inout [String: Any],
        key: String,
        value: Any?
    ) {
        guard let value else {
            return
        }
        object[key] = value
    }

    private static func decodeBoolean(_ databaseValue: DatabaseValue) -> Bool {
        if let value = Int64.fromDatabaseValue(databaseValue) {
            return value != 0
        }

        if let value = Bool.fromDatabaseValue(databaseValue) {
            return value
        }

        return false
    }

    private static func decodeRating(_ databaseValue: DatabaseValue) -> Int? {
        guard let value = Int.fromDatabaseValue(databaseValue), value > 0 else {
            return nil
        }

        return value
    }
}

private struct PaprikaSQLiteSchema: Sendable {
    static let schemaFlavor = "paprika-3-core-data"
    static let requiredTables = [
        "ZRECIPE",
        "ZRECIPECATEGORY",
        "Z_12CATEGORIES",
        "Z_METADATA",
    ]

    let recipeColumns: Set<String>
    let categoryColumns: Set<String>
    let recipeCategoryLinkColumns: Set<String>
    let mealColumns: Set<String>?
    let mealTypeColumns: Set<String>?
    let groceryItemColumns: Set<String>?
    let groceryListColumns: Set<String>?
    let groceryAisleColumns: Set<String>?
    let pantryItemColumns: Set<String>?

    static func inspect(_ db: Database) throws -> PaprikaSQLiteSchema {
        for table in requiredTables {
            try requireTable(table, in: db)
        }

        let recipeColumns = try Set(db.columns(in: "ZRECIPE").map(\.name))
        let categoryColumns = try Set(db.columns(in: "ZRECIPECATEGORY").map(\.name))
        let recipeCategoryLinkColumns = try Set(db.columns(in: "Z_12CATEGORIES").map(\.name))
        let mealColumns = try db.tableExists("ZMEAL") ? Set(db.columns(in: "ZMEAL").map(\.name)) : nil
        let mealTypeColumns = try db.tableExists("ZMEALTYPE") ? Set(db.columns(in: "ZMEALTYPE").map(\.name)) : nil
        let groceryItemColumns = try db.tableExists("ZGROCERYITEM") ? Set(db.columns(in: "ZGROCERYITEM").map(\.name)) : nil
        let groceryListColumns = try db.tableExists("ZGROCERYLIST") ? Set(db.columns(in: "ZGROCERYLIST").map(\.name)) : nil
        let groceryAisleColumns = try db.tableExists("ZGROCERYAISLE") ? Set(db.columns(in: "ZGROCERYAISLE").map(\.name)) : nil
        let pantryItemColumns = try db.tableExists("ZPANTRYITEM") ? Set(db.columns(in: "ZPANTRYITEM").map(\.name)) : nil

        try requireColumn("Z_PK", in: "ZRECIPE", availableColumns: recipeColumns)
        try requireColumn("ZUID", in: "ZRECIPE", availableColumns: recipeColumns)
        try requireColumn("ZNAME", in: "ZRECIPE", availableColumns: recipeColumns)

        try requireColumn("Z_PK", in: "ZRECIPECATEGORY", availableColumns: categoryColumns)
        try requireColumn("ZUID", in: "ZRECIPECATEGORY", availableColumns: categoryColumns)
        try requireColumn("ZNAME", in: "ZRECIPECATEGORY", availableColumns: categoryColumns)

        try requireColumn("Z_12RECIPES", in: "Z_12CATEGORIES", availableColumns: recipeCategoryLinkColumns)
        try requireColumn("Z_13CATEGORIES", in: "Z_12CATEGORIES", availableColumns: recipeCategoryLinkColumns)

        if let mealColumns {
            try requireColumn("ZUID", in: "ZMEAL", availableColumns: mealColumns)
            try requireColumn("ZNAME", in: "ZMEAL", availableColumns: mealColumns)
        }

        if let groceryItemColumns {
            try requireColumn("ZUID", in: "ZGROCERYITEM", availableColumns: groceryItemColumns)
            try requireColumn("ZNAME", in: "ZGROCERYITEM", availableColumns: groceryItemColumns)
        }

        if let pantryItemColumns {
            try requireColumn("ZUID", in: "ZPANTRYITEM", availableColumns: pantryItemColumns)
            try requireColumn("ZINGREDIENT", in: "ZPANTRYITEM", availableColumns: pantryItemColumns)
        }

        return PaprikaSQLiteSchema(
            recipeColumns: recipeColumns,
            categoryColumns: categoryColumns,
            recipeCategoryLinkColumns: recipeCategoryLinkColumns,
            mealColumns: mealColumns,
            mealTypeColumns: mealTypeColumns,
            groceryItemColumns: groceryItemColumns,
            groceryListColumns: groceryListColumns,
            groceryAisleColumns: groceryAisleColumns,
            pantryItemColumns: pantryItemColumns
        )
    }

    var recipeSyncHashExpression: String {
        recipeColumns.contains("ZSYNCHASH") ? "ZSYNCHASH" : "NULL"
    }

    var recipeDeletedExpression: String {
        recipeColumns.contains("ZINTRASH") ? "COALESCE(ZINTRASH, 0)" : "0"
    }

    var categoryDeletedExpression: String {
        categoryColumns.contains("ZSTATUS")
            ? "CASE WHEN lower(COALESCE(ZSTATUS, '')) = 'deleted' THEN 1 ELSE 0 END"
            : "0"
    }

    var notesExpression: String {
        switch (recipeColumns.contains("ZNOTES"), recipeColumns.contains("ZDESCRIPTIONTEXT")) {
        case (true, true):
            return "COALESCE(NULLIF(ZNOTES, ''), ZDESCRIPTIONTEXT)"
        case (true, false):
            return "ZNOTES"
        case (false, true):
            return "ZDESCRIPTIONTEXT"
        case (false, false):
            return "NULL"
        }
    }

    var ratingExpression: String {
        recipeColumns.contains("ZRATING") ? "ZRATING" : "NULL"
    }

    var favoriteExpression: String {
        recipeColumns.contains("ZONFAVORITES") ? "COALESCE(ZONFAVORITES, 0)" : "0"
    }

    var mealDeletedExpression: String {
        guard let mealColumns, mealColumns.contains("ZSTATUS") else {
            return "0"
        }

        return "CASE WHEN lower(COALESCE(meals.ZSTATUS, '')) = 'deleted' THEN 1 ELSE 0 END"
    }

    var mealTimestampExpression: String {
        timestampExpression(column: "ZDATE", from: mealColumns, tableAlias: "meals")
    }

    var groceryPurchasedExpression: String {
        groceryItemColumns?.contains("ZPURCHASED") == true ? "COALESCE(items.ZPURCHASED, 0)" : "0"
    }

    var groceryDeletedExpression: String {
        guard let groceryItemColumns, groceryItemColumns.contains("ZSTATUS") else {
            return "0"
        }

        return "CASE WHEN lower(COALESCE(items.ZSTATUS, '')) = 'deleted' THEN 1 ELSE 0 END"
    }

    var groceryListNameExpression: String {
        let joinedListName = optionalTextExpression(column: "ZNAME", from: groceryListColumns, tableAlias: "grocery_list")
        return joinedListName
    }

    var pantryInStockExpression: String {
        pantryItemColumns?.contains("ZINSTOCK") == true ? "COALESCE(items.ZINSTOCK, 0)" : "0"
    }

    var pantryHasExpirationExpression: String {
        pantryItemColumns?.contains("ZHASEXPIRATION") == true ? "COALESCE(items.ZHASEXPIRATION, 0)" : "0"
    }

    var pantryDeletedExpression: String {
        guard let pantryItemColumns, pantryItemColumns.contains("ZSTATUS") else {
            return "0"
        }

        return "CASE WHEN lower(COALESCE(items.ZSTATUS, '')) = 'deleted' THEN 1 ELSE 0 END"
    }

    var pantryAisleNameExpression: String {
        let itemAisleName = optionalTextExpression(column: "ZAISLENAME", from: pantryItemColumns, tableAlias: "items")
        let joinedAisleName = optionalTextExpression(column: "ZNAME", from: groceryAisleColumns, tableAlias: "grocery_aisle")
        return "COALESCE(\(itemAisleName), \(joinedAisleName))"
    }

    var groceryAisleNameExpression: String {
        let itemAisleName = optionalTextExpression(column: "ZAISLENAME", from: groceryItemColumns, tableAlias: "items")
        let joinedAisleName = optionalTextExpression(column: "ZNAME", from: groceryAisleColumns, tableAlias: "grocery_aisle")
        return "COALESCE(\(itemAisleName), \(joinedAisleName))"
    }

    func optionalTextExpression(column: String) -> String {
        recipeColumns.contains(column) ? column : "NULL"
    }

    func optionalTextExpression(
        column: String,
        from availableColumns: Set<String>?,
        tableAlias: String? = nil
    ) -> String {
        guard let availableColumns, availableColumns.contains(column) else {
            return "NULL"
        }

        let qualifiedColumn = tableAlias.map { "\($0).\(column)" } ?? column
        return "NULLIF(\(qualifiedColumn), '')"
    }

    func coreDataTimestampExpression(column: String) -> String {
        timestampExpression(column: column, from: recipeColumns)
    }

    func timestampExpression(
        column: String,
        from availableColumns: Set<String>?,
        tableAlias: String? = nil
    ) -> String {
        guard let availableColumns, availableColumns.contains(column) else {
            return "NULL"
        }

        let qualifiedColumn = tableAlias.map { "\($0).\(column)" } ?? column
        return "CASE WHEN \(qualifiedColumn) IS NULL THEN NULL ELSE datetime(\(qualifiedColumn) + 978307200, 'unixepoch') END"
    }

    func requireMealSupport() throws {
        guard mealColumns != nil else {
            throw PaprikaSQLiteSourceError.missingTable("ZMEAL")
        }
    }

    func requireGrocerySupport() throws {
        guard groceryItemColumns != nil else {
            throw PaprikaSQLiteSourceError.missingTable("ZGROCERYITEM")
        }
    }

    func requirePantrySupport() throws {
        guard pantryItemColumns != nil else {
            throw PaprikaSQLiteSourceError.missingTable("ZPANTRYITEM")
        }
    }

    func makeInspection(
        db: Database,
        databaseURL: URL,
        fileManager: FileManager
    ) throws -> PaprikaSQLiteSourceInspection {
        let queryOnly = try Bool.fetchOne(db, sql: "PRAGMA query_only") ?? false
        guard queryOnly else {
            throw PaprikaSQLiteSourceError.readOnlyGuardFailed("PRAGMA query_only returned 0.")
        }

        let journalMode = try String.fetchOne(db, sql: "PRAGMA journal_mode") ?? "unknown"
        let hasWriteAheadLogFiles = fileManager.fileExists(
            atPath: databaseURL
                .deletingPathExtension()
                .appendingPathExtension("sqlite-wal")
                .path
        ) || fileManager.fileExists(atPath: databaseURL.path + "-wal")
        let paprikaSync = Self.inspectPaprikaSync(databaseURL: databaseURL, fileManager: fileManager)
        let appInstallation = Self.inspectPaprikaAppInstallation(fileManager: fileManager)

        return PaprikaSQLiteSourceInspection(
            schemaFlavor: Self.schemaFlavor,
            requiredTables: Self.requiredTables,
            accessMode: "read-only",
            queryOnly: queryOnly,
            journalMode: journalMode,
            hasWriteAheadLogFiles: hasWriteAheadLogFiles,
            paprikaSync: paprikaSync,
            appInstallation: appInstallation
        )
    }

    private static func inspectPaprikaSync(
        databaseURL: URL,
        fileManager: FileManager
    ) -> PaprikaSyncDetails? {
        for candidate in candidateSyncPreferenceFiles(databaseURL: databaseURL, fileManager: fileManager) {
            guard fileManager.fileExists(atPath: candidate.location.path) else {
                continue
            }

            guard
                let propertyList = readPropertyList(at: candidate.location),
                let lastSyncAt = decodePaprikaLastSyncDate(propertyList["LastSyncedDate"])
            else {
                continue
            }

            return PaprikaSyncDetails(
                lastSyncAt: lastSyncAt,
                signalSource: candidate.signalSource,
                signalLocation: candidate.location.path
            )
        }

        return nil
    }

    private static func inspectPaprikaAppInstallation(
        fileManager: FileManager
    ) -> PaprikaAppInstallation? {
        for appURL in candidateAppBundleURLs(fileManager: fileManager) {
            guard fileManager.fileExists(atPath: appURL.path) else {
                continue
            }

            let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
            let infoPlist = readPropertyList(at: infoPlistURL) ?? [:]
            let bundleIdentifier = infoPlist["CFBundleIdentifier"] as? String
            let executableName = infoPlist["CFBundleExecutable"] as? String
            let executableURL = executableName.map {
                appURL.appendingPathComponent("Contents/MacOS/\($0)")
            }
            let executablePresent = executableURL.map {
                fileManager.fileExists(atPath: $0.path)
            } ?? false

            return PaprikaAppInstallation(
                appBundlePath: appURL.path,
                bundleIdentifier: bundleIdentifier,
                executablePath: executableURL?.path,
                executablePresent: executablePresent,
                customURLSchemes: decodeCustomURLSchemes(from: infoPlist)
            )
        }

        return nil
    }

    private static func candidateSyncPreferenceFiles(
        databaseURL: URL,
        fileManager: FileManager
    ) -> [(signalSource: String, location: URL)] {
        var candidates = [(signalSource: String, location: URL)]()

        if
            let groupContainerURL = derivedGroupContainerURL(from: databaseURL),
            let containerIdentifier = groupContainerURL.lastPathComponent.trimmedNonEmpty
        {
            candidates.append(
                (
                    signalSource: "group-container-preferences",
                    location: groupContainerURL
                        .appendingPathComponent("Library/Preferences")
                        .appendingPathComponent("\(containerIdentifier).plist")
                )
            )
        }

        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        candidates.append(
            (
                signalSource: "group-container-preferences",
                location: homeDirectory
                    .appendingPathComponent("Library/Group Containers/72KVKW69K8.com.hindsightlabs.paprika.mac.v3/Library/Preferences/72KVKW69K8.com.hindsightlabs.paprika.mac.v3.plist")
            )
        )
        candidates.append(
            (
                signalSource: "container-preferences",
                location: homeDirectory
                    .appendingPathComponent("Library/Containers/com.hindsightlabs.paprika.mac.v3/Data/Library/Preferences/com.hindsightlabs.paprika.mac.v3.plist")
            )
        )

        var seenPaths = Set<String>()
        return candidates.filter { seenPaths.insert($0.location.path).inserted }
    }

    private static func derivedGroupContainerURL(from databaseURL: URL) -> URL? {
        let directory = databaseURL.deletingLastPathComponent()
        guard directory.lastPathComponent == "Database" else {
            return nil
        }

        let dataDirectory = directory.deletingLastPathComponent()
        guard dataDirectory.lastPathComponent == "Data" else {
            return nil
        }

        return dataDirectory.deletingLastPathComponent()
    }

    private static func candidateAppBundleURLs(fileManager: FileManager) -> [URL] {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return [
            URL(fileURLWithPath: "/Applications/Paprika Recipe Manager 3.app"),
            homeDirectory.appendingPathComponent("Applications/Paprika Recipe Manager 3.app"),
        ]
    }

    private static func readPropertyList(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        guard
            let propertyList = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = propertyList as? [String: Any]
        else {
            return nil
        }

        return dictionary
    }

    private static func decodePaprikaLastSyncDate(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }

        guard let text = value as? String else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: text)
    }

    private static func decodeCustomURLSchemes(from infoPlist: [String: Any]) -> [String] {
        guard let urlTypes = infoPlist["CFBundleURLTypes"] as? [[String: Any]] else {
            return []
        }

        return urlTypes
            .flatMap { entry in
                (entry["CFBundleURLSchemes"] as? [String]) ?? []
            }
            .filter { !$0.isEmpty }
    }

    private static func requireTable(_ name: String, in db: Database) throws {
        guard try db.tableExists(name) else {
            throw PaprikaSQLiteSourceError.missingTable(name)
        }
    }

    private static func requireColumn(
        _ name: String,
        in table: String,
        availableColumns: Set<String>
    ) throws {
        guard availableColumns.contains(name) else {
            throw PaprikaSQLiteSourceError.missingColumn(table: table, column: name)
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
