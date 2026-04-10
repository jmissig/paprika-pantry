# TODO.md

## Phase 1 — Package and CLI scaffold

- [x] Create Swift Package Manager package
- [x] Add dependencies:
  - [x] `swift-argument-parser`
  - [x] `GRDB`
- [x] Create targets:
  - [x] `PantryKit`
  - [x] `paprika-pantry`
  - [x] `PantryKitTests`
- [x] Create initial source layout:
  - [x] `CLI/`
  - [x] `Auth/`
  - [x] `Remote/`
  - [x] `Sync/`
  - [x] `Store/`
  - [x] `Model/`
  - [x] `Support/`
- [x] Add root CLI and initial command tree
- [x] Add config/path plumbing for managed config/session/database locations
- [x] Add shared JSON output support
- [x] Stub commands that are intentionally later:
  - [x] `meals list`
  - [x] `groceries list`
  - [x] `doctor`

## Phase 2 — First trustworthy recipe mirror slice

- [ ] Implement `SimpleAccountAuth`
- [ ] Implement local session/config storage
- [ ] Implement small Paprika HTTP client directly in this repo
- [ ] Add first SQLite migration
- [ ] Add recipe sync flow:
  - [ ] fetch stub list
  - [ ] diff by `uid` and remote hash
  - [ ] hydrate changed/new recipes
  - [ ] tombstone missing recipes
  - [ ] record sync run results
- [ ] Implement commands:
  - [ ] `auth login`
  - [ ] `auth status`
  - [ ] `auth logout`
  - [ ] `sync run`
  - [ ] `sync status`
  - [ ] `recipes list`
  - [ ] `recipes show`
  - [ ] `recipes search`
  - [ ] `db stats`
- [ ] Definition of done:
  - [ ] after one successful sync, recipe queries work locally with the network off

## Phase 3 — Trust/reporting

- [ ] Add stale/fresh reporting to sync status and recipe outputs
- [ ] Implement `doctor`
- [ ] Improve local diagnostics for missing DB/session/never-synced/stale state
- [ ] Add fixture-driven sync reporting tests

## Phase 4 — Later

- [ ] Add meals mirror and queries
- [ ] Add groceries mirror and queries
- [ ] Add categories support
- [ ] Consider `LicensedClientAuth` if simple login proves fragile

## Explicitly not yet

- [ ] No upstream writes
- [ ] No background daemon/scheduler
- [ ] No multi-account support
- [ ] No attachments/photos
- [ ] No generic SDK extraction
- [ ] No broad search grammar beyond basic local FTS
