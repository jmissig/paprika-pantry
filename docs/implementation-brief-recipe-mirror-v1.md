# Recipe Mirror V1 Implementation Brief

Implement the first real local recipe-mirror slice for `paprika-pantry`.

## Goal

Turn the current auth + placeholder scaffolding into a trustworthy SQLite-backed local recipe mirror.

This slice should:
- sync recipe stubs and full recipe payloads into a local DB
- expose compact local read commands that work offline after one successful sync
- keep the tool evidence-oriented, not judgment-oriented

Like `protect-cadence` and `clime`, the tool should expose rich local evidence for downstream reasoning. Recommendation logic and interpretation should stay outside the tool.

## Scope for this slice

Implement now:
- GRDB migration(s) for the first real local mirror
- recipe store APIs
- sync-run recording
- concrete recipe sync engine
- `sync run`
- `sync status`
- `recipes list`
- `recipes show <uid|name>`
- `db stats`

Defer:
- `recipes search`
- FTS
- meals / last-cooked history
- groceries
- `doctor`
- upstream writes
- recommendation / ranking logic
- source URL as a first-class field

## Metadata to expose in the recipe mirror

If present in Paprika recipe payloads, expose these as first-class fields:
- name
- category or categories
- source name
- ingredients
- directions
- notes
- star rating
- favorite / heart
- prep time
- cook time
- total time
- servings
- created / updated timestamps
- sync metadata
- full raw payload in `raw_json`

Notes:
- category matters because Alice likely uses it for useful commentary and downstream reasoning
- source name matters now; source URL can stay in `raw_json` for this pass
- star rating and favorite/heart should be first-class now
- meals/history are loosely later; do not block on last-cooked data in this slice

## Recommended schema

### `recipes`

- `uid TEXT PRIMARY KEY NOT NULL`
- `name TEXT NOT NULL`
- `source_name TEXT`
- `ingredients TEXT`
- `directions TEXT`
- `notes TEXT`
- `star_rating INTEGER`
- `is_favorite INTEGER NOT NULL DEFAULT 0`
- `prep_time TEXT`
- `cook_time TEXT`
- `total_time TEXT`
- `servings TEXT`
- `created_at TEXT`
- `updated_at TEXT`
- `remote_hash TEXT`
- `is_deleted INTEGER NOT NULL DEFAULT 0`
- `last_synced_at TEXT`
- `raw_json TEXT NOT NULL`

Indexes:
- `recipes(name)`
- `recipes(is_favorite)`
- `recipes(star_rating)`
- `recipes(is_deleted)`
- `recipes(last_synced_at)`

### `recipe_categories`

- `recipe_uid TEXT NOT NULL`
- `category_name TEXT NOT NULL`
- `PRIMARY KEY (recipe_uid, category_name)`
- foreign key to `recipes(uid)`

Indexes:
- `recipe_categories(category_name)`
- `recipe_categories(recipe_uid)`

Use a normalized category table, not a comma-joined field.

### `sync_runs`

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `started_at TEXT NOT NULL`
- `finished_at TEXT`
- `status TEXT NOT NULL`
- `recipes_seen INTEGER NOT NULL DEFAULT 0`
- `recipes_changed INTEGER NOT NULL DEFAULT 0`
- `recipes_deleted INTEGER NOT NULL DEFAULT 0`
- `error_message TEXT`

Indexes:
- `sync_runs(started_at)`
- `sync_runs(status)`

## CLI behavior

### `sync run`

Should:
- use saved auth session
- fetch recipe stubs
- fetch full payloads for changed/new recipes
- upsert recipes and categories
- tombstone missing recipes
- record sync run

### `sync status`

Should show:
- whether the mirror has ever synced
- last attempt
- last success
- freshness age
- recipe counts
- last failure if relevant

### `recipes list`

Should:
- be local-only
- list non-deleted recipes
- show useful summary metadata like category/source/rating/favorite

### `recipes show <uid|name>`

Should:
- be local-only
- match exact UID first
- then exact case-insensitive name
- fail clearly on ambiguity
- show categories, source name, notes, rating, favorite, times, servings, timestamps, and sync metadata

### `db stats`

Should report counts for:
- recipes
- deleted recipes
- favorite recipes
- category links
- sync runs

## Tradeoff calls already locked

- Categories should be normalized now via `recipe_categories`
- Keep sync semantics all-or-nothing after fetching changed/new payloads; avoid half-applied mirrors
- `recipes show` resolution order is UID first, then exact case-insensitive name, then ambiguity error
- Time/servings fields should be nullable `TEXT` for now unless payload shape proves stably numeric
- Source URL should remain only in `raw_json` for this slice
- Meals / last-cooked history are later, not part of this implementation slice

## Key tests

Database/store:
- migration creates `recipes`, `recipe_categories`, and `sync_runs`
- migration is idempotent
- recipe upsert writes core fields and `raw_json`
- category links replace correctly on update
- tombstoning marks missing recipes deleted without deleting rows
- list/show queries exclude deleted recipes by default

Remote/sync:
- initial sync inserts recipes and categories
- second sync with unchanged hashes skips full re-fetch and reports zero changes
- changed hash updates existing recipe
- missing remote recipe becomes tombstoned
- failed detail fetch records failed sync run
- avoid leaving a half-applied mirror

CLI/report:
- `sync status` works for never-synced state and successful state
- `recipes show` resolves UID first, then exact case-insensitive name
- duplicate names return a clear disambiguation error
- human and JSON output include categories/source/rating/favorite/sync freshness
- after one successful sync, local reads work with the network off

## Suggested implementation order

1. implement the first GRDB migration in `PantryDatabase`
2. add row/model types for recipes, categories, and sync runs
3. add store APIs for recipe upsert, fetch, list, category replacement, and tombstoning
4. add sync-run recording helpers
5. extend the remote client to fetch full recipe details, not just stubs
6. implement the concrete sync engine
7. wire auth/session loading into sync
8. wire `sync run`
9. wire `sync status`
10. wire `recipes list`, `recipes show`, and `db stats`
11. leave `recipes search`, meals, groceries, and doctor deferred

## Definition of done

This slice is done when one successful `sync run` produces a usable offline recipe mirror and the local read commands return structured recipe evidence cleanly.
