# Paprika 4 compatibility and sidecar transition plan

Date: 2026-11-08. Status: implemented for version 2.0.0; validated locally (unit/integration tests and isolated v4 end-to-end reads/rebuild).

## Hardening follow-up

The compatibility design below was implemented before the
[2.0 hardening plan](2.0-hardening-plan.md). The hardening pass supersedes the old
open-time migration and optional-binding mechanics: only index writers migrate;
queries are source-bound and read-only; canonical reads tolerate unavailable
sidecars; all publications validate a pre-extraction baseline; diagnostics use one
read transaction. Swift tools 6.2, GRDB 7 and native async commands are now the
implementation baseline. Original semantic/open checkpoints below remain valid.

## Boundary and evidence

Paprika alone migrates its canonical database. paprika-pantry detects and reads the
result; it must never rename source tables, create compatibility views in the
source, or run Core Data migration against it. Only our rebuildable sidecar gets
our migrations. Support both observed v3 and v4 layouts during rollout.

Inspection of a user-supplied, isolated v4 database established:

- SQLite quick_check passes; the existing reader rejects the category-link table.
- v3 requires `Z_12CATEGORIES(Z_12RECIPES, Z_13CATEGORIES)`; this v4 store uses
  `Z_15CATEGORIES(Z_15RECIPES, Z_16CATEGORIES)`.
- v4 adds cookbook, pantry-location, recipe-nutrition and saved-search entities;
  meal scale/ingredient flags; recipe numeric times and serving ranges.
- A default cookbook exists while recipe cookbook references are null. Null
  membership semantics need explicit treatment, not an inner join that loses recipes.
- The sample does not exercise every new feature. Use synthetic data for those cases.

Private source copies and extracted schema are in ignored `local/`; do not commit
recipe data, Core Data metadata blobs, source UUIDs or corpus-specific counts.

## 1. Detect the database, not the app's marketing version

Replace the fixed `schemaFlavor` and embedded category SQL identifiers in
`PaprikaSQLiteSource.swift` with a small inspected schema descriptor:

- Recognized layout: v3, v4, or unsupported/ambiguous.
- Validated category join table and its recipe/category columns.
- Per-domain capabilities (recipes/categories, meals, groceries, pantry, photos,
  and optional v4 fields) based on actual tables and columns.
- A deterministic signature of the supported structural contract, plus a full
  structural digest for diagnostics. Ignore extra unrelated columns/tables for
  compatibility decisions; they must not cause needless rebuilds.
- Source store UUID from `Z_METADATA`, when readable, for local identity—not as
  proof of an app version, account identity, or content freshness.

Start with the two demonstrated layouts, verifying required columns, not just a
table's name. No guessed `Z_<number>` substitution or arbitrary SQL identifiers.
Use Core Data entity metadata as corroboration where useful, not a new generic ORM.
Both layouts present, conflicting evidence, or missing critical columns must
produce an actionable unsupported-schema diagnostic, not silently select one.
Optional unsupported domains report unavailable rather than empty data.

Report layout, capabilities, selected source path, and compatibility reason in
`source status` and `doctor`. Keep app version and sync observation separate:
a copied database can be readable without a local app or sync preferences.

## 2. Source selection and v3 → v4 operation

Preserve explicit source configuration/environment overrides. Never switch from
an explicitly configured unreadable path to another store silently.

Retain known v3 paths: an upgraded app can keep a v3-named container. Discover
additional paths/app bundle identifiers only from inspected installations, not
by replacing `3` with `4`. With multiple plausible distinct stores, require explicit
selection; do not choose by mtime. Path movement alone need not mean new content.

On each source open, inspect and choose the supported descriptor automatically.
After Paprika migrates a store, the next CLI invocation selects v4 without config
rewrites if the path is unchanged. A long-running index operation must not mix
pre-/post-migration source reads: use one read snapshot for the extraction phase
or a consistent SQLite backup snapshot; reject structural changes before publishing.
Use the existing GRDB/SQLite facilities, not a custom migration framework.

App launch and last-sync preference discovery require their own v4 validation.
Never use Saga's preference timestamp as freshness evidence for an imported copy.
Do not launch an app, trigger sync, or upgrade it as a side effect of inspection.

## 3. Minimum semantic correctness for v4

- Keep recipe/category UIDs as durable identifiers; Core Data row IDs remain
  adapter-local. Read all collections for existing all-recipes commands.
- Model optional collection UID/name separately from recipe `sourceName`. Preserve
  `recipes cookbooks` as its existing source/publication rollup for now; clarify
  the wording rather than silently redefining its results.
- Resolve null cookbook references to a unique valid default only after confirming
  that rule. Otherwise preserve unknown membership with a diagnostic. Missing,
  deleted, or ambiguous references must not hide recipes. Test category names
  duplicated across cookbooks; identity stays UID-based.
- Expose meal scale and ingredient-only status without counting an ingredient as
  a cooked recipe. Preserve the existing usage denominator contract unless a
  separately documented change is justified. Scale does not multiply meal count.
- Expose pantry location and notes in direct reads; v3 absence is unsupported/null,
  not fabricated values. Distinguish unknown, empty and explicit false/zero.
- Preserve original text times, servings and nutrition. Initially keep existing
  time derivation behavior. Numeric-time adoption and structured-nutrition output
  are a subsequent slice with explicit provenance, zero/null/sentinel tests, and
  comparison against Paprika's UI. Do not assume newly populated numeric fields
  are authoritative or that legacy nutrition text has disappeared.

## 4. Sidecar: structural migrations are not data freshness

Pre-implementation facts (historical): `PantrySidecarDatabase` used named GRDB migrations on open;
`source_state` records path/sync observation but no source schema or adapter version;
routine updates skip recipes by source fingerprints; pairing evidence is deliberately
left untouched by `index update`. Final index rows are published in a write transaction.

