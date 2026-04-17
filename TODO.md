# TODO

## Current direction

`paprika-pantry` is a local-first Paprika query and analysis CLI.

Current architecture direction:

- read canonical data directly from the local Paprika 3 SQLite database
- never write to the real `Paprika.sqlite`
- keep Paprika-specific Core Data weirdness behind a narrow adapter layer
- use a sidecar SQLite database only for things we own: indexing, denormalized helper tables, derived facts, analysis artifacts, and refresh bookkeeping
- keep sidecar outputs evidence-first and inspectable, not opaque magic
- design the CLI as a good tool for an LLM: keep reasoning and fuzzy interpretation in the LLM, while the CLI exposes reliable filters, evidence, thresholds, and inspectable outputs
- remove now-stale mirror-first and remote-auth-as-product planning

## Product-shaped use cases to support

The sidecar should earn its complexity by making queries like these possible and legible:

- "what's a good side that would use up our avocados that goes well with risotto?"
- "which cookbook have we consistently liked best?"
- "across all our recipes, what have we found to be a good substitution for yams?"
- "which main can I make in 30 minutes with the fewest ingredients?"

These imply four broad capability areas:

1. recipe feature extraction
2. source/cookbook aggregate tables
3. ingredient normalization/indexing
4. pattern tables for substitutions, pairings, and co-occurrence

## Already landed

### Package / CLI scaffold

- [x] Create Swift Package Manager package
- [x] Add dependencies:
  - [x] `swift-argument-parser`
  - [x] `GRDB`
- [x] Create targets:
  - [x] `PantryKit`
  - [x] `paprika-pantry`
  - [x] `PantryKitTests`
- [x] Create initial source layout
- [x] Add root CLI and initial command tree
- [x] Add managed path plumbing
- [x] Add shared JSON output support

### Source seam and local-store groundwork

- [x] Introduce `PantrySource` and source model types
- [x] Add source-provider plumbing
- [x] Add a `paprika-sqlite` source kind
- [x] Add sidecar SQLite migration/store groundwork
- [x] Add owned sidecar index/store/report code for recipe search

## Remove / reshape

These are now legacy direction and should be removed or reshaped around the new architecture:

- [x] Delete remaining direct Paprika HTTP client code
- [x] Delete mirror-first sync logic that assumed canonical duplication was the default
- [x] Rewrite tests around the current direct-source and sidecar-index flow
- [x] Rewrite docs/help text that still described the product as a remote-auth or full-mirror tool

## Next implementation slice

### Phase A — real read-only Paprika adapter

- [x] Detect the real Paprika 3 Core Data schema (`ZRECIPE`, `ZRECIPECATEGORY`, `Z_12CATEGORIES`, etc.)
- [x] Open the real Paprika DB read-only via GRDB
- [x] Make the default database-path discovery point at the Group Containers location
- [x] Add hard guards against opening the source DB through migration-writing code paths
- [x] Map recipes and categories from the real schema into stable internal source/domain models
- [x] Handle Paprika/Core Data timestamp conversion cleanly

### Phase B — direct query surfaces over canonical data

- [x] Make `source doctor` confirm read-only access, schema shape, and WAL conditions
- [x] Make `recipes list` read directly from the Paprika adapter
- [x] Make `recipes show <uid|name>` read directly from the Paprika adapter
- [x] Add a safe verification/report command for raw source counts and sample coverage

### Phase C — sidecar foundations and first useful query path

- [x] Define a minimal sidecar schema for owned data
- [x] Add search/FTS indexes
- [x] Add index/update bookkeeping
- [x] Add `index stats`
- [x] Add `index rebuild`
- [x] Add the first worthwhile sidecar-backed feature, recipe search
- [x] Make direct-vs-derived provenance clearer in reports where it matters
- [ ] Add staleness/freshness reporting for sidecar-derived answers

### Phase D — derived recipe features

- [x] Extract normalized recipe features into the sidecar, for example:
  - [x] total/prep/cook time where available
  - [x] ingredient counts
  - [ ] likely meal role or course hints such as main/side
- [x] Add query/report surfaces that use those features without pretending they are canonical truth
- [x] Let `recipes list` / `recipes search` combine canonical filters with derived time and ingredient-line constraints plus derived-aware sort modes
- [ ] Support questions like "which main can I make in 30 minutes with the fewest ingredients?" when meal-role hints exist beyond canonical category names

### Phase E — ratings-aware querying

- [x] Add query surfaces for canonical rating/favorite filters
- [x] Add canonical category-backed filters to the same query surface
- [x] Support questions like "what are our favorite risottos?" by letting the LLM interpret the noun phrase while the CLI enforces thresholds like star rating and favorite status
- [x] Keep outputs inspectable so the LLM can cite the concrete rating/favorite evidence it used

### Phase F — source/cookbook aggregates

- [x] Add rollups by source/cookbook
- [x] Add rating/favorite summaries by source
- [ ] Add usage/frequency summaries where evidence exists
- [x] Support questions like "which cookbook have we consistently liked best?"

### Phase G — ingredient normalization/indexing

- [x] Parse and normalize ingredient lines into queryable tokens
- [x] Add ingredient-oriented helper tables and indexes
- [x] Support ingredient-based filtering through recipe query surfaces
- [x] Broaden ingredient query primitives to support include, exclude, and include-match semantics
- [ ] Consider whether higher-level task phrasing should emerge naturally from the general ingredient query surface rather than become a first-class command

### Phase H — pattern tables and household evidence mining

- [ ] Add substitution candidate tables with provenance/evidence counts
- [ ] Add ingredient co-occurrence and pairing tables
- [ ] Keep pattern outputs inspectable and confidence-limited
- [ ] Support questions like "what have we found to be a good substitution for yams?"

### Phase I — broaden direct read coverage

- [x] Add meals adapter/query support
- [ ] Add groceries adapter/query support
- [ ] Add pantry adapter/query support if it looks useful

## Explicitly not now

- [ ] No writes to the real Paprika DB
- [ ] No remote-auth resurrection as product direction
- [ ] No blind full duplication of Paprika canonical rows into our sidecar
- [ ] No background daemon/scheduler
- [ ] No multi-account support
- [ ] No generic Paprika SDK extraction
- [ ] No opaque recommendation logic in the CLI without evidence or inspectable provenance
