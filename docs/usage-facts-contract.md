# Usage Facts Contract

`paprika-pantry` derives recipe usage facts from Paprika meal history and stores them in the local sidecar/index. These facts are descriptive evidence, not preference labels.

Paprika remains canonical for recipe content. The sidecar is rebuildable and stores only search inputs and derived facts. Recipe `description` and household `notes` stay separate in canonical reads and sidecar search; neither substitutes for the other, and `hasNotes` means nonblank notes only.

## Source Semantics

Use Paprika meal `scheduledAt` as the meal timestamp.

Ignore meals that are deleted, missing `scheduledAt`, or scheduled in the future. For per-recipe usage facts, also ignore meals without a recipe UID or explicitly marked ingredient-only in Paprika 4. Recipe scale does not multiply occurrences.

Dataset-level `total_meal_count` includes all qualifying meals with a valid non-future `scheduledAt`, even when no recipe UID is attached. Duplicate same-day meals count separately.

## Stored Facts

For each recipe UID with qualifying linked meals, store:

- `meal_count`
- `first_meal_at`
- `first_cooked_at`
- `last_meal_at`
- `meal_gap_days`
- `days_spanned_by_meals`
- `median_meal_gap_days`
- `meal_share`
- `derived_at`

`days_since_last_meal` is computed at query/report time from `last_meal_at`. Do not store it in the sidecar.

## Query Surface

Usage facts can appear in:

- `recipes list`
- `recipes search`
- `recipes show`
- `recipes cookbooks`
- `index stats`
- `index update`
- `index rebuild`

Mechanical usage filters are allowed, including meal count, days since last meal, and median meal gap bounds. These filters should explain query behavior, not imply that a recipe is loved, disliked, forgotten, or recommended.

## Interpretation Boundary

Frequency, recency, gaps, ratings, and favorites are evidence. They are not final household taste claims.

Robut or another guide layer may interpret usage facts with context, human notes, and current constraints. The CLI should expose stable facts, freshness, and provenance.
