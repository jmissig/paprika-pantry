# TODO

## Current direction

`paprika-pantry` remains a local-first mirror and query CLI.

What changed is the architectural reset:

- the local mirror work was worth doing and should stay
- the owned direct-auth / direct-Paprika-HTTP path is no longer the product direction
- next step is to introduce a `PantrySource` seam
- only after that seam exists should we decide the first real source backend
- kappari is currently best treated as reference/protocol knowledge, not yet assumed to be the runtime backend

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
- [x] Stub intentionally-later commands:
  - [x] `meals list`
  - [x] `groceries list`
  - [x] `doctor`

### Local recipe mirror core

- [x] Add first SQLite migration(s)
- [x] Add recipe/category/sync-run store layer
- [x] Add recipe sync engine behavior for:
  - [x] stub listing
  - [x] changed/new hydration
  - [x] tombstoning missing recipes
  - [x] sync-run recording
- [x] Add local commands:
  - [x] `sync run`
  - [x] `sync status`
  - [x] `recipes list`
  - [x] `recipes show`
  - [x] `db stats`
- [x] Add tests for store, sync engine, reports, and command resolution

### Experimental path now considered non-strategic

These landed, but are now on the chopping block rather than future foundation:

- [x] direct auth/session/config flow
- [x] direct Paprika HTTP clients
- [x] `auth login`
- [x] `auth status`
- [x] `auth logout`

## Next implementation slice

### Phase A — source seam

- [ ] Introduce `PantrySource` and source model types
- [ ] Reframe current remote abstraction around `PantrySource`
- [ ] Rewrite `RecipeMirrorSyncEngine` to depend on `PantrySource`
- [ ] Add fake/in-memory source for tests
- [ ] Move sync-engine tests onto the source abstraction

### Phase B — source-oriented CLI plumbing

- [ ] Rewrite `sync run` to use a source provider instead of session/token loading
- [ ] Add `source doctor`
- [ ] Update CLI help/discussion text to describe source-oriented architecture
- [ ] Update path/config plumbing so it no longer assumes owned auth/session files

### Phase C — remove owned auth path

- [ ] Delete auth commands
- [ ] Delete auth/session/config model/store code
- [ ] Delete direct Paprika HTTP clients
- [ ] Delete auth/direct-HTTP tests
- [ ] Remove stale references to direct auth from docs/help/tests

## Decision to make after the seam exists

- [ ] Choose the first real source backend:
  - [ ] thin kappari wrapper
  - [ ] local source implementation informed by kappari

Do not make this call before the source seam is in place.

## Later

- [ ] Add stale/fresh reporting improvements where still needed
- [ ] Add `recipes search`
- [ ] Add meals mirror and queries
- [ ] Add groceries mirror and queries
- [ ] Revisit category model/schema if source integration reveals needed changes
- [ ] Consider photos/attachments only if they become important to real usage

## Explicitly not yet

- [ ] No upstream writes
- [ ] No background daemon/scheduler
- [ ] No multi-account support
- [ ] No generic Paprika SDK extraction
- [ ] No recommendation/ranking logic in the CLI
