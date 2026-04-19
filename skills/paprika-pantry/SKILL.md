---
name: paprika-pantry
description: Work with the paprika-pantry CLI and codebase. Use when building, debugging, testing, documenting, or operating paprika-pantry, and when answering questions about local Paprika reads, sidecar indexing, query commands, source freshness, or output conventions.
---

# Paprika Pantry

Treat `paprika-pantry` as a small local-first Paprika query and analysis CLI.

## Core rules

- Keep reads from Paprika local SQLite read-only.
- Do not write to the real `Paprika.sqlite`.
- Treat the sidecar as secondary and inspectable.
- Keep evidence separate from judgment.
- Prefer a small, legible command surface.

## Output

- Prefer `--format json` for agent and script use.
- Use CSV only for row-oriented reports.
- Keep default human output compact.
- Preserve the distinction between canonical source reads, derived sidecar facts, and doctor/source-status output.

## Common commands

```bash
paprika-pantry doctor --format json
paprika-pantry source last-sync-time
paprika-pantry source cookbooks --format json
paprika-pantry index stats --format json
paprika-pantry index update
paprika-pantry recipes list --format json
paprika-pantry recipes search risotto --format json
paprika-pantry recipes show "Mushroom Risotto" --format json
paprika-pantry meals list --format json
paprika-pantry groceries list --format json
paprika-pantry pantry list --format json
```

## Working style

- Read `README.md` and `AGENTS.md` first.
- Keep the Paprika adapter boundary narrow.
- Prefer small, useful slices.
- Run focused tests, then `swift test` before finishing substantial code changes.
- Update docs when command shapes or output contracts change.

## Architecture

Keep the system legible as:

1. Paprika read adapter
2. domain/query layer
3. sidecar store/index
4. CLI presentation

Keep Paprika Core Data oddities inside the adapter layer.

## Success criterion

Build a small, quiet, trustworthy pantry reader with a useful sidecar.

Do not build a Paprika empire.
