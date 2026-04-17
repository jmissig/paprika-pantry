# Local Paprika + Sidecar Architecture Sketch

## Summary

`paprika-pantry` should pivot from a mirror-first design to a read-adapter-plus-sidecar design.

Canonical facts live in Paprika's own local SQLite database.
`paprika-pantry` reads those facts read-only, maps them into stable internal models, and maintains a separate sidecar database only for value-added local capabilities.

The sidecar is for things we own.
Paprika remains the source of truth.

## Architectural stance

### Source of truth

- The real Paprika 3 database is the canonical source.
- The real DB must be opened read-only.
- `paprika-pantry` must never run migrations or writes against the real `Paprika.sqlite`.

### What `paprika-pantry` owns

- a read-only adapter over the Paprika schema
- stable internal domain models
- CLI query/report surfaces
- an optional sidecar SQLite database for indexing and derived facts
- source-health and sidecar-health reporting

### What `paprika-pantry` does not own

- Paprika auth and cloud protocol archaeology as product direction
- a full duplicate canonical mirror by default
- any write path into Paprika's database
- raw `Z...` table leakage into the CLI surface

## High-level shape

```text
Paprika.sqlite (real source, read-only)
    -> PaprikaReadAdapter
    -> PantryDomain models / query layer
    -> optional PantrySidecar.sqlite
        -> FTS indexes
        -> denormalized helper tables
        -> derived facts / clustering / patterns
        -> bookkeeping
    -> CLI + agent-facing reports
```

## Core components

### 1. PaprikaReadAdapter

Purpose:
- hide Paprika Core Data table names and join weirdness
- expose stable reads for recipes, categories, meals, groceries, and pantry items

Responsibilities:
- open DB in read-only mode
- detect schema shape
- handle WAL-safe read behavior
- map from `Z...` tables into internal models
- convert Core Data timestamps into legible values

Likely real-schema mappings:
- `ZRECIPE`
- `ZRECIPECATEGORY`
- `Z_12CATEGORIES`
- `ZMEAL`
- `ZMEALTYPE`
- `ZGROCERYITEM`
- `ZGROCERYAISLE`
- `ZGROCERYLIST`
- `ZGROCERYINGREDIENT`
- later: `ZPANTRYITEM`

### 2. PantryDomain

Purpose:
- define stable, Paprika-independent internal models
- give the rest of the app something clean to depend on

Examples:
- `RecipeSummary`
- `RecipeDetail`
- `Category`
- `MealEntry`
- `GroceryItem`
- `PantryItem`

Rules:
- no `Z...` field names outside adapter code
- no raw Core Data join-table semantics outside adapter code
- no CLI/report code reaching into raw SQL rows directly

### 3. PantrySidecar

Purpose:
- store only derived or performance-oriented data that does not belong in Paprika

Good sidecar candidates:
- full-text search indexes
- tokenized ingredient search helpers
- recipe embeddings
- co-occurrence / clustering tables
- normalized denormalized projections for expensive queries
- source fingerprint / refresh bookkeeping

Bad sidecar candidates:
- wholesale duplication of every canonical Paprika row just because we can
- write-back state for Paprika
- a second shadow source of truth

## Read strategy

Preferred v1 behavior:

1. open the real Paprika DB read-only
2. read recipes and categories directly from Paprika
3. expose direct query commands over those reads
4. add sidecar-backed search/index features only when they buy something concrete

This gives us a simpler trust story:

- direct query surfaces answer from the canonical DB
- sidecar features answer from clearly labeled derived data

## WAL and consistency stance

The real Paprika DB is WAL-backed.

That implies:
- reads must tolerate Paprika being open and active
- we should prefer GRDB read-only configuration
- we should avoid long, sloppy multi-step reads without a consistency plan
- if we need stronger consistency for multi-query reports or index rebuilds, use a snapshot-friendly approach where practical

## CLI direction

### Direct canonical read commands

- `paprika-pantry source doctor`
- `paprika-pantry recipes list`
- `paprika-pantry recipes show <uid|name>`
- `paprika-pantry meals list`
- `paprika-pantry groceries list`

### Sidecar-oriented commands

- `paprika-pantry index stats`
- `paprika-pantry index rebuild`
- `paprika-pantry recipes search <query>`

General rule:
- direct facts should come from Paprika
- search and heavier analysis may come from the sidecar

## Recommended file/module shape

Possible direction:

- `Sources/PantryKit/Source/PaprikaReadAdapter.swift`
- `Sources/PantryKit/Source/PaprikaSchemaDetector.swift`
- `Sources/PantryKit/Source/PaprikaRowMappers.swift`
- `Sources/PantryKit/Domain/...`
- `Sources/PantryKit/Sidecar/PantrySidecarDatabase.swift`
- `Sources/PantryKit/Sidecar/...`
- `Sources/PantryKit/CLI/SourceCommands.swift`
- `Sources/PantryKit/CLI/IndexCommands.swift`

Existing mirror-oriented code can be reused selectively, but should stop implying that full duplication is the default architecture.

## Phased implementation plan

### Phase 1: safe direct recipe reads

- detect the real Paprika schema
- wire the Group Containers DB path as the default
- open it read-only with hard safety checks
- map recipe and category reads from the real schema
- make `source doctor`, `recipes list`, and `recipes show` work directly

### Phase 2: sidecar foundations

- define a minimal sidecar schema
- add index bookkeeping and stats
- implement one useful sidecar-backed feature, likely search

### Phase 3: broader data coverage

- add meals
- add groceries
- add pantry items if worthwhile

### Phase 4: analysis features

- pattern finding
- clustering
- richer derived fact extraction

## Tradeoff call

The price of this architecture is coupling to Paprika's local schema.

That is acceptable if we contain it behind the adapter layer.
It is still cheaper and cleaner than maintaining a full duplicated mirror by default when the canonical local DB is already present.

## Bottom line

Use Paprika's local DB as truth.
Read it safely.
Own the adapter.
Own the sidecar.
Do not duplicate canonical data unless a specific need earns that complexity.
