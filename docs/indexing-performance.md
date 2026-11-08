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

Keep corpus- and machine-specific benchmark snapshots in ignored `local/benchmarks/` files. Committed documentation should describe the measurement method and the behavior it is intended to validate without publishing private corpus details.

## Version 2 compatibility and dependency invalidation

Named sidecar migrations add per-family `index_provenance` and attempt provenance
on `index_runs`. Source identity, supported schema signature, adapter version and
derivation version must match before a production derived read or partial update.
Unknown legacy provenance requires explicit `index rebuild`, not inferred freshness.
The initial v3/v4 transition rebuilds every family; regular updates leave pairing
provenance untouched. A failed transaction preserves the prior rows and provenance.

A source snapshot is captured with GRDB's SQLite backup API into an in-memory
queue before extraction. This includes committed WAL data and avoids holding a
source read transaction through expensive derivation/sidecar writing. Snapshot
memory scales with the source database size, not the larger derived sidecar size.

Category names and relationship membership are hashed independently of recipe
sync hashes. Changes disable routine recipe skips so FTS cannot retain old category
labels. Missing ingredient lines/tokens also prevent skipping unchanged recipes.
Only adapter-consumed schema fields affect compatibility; unrelated additive
columns change the diagnostic digest but do not force rebuilding.
