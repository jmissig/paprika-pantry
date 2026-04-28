# AGENTS.md

This file gives coding agents the durable context they need to work safely and consistently in this repository.

Preserve `paprika-pantry`’s purpose. Do not broaden scope or invent a platform unless Julian explicitly asks.

## Project posture

Current posture: **in use**

`paprika-pantry` is a working local-first CLI and OpenClaw-facing tool. Prefer careful evolution over churn, but do not preserve stale paths out of inertia.

Project posture controls how aggressive architecture, schema, dependency, and cleanup changes should be.

- **In use** — prefer careful evolution. Debate sweeping architecture, schema, dependency, or command-surface changes before making them; if accepted, commit fully, document migration steps, and remove old paths cleanly.
- Prefer current recommended patterns and tools over preserving old approaches.
- Backwards compatibility is not a default goal unless this file, `README.md`, or a specific operator workflow says it is.

Underlying philosophy: **software is ephemeral**. Old code should earn its keep. Keep the tool alive by letting it change deliberately.

## Project brief

`paprika-pantry` is a small local CLI for reading Paprika 3 data directly from the real local Paprika SQLite database and querying it as compact local evidence.

This project is:
- a local-first Paprika reader and query CLI
- an agent-facing evidence tool for OpenClaw/Robut
- a Swift Package Manager project with a `PantryKit` library and `paprika-pantry` executable
- a local index / sidecar store for search and derived cooking-pattern evidence we actually use
- a safe way to inspect recipes, meals, groceries, pantry items, cookbook/source rollups, and source freshness without writing to the real Paprika DB

It helps answer questions like:
- what are our favorite risottos?
- which cookbook or source has consistently worked well?
- which main can I make in 30 minutes with the fewest ingredients?
- what side uses up avocados and goes with risotto?
- what substitutions or pairings have evidence in our cooking history?

Source of truth:
- Canonical data: the real local Paprika 3 SQLite database, opened read-only
- Owned/derived data: `paprika-pantry`’s local sidecar/index database, rebuildable from Paprika source data and derived analysis
- Human-facing usage guide: `README.md`
- Active backlog: `TODO.md`
- Architecture notes/specs: `docs/`
- OpenClaw tool skill: `skills/paprika-pantry/SKILL.md`

Never write to:
- the real Paprika database (`Paprika.sqlite` or equivalent local source DB)
- Paprika cloud/server state
- installed binaries, installed OpenClaw skills, or ambient user config during routine tests
- non-fixture user data unless Julian explicitly asks to exercise real local state

Non-goals / anti-goals:
- not a full Paprika replacement app
- not a GUI or kitchen UI
- not a write path into Paprika
- not a background sync daemon or scheduler
- not a generic Paprika SDK for every possible integration
- not a remote-auth or mirror-first product direction
- not an opaque recommendation engine
- not a generic cooking AI; the CLI exposes evidence and OpenClaw/downstream tools do judgment

## Current state

Current stack:
- Swift 6 package targeting macOS 13+
- `PantryKit` library target
- `paprika-pantry` executable target
- `PantryKitTests` test target
- `swift-argument-parser` for CLI parsing
- GRDB for SQLite access
- `Makefile` wrappers for build/test/install/version sync

Current command surface includes:
- `paprika-pantry doctor`
- `paprika-pantry source last-sync-time`
- `paprika-pantry source stats`
- `paprika-pantry source cookbooks`
- `paprika-pantry source launch-app [--wait-for-sync]`
- `paprika-pantry recipes list|show|search|features|ingredients`
- `paprika-pantry meals list`
- `paprika-pantry groceries list`
- `paprika-pantry pantry list`
- `paprika-pantry index stats|update|rebuild`