Keep this architecture and add a small explicit compatibility contract:

1. Add an append-only GRDB migration for per-index-family build provenance, using
   existing index-family names. Record source store identity, source layout/contract
   signature, adapter contract version, derivation version, successful build time,
   and build/generation identifier. Record corresponding provenance on index runs
   so failures can be explained. Do not change old migration definitions.
2. Keep latest source observation separate from provenance of the data actually
   built. An observation must never make old indexes appear current.
3. Existing sidecars with no provenance are `rebuild required`, not implicitly
   compatible. Migration can add nullable fields; only a successful build supplies
   trustworthy provenance. Retain old rows until their replacement commits.
4. Compare source identity + relevant schema/adapter/derivation contracts before
   serving sidecar-derived evidence or applying fingerprint-based skips. An unchanged
   Paprika `ZSYNCHASH` cannot prove that our extraction semantics stayed unchanged.
5. For the initial v3→v4 transition, require one explicit full `index rebuild`.
   `index update` should explain the requirement and stop before modifying indexes;
   do not silently run the expensive pairing rebuild. Direct source reads remain
   available. The same rule covers a different source store, unknown legacy
   provenance, or return to an older source layout.
6. Rebuild all families from the same source snapshot and publish rows + successful
   provenance atomically. On failure preserve the previous generation but do not
   expose it as compatible with the newly selected source. Do not mark a family
   fresh merely because another family rebuilt successfully.
7. Preserve routine-update semantics after initialization. Pairing provenance stays
   at its own last rebuild; distinguish compatible-but-old pairings from incompatible
   pairings. Refuse incompatible derived results with the exact recovery command.
8. Guard older binaries against a sidecar with unknown future migrations/contracts:
   fail clearly before mutation; never erase-on-schema-change. Verify GRDB's actual
   behavior with a regression test rather than assuming downgrade safety.

Use a single-source sidecar, not account multiplexing or compound UID rewrites.
A changed path with the same UUID and supported contract need not force rebuilding;
UUID alone is not a content checksum. Missing UUID means conservative identity
handling. Restoring/copying a store must still go through content freshness checks.

Fix dependent-input invalidation too: category names and membership influence FTS
even when a recipe hash does not change. Include those dependencies in the update
contract (e.g. a deterministic category/membership signature that forces routine
recipe reindexing). Do likewise for cookbook names only if indexed. Detect missing
ingredient rows rather than treating matching search/feature hashes as completeness.

Do not mirror the new Paprika tables into our sidecar by default. Add nullable
collection keys only where an actual indexed query needs them. Pantry, meal-detail,
nutrition and saved-search data can stay direct reads. Keep internal sidecar schema
version independent of Paprika's major version.

## 5. Implementation slices and acceptance criteria

### A. Detection + basic direct reads

Change source schema descriptor, category SQL, source diagnostics and source-provider
tests. Add synthetic v3/v4 fixtures and malformed/ambiguous variants. Verify recipes,
categories, details/photos, meals, groceries and pantry reads, including v3 regression.
The supplied private sample is a local smoke test, never a committed fixture.

### B. Sidecar provenance + transition gate

Change database migrations, stored state/reports, store update planning, and the
shared derived-read boundary. Inventory every sidecar query entry point so no
search/filter/feature/ingredient/usage/source-rollup/pairing path bypasses the gate.
Test unchanged recipe hashes across layout and derivation-version changes, legacy
sidecars, source swaps, v4→v3 transitions, future migrations, and interrupted rebuilds.
Check that routine updates never relabel old pairing evidence as newly rebuilt.

### C. v4 semantic fields (product terminology: Collections)

Add cookbook context, meal scale/kind and pantry location/notes with synthetic
populated examples, including default/null membership and duplicate category names.
Keep new indexed filters, nutrition features and numeric-time policy out of this
first compatibility release unless needed for correctness.

### D. Isolated end-to-end validation and rollout

Run `make build` and `make test`. Against copied source data and a separate `--home`,
run `source status`, direct reads, full `index rebuild`, then `index update` and
representative search/usage/pairing queries. Verify output semantics and counts
against direct SQL; use fault injection to establish rollback and stale-result gating.
Verify source files remain unmodified, allowing any SQLite bookkeeping only in
disposable working copies. No real app install or ambient sidecar writes in tests.

Update README, tool skill, and architecture guidance with supported layouts and
the one-time rebuild behavior. Deployment/install remains a separately authorized
step. When Saga's Paprika is eventually upgraded: establish recoverable app/data
backup, verify the migrated source, then explicitly rebuild the local sidecar and
check representative results before resuming normal evidence queries.

## Open checkpoints

- Confirm null/default cookbook behavior with a populated multi-cookbook sample.
- Inspect actual v4 app bundle/preferences paths before changing discovery.
- Validate numeric time and nutrition semantics before relying on them.
- Snapshot checkpoint resolved: GRDB SQLite backup into an in-memory query-only queue.

No Paprika source migration, automatic app update, cloud write path, new daemon,
or generic future-schema guessing is part of this plan.

## Implementation decisions

- Public commands and fields call Paprika Cookbooks **Collections**. Existing
  `recipes cookbooks` keeps publication/source aggregate semantics.
- Snapshot implementation: GRDB SQLite backup into an in-memory read-only queue.
- Null collection references remain explicitly unknown until default-membership
  semantics can be demonstrated. No recipes are discarded on that account.
- Version 2 introduces a future-migration refusal; this cannot retrofit guards
  into already-released 1.x binaries. Do not reuse a v2 sidecar with a v1 binary.
- No new v4 app paths were invented. Source reading is validated independently
  of app launch/preferences, pending inspection of an installed v4 bundle.
