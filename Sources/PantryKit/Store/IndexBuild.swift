import Foundation
import GRDB

extension PantrySidecarStore {
    public func rebuildRecipeIndexes(
        from source: any PantrySource,
        refreshIngredientPairEvidence: Bool = true,
        now: @escaping @Sendable () -> Date = Date.init,
        phaseClock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) async throws -> RecipeIndexesRebuildSummary {
        try await buildRecipeIndexes(from: source, refreshIngredientPairEvidence: refreshIngredientPairEvidence, now: now, phaseClock: phaseClock)
    }

    func buildRecipeIndexes(
        from source: any PantrySource,
        refreshIngredientPairEvidence: Bool = true,
        now: @escaping @Sendable () -> Date = Date.init,
        phaseClock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        hooks: IndexBuildHooks = IndexBuildHooks()
    ) async throws -> RecipeIndexesRebuildSummary {
        switch role {
        case .writer, .fixture: break
        default: throw IndexCompatibilityError.invalidRole("Index writes require an index writer")
        }
        try Task.checkCancellation()
        let baseline = try await dbQueue.read(IndexBuildBaseline.capture)
        try await hooks.afterBaseline?()
        try Task.checkCancellation()
        let source: any PantrySource = try (source as? any IndexablePantrySource)?.makeIndexSnapshot() ?? source
        try Task.checkCancellation()
        let contract = (source as? any IndexablePantrySource)?.indexContract
        if !refreshIngredientPairEvidence, let contract { try baseline.requireCompatible(contract) }
        let dependencySignature = try (source as? any IndexablePantrySource)?.categoryDependencySignature()
        let previousDependencies = baseline.provenance.first { $0.family == "recipe-search" }?.dependencySignature
        let generation = UUID().uuidString
        var phaseTimings = RecipeIndexPhaseTimingRecorder(clock: phaseClock)
        let startedAt = now()
        let names: [String] = [Self.recipeSearchIndexName, Self.recipeFeatureIndexName, Self.recipeIngredientIndexName, Self.recipeUsageIndexName]
            + (refreshIngredientPairEvidence ? [Self.ingredientPairIndexName] : [])
        // Atomic setup: a failed metadata write cannot leave orphan running rows.
        let ids = try await dbQueue.write { db in
            try baseline.requireUnchanged(db)
            return try names.map { name in
                let id = try startIndexRun(named: name, startedAt: startedAt, in: db)
                try db.execute(sql: "UPDATE index_runs SET source_contract=?, generation=? WHERE id=?", arguments: [contract?.encoded, generation, id])
                return id
            }
        }
        let searchRunID = ids[0], featureRunID = ids[1], ingredientRunID = ids[2], usageRunID = ids[3]
        let ingredientPairRunID = refreshIngredientPairEvidence ? ids[4] : nil
        do {
            try Task.checkCancellation()
            var phaseItemCounts = [RecipeIndexPhase: Int]()
            let categoriesStartedAt = phaseClock()
            let categoryNamesByUID = try await loadCategoryNamesByUID(from: source)
            phaseTimings.add(.sourceCategories, startedAt: categoriesStartedAt)
            phaseItemCounts[.sourceCategories] = categoryNamesByUID.count

            let stubsStartedAt = phaseClock()
            let stubs = try await source.listRecipeStubs()
            phaseTimings.add(.sourceRecipeStubs, startedAt: stubsStartedAt)
            let activeStubs = stubs.filter { !$0.isDeleted }
            phaseItemCounts[.sourceRecipeStubs] = stubs.count
            let activeRecipeUIDs = Set(activeStubs.map(\.uid))
            let routineUpdatePlan = try makeRecipeRoutineUpdatePlan(
                activeStubs: activeStubs,
                usePartialUpdate: !refreshIngredientPairEvidence && dependencySignature == previousDependencies,
                baseline: baseline
            )
            let recipeStubsToFetch = refreshIngredientPairEvidence
                ? activeStubs
                : routineUpdatePlan.changedStubs
            let meals: [SourceMeal]
            if let mealsSource = source as? any MealsReadablePantrySource {
                let mealsStartedAt = phaseClock()
                meals = try await mealsSource.listMeals()
                phaseTimings.add(.sourceMeals, startedAt: mealsStartedAt)
            } else {
                meals = []
                let mealsStartedAt = phaseClock()
                phaseTimings.add(.sourceMeals, startedAt: mealsStartedAt)
            }
            phaseItemCounts[.sourceMeals] = meals.count

            var documents = [RecipeSearchDocument]()
            var features = [RecipeDerivedFeatures]()
            var ingredientIndexes = [RecipeIngredientIndex]()
            let usageStats = phaseTimings.measure(.deriveUsageStats) {
                RecipeIndexDerivation.deriveUsageStats(
                    from: meals,
                    activeRecipeUIDs: activeRecipeUIDs,
                    derivedAt: startedAt,
                    referenceDate: startedAt
                )
            }
            documents.reserveCapacity(activeStubs.count)
            features.reserveCapacity(activeStubs.count)
            ingredientIndexes.reserveCapacity(activeStubs.count)

            if recipeStubsToFetch.isEmpty {
                phaseTimings.add(.sourceFetchRecipes, startedAt: phaseClock())
                phaseTimings.add(.deriveRecipeDocumentsFeaturesIngredients, startedAt: phaseClock())
            }
            for stub in recipeStubsToFetch {
                try Task.checkCancellation()
                let fetchRecipeStartedAt = phaseClock()
                let recipe = try await source.fetchRecipe(uid: stub.uid)
                phaseTimings.add(.sourceFetchRecipes, startedAt: fetchRecipeStartedAt)
                let recipeDerivationStartedAt = phaseClock()
                let rows = RecipeIndexDerivation.makeRoutineRecipeIndexRows(
                    from: recipe,
                    categoryNamesByUID: categoryNamesByUID,
                    derivedAt: startedAt
                )
                documents.append(rows.document)
                features.append(rows.features)
                if let ingredientIndex = rows.ingredientIndex {
                    ingredientIndexes.append(ingredientIndex)
                }
                phaseTimings.add(.deriveRecipeDocumentsFeaturesIngredients, startedAt: recipeDerivationStartedAt)
            }
            phaseItemCounts[.sourceFetchRecipes] = recipeStubsToFetch.count
            phaseItemCounts[.deriveRecipeDocumentsFeaturesIngredients] = recipeStubsToFetch.count
            phaseItemCounts[.deriveUsageStats] = meals.count

            try Task.checkCancellation()
            let indexedAt = now()
            let indexedAtString = DatabaseTimestamp.encode(indexedAt)
            let sortedDocuments: [RecipeSearchDocument]
            let sortedFeatures: [RecipeDerivedFeatures]
            let sortedIngredientIndexes: [RecipeIngredientIndex]
            let sortedUsageStats: [RecipeUsageStats]
            let recipeSearchDocumentCount: Int
            (
                sortedDocuments,
                sortedFeatures,
                sortedIngredientIndexes,
                sortedUsageStats,
                recipeSearchDocumentCount
            ) = phaseTimings.measure(.sortAndCount) {
                let sortedDocuments = documents.sorted(by: RecipeIndexDerivation.sortSearchDocuments)
                let sortedFeatures = features.sorted { $0.uid < $1.uid }
                let sortedIngredientIndexes = ingredientIndexes.sorted { $0.uid < $1.uid }
                let sortedUsageStats = usageStats.stats.sorted { $0.uid < $1.uid }
                return (
                    sortedDocuments,
                    sortedFeatures,
                    sortedIngredientIndexes,
                    sortedUsageStats,
                    sortedDocuments.count
                )
            }
            phaseItemCounts[.sortAndCount] = recipeStubsToFetch.count

            let sortedIngredientPairSummaries: [IngredientPairEvidenceSummary]
            let sortedIngredientPairEvidence: [IngredientPairRecipeEvidenceRow]
            if refreshIngredientPairEvidence {
                try Task.checkCancellation()
                (sortedIngredientPairSummaries, sortedIngredientPairEvidence) = phaseTimings.measure(.deriveIngredientPairs) {
                    let ingredientPairDerivation = RecipeIndexDerivation.deriveIngredientPairEvidence(
                        ingredientIndexes: sortedIngredientIndexes,
                        documents: sortedDocuments,
                        usageStats: sortedUsageStats,
                        derivedAt: indexedAt
                    )
                    let sortedIngredientPairSummaries = ingredientPairDerivation.summaries.sorted {
                        if $0.tokenA != $1.tokenA {
                            return $0.tokenA < $1.tokenA
                        }

                        return $0.tokenB < $1.tokenB
                    }
                    let sortedIngredientPairEvidence = ingredientPairDerivation.recipeEvidence.sorted {
                        if $0.tokenA != $1.tokenA {
                            return $0.tokenA < $1.tokenA
                        }

                        if $0.tokenB != $1.tokenB {
                            return $0.tokenB < $1.tokenB
                        }

                        return $0.recipeUID < $1.recipeUID
                    }
                    return (sortedIngredientPairSummaries, sortedIngredientPairEvidence)
                }
            } else {
                sortedIngredientPairSummaries = []
                sortedIngredientPairEvidence = []
            }
            let linkedMealCount = usageStats.linkedMealCount
            let totalMealCount = usageStats.totalMealCount
            let ingredientPairSummaryCount = sortedIngredientPairSummaries.count
            let ingredientPairRecipeEvidenceCount = sortedIngredientPairEvidence.count
            if refreshIngredientPairEvidence {
                phaseItemCounts[.deriveIngredientPairs] = ingredientPairRecipeEvidenceCount
            }
            let sourceState = Self.makeStoredSourceState(from: source, observedAt: indexedAt)
            let writeTransactionStartedAt = phaseClock()
            try await hooks.beforePublication?()
            try Task.checkCancellation()
            let transactionResult = try await dbQueue.write { db in
                try baseline.requireUnchanged(db)
                if refreshIngredientPairEvidence {
                    try Self.dropIngredientPairSecondaryIndexes(in: db)
                }

                if refreshIngredientPairEvidence {
                    try db.execute(sql: "DELETE FROM recipe_search_documents")
                    try db.execute(sql: "DELETE FROM recipe_search_fts")
                    try db.execute(sql: "DELETE FROM recipe_features")
                    try db.execute(sql: "DELETE FROM recipe_ingredient_tokens")
                    try db.execute(sql: "DELETE FROM recipe_ingredient_lines")
                } else {
                    let replacedRecipeUIDs = Set(sortedDocuments.map(\.uid))
                    let staleRecipeUIDs = replacedRecipeUIDs.union(routineUpdatePlan.deletedRecipeUIDs)
                    try Self.deleteRecipeOwnedIndexRows(recipeUIDs: staleRecipeUIDs, in: db)
                }

                try db.execute(sql: "DELETE FROM recipe_usage_stats")
                try db.execute(sql: "DELETE FROM recipe_usage_summary")
                if refreshIngredientPairEvidence {
                    try db.execute(sql: "DELETE FROM ingredient_pair_recipe_evidence")
                    try db.execute(sql: "DELETE FROM ingredient_pair_summaries")
                }
                try db.execute(sql: "DELETE FROM source_state")

                try hooks.duringPublication?(db)
                for document in sortedDocuments {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_search_documents (
                            uid,
                            name,
                            categories,
                            source_name,
                            ingredients,
                            description,
                            notes,
                            source_fingerprint,
                            indexed_at,
                            is_favorite,
                            star_rating
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            document.uid,
                            document.name,
                            Self.encodeCategories(document.categories),
                            document.sourceName,
                            document.ingredients,
                            document.description,
                            document.notes,
                            document.sourceFingerprint,
                            indexedAtString,
                            document.isFavorite,
                            document.starRating,
                        ]
                    )

                    try db.execute(
                        sql: """
                        INSERT INTO recipe_search_fts (
                            uid,
                            name,
                            categories,
                            source_name,
                            ingredients,
                            description,
                            notes
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            document.uid,
                            document.name,
                            document.categories.joined(separator: " "),
                            document.sourceName,
                            document.ingredients,
                            document.description,
                            document.notes,
                        ]
                    )
                }

                for feature in sortedFeatures {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_features (
                            uid,
                            source_fingerprint,
                            derived_at,
                            prep_time_minutes,
                            cook_time_minutes,
                            total_time_minutes,
                            total_time_basis,
                            ingredient_line_count,
                            ingredient_line_count_basis
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            feature.uid,
                            feature.sourceFingerprint,
                            indexedAtString,
                            feature.prepTimeMinutes,
                            feature.cookTimeMinutes,
                            feature.totalTimeMinutes,
                            feature.totalTimeBasis?.rawValue,
                            feature.ingredientLineCount,
                            feature.ingredientLineCountBasis?.rawValue,
                        ]
                    )
                }

                for ingredientIndex in sortedIngredientIndexes {
                    for line in ingredientIndex.lines {
                        try db.execute(
                            sql: """
                            INSERT INTO recipe_ingredient_lines (
                                recipe_uid,
                                line_number,
                                source_text,
                                normalized_text,
                                source_fingerprint,
                                derived_at
                            ) VALUES (?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [
                                ingredientIndex.uid,
                                line.lineNumber,
                                line.sourceText,
                                line.normalizedText,
                                ingredientIndex.sourceFingerprint,
                                indexedAtString,
                            ]
                        )

                        for (offset, token) in line.normalizedTokens.enumerated() {
                            try db.execute(
                                sql: """
                                INSERT INTO recipe_ingredient_tokens (
                                    recipe_uid,
                                    line_number,
                                    token,
                                    token_position
                                ) VALUES (?, ?, ?, ?)
                                """,
                                arguments: [
                                    ingredientIndex.uid,
                                    line.lineNumber,
                                    token,
                                    offset + 1,
                                ]
                            )
                        }
                    }
                }

                for usageStat in sortedUsageStats {
                    try db.execute(
                        sql: """
                        INSERT INTO recipe_usage_stats (
                            uid,
                            derived_at,
                            times_cooked,
                            last_cooked_at,
                            meal_count,
                            first_meal_at,
                            first_cooked_at,
                            last_meal_at,
                            meal_gap_days_json,
                            days_spanned_by_meals,
                            median_meal_gap_days,
                            meal_share
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            usageStat.uid,
                            indexedAtString,
                            usageStat.mealCount,
                            usageStat.lastMealAt,
                            usageStat.mealCount,
                            usageStat.firstMealAt,
                            usageStat.firstCookedAt,
                            usageStat.lastMealAt,
                            Self.encodeIntArrayJSON(usageStat.mealGapDays),
                            usageStat.daysSpannedByMeals,
                            usageStat.medianMealGapDays,
                            usageStat.mealShare,
                        ]
                    )
                }

                try db.execute(
                    sql: """
                    INSERT INTO recipe_usage_summary (
                        summary_key,
                        derived_at,
                        total_meal_count
                    ) VALUES (?, ?, ?)
                    """,
                    arguments: [
                        Self.recipeUsageSummaryKey,
                        indexedAtString,
                        totalMealCount,
                    ]
                )

                if refreshIngredientPairEvidence {
                    let insertIngredientPairSummaryStatement = try db.makeStatement(
                        sql: """
                        INSERT INTO ingredient_pair_summaries (
                        basis,
                        token_a,
                        token_b,
                        derived_at,
                        recipe_count,
                        cooked_recipe_count,
                        cooked_meal_count,
                        favorite_recipe_count,
                        rated_recipe_count,
                        average_star_rating,
                        first_meal_at,
                        last_meal_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """
                    )

                    for summary in sortedIngredientPairSummaries {
                        try insertIngredientPairSummaryStatement.execute(arguments: [
                            summary.basis,
                            summary.tokenA,
                            summary.tokenB,
                            indexedAtString,
                            summary.recipeCount,
                            summary.cookedRecipeCount,
                            summary.cookedMealCount,
                            summary.favoriteRecipeCount,
                            summary.ratedRecipeCount,
                            summary.averageStarRating,
                            summary.firstMealAt,
                            summary.lastMealAt,
                        ])
                    }

                    let insertIngredientPairRecipeEvidenceStatement = try db.makeStatement(
                        sql: """
                        INSERT INTO ingredient_pair_recipe_evidence (
                        basis,
                        token_a,
                        token_b,
                        recipe_uid,
                        recipe_name,
                        source_name,
                        token_a_line_numbers_json,
                        token_b_line_numbers_json,
                        is_favorite,
                        star_rating,
                        meal_count,
                        first_meal_at,
                        last_meal_at,
                        derived_at
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """
                    )

                    for evidence in sortedIngredientPairEvidence {
                        try insertIngredientPairRecipeEvidenceStatement.execute(arguments: [
                            evidence.basis,
                            evidence.tokenA,
                            evidence.tokenB,
                            evidence.recipeUID,
                            evidence.recipeName,
                            evidence.sourceName,
                            Self.encodeIntArrayJSON(evidence.tokenALineNumbers),
                            Self.encodeIntArrayJSON(evidence.tokenBLineNumbers),
                            evidence.isFavorite,
                            evidence.starRating,
                            evidence.mealCount,
                            evidence.firstMealAt,
                            evidence.lastMealAt,
                            indexedAtString,
                        ])
                    }

                    try Self.createIngredientPairSecondaryIndexes(in: db)
                }

                if let sourceState {
                    try writeStoredSourceState(sourceState, in: db)
                }

                if let contract {
                    try writeProvenance(contract: contract, families: refreshIngredientPairEvidence ? Self.allFamilies : Self.routineFamilies,
                        generation: generation, at: indexedAtString, dependencies: dependencySignature, db: db)
                } else {
                    // Non-Paprika fixture/custom sources cannot inherit a prior Paprika contract.
                    for family in (refreshIngredientPairEvidence ? Self.allFamilies : Self.routineFamilies) {
                        try db.execute(sql: "DELETE FROM index_provenance WHERE family=?", arguments: [family])
                    }
                }
                let storedCounts = try Self.fetchRecipeIndexStoredCounts(db: db)
                let finishedAt = now()
                try finishIndexRun(
                    id: searchRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: storedCounts.recipeSearchDocumentCount,
                    errorMessage: nil,
                    in: db
                )
                try finishIndexRun(
                    id: featureRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: storedCounts.recipeFeatureCount,
                    errorMessage: nil,
                    in: db
                )
                try finishIndexRun(
                    id: ingredientRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: storedCounts.recipeIngredientRecipeCount,
                    errorMessage: nil,
                    in: db
                )
                try finishIndexRun(
                    id: usageRunID,
                    status: .success,
                    finishedAt: finishedAt,
                    recipeCount: storedCounts.recipeUsageStatsCount,
                    errorMessage: nil,
                    in: db
                )
                if let ingredientPairRunID {
                    try finishIndexRun(
                        id: ingredientPairRunID,
                        status: .success,
                        finishedAt: finishedAt,
                        recipeCount: ingredientPairSummaryCount,
                        errorMessage: nil,
                        in: db
                    )
                }
                return (finishedAt: finishedAt, storedCounts: storedCounts)
            }
            await hooks.afterPublication?()
            phaseTimings.add(.sidecarWriteTransaction, startedAt: writeTransactionStartedAt)
            phaseItemCounts[.sidecarWriteTransaction] = refreshIngredientPairEvidence
                ? recipeSearchDocumentCount
                : routineUpdatePlan.changedStubs.count + routineUpdatePlan.deletedRecipeUIDs.count
            let finishedAt = max(transactionResult.finishedAt, now())
            let storedCounts = transactionResult.storedCounts

            return RecipeIndexesRebuildSummary(
                startedAt: startedAt,
                finishedAt: finishedAt,
                recipeSearchDocumentCount: storedCounts.recipeSearchDocumentCount,
                recipeFeatureCount: storedCounts.recipeFeatureCount,
                recipeFeaturesWithTotalTimeCount: storedCounts.recipeFeaturesWithTotalTimeCount,
                recipeFeaturesWithIngredientLineCountCount: storedCounts.recipeFeaturesWithIngredientLineCountCount,
                recipeIngredientRecipeCount: storedCounts.recipeIngredientRecipeCount,
                recipeIngredientLineCount: storedCounts.recipeIngredientLineCount,
                recipeIngredientTokenCount: storedCounts.recipeIngredientTokenCount,
                recipeUsageStatsCount: storedCounts.recipeUsageStatsCount,
                recipeUsageStatsWithLastMealAtCount: storedCounts.recipeUsageStatsWithLastMealAtCount,
                recipeUsageStatsWithGapArrayCount: storedCounts.recipeUsageStatsWithGapArrayCount,
                linkedMealCount: linkedMealCount,
                totalMealCount: totalMealCount,
                refreshedIngredientPairEvidence: refreshIngredientPairEvidence,
                ingredientPairSummaryCount: ingredientPairSummaryCount,
                ingredientPairRecipeEvidenceCount: ingredientPairRecipeEvidenceCount,
                changedRecipeCount: refreshIngredientPairEvidence ? 0 : routineUpdatePlan.changedStubs.count,
                skippedRecipeCount: refreshIngredientPairEvidence ? 0 : routineUpdatePlan.skippedRecipeCount,
                deletedRecipeCount: refreshIngredientPairEvidence ? 0 : routineUpdatePlan.deletedRecipeUIDs.count,
                phaseTimings: phaseTimings.timings(itemCounts: phaseItemCounts),
                sourceState: sourceState
            )
        } catch {
            // Synchronous cleanup remains possible even when the task is cancelled.
            // Keep the original error if failure reporting itself cannot be persisted.
            recordBuildFailure(ids: ids, at: now(), error: error)
            throw error
        }
    }

    private func recordBuildFailure(ids: [Int64], at date: Date, error: Error) {
        try? dbQueue.write { db in
            for id in ids {
                try finishIndexRun(id: id, status: .failed, finishedAt: date, recipeCount: 0,
                                   errorMessage: String(describing: error), in: db)
            }
        }
    }

    private static func makeStoredSourceState(
        from source: any PantrySource,
        observedAt: Date
    ) -> PantryStoredSourceState? {
        (source as? any IndexablePantrySource)?.storedSourceState(observedAt: observedAt)
    }

    private func writeStoredSourceState(
        _ sourceState: PantryStoredSourceState,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            INSERT INTO source_state (
                source_type,
                source_location,
                observed_at,
                paprika_last_sync_at,
                paprika_sync_signal_source,
                paprika_sync_signal_location
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                sourceState.sourceType,
                sourceState.sourceLocation,
                DatabaseTimestamp.encode(sourceState.observedAt),
                sourceState.paprikaSync.map { DatabaseTimestamp.encode($0.lastSyncAt) },
                sourceState.paprikaSync?.signalSource,
                sourceState.paprikaSync?.signalLocation,
            ]
        )
    }

    private func startIndexRun(named indexName: String, startedAt: Date, in db: Database) throws -> Int64 {
            try db.execute(
                sql: """
                INSERT INTO index_runs (
                    started_at,
                    status,
                    index_name
                ) VALUES (?, ?, ?)
                """,
                arguments: [
                    DatabaseTimestamp.encode(startedAt),
                    PantryIndexRunStatus.running.rawValue,
                    indexName,
                ]
            )
            return db.lastInsertedRowID
    }

    private func finishIndexRun(
        id: Int64,
        status: PantryIndexRunStatus,
        finishedAt: Date,
        recipeCount: Int,
        errorMessage: String?
    ) throws {
        try dbQueue.write { db in
            try finishIndexRun(
                id: id,
                status: status,
                finishedAt: finishedAt,
                recipeCount: recipeCount,
                errorMessage: errorMessage,
                in: db
            )
        }
    }

    private func finishIndexRun(
        id: Int64,
        status: PantryIndexRunStatus,
        finishedAt: Date,
        recipeCount: Int,
        errorMessage: String?,
        in db: Database
    ) throws {
        try db.execute(
            sql: """
            UPDATE index_runs
            SET finished_at = ?,
                status = ?,
                recipe_count = ?,
                error_message = ?
            WHERE id = ?
            """,
            arguments: [
                DatabaseTimestamp.encode(finishedAt),
                status.rawValue,
                recipeCount,
                errorMessage,
                id,
            ]
        )
    }

    private func loadCategoryNamesByUID(from source: any PantrySource) async throws -> [String: String] {
        let categories = try await source.listRecipeCategories()
        return Dictionary(
            uniqueKeysWithValues: categories
                .filter { !$0.isDeleted }
                .map { ($0.uid, $0.name) }
        )
    }

    private func makeRecipeRoutineUpdatePlan(
        activeStubs: [SourceRecipeStub],
        usePartialUpdate: Bool,
        baseline: IndexBuildBaseline
    ) throws -> RecipeRoutineUpdatePlan {
        guard usePartialUpdate else {
            return RecipeRoutineUpdatePlan(
                changedStubs: activeStubs,
                skippedRecipeCount: 0,
                deletedRecipeUIDs: try dbQueue.read { db in
                    try baseline.requireUnchanged(db)
                    return Set(try Self.fetchExistingRoutineRecipeIndexRows(db: db).keys).subtracting(Set(activeStubs.map(\.uid)))
                }
            )
        }

        let activeRecipeUIDs = Set(activeStubs.map(\.uid))
        return try dbQueue.read { db in
            try baseline.requireUnchanged(db)
            guard
                try latestSuccessfulIndexRun(named: Self.recipeSearchIndexName, db: db) != nil,
                try latestSuccessfulIndexRun(named: Self.recipeFeatureIndexName, db: db) != nil,
                try latestSuccessfulIndexRun(named: Self.recipeIngredientIndexName, db: db) != nil
            else {
                return RecipeRoutineUpdatePlan(
                    changedStubs: activeStubs,
                    skippedRecipeCount: 0,
                    deletedRecipeUIDs: Set(try Self.fetchExistingRoutineRecipeIndexRows(db: db).keys).subtracting(activeRecipeUIDs)
                )
            }

            let existingRows = try Self.fetchExistingRoutineRecipeIndexRows(db: db)
            var changedStubs = [SourceRecipeStub]()
            var skippedRecipeCount = 0

            for stub in activeStubs {
                guard
                    let sourceFingerprint = stub.sourceFingerprint,
                    let existingRow = existingRows[stub.uid],
                    existingRow.searchSourceFingerprint == sourceFingerprint,
                    existingRow.featureSourceFingerprint == sourceFingerprint,
                    try Self.ingredientRowsComplete(uid: stub.uid, db: db)
                else {
                    changedStubs.append(stub)
                    continue
                }

                skippedRecipeCount += 1
            }

            return RecipeRoutineUpdatePlan(
                changedStubs: changedStubs,
                skippedRecipeCount: skippedRecipeCount,
                deletedRecipeUIDs: Set(existingRows.keys).subtracting(activeRecipeUIDs)
            )
        }
    }

    private static func ingredientRowsComplete(uid: String, db: Database) throws -> Bool {
        let expected = try Int.fetchOne(db, sql: "SELECT COALESCE(ingredient_line_count,0) FROM recipe_features WHERE uid=?", arguments: [uid]) ?? -1
        let actual = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_ingredient_lines WHERE recipe_uid=?", arguments: [uid]) ?? 0
        guard expected == actual else { return false }
        let lines = try Row.fetchAll(db, sql: "SELECT line_number, normalized_text FROM recipe_ingredient_lines WHERE recipe_uid=?", arguments: [uid])
        for line in lines {
            let normalized: String? = line["normalized_text"]
            let number: Int = line["line_number"]
            let tokens = try String.fetchAll(db, sql: "SELECT token FROM recipe_ingredient_tokens WHERE recipe_uid=? AND line_number=? ORDER BY token_position", arguments: [uid, number])
            if tokens != (normalized?.split(separator: " ").map(String.init) ?? []) { return false }
        }
        return true
    }

    private static func fetchExistingRoutineRecipeIndexRows(
        db: Database
    ) throws -> [String: ExistingRoutineRecipeIndexRow] {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT
                recipe_search_documents.uid,
                recipe_search_documents.source_fingerprint AS search_source_fingerprint,
                recipe_features.source_fingerprint AS feature_source_fingerprint
            FROM recipe_search_documents
            LEFT JOIN recipe_features
                ON recipe_features.uid = recipe_search_documents.uid
            """
        )

        return Dictionary(
            uniqueKeysWithValues: rows.map { row in
                (
                    row["uid"],
                    ExistingRoutineRecipeIndexRow(
                        searchSourceFingerprint: row["search_source_fingerprint"],
                        featureSourceFingerprint: row["feature_source_fingerprint"]
                    )
                )
            }
        )
    }

    private static func deleteRecipeOwnedIndexRows(
        recipeUIDs: Set<String>,
        in db: Database
    ) throws {
        let sortedUIDs = recipeUIDs.sorted()
        guard !sortedUIDs.isEmpty else {
            return
        }

        var arguments = Self.statementArguments(for: sortedUIDs)
        let placeholders = sqlPlaceholders(count: sortedUIDs.count)
        try db.execute(
            sql: "DELETE FROM recipe_search_documents WHERE uid IN (\(placeholders))",
            arguments: arguments
        )

        arguments = Self.statementArguments(for: sortedUIDs)
        try db.execute(
            sql: "DELETE FROM recipe_search_fts WHERE uid IN (\(placeholders))",
            arguments: arguments
        )

        arguments = Self.statementArguments(for: sortedUIDs)
        try db.execute(
            sql: "DELETE FROM recipe_features WHERE uid IN (\(placeholders))",
            arguments: arguments
        )

        arguments = Self.statementArguments(for: sortedUIDs)
        try db.execute(
            sql: "DELETE FROM recipe_ingredient_tokens WHERE recipe_uid IN (\(placeholders))",
            arguments: arguments
        )

        arguments = Self.statementArguments(for: sortedUIDs)
        try db.execute(
            sql: "DELETE FROM recipe_ingredient_lines WHERE recipe_uid IN (\(placeholders))",
            arguments: arguments
        )
    }

    private static func statementArguments(for values: [String]) -> StatementArguments {
        var arguments = StatementArguments()
        for value in values {
            arguments += [value]
        }
        return arguments
    }

    private static func fetchRecipeIndexStoredCounts(db: Database) throws -> RecipeIndexStoredCounts {
        RecipeIndexStoredCounts(
            recipeSearchDocumentCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_search_documents") ?? 0,
            recipeFeatureCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_features") ?? 0,
            recipeFeaturesWithTotalTimeCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipe_features WHERE total_time_minutes IS NOT NULL"
            ) ?? 0,
            recipeFeaturesWithIngredientLineCountCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipe_features WHERE ingredient_line_count IS NOT NULL"
            ) ?? 0,
            recipeIngredientRecipeCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(DISTINCT recipe_uid) FROM recipe_ingredient_lines"
            ) ?? 0,
            recipeIngredientLineCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_ingredient_lines") ?? 0,
            recipeIngredientTokenCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_ingredient_tokens") ?? 0,
            recipeUsageStatsCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recipe_usage_stats") ?? 0,
            recipeUsageStatsWithLastMealAtCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipe_usage_stats WHERE last_meal_at IS NOT NULL"
            ) ?? 0,
            recipeUsageStatsWithGapArrayCount: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM recipe_usage_stats WHERE meal_gap_days_json IS NOT NULL"
            ) ?? 0
        )
    }

    private static func dropIngredientPairSecondaryIndexes(in db: Database) throws {
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_token_a")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_token_b")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_recipe_count")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_summaries_on_cooked_meal_count")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_recipe_evidence_on_recipe_uid")
        try db.execute(sql: "DROP INDEX IF EXISTS ingredient_pair_recipe_evidence_on_pair")
    }

    private static func createIngredientPairSecondaryIndexes(in db: Database) throws {
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_token_a ON ingredient_pair_summaries(token_a)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_token_b ON ingredient_pair_summaries(token_b)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_recipe_count ON ingredient_pair_summaries(recipe_count)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_summaries_on_cooked_meal_count ON ingredient_pair_summaries(cooked_meal_count)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_recipe_evidence_on_recipe_uid ON ingredient_pair_recipe_evidence(recipe_uid)")
        try db.execute(sql: "CREATE INDEX IF NOT EXISTS ingredient_pair_recipe_evidence_on_pair ON ingredient_pair_recipe_evidence(basis, token_a, token_b)")
    }

    private static func encodeCategories(_ categories: [String]) -> String {
        categories.joined(separator: "\u{1F}")
    }

    private static func encodeIntArrayJSON(_ values: [Int]?) -> String? {
        guard let values else {
            return nil
        }

        return "[\(values.map(String.init).joined(separator: ","))]"
    }
}

