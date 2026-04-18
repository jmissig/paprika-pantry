# Recipe Meal History Facts, Phase 1 Spec

## Goal

Extend `paprika-pantry`'s existing sidecar-derived recipe usage layer into a richer, still purely descriptive per-recipe meal-history facts layer derived from Paprika meal history.

This phase should deepen the current `RecipeUsageStats` path rather than introduce a parallel subsystem.

## Product shape

The layer should remain:
- sidecar-derived
- read-only with respect to the real Paprika database
- purely descriptive
- free of heuristics, buckets, classifications, or interpretation
- free of ingredient/source/rating analysis
- free of time-normalized rates
- free of LLM involvement

## Agreed semantics

Use Paprika meal `scheduledAt` as the meal timestamp.

Ignore:
- deleted meals
- meals with missing `scheduledAt`
- meals whose `scheduledAt` is in the future

For per-recipe facts, also ignore meals with missing `recipeUID`.

For dataset-level denominator facts, `total_meal_count` should include all qualifying meals with a valid non-future `scheduledAt`, even if `recipeUID` is missing.

Duplicate same-day meals count separately.

## Per-recipe facts to derive

For each recipe UID, derive and store:
- `meal_count`
- `first_meal_at`
- `last_meal_at`
- `meal_gap_days`
  - full ordered list of consecutive gaps in days
  - preserve time order
- `days_spanned_by_meals`
  - `last_meal_at - first_meal_at` in whole days
- `median_meal_gap_days`
- `meal_share`
  - `meal_count / total_meal_count`

Also keep:
- `derived_at`

Null when fewer than 2 qualifying meals:
- `meal_gap_days`
- `median_meal_gap_days`
- `days_spanned_by_meals`

Do not store:
- `days_since_last_meal`

Compute `days_since_last_meal` at query/report time from `last_meal_at`.

## Mapping to current repo shape

This should evolve the existing usage layer centered around:
- `Sources/PantryKit/Store/PantryStore.swift`
- `Sources/PantryKit/Recipes/RecipeReadService.swift`
- `Sources/PantryKit/Model/RecipeReports.swift`
- `Sources/PantryKit/CLI/RecipeCommands.swift`
- existing sidecar table `recipe_usage_stats`

Recommendation:
- keep the usage concept as the repo-native home for meal-history facts
- expand `RecipeUsageStats` rather than creating a second sibling type unless implementation pressure clearly justifies a split

If a rename is tempting, defer it for now. Phase 1 should preserve repo continuity.

## Sidecar schema direction

Prefer evolving `recipe_usage_stats` in place.

Add columns to `recipe_usage_stats`:
- `meal_count` integer not null
- `first_meal_at` text null
- `last_meal_at` text null
- `meal_gap_days_json` text null
- `days_spanned_by_meals` integer null
- `median_meal_gap_days` real null
- `meal_share` real null

Compatibility note:
- `times_cooked` currently exists and is the old public concept
- in Phase 1, either:
  1. keep `times_cooked` physically present as a compatibility column and write the same value as `meal_count`, or
  2. replace it at the schema/model level and update all callers in one migration pass

Recommended option for Phase 1:
- prefer a clean transition in code to `meal_count`
- if migration complexity is materially lower, temporarily keep `times_cooked` as a compatibility/storage alias during migration

Also capture dataset-level denominator during rebuild:
- `total_meal_count`

Recommended storage for denominator:
- do not duplicate `total_meal_count` into every row unless it simplifies query/report behavior substantially
- prefer one of:
  - a small sidecar metadata table entry, or
  - an extension of existing source/index state storage

If that is awkward in Phase 1, storing `total_meal_count` redundantly per row is acceptable as an implementation convenience, but it is not the ideal shape.

## Swift model direction

Evolve `RecipeUsageStats` to carry meal-history facts.

Target shape:

```swift
public struct RecipeUsageStats: Codable, Equatable, Sendable {
    public let uid: String
    public let derivedAt: Date
    public let mealCount: Int
    public let firstMealAt: String?
    public let lastMealAt: String?
    public let mealGapDays: [Int]?
    public let daysSpannedByMeals: Int?
    public let medianMealGapDays: Double?
    public let mealShare: Double?
}
```

Query-time only helper logic may compute:
- `daysSinceLastMeal(now:)`

Do not store `daysSinceLastMeal` in the sidecar.

## Derivation logic

Keep derivation in the current index rebuild path in `PantryStore`.

Today the usage derivation already happens during `rebuildRecipeIndexes(from:)` and consumes `source.listMeals()` when available.

Phase 1 should:
1. keep that overall flow
2. replace the lightweight counting logic with a richer derivation pass
3. preserve the existing index run accounting and write ordering

Recommended internal derivation steps:
1. load meals from the source if meal support exists
2. filter to qualifying meals for denominator:
   - not deleted
   - has non-empty `scheduledAt`
   - parsed timestamp is not in the future
3. count those rows as `total_meal_count`
4. further filter to per-recipe qualifying meals:
   - all of the above
   - has non-empty `recipeUID`
5. group qualifying per-recipe meals by `recipeUID`
6. sort each recipe's meals by timestamp ascending, with stable tie handling
7. derive:
   - `meal_count`
   - `first_meal_at`
   - `last_meal_at`
   - ordered consecutive integer day gaps
   - `days_spanned_by_meals`
   - `median_meal_gap_days`
   - `meal_share`
