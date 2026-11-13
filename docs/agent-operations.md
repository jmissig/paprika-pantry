# Agent operations and evidence boundaries

This is agent-facing operational guidance. README.md is the human entry point:
installation, cooking questions, ordinary commands, and actionable upgrade steps.
Keep adapter mechanics, output contracts, and investigation procedures here or in
the focused documents linked below—not in the README.

## Source reads versus indexed evidence

- Direct reads: recipe records, categories, Collections, meals, groceries and pantry.
- Indexed evidence: FTS search, ingredient filters, derived time constraints, usage
  summaries, publication/source rollups, and ingredient pairings.
- Prefer the CLI when a stable command answers the question. Read-only SQL or
  Datasette is for coverage, freshness, provenance and debugging investigations;
  see [read-only-exploration.md](read-only-exploration.md).
- Use JSON for agent consumption and scripts. Read human output when validating CLI
  UX. Do not force human README examples into JSON for implementation convenience.

`recipes show <uid>` is the full recipe-detail boundary. List/search/meal/pairing/
source-rollup rows are partial evidence. Resolve by UID before interpreting recipe
text or household modifications. `description` is publisher context; `notes` is a
separate field. Neither substitutes for the other. Photo paths refer to existing
Paprika-owned files; the CLI does not copy image bytes.

JSON `target` and `recipeTarget` objects and text handles such as
`target=paprika.recipe:<uid>` identify evidence for follow-up reads or notes. They
are not commands, URLs, or complete records. Preserve the distinction between
`paprika.recipe`, `paprika.meal`, and `paprika.source` targets.

## Paprika 4 vocabulary and coverage

Public commands and fields use **Collections** for what Paprika calls **Cookbooks**.
`recipes collections` lists those entities; `recipes cookbooks` retains its older
publication/source aggregation meaning. Collection context is available in direct
recipe list/detail output, not an indexed Collection-filter feature.

`null-reference` and `missing-reference` are unresolved collection memberships.
Do not infer the default collection or discard the recipe. Optional fields absent
in v3 remain unsupported/null rather than invented defaults. Meal scale does not
multiply occurrences; ingredient-only meals do not count as recipe usage. Preserve
the denominator documented in [usage-facts-contract.md](usage-facts-contract.md).

Numeric Paprika 4 recipe times and structured nutrition do not yet drive derived
results. Original text fields remain the basis until the new semantics are verified.

## Compatibility, refresh and diagnosis

- `source status` diagnoses the selected source independently of app installation.
- `doctor` combines source readiness and sidecar compatibility/readiness.
- `index stats --format json` exposes per-family build provenance and build times.
- `source last-sync-time` is an observed preference marker, not a cloud-sync API.
- `source launch-app --wait-for-sync` waits for that marker to advance after launch.
  App discovery matches the detected source layout to the v3/v4 app name in
  `/Applications` or `~/Applications`, without cross-version fallback. Paprika 4
  retains the `.mac.v3` bundle ID and group preferences on Saga. End-to-end
  sync-on-launch remains unverified; a readable timestamp alone does not prove it.
  Never reuse ambient preferences as freshness evidence for a copied database.

Only explicit index-writing operations open/create/migrate the sidecar for writing.
Read/query/diagnostic operations inspect an existing sidecar read-only. Schema
migration does not establish data freshness. Missing legacy provenance, changed source identity/layout, or changed
interpretation contracts require an explicit full `index rebuild`. Do not silently
promote a routine update to the expensive pairing rebuild. Incompatible derived
results are blocked; canonical list/detail reads omit incompatible enrichments.
Canonical output uses `enrichmentIssue` (JSON) / `enrichment_unavailable` (text) to
explain omitted extras, without fabricating usage or freshness. Required indexed
constraints never disappear silently. A future-version sidecar needs its compatible
binary or a separate home; do not suggest rebuilding over unknown migrations.
`doctor` retains source diagnostics even if the sidecar is missing or unreadable.

Builds extract a consistent SQLite backup snapshot into memory, then publish rows
and provenance atomically. Failure preserves the previous generation without
relabeling it as compatible. Routine updates leave pairing provenance unchanged.
Both update and rebuild capture a baseline before source extraction and reject a
competing publication inside their write transaction. Retry explicitly; a rejected
build never overwrites the winner. Diagnostics use one read transaction.

The CLI uses native async commands with command-owned options. Cancellation is
checked around expensive work and is honored by GRDB's async writes. Cancellation
before commit rolls back final rows/provenance; attempt failure reporting uses a
synchronous cleanup transaction. Cancellation after commit does not relabel success
as rollback. This is task-cancellation behavior, not a promise of graceful SIGINT
handling. Abrupt process termination may leave a running attempt record.
See [indexing-performance.md](indexing-performance.md) for dependency invalidation
and [paprika-4-compatibility-plan.md](paprika-4-compatibility-plan.md) for schema,
transition, rollback, and validation details.

Explicit source paths never silently fall back to another database. Multiple default
locations require explicit selection rather than an mtime-based guess. 2.x refuses
unknown future sidecar migrations; that protection cannot be retrofitted into 1.x
binaries. Use isolated `--home` directories for downgrade and migration experiments.

## Skill installation configuration

The repository skill is `skills/paprika-pantry/SKILL.md`. Installation destinations:

- OpenClaw: `$OPENCLAW_HOME/skills/paprika-pantry`; default home `~/.openclaw`.
- Codex: `$CODEX_HOME/skills/paprika-pantry`; default home `~/.codex`.
- Claude Code: `$CLAUDE_CONFIG_DIR/skills/paprika-pantry`; default home `~/.claude`.

`SKILLS_DIR` overrides the destination parent. `SKILL_TARGET` chooses the assistant;
`make install-skill` installs only that selected target. Do not install or overwrite
ambient skills during normal verification. Agent usage instructions belong in the
skill; deeper implementation context belongs in repository docs and AGENTS.md.
