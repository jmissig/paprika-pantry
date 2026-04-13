# First Recipe Mirror Schema Proposal

This document proposes the first real SQLite-backed local mirror schema for `paprika-pantry`.

The goal is to establish a small, trustworthy, local-first foundation for recipe sync and query, without overfitting to Paprika's full internal database.

## Goals

- establish a formal first GRDB migration
- create a minimal but durable local recipe mirror
- support future incremental sync by remote `uid` and hash
- preserve enough raw remote data for debugging and later schema evolution
- keep the schema small, explicit, and local-first

## Design principles

- prefer a quiet, inspectable local schema over copying Paprika's whole DB
- keep remote/API concerns separate from local query concerns
- store normalized query columns plus raw remote payload
- use soft-delete semantics, not hard delete
- defer FTS, categories, meals, and groceries until after basic recipe sync works

## Proposed initial tables

### `recipes`

Purpose: canonical local mirror of recipe entities.

Columns:
- `uid TEXT PRIMARY KEY NOT NULL`
- `name TEXT NOT NULL`
- `ingredients TEXT`
- `directions TEXT`
- `source TEXT`
- `source_url TEXT`
- `created_at TEXT`
- `updated_at TEXT`
- `remote_hash TEXT`
- `is_deleted INTEGER NOT NULL DEFAULT 0`
- `last_synced_at TEXT`
- `raw_json TEXT NOT NULL`

Notes:
- `uid` is the durable remote identity, expected to be an uppercase UUID
- `remote_hash` stores Paprika's change token or hash when available
- `raw_json` preserves the full remote entity for trust, debugging, and future fields
- timestamps may be stored as ISO-8601 strings for simplicity and legibility
- do not add a local integer surrogate key unless later SQL or GRDB usage proves it worthwhile

Indexes:
- primary key on `uid`
- index on `name`
- index on `is_deleted`
- index on `last_synced_at`

### `sync_runs`

Purpose: record each sync attempt and its result.

Columns:
- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `started_at TEXT NOT NULL`
- `finished_at TEXT`
- `status TEXT NOT NULL`
- `recipes_seen INTEGER NOT NULL DEFAULT 0`
- `recipes_changed INTEGER NOT NULL DEFAULT 0`
- `recipes_deleted INTEGER NOT NULL DEFAULT 0`
- `error_message TEXT`

Notes:
- `status` can stay simple, for example `running`, `success`, `failed`
- this table is for sync visibility and future `sync status` or `doctor` reporting

Indexes:
- index on `started_at`
- index on `status`

## Explicit deferrals

Do not include yet:
- FTS or search tables
- `categories`
- `recipe_categories`
- `meals`
- `groceries`
- photo or file tables
- upstream write-tracking fields from Paprika's full local app sync machinery
- UI-state fields from Paprika's own DB

## Migration shape

Implement the first GRDB migration in `PantryDatabase.migrator()`:
- create `recipes`
- create indexes for the common lookup and reporting paths
- create `sync_runs`
- create indexes for sync history and status reporting

## Expected next implementation steps

1. add recipe row model and decoding layer
2. add store methods:
   - upsert recipe
   - fetch recipe by `uid`
   - list non-deleted recipes
   - mark missing recipes deleted
3. add sync-run recording helpers:
   - start run
   - finish run success or failure
4. wire this into a first real `sync run`
5. implement minimal `recipes list`, `recipes show`, and `sync status`

## Non-goals for this pass

- perfect emulation of Paprika's internal schema
- local write-back to Paprika
- advanced conflict handling
- generalized sync framework extraction

## Codex handoff framing

Please implement this proposal as the first DB-backed slice for `paprika-pantry`, starting with the GRDB migration and the minimal store layer.

Constraints:
- keep the schema explicit and small
- prefer legible SQL and straightforward GRDB usage over abstraction
- do not add FTS, categories, meals, groceries, or upstream writes in this pass
- optimize for a trustworthy local mirror, not for feature breadth