Current source layout:
- `Sources/PantryKit/CLI`: command definitions and runtime options
- `Sources/PantryKit/Source`: Paprika source adapters and source-state/stat reporting
- `Sources/PantryKit/Store`: sidecar/index database and store logic
- `Sources/PantryKit/Recipes`, `Meals`, `Groceries`, `PantryItems`: read/query services
- `Sources/PantryKit/Model`: report and domain-ish output models
- `Sources/PantryKit/Support`: output formats, config, paths, helpers
- `Sources/paprika-pantry`: executable entry point
- `Tests/PantryKitTests`: unit/integration tests
- `docs/`: architecture notes and focused implementation specs

## Validation

Routine checks:

```bash
make build
make test
```

Direct Swift equivalents:

```bash
swift build --build-path build --product paprika-pantry
swift test --build-path build
```

Useful smoke checks when the binary exists:

```bash
.build/debug/paprika-pantry --help
build/debug/paprika-pantry --help
```

Use whichever build path matches the command used. `make build` writes to `build/`.

Do not run during routine verification:
- `make install`
- `make install-skill`
- commands that write to real operator config or installed OpenClaw skill directories
- commands that mutate the real Paprika database
- destructive cleanup of sidecar databases outside repo-local/temp/fixture paths

Use repo-local, fixture, sandboxed, or temporary paths for tests. Do not rely on the human’s live Paprika database during routine verification unless Julian explicitly asks for a live-data smoke test.

## Core principles

- Keep the project narrow and purpose-built.
- Prefer clarity over cleverness.
- Prefer the smallest coherent implementation that supports real local queries.
- Treat lines of code as a liability: more code means more surface area, more entanglement, and more future reading.
- Prefer local, legible, inspectable state.
- Keep source-of-truth boundaries explicit and documented.
- Keep the Paprika-specific boundary narrow and replaceable.
- Keep SQL legible.
- Keep command shapes coherent across subcommands.
- Preserve a clear distinction between evidence, source health, derived facts, and judgment.
- Let OpenClaw or downstream agents do fuzzy interpretation and recommendations.
- The CLI should retrieve, filter, threshold, sort, and show evidence.
- Do not let this turn into a generic sync framework or Paprika empire.

## Architecture guidance

Preferred high-level flow:

```text
Paprika 3 local SQLite database (read-only)
    -> Paprika read adapter / mapper
    -> stable internal domain/query model
    -> optional sidecar SQLite store for indexes and derived facts
    -> query/search/report CLI
    -> local agent / OpenClaw
```

Keep the system split into four legible layers:
1. Paprika read adapter
2. domain/query layer
3. sidecar store/index
4. CLI presentation

Rules:
- Paprika’s Core Data schema may be ugly or unstable-looking; do not leak raw `Z...` schema details outside adapter boundaries.
- Separate ingestion/source reads, domain interpretation, derived storage, and presentation.
- Keep external API details, Paprika schema quirks, and local filesystem discovery out of command presentation code.
- Use protocol or adapter seams where they make testing and replacement easier, but avoid deep abstraction for its own sake.
- Prefer explicit schemas and data flow over hidden state or magical background behavior.
- After a directional change, make the new path the real path. Delete or clearly retire superseded code, docs, files, TODOs, and stale architectural discussion unless needed for migration or recovery.

## Tool and dependency posture

Preferred stack unless a strong reason appears otherwise:
- Swift
- Swift Package Manager
- `swift-argument-parser`
- SQLite
- GRDB, used lightly
- `Makefile` wrappers for common commands

Use GRDB for:
- opening SQLite databases
- read-only source access
- sidecar migrations
- parameterized queries
- straightforward row decoding
- FTS integration if useful

Avoid:
- elaborate ORM patterns
- abstraction that hides SQL shape
- large dependency surfaces for a small local tool
- framework-heavy designs
- clever async/background architecture without a concrete need
- dependency sprawl that obscures simple data flow

For major architecture choices — persistence, indexing, CLI parsing, output formats, sync observation, auth, testing — do a quick current tool/library scan before inventing custom infrastructure.

## CLI / local tool guidance

