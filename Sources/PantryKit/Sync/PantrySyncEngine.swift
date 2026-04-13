import Foundation

public struct SyncSummary: Codable, Equatable, Sendable {
    public let startedAt: Date
    public let finishedAt: Date
    public let status: PantrySyncRunStatus
    public let recipesSeen: Int
    public let changedRecipeCount: Int
    public let deletedRecipeCount: Int

    public init(
        startedAt: Date,
        finishedAt: Date,
        status: PantrySyncRunStatus,
        recipesSeen: Int,
        changedRecipeCount: Int,
        deletedRecipeCount: Int
    ) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.recipesSeen = recipesSeen
        self.changedRecipeCount = changedRecipeCount
        self.deletedRecipeCount = deletedRecipeCount
    }
}

public protocol PantrySyncEngine: Sendable {
    func run() async throws -> SyncSummary
}

public struct RecipeMirrorSyncEngine: PantrySyncEngine {
    private let remoteClient: any PaprikaRemoteClient
    private let store: PantryStore
    private let now: @Sendable () -> Date

    public init(
        remoteClient: any PaprikaRemoteClient,
        store: PantryStore,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.remoteClient = remoteClient
        self.store = store
        self.now = now
    }

    public func run() async throws -> SyncSummary {
        let startedAt = now()
        let syncRunID = try store.startSyncRun(startedAt: startedAt)

        var recipesSeen = 0
        var changedRecipeCount = 0

        do {
            let remoteStubs = try await remoteClient.listRecipeStubs()
            let activeStubs = remoteStubs.filter { !$0.isDeleted }
            recipesSeen = activeStubs.count

            let remoteCategories = try await remoteClient.listRecipeCategories()
            let categoryNamesByUID = Dictionary(
                uniqueKeysWithValues: remoteCategories
                    .filter { !$0.isDeleted }
                    .map { ($0.uid, $0.name) }
            )

            let localIndex = try store.fetchRecipeIndex()
            let changedStubs = activeStubs.filter { stub in
                guard let existing = localIndex[stub.uid] else {
                    return true
                }

                return existing.isDeleted || existing.remoteHash != stub.hash
            }
            changedRecipeCount = changedStubs.count

            var mirroredRecipes = [MirroredRecipeInput]()
            mirroredRecipes.reserveCapacity(changedStubs.count)

            for stub in changedStubs {
                let remoteRecipe = try await remoteClient.fetchRecipe(uid: stub.uid)
                mirroredRecipes.append(
                    MirroredRecipeInput(
                        uid: remoteRecipe.uid,
                        name: remoteRecipe.name,
                        categories: resolvedCategories(
                            remoteRecipe.categoryReferences,
                            categoryNamesByUID: categoryNamesByUID
                        ),
                        sourceName: remoteRecipe.sourceName,
                        ingredients: remoteRecipe.ingredients,
                        directions: remoteRecipe.directions,
                        notes: remoteRecipe.notes,
                        starRating: remoteRecipe.starRating,
                        isFavorite: remoteRecipe.isFavorite,
                        prepTime: remoteRecipe.prepTime,
                        cookTime: remoteRecipe.cookTime,
                        totalTime: remoteRecipe.totalTime,
                        servings: remoteRecipe.servings,
                        createdAt: remoteRecipe.createdAt,
                        updatedAt: remoteRecipe.updatedAt,
                        remoteHash: remoteRecipe.remoteHash ?? stub.hash,
                        rawJSON: remoteRecipe.rawJSON
                    )
                )
            }

            let finishedAt = now()
            var deletedRecipeCount = 0

            try store.write { db in
                for recipe in mirroredRecipes {
                    try store.upsertRecipe(recipe, syncedAt: finishedAt, in: db)
                }

                deletedRecipeCount = try store.tombstoneRecipes(
                    missingFrom: Set(activeStubs.map(\.uid)),
                    syncedAt: finishedAt,
                    in: db
                )

                try store.finishSyncRun(
                    id: syncRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipesSeen: recipesSeen,
                    recipesChanged: changedRecipeCount,
                    recipesDeleted: deletedRecipeCount,
                    errorMessage: nil,
                    in: db
                )
            }

            return SyncSummary(
                startedAt: startedAt,
                finishedAt: finishedAt,
                status: .success,
                recipesSeen: recipesSeen,
                changedRecipeCount: changedRecipeCount,
                deletedRecipeCount: deletedRecipeCount
            )
        } catch {
            let finishedAt = now()
            try? store.finishSyncRun(
                id: syncRunID,
                status: .failed,
                finishedAt: finishedAt,
                recipesSeen: recipesSeen,
                recipesChanged: changedRecipeCount,
                recipesDeleted: 0,
                errorMessage: error.localizedDescription
            )
            throw error
        }
    }

    private func resolvedCategories(
        _ references: [String],
        categoryNamesByUID: [String: String]
    ) -> [String] {
        references.map { categoryNamesByUID[$0] ?? $0 }
    }
}
