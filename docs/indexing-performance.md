# Indexing Performance

`index update` and `index rebuild` report phase timings in their rebuild summary. Human output includes a compact `phase_durations_ms` line, and JSON output exposes the same data as `summary.phaseTimings`.

Current measured phases:

- `source.categories`
- `source.recipe_stubs`
- `source.meals`
- `derive.usage_stats`
- `source.fetch_recipes`
- `derive.recipe_documents_features_ingredients`
- `sort_and_count`
- `derive.ingredient_pairs` (`index rebuild` only)
- `sidecar.write_transaction`

Partial index updates should be evidence-first. Do not optimize a visible phase just because it exists in the pipeline. Run the current command against real local Paprika data with `--format json`, identify the phase or phases that are inordinately slow, then target only those measured slow phases.

Preserve correctness and rebuildability over speed. Pairings remain descriptive evidence, not recommendations.

## Routine Partial Update

`index update` is the narrow partial path for routine recipe-owned rows. It compares active recipe stubs with existing sidecar `source_fingerprint` values and only fetches and rewrites recipe search documents, derived feature rows, and ingredient-token rows for new or changed recipes. It also removes recipe-owned rows for recipes that no longer appear as active source stubs. Recipes without a usable source fingerprint are treated as changed.

`index rebuild` remains the full reset path and rewrites all routine indexes plus ingredient-pair evidence.

Usage stats are still a full refresh during `index update`. Meal edits can change `recipe_usage_stats` and source/cookbook usage aggregates even when no recipe fingerprint changed, and there is not yet a safe meal-level partial update contract. This keeps daily updates correct while avoiding the measured waste of refetching and rewriting thousands of unchanged recipe-owned rows.

Ingredient pair evidence is not touched by `index update`. Run `index rebuild` when pairings should be refreshed.


## Local Timing Snapshot — 2026-04-27

Before the routine partial-update path, local real-data `index update --format json` over 3,599 active recipes took about 7 seconds. The largest routine phase was `sidecar.write_transaction` at about 4.3 seconds because the command rewrote all recipe-owned sidecar rows even when no recipes had changed.

After the partial-update path, a no-recipe-change local `index update --format json` reported:

- `changedRecipeCount`: 0
- `skippedRecipeCount`: 3,599
- `deletedRecipeCount`: 0
- `source.fetch_recipes`: 0 ms / 0 items
- `derive.recipe_documents_features_ingredients`: 0 ms / 0 items
- `sidecar.write_transaction`: about 0.5 seconds / 0 recipe-owned row changes
- total command window: about 1 second

This confirms the daily-path optimization is aimed at the measured waste: refetching and rewriting thousands of unchanged recipe-owned rows. Usage stats still refresh fully for correctness.