This tool should feel like Julian’s other local-first CLIs:
- small command surface
- explicit local store/source boundary
- compact human output by default
- structured output for agents and scripts
- narrow extraction-oriented commands
- clear diagnostic / doctor / status commands

Preferred command families:
- `source`
- `index`
- `recipes`
- `meals`
- `groceries`
- `pantry`
- `doctor`

Keep the command surface small and coherent. Do not explode it prematurely.

Default output should be concise and useful to a human operator.

Structured output:
- use `--format json` for machine-readable output
- `--json` may exist as shorthand, but docs and examples should prefer `--format json`
- use CSV only for row-oriented reports that flatten honestly
- detail/diagnostic commands may support only text and JSON if CSV would be misleading

Output should expose evidence rather than narrating conclusions. OpenClaw or downstream tools interpret it.

For config and docs:
- config files should optimize for humans
- if writing JSON config, avoid unnecessary escaped slashes like `\/`
- install docs should prefer `PREFIX` style examples over raw `BINDIR=...`
  - canonical alternate install example: `make install PREFIX="$HOME/.local"`

## Data and persistence

### Read-only Paprika source

This project is read-only against Paprika.

Users should be able to trust:
- canonical facts came directly from Paprika
- derived facts came from `paprika-pantry`’s sidecar/index layer
- indexes can be rebuilt/refreshed on request
- source health and freshness are visible

Preferred read strategy:
- open Paprika SQLite read-only
- detect expected schema flavor
- map `Z...` tables into stable internal models
- keep direct queries direct when possible
- build sidecar indexes only for capabilities that need them

The hard part is not opening SQLite. The hard part is maintaining a sane boundary between Paprika’s Core Data schema and our own stable internal model.

### Sidecar/index store

SQLite sidecar storage is for things this project owns.

The sidecar should store only data that adds value beyond direct Paprika reads, for example:
- FTS/search indexes
- denormalized helper tables
- derived recipe feature tables such as time, ingredient count, and meal-role hints
- source/cookbook aggregate tables
- ingredient normalization artifacts
- recipe/meal history facts
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

If a sidecar-derived answer would be surprising, the CLI should be able to show the evidence, counts, or contributing recipes/meals that led to it.

### Sync observation

The sync-related behavior is observational, not a real sync API.

Today that means:
- `source last-sync-time` reads the locally observed Paprika last-sync marker
- `source launch-app` launches the Mac Paprika app
- `source launch-app --wait-for-sync` waits for the observed last-sync timestamp to advance

Do not represent this as authoritative Paprika sync control. It is a practical local helper because Paprika often syncs on launch.

## Query and search guidance

Search/query is a primary feature, not an afterthought.

Support should continue to emphasize:
- recipe listing and lookup by ID or name
- full-text recipe search
- category filtering
- favorite/rating filters
- ingredient include/exclude filters
- feature-constrained queries such as fast mains with few ingredients
- source/cookbook aggregate queries
- ingredient-oriented search
- substitution/pairing evidence queries
- meals lookup
- groceries lookup
- pantry item lookup
- source doctor and index status reporting

Prefer canonical filters like rating, favorite status, category membership, ingredient membership, and time bounds over embedding opaque reasoning into the CLI.

Default ranking should prefer meaningful evidence over alphabetical ordering where possible. When multiple strong candidates exist, usage is usually a better tie-breaker than name.

There is a strong product desire to deep-link directly into individual Paprika recipes, but investigation so far did not find a reliable way to do that. Treat direct recipe deep links as desirable but currently unsupported unless new evidence appears.

When choosing between a smart CLI and a useful CLI, prefer useful. The model decides what the human meant; the CLI returns trustworthy evidence-bounded candidates and filters.

## Layering rules

