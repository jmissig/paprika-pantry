# AGENTS.md

## Purpose

`paprika-pantry` is a local-first Paprika mirror and query CLI.

Its job is to:
- authenticate to Paprika
- pull down remote recipe data into a durable local cache
- expose fast local search and query commands
- make freshness, sync state, and cache health legible to humans and agents

It is not just a thin remote API wrapper.
It is not a general Paprika app replacement.
It is not a kitchen UI.

The center of gravity should be the local mirror.
The CLI is attached to that mirror.

## Project shape

This project should feel temperamentally similar to `protect-cadence` and `clime`:
- small local-first CLI
- explicit local SQLite store
- compact human output
- structured JSON when useful
- a narrow, legible command surface
- simple install/build/test flow
- clear diagnostic commands

But unlike those tools, `paprika-pantry` is more explicitly a sync-and-cache tool.

A useful framing:
- `protect-cadence` is a local observation pipeline with query commands
- `clime` is a local evidence store with import and query commands
- `paprika-pantry` should be a local mirror with sync, freshness, and query commands

## Primary goals

The tool should make it easy to:
- sync Paprika data into a local cache
- search recipes quickly without hitting the network every time
- inspect meals, groceries, and categories locally
- understand whether local data is fresh or stale
- give OpenClaw and other local tools a fast, trustworthy local source of truth

The system should produce:
- durable local storage
- incremental refresh when practical
- clear sync metadata
- query surfaces optimized for extraction, not narration
- outputs that keep evidence separate from judgment

## Non-goals

Avoid building, at least initially:
- a GUI
- a full Paprika replacement app
- a broad Paprika SDK meant for every possible integration
- background daemons before there is a clear need
- heavy sync conflict machinery unless real write support appears
- embedded recommendations or cooking judgment in the CLI

The CLI should expose evidence.
OpenClaw or downstream tools can do interpretation.

## Read-only first

Be conservative about touching the real Paprika account.

Implementation priority should be:
1. read-only auth
2. read-only remote fetches
3. durable local database sync
4. fast local search and query
5. freshness / doctor / sync-health reporting
6. only then, consider any operation that could modify the upstream account

Until the local mirror is trustworthy, do not rush into writes.
Anything that could modify the original Paprika data should be treated as a later phase, after read sync is solid and easy to inspect.

## Architectural direction

Preferred high-level flow:

```text
Paprika cloud API
    -> auth client
    -> sync engine
    -> local SQLite mirror
    -> query/search CLI
    -> local agent / OpenClaw
```

Keep the system split into four legible layers:
1. remote client
2. sync engine
3. local store/index
4. CLI presentation

That separation matters here more than in simpler local-data tools because auth and sync behavior may need to change independently from the cache and query surface.

## Auth direction

Current expected direction:
- start with the simpler account-login API shape proven by `paprika-recipe-cli`
- do not make `paprika-recipe-cli` a runtime dependency
- reimplement the necessary HTTP client logic directly in this project
- keep auth behind a narrow interface so a stricter licensed-client flow can be swapped in later if needed

Rationale:
- the read-oriented API surface appears small enough to reimplement cleanly
- the real project value is the local mirror, not shelling out to another CLI
- the simpler auth path may be relying on an older or compatibility endpoint, so the rest of the project should not be tightly coupled to it

Preferred auth abstraction shape:
- `SimpleAccountAuth`
- `LicensedClientAuth`

The rest of the sync engine should not care which one is active.

## Technology preferences

Preferred stack unless a strong reason appears otherwise:
- language: Swift
- package model: Swift Package Manager
- CLI parsing: `swift-argument-parser`
- local store: SQLite
- SQLite layer: GRDB, used lightly

Use GRDB for:
- opening the database
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

SQLite is the canonical local cache.

The database should store:
- recipes
- recipe stub metadata and remote hashes where available
- categories
- meals
- groceries
- sync runs / sync state
- deletion or tombstone state when needed