private enum RecipeIndexPhase: String, CaseIterable {
    case sourceCategories = "source.categories"
    case sourceRecipeStubs = "source.recipe_stubs"
    case sourceMeals = "source.meals"
    case deriveUsageStats = "derive.usage_stats"
    case sourceFetchRecipes = "source.fetch_recipes"
    case deriveRecipeDocumentsFeaturesIngredients = "derive.recipe_documents_features_ingredients"
    case sortAndCount = "sort_and_count"
    case deriveIngredientPairs = "derive.ingredient_pairs"
    case sidecarWriteTransaction = "sidecar.write_transaction"
}

private struct RecipeIndexPhaseTimingRecorder {
    private let clock: @Sendable () -> TimeInterval
    private var durationsByPhase = [RecipeIndexPhase: TimeInterval]()

    init(clock: @escaping @Sendable () -> TimeInterval) {
        self.clock = clock
    }

    mutating func add(_ phase: RecipeIndexPhase, startedAt start: TimeInterval) {
        let duration = max(0, clock() - start)
        durationsByPhase[phase, default: 0] += duration
    }

    mutating func measure<T>(_ phase: RecipeIndexPhase, _ work: () throws -> T) rethrows -> T {
        let start = clock()
        defer {
            add(phase, startedAt: start)
        }
        return try work()
    }