- CLI commands should parse options and call services; they should not own Paprika schema details.
- Paprika source adapters should map raw rows into stable internal/report models at the boundary.
- Sidecar schema and migrations belong in the store/index layer.
- Feature services should not scatter repair or migration policy when a centralized store/index boundary exists.
- If malformed source or sidecar state appears, prefer clear diagnostics and doctor/index-health reporting over silent magical repair.
- Keep business/domain logic testable without the live Paprika database, network, account, or ambient filesystem side effects.

## Testing and verification

Use the documented validation commands before declaring success. If they are missing or stale, update them as part of the work.

Prefer tests for:
- source schema detection
- read-only source access behavior
- raw Paprika row -> stable model mapping
- sidecar schema and migrations
- index rebuild/update semantics
- recipe search/filter/ranking semantics
- output format contracts: auto/text/JSON/CSV where applicable
- source health / doctor diagnostics
- path/config selection
- data-loss or accidental-write regressions

Testing rules:
- Use repo-local, temp, fixture, or explicitly supplied paths.
- Do not mutate ambient/default operator state during routine verification.
- Do not require the live Paprika database in normal tests.
- Do not install or publish as part of normal validation unless explicitly asked.
- Keep tests seam-focused and deterministic.
- Avoid broad tests that just freeze incidental human-readable copy.

## Failure signals

Agents should add or refine this section over time when the project reveals what bad drift looks like.

Watch for:
- the project becomes mostly Paprika schema archaeology leaking everywhere
- the CLI becomes a mirror of raw `Z...` tables
- sidecar duplication outruns actual use cases
- index state is hard to explain
- direct reads from Paprika become unsafe, or accidental writes slip in
- install/config commands run during routine tests
- commands narrate opaque recommendations without exposing evidence
- the command surface grows as one-off verbs instead of coherent command families
- source health, sidecar freshness, and derived-fact provenance become hard to distinguish
- `AGENTS.md` becomes a backlog or philosophy dump instead of durable operating guidance

## Documentation and project hygiene

Use this docs split:
- `README.md` — human-facing usage guide: install, purpose, normal commands, practical examples
- `TODO.md` — active backlog / near-term parking lot, not a philosophy dump
- `AGENTS.md` — durable architecture, constraints, source-of-truth boundaries, project posture, validation, and agent guidance
- `docs/` — focused architecture notes/specs when details would bloat `AGENTS.md`
- `skills/paprika-pantry/SKILL.md` — OpenClaw skill instructions for using the installed tool

Completed work should leave `TODO.md` and live in git history, tests, code, and release notes if relevant.

When architecture choices change, update a decision section or relevant docs with:
- date
- decision
- alternatives considered
- rationale
- migration impact

If unresolved, mark it as `OPEN` with the next checkpoint.

## When to update AGENTS.md

Update this file when agent behavior should change in future sessions.

Good reasons to update it:
- project posture changes
- validation commands change
- source-of-truth boundaries change
- a durable architecture or schema decision changes
- a recurring agent mistake needs a guardrail
- a new failure signal becomes clear
- a project-specific constraint would otherwise need to be repeated in prompts

Agents may update `AGENTS.md` proactively for small durable guardrails, corrected validation commands, clarified source-of-truth boundaries, or newly obvious failure signals.

Agents should propose or confirm before making larger changes to project philosophy, posture, architecture direction, or scope boundaries.

Do not use `AGENTS.md` as a changelog or scratchpad. Keep it concise, durable, and action-guiding.

## Working style for contributors and agents

- Start by reading `AGENTS.md`, `README.md`, `TODO.md`, and focused docs under `docs/` when relevant.
- Prefer the smallest real slice that yields useful direct reads or derived evidence.
- Be suspicious of architecture that is impressive but unnecessary.
- Keep SQL legible.
- Keep command shapes coherent across subcommands.
- Preserve the distinction between evidence, source health, derived facts, and judgment.
- Challenge scope drift kindly and directly.
- When uncertain, choose the narrower interpretation and ask before broadening scope.

## Final rule

Build a small, quiet, trustworthy pantry reader with a useful sidecar.

Do not build a Paprika empire.