8. write the derived rows to `recipe_usage_stats`

## Time calculations

Use a single clear day-difference rule and test it heavily.

Recommended rule for Phase 1:
- parse stored meal timestamps as actual timestamps
- compute gap values in whole days using calendar day boundaries in a consistent calendar/timezone strategy
- use the same strategy for `days_spanned_by_meals` and query-time `days_since_last_meal`

Important: pick one rule and document it in tests so we do not silently mix 24-hour differences with calendar-day differences.

## CLI and report surfaces for Phase 1

Do not add a new top-level command family yet.

Expose the richer facts first through existing surfaces:

### `recipes show`
Add fields when usage stats are present:
- `meal_count`
- `first_meal_at`
- `last_meal_at`
- `meal_gap_days`
- `days_spanned_by_meals`
- `median_meal_gap_days`
- `meal_share`
- query-time `days_since_last_meal`

### `recipes list`
Include compact usage evidence in human and JSON output.
Prefer concise evidence lines rather than a wall of fields.
CSV may initially include only the most stable scalar fields, for example:
- `meal_count`
- `last_meal_at`
- `days_spanned_by_meals`
- `median_meal_gap_days`
- `meal_share`

Avoid putting raw `meal_gap_days` arrays into CSV in Phase 1.

### `recipes search`
Same display philosophy as `recipes list`.
No new interpretation or ranking logic is required in Phase 1.
The existing usage-aware ranking may continue to use count/recency semantics after being updated to the renamed fields.

### `index stats`
Update status reporting so the usage layer remains legible. Suggested additions:
- usage row count
- rows with `last_meal_at`
- rows with gap arrays
- captured `total_meal_count` if stored centrally

### `index rebuild` report
Update summary fields so rebuild output reflects the richer usage layer, not just old `times_cooked` counts.

## Sorting and filtering

Phase 1 should expose the facts in existing recipe outputs first.

Optional if straightforward:
- update current usage-based sort paths to use `meal_count` and `last_meal_at`

Not required for Phase 1:
- dedicated new filter flags for meal-history fields
- dedicated `recipes usage` or `recipes history` commands

Those can come after the layer is stable.

## Migration guidance

This change touches existing persisted sidecar state.

Migration should:
- preserve the current table if practical
- add the new columns safely
- handle older local-first cleanup migrations without reintroducing legacy sync-era shape
- remain idempotent

If schema evolution becomes messy, a pragmatic fallback is acceptable:
- migrate by rebuilding the table contents from source during the next `index rebuild`
- but the migration still needs to leave the DB schema in a coherent state before rebuild

## Edge cases to test

Add or update tests for:
- no meals at all
- meals present but all deleted
- meals with missing `scheduledAt`
- meals with future `scheduledAt`
- meals with missing `recipeUID` that still count toward `total_meal_count`
- one qualifying meal for a recipe
- multiple meals for a recipe in chronological order
- same-day duplicate meals
- identical timestamps
- unordered input meals that must be sorted before derivation
- median with odd number of gaps
- median with even number of gaps
- recipe rows absent when no qualifying linked meals exist
- query-time `days_since_last_meal`

## Primary files likely to change

Core implementation:
- `Sources/PantryKit/Store/PantryStore.swift`
- `Sources/PantryKit/Recipes/RecipeReadService.swift`
- `Sources/PantryKit/Model/RecipeReports.swift`
- `Sources/PantryKit/CLI/RecipeCommands.swift`

If index summaries/stats change:
- `Sources/PantryKit/Model/RecipeReports.swift`
- possibly related report/model sections in `PantryStore.swift`

Tests:
- `Tests/PantryKitTests/PantrySidecarDatabaseTests.swift`
- `Tests/PantryKitTests/PantrySidecarStoreTests.swift`
- `Tests/PantryKitTests/QueryReportsTests.swift`
- `Tests/PantryKitTests/JSONOutputTests.swift`
- `Tests/PantryKitTests/OutputFormatTests.swift`

Possible doc touch-ups after implementation:
- `README.md`
- `TODO.md`

## Phased execution plan

### Phase 1A, storage and derivation
- evolve sidecar schema/migration for richer usage facts
- replace the current lightweight usage derivation with meal-history fact derivation
- keep rebuild flow coherent and green

### Phase 1B, read path and reports
- update fetch/decode methods for `RecipeUsageStats`
- update `recipes show`, `recipes list`, and `recipes search` outputs
- add query-time `days_since_last_meal`

### Phase 1C, verification and cleanup
- update index stats/rebuild summaries
- refresh tests
- do a light README/TODO pass only if the surfaced behavior materially changed

## Explicit non-goals for this phase

Do not add:
- classification of frequent vs infrequent recipes
- recommendation logic
- ingredient or source correlation inside this layer
- normalized rates like meals per month
- LLM interpretation
- a separate analytics subsystem
- writes to the real Paprika database

## Definition of done for Phase 1

Phase 1 is done when:
- `index rebuild` derives the agreed meal-history facts into the sidecar
- existing recipe outputs can show those facts coherently
- `days_since_last_meal` is computed at query time, not stored
- migrations are covered
- tests document the edge-case semantics clearly
- the whole Swift test suite passes