    func timings(itemCounts: [RecipeIndexPhase: Int]) -> [RecipeIndexPhaseTiming] {
        RecipeIndexPhase.allCases.compactMap { phase in
            guard let duration = durationsByPhase[phase] else {
                return nil
            }

            return RecipeIndexPhaseTiming(
                phase: phase.rawValue,
                durationMilliseconds: Int((duration * 1_000).rounded()),
                itemCount: itemCounts[phase]
            )
        }
    }
}

private struct RecipeRoutineUpdatePlan: Sendable {
    let changedStubs: [SourceRecipeStub]
    let skippedRecipeCount: Int
    let deletedRecipeUIDs: Set<String>
}

private struct ExistingRoutineRecipeIndexRow: Sendable {
    let searchSourceFingerprint: String?
    let featureSourceFingerprint: String?
}

private struct RecipeIndexStoredCounts: Sendable {
    let recipeSearchDocumentCount: Int
    let recipeFeatureCount: Int
    let recipeFeaturesWithTotalTimeCount: Int
    let recipeFeaturesWithIngredientLineCountCount: Int
    let recipeIngredientRecipeCount: Int
    let recipeIngredientLineCount: Int
    let recipeIngredientTokenCount: Int
    let recipeUsageStatsCount: Int
    let recipeUsageStatsWithLastMealAtCount: Int
    let recipeUsageStatsWithGapArrayCount: Int
}

