# TODO

## Current direction

`paprika-pantry` is no longer primarily a mirror/sync tool.

Current architecture direction:

- read canonical data directly from the local Paprika 3 SQLite database
- never write to the real `Paprika.sqlite`
- keep Paprika-specific Core Data weirdness behind a narrow adapter layer
- use a sidecar SQLite database only for things we own: indexing, denormalized helper tables, derived facts, and analysis artifacts
- remove now-stale mirror-first and kappari-cutover planning

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
- [x] Add recipe/category/sync-style store and report code that may be partially reusable for sidecar/index work

## Remove / reshape

These are now legacy direction and should be removed or reshaped around the new architecture:

- [ ] Delete remaining direct Paprika HTTP client code
- [ ] Delete or rewrite mirror-first sync logic that assumes canonical duplication is the default
- [ ] Delete or rewrite tests that assume the old simplified Paprika SQLite schema
- [ ] Rewrite docs/help text that still describes the product as a remote-auth or full-mirror tool

## Next implementation slice

### Phase A — real read-only Paprika adapter

- [ ] Detect the real Paprika 3 Core Data schema (`ZRECIPE`, `ZRECIPECATEGORY`, `Z_12CATEGORIES`, etc.)
- [ ] Open the real Paprika DB read-only via GRDB
- [ ] Make the default database-path discovery point at the Group Containers location
- [ ] Add hard guards against opening the source DB through migration-writing code paths
- [ ] Map recipes and categories from the real schema into stable internal source/domain models
- [ ] Handle Paprika/Core Data timestamp conversion cleanly

### Phase B — direct query surfaces over canonical data

- [x] Make `source doctor` confirm read-only access, schema shape, and WAL conditions
- [x] Make `recipes list` read directly from the Paprika adapter
- [x] Make `recipes show <uid|name>` read directly from the Paprika adapter
- [x] Add a safe verification/report command for raw source counts and sample coverage

### Phase C — sidecar, only where it helps

- [ ] Define a sidecar schema for owned data only:
  - [ ] search/FTS indexes
  - [ ] derived fact tables
  - [ ] clustering/pattern tables
  - [ ] index/update bookkeeping
- [ ] Add `index stats`
- [ ] Add `index rebuild`
- [ ] Add the first worthwhile sidecar-backed feature, probably recipe search

### Phase D — broaden direct read coverage

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
- [ ] No recommendation/ranking logic in the CLI