The local store should also make these questions easy to answer:
- when was the last successful sync?
- what data is stale?
- what changed since the last sync?
- which entities failed to hydrate?
- which remote items disappeared and should be marked deleted?

Prefer explicit, inspectable tables over opaque blobs.
If raw payload storage is useful for debugging or trust, keep it clearly secondary to normalized columns.

## Sync model guidance

This project is offline-first for reads.

That means users should be able to trust:
- show me what you know
- tell me how fresh it is
- refresh now if I ask

Preferred sync strategy for v0:
- fetch recipe stubs or equivalent lightweight remote listing
- track stable IDs plus remote change hashes where available
- only re-fetch full entities when their hash changed or the entity is new
- mark local rows deleted when a previously-known remote ID disappears
- do occasional full reconciliation if needed

This is probably the sweet spot between:
- naive full refresh, which is simple but wasteful
- full desktop-app sync emulation, which is much more complex

The hard part is not talking to the API.
The hard part is maintaining a sane, trustworthy local mirror.

## Query and search guidance

Search/query is a primary feature, not an afterthought.

Support should eventually include:
- recipe listing
- recipe lookup by ID or name
- full-text recipe search
- category filtering
- ingredient-oriented search
- meals lookup
- groceries lookup
- freshness and sync status reporting

Prefer a coherent command grammar over a pile of one-off verbs.

Structured JSON output should be first-class for agent consumption.
Compact human-readable output should remain pleasant by default.

## CLI direction

Likely command families:
- `auth`
- `sync`
- `recipes`
- `meals`
- `groceries`
- `db`
- `doctor`

Plausible early command surface:
- `paprika-pantry auth login`
- `paprika-pantry auth status`
- `paprika-pantry sync run`
- `paprika-pantry sync status`
- `paprika-pantry recipes list`
- `paprika-pantry recipes show <uid|name>`
- `paprika-pantry recipes search <query>`
- `paprika-pantry meals list`
- `paprika-pantry groceries list`
- `paprika-pantry db stats`
- `paprika-pantry doctor`

The command surface should stay small and legible.
Do not explode it prematurely.

## Output and UX guidance

Borrow the good habits from sibling tools:
- compact default output
- JSON output where structured downstream use matters
- clear freshness/staleness indicators
- diagnostics that explain what is wrong without drama
- defaults optimized for local use, not cloud-hosted multi-user deployments

For stale data, prefer the `clime` pattern:
- still show the normal report
- include a clear warning that the data is old

For config and docs, carry forward these established preferences:
- config files should optimize for humans
- if writing JSON config, avoid unnecessary escaped slashes like `\/`
- install docs should prefer `PREFIX` style examples over raw `BINDIR=...`
  - canonical alternate install example: `make install PREFIX="$HOME/.local"`

## Working style for contributors and agents

- Prefer the smallest real slice that yields a useful local mirror.
- Be suspicious of architecture that is impressive but unnecessary.
- Keep the remote boundary thin and replaceable.
- Keep SQL legible.
- Keep command shapes coherent across subcommands.
- Preserve a clear distinction between evidence, freshness, and judgment.
- Do not let this turn into a generic sync framework.

Success looks like:
- a small tool that syncs quickly enough
- local search that feels fast
- easy-to-understand freshness and sync health
- a query surface that agents can use reliably

Failure signals:
- the project becomes mostly about auth plumbing
- the CLI becomes a mirror of the raw API surface
- local cache semantics are hard to explain
- schema growth outruns actual use cases
- the tool requires the network for common queries that should be local

## Initial implementation priorities

Suggested sequence:
1. create the Swift package and basic CLI skeleton
2. implement simple account auth behind a protocol
3. create SQLite schema and migrations
4. sync and cache recipe stubs plus full recipes
5. add recipe search and lookup
6. add sync status and freshness reporting
7. add meals, groceries, and categories
8. add `doctor`
9. consider alternate auth if the simple login path proves fragile

## Final rule

Build a small, quiet, trustworthy pantry mirror.

Do not build a Paprika empire.
