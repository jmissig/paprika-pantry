# Source-first architecture brief

## Goal

Reframe `paprika-pantry` around the part that is actually ours:

- local SQLite mirror
- local-first query/report CLI
- freshness and sync evidence
- stable data model for Robut and other local tools

The immediate architectural move is **not** "make kappari the backend".
The immediate move is to introduce a narrow source abstraction and stop treating owned Paprika auth as product-defining work.

## Current read on kappari

After reviewing the canonical kappari repo, the most accurate stance is:

- kappari is valuable reverse-engineering work
- kappari is useful protocol and SQLite knowledge
- kappari may become a helper or runtime dependency later
- kappari does **not yet obviously present** the stable product/backend surface we would want to depend on directly

So for now:

- treat kappari as reference and leverage
- do not assume `KappariSource` is the first implementation step
- do not assume a thin Swift wrapper over kappari is already enough product

## Core architecture

Near-term architecture:

```text
Paprika cloud / Paprika local DB knowledge
  -> source abstraction (`PantrySource`)
  -> local SQLite mirror
  -> local query/report CLI
  -> Robut / local tools
```

Possible later architecture, if kappari proves to be the right runtime seam:

```text
Paprika cloud / Paprika local DB
  -> kappari
  -> `KappariSource`
  -> local SQLite mirror
  -> local query/report CLI
  -> Robut / local tools
```

## Product boundary

### `paprika-pantry` owns

- normalized or at least deliberate local schema
- import/sync orchestration into the local mirror
- tombstones / local freshness state
- sync-run reporting
- compact human output
- structured local query output
- agent-friendly, evidence-oriented local reads

### `paprika-pantry` should not keep owning as first-class product identity

- Paprika authentication
- licensed-client behavior
- Paprika protocol archaeology
- direct HTTP/API details as the main architectural story

### kappari may help with

- understanding Paprika auth constraints
- understanding Paprika local SQLite schema
- understanding sync protocol details
- possibly later providing a runtime source/backend surface

## Design principles

- Keep `paprika-pantry` local-first.
- Keep local reads offline after a successful sync.
- Do not re-implement Paprika auth unless forced.
- Do not turn `paprika-pantry` into a generic Paprika SDK.
- Keep the integration seam narrow so the upstream source can change later.
- Preserve evidence-oriented outputs, not recommendation logic.

## Source abstraction

Define one narrow source interface inside `paprika-pantry`, for example:

- `listRecipeStubs()`
- `listRecipeCategories()`
- `fetchRecipe(uid:)`
- later: `listMeals()`, `listGroceries()`, etc.

The sync engine and local store should depend on this abstraction, not on Paprika HTTP specifics and not on kappari internals.

Immediate implementation target:

- `PantrySource`

Possible later implementation:

- `KappariSource`

## Command surface

Primary commands should remain centered on the local mirror:

- `paprika-pantry sync run`
- `paprika-pantry sync status`
- `paprika-pantry recipes list`
- `paprika-pantry recipes show <uid|name>`
- `paprika-pantry db stats`
- `paprika-pantry source doctor`

De-emphasize or remove first-class custom auth commands.

If source diagnostics are needed, prefer a source-facing diagnostic command over local credential ownership.

## Sync flow

`sync run` should:

1. ask the active source for recipe stubs and categories
2. compare against the local mirror
3. fetch full details only for new or changed recipes
4. write normalized rows into SQLite
5. tombstone previously-known recipes that disappeared upstream
6. record sync-run stats and failures
7. leave local reads fully offline

## Data model guidance

Keep the current local-first schema shape unless real source behavior forces small adjustments.

Continue to prefer:

- normalized categories when they help local queries and reasoning
- first-class recipe fields where they materially help local queries
- raw payload retention only as secondary evidence/debug data
- explicit sync metadata
- tombstones instead of hard deletes

## What to keep from the current work

Assuming the existing DB and local read path are sound, keep:

- DB migrations
- row/store types
- recipe/category mirror tables
- tombstone handling
- sync-run tracking
- local query commands and reports
- most local-store and sync/report tests

These are still the core of the tool.

## What to change from the current work

Change the remote side of the design:

- retire custom direct Paprika auth as the main path
- retire direct Paprika HTTP sync client as the default source path
- route upstream access through a `PantrySource` seam
- decide the first real backend only after that seam is in place

Custom auth should only survive, if at all, as an explicitly secondary experimental path.

## Suggested implementation order

### Phase 1: source seam

- introduce `PantrySource`
- introduce source model types
- move sync engine onto the source abstraction
- move sync-engine tests onto a fake/in-memory source

### Phase 2: source-oriented CLI plumbing

- wire `sync run` to use a source provider
- add `source doctor`
- remove auth-oriented assumptions from help text and path/config plumbing

### Phase 3: command cleanup

- remove or demote custom auth commands
- delete direct auth/session persistence
- delete direct Paprika HTTP clients and their tests
- update docs to reflect the source-first architecture

### Phase 4: backend choice

- decide whether the first real source backend should be:
  - a thin kappari wrapper, or
  - local code informed by kappari’s reverse-engineering work

## Non-goals

For this architectural reset, do not broaden scope into:

- meals/history
- groceries
- full-text search
- recommendation/ranking logic
- upstream writes
- a general Paprika abstraction layer beyond what the local mirror needs

## Decision summary

If restarting from scratch today, `paprika-pantry` should be:

- a local-first mirror and query CLI
- source-driven internally
- opinionated about local evidence and sync state
- intentionally unambitious about Paprika auth reimplementation

And kappari should currently be treated as:

- valuable documentation
- valuable reverse-engineering work
- possible future leverage
- not yet automatically the backend