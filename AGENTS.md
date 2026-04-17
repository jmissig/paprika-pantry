# AGENTS.md

## Purpose

`paprika-pantry` is a local-first Paprika query and analysis CLI.

Its job is to:
- read Paprika data safely from the local Paprika 3 SQLite database
- expose fast local query commands over canonical Paprika data
- maintain an optional sidecar SQLite database for indexing, derived facts, and agent-oriented analysis
- make source health, freshness, and sidecar state legible to humans and agents

It is not just a thin database browser.
It is not a general Paprika app replacement.
It is not a kitchen UI.

The center of gravity should be the local Paprika database plus our sidecar.
The CLI is attached to those read models.

## Project shape

This project should feel temperamentally similar to `protect-cadence` and `clime`:
- small local-first CLI
- explicit local SQLite store
- compact human output
- structured JSON when useful
- a narrow, legible command surface
- simple install/build/test flow
- clear diagnostic commands

But unlike those tools, `paprika-pantry` is more explicitly a read-adapter plus derived-index tool.

A useful framing:
- `protect-cadence` is a local observation pipeline with query commands
- `clime` is a local evidence store with import and query commands
- `paprika-pantry` should be a local Paprika adapter with query, indexing, and analysis commands

## Primary goals

The tool should make it easy to:
- read recipes, meals, groceries, and categories directly from Paprika's local DB
- search and analyze that data quickly without mutating the source DB
- build and query derived local indexes when useful
- understand whether the local source is available and whether sidecar indexes are current
- give OpenClaw and other local tools a fast, trustworthy local source of truth

The system should produce:
- safe read-only source access
- durable local derived storage where it adds value
- clear source and index metadata
- query surfaces optimized for extraction, not narration
- outputs that keep evidence separate from judgment

## Non-goals

Avoid building, at least initially:
- a GUI
- a full Paprika replacement app
- a broad Paprika SDK meant for every possible integration
- background daemons before there is a clear need
- any write path into the real Paprika database
- embedded recommendations or cooking judgment in the CLI

The CLI should expose evidence.
OpenClaw or downstream tools can do interpretation.

## Read-only first

Be conservative about touching the real Paprika database.

Implementation priority should be:
1. read-only local DB access
2. stable internal domain mapping
3. sidecar index / derived-data storage
4. fast local search and query
5. source doctor / index-health reporting
6. only then, consider whether any local mirror of canonical rows is actually needed

Do not write to the real `Paprika.sqlite`.
Anything that could modify original Paprika data should be treated as out of scope unless Julian explicitly changes that requirement.

## Architectural direction

Preferred high-level flow:

```text
Paprika 3 local SQLite (read-only)
    -> read adapter / mapper
    -> internal domain model
    -> optional sidecar SQLite for indexes and derived facts
    -> query/search/report CLI
    -> local agent / OpenClaw
```

Keep the system split into four legible layers:
1. Paprika read adapter
2. domain/query layer
3. sidecar store/index
4. CLI presentation

That separation matters because Paprika's Core Data schema is ugly and unstable-looking, while our internal domain and sidecar should stay legible.

## Technology preferences

Preferred stack unless a strong reason appears otherwise:
- language: Swift
- package model: Swift Package Manager
- CLI parsing: `swift-argument-parser`
- local store: SQLite
- SQLite layer: GRDB, used lightly

Use GRDB for:
- opening the databases
- migrations
- parameterized queries
- straightforward row decoding
- FTS integration if useful

Avoid:
- elaborate ORM patterns
- abstraction that hides SQL shape
- framework-heavy designs
- clever async architecture without a concrete need

## Local store guidance

SQLite sidecar storage is for things we own.

The sidecar should store only data that adds value beyond direct Paprika reads, for example:
- FTS/search indexes
- denormalized helper tables
- derived recipe feature tables like time, ingredient count, and meal-role hints
- source/cookbook aggregate tables
- ingredient normalization artifacts
- pattern-detection outputs
- cached derived facts
- index/update bookkeeping

The system should make these questions easy to answer:
- can I read the source DB right now?
- what schema flavor did we detect?
- when was the sidecar last rebuilt or refreshed?
- which indexes are present and usable?
- what derived facts are based on stale source reads?

Prefer explicit, inspectable tables over opaque blobs.
Do not duplicate whole canonical Paprika entities into the sidecar unless a concrete need proves that duplication is worth the drift risk.
If a sidecar-derived answer would be surprising, the CLI should be able to show what evidence, counts, or contributing recipes led to it.

## Source model guidance

This project is read-only against Paprika.

That means users should be able to trust:
- show me the canonical Paprika facts
- tell me whether they came directly from Paprika or from sidecar-derived analysis
- rebuild or refresh indexes if I ask

Preferred read strategy for v0:
- open Paprika.sqlite read-only
- map `Z...` tables into stable internal models
- keep direct queries direct when possible
- build sidecar indexes only for capabilities that need them

The hard part is not opening SQLite.
The hard part is maintaining a sane boundary between Paprika's Core Data schema and our own stable internal model.

## Query and search guidance

Search/query is a primary feature, not an afterthought.

Support should eventually include:
- recipe listing
- recipe lookup by ID or name
- full-text recipe search
- category filtering
- feature-constrained queries like fast mains with few ingredients
- source/cookbook aggregate queries
- ingredient-oriented search
- substitution/pairing evidence queries
- meals lookup
- groceries lookup
- source doctor and index status reporting

Prefer a coherent command grammar over a pile of one-off verbs.

Structured JSON output should be first-class for agent consumption.
Compact human-readable output should remain pleasant by default.

## CLI direction

Likely command families:
- `source`
- `index`
- `recipes`
- `meals`
- `groceries`
- `db`
- `doctor`

Plausible early command surface:
- `paprika-pantry source doctor`
- `paprika-pantry recipes list`
- `paprika-pantry recipes show <uid|name>`
- `paprika-pantry recipes search <query>`
- `paprika-pantry meals list`
- `paprika-pantry groceries list`
- `paprika-pantry index stats`
- `paprika-pantry index rebuild`
- `paprika-pantry db stats`
- `paprika-pantry doctor`

The command surface should stay small and legible.
Do not explode it prematurely.

## Output and UX guidance

Borrow the good habits from sibling tools:
- compact default output
- JSON output where structured downstream use matters
- diagnostics that explain what is wrong without drama
- defaults optimized for local use, not cloud-hosted multi-user deployments

For config and docs, carry forward these established preferences:
- config files should optimize for humans
- if writing JSON config, avoid unnecessary escaped slashes like `\/`
- install docs should prefer `PREFIX` style examples over raw `BINDIR=...`
  - canonical alternate install example: `make install PREFIX="$HOME/.local"`

## Working style for contributors and agents

- Prefer the smallest real slice that yields useful direct reads.
- Be suspicious of architecture that is impressive but unnecessary.
- Keep the Paprika-specific boundary narrow and replaceable.
- Keep SQL legible.
- Keep command shapes coherent across subcommands.
- Preserve a clear distinction between evidence, source health, and judgment.
- Do not let this turn into a generic sync framework.

Success looks like:
- a small tool that reads Paprika data safely and directly
- local search that feels fast
- derived indexes that are clearly secondary, useful, and inspectable
- a query surface that agents can use reliably

Failure signals:
- the project becomes mostly about Paprika schema archaeology leaking everywhere
- the CLI becomes a mirror of raw `Z...` tables
- sidecar duplication outruns actual use cases
- index state is hard to explain
- direct reads from Paprika become unsafe or accidental writes slip in

## Initial implementation priorities

Suggested sequence:
1. create the Swift package and basic CLI skeleton
2. implement read-only Paprika DB adapter and schema detection
3. map recipes and categories into stable internal models
4. add direct recipe search and lookup
5. add sidecar schema and indexing only where it adds clear value
6. add derived recipe features and source/cookbook aggregates
7. add ingredient normalization and evidence-backed pattern tables
8. add meals, groceries, and categories
9. add source / index / doctor reporting
10. consider heavier caching only if direct-read performance or stability proves inadequate

## Final rule

Build a small, quiet, trustworthy pantry reader with a useful sidecar.

Do not build a Paprika empire.
