# paprika-pantry

`paprika-pantry` is a small local CLI for reading Paprika 3 data directly from the real local Paprika SQLite database and querying it as compact local evidence.

It is built around a few normal tasks:

- inspect whether the local Paprika source is readable and current
- read recipes, meals, groceries, and pantry items directly from canonical Paprika data
- build and query a small owned sidecar index for search and derived recipe facts
- inspect cookbook/source rollups and source freshness without writing to the real Paprika DB

It also has a practical sync-adjacent helper:

- launch the local Paprika app and optionally wait for the observed last-sync marker to advance

## Install

Build and install the binary:

```bash
make install
```

That installs `paprika-pantry` to `~/bin/paprika-pantry` by default.

If `~/bin` is not already on your `PATH`, add it first.

If you want a different install location:

```bash
sudo make install PREFIX="/usr/local"
```

## First Run

The normal first check is:

```bash
paprika-pantry source doctor
```

On a machine with Paprika 3 installed in the normal place, this should tell you:

- whether the real `Paprika.sqlite` was found
- whether it is readable in read-only mode
- which schema flavor was detected
- when Paprika last appears to have completed a sync
- where the managed config and sidecar database live

The default managed paths are:

- config: `~/Library/Application Support/paprika-pantry/config.json`
- database: `~/Library/Application Support/paprika-pantry/pantry.sqlite`

If the direct source is readable, a useful next step is:

```bash
paprika-pantry index rebuild
```

That builds the owned sidecar search and derived-data tables from the canonical local Paprika source.

After that, the usual commands are things like:

```bash
paprika-pantry recipes list
paprika-pantry recipes search risotto
paprika-pantry source cookbooks
paprika-pantry index stats
paprika-pantry doctor
```

## Output Formats

Commands default to compact human-readable output.

- `--format human` forces compact operator-oriented text
- `--format json` forces machine-readable JSON
- `--json` is a shortcut for `--format json`
- `--format csv` is supported only on row-oriented reports for now

Prefer `--format json` in docs, scripts, and agent usage.

Examples:

```bash
paprika-pantry recipes list --format json
paprika-pantry recipes search risotto --format json
paprika-pantry groceries list --format csv
paprika-pantry source cookbooks --format csv
```

Not every command flattens honestly to CSV. Detail and diagnostic commands continue to support human and JSON output only, and will fail clearly if asked for CSV.

## Common Commands

Most people will use these:

```bash
paprika-pantry source doctor
paprika-pantry source last-sync-time
paprika-pantry source stats
paprika-pantry source cookbooks
paprika-pantry source cookbooks --sort recipes --min-recipes 2 --format csv
paprika-pantry source launch-app
paprika-pantry source launch-app --wait-for-sync
paprika-pantry source launch-app --wait-for-sync --timeout-seconds 300

paprika-pantry recipes list
paprika-pantry recipes list --favorite
paprika-pantry recipes list --min-rating 4
paprika-pantry recipes list --category Dinner --category Weeknight
paprika-pantry recipes list --ingredient basil --ingredient "green onion"
paprika-pantry recipes list --exclude-ingredient anchovy
paprika-pantry recipes list --max-total-time-minutes 30 --sort fewest-ingredients
paprika-pantry recipes list --format csv

paprika-pantry recipes show "Mushroom Risotto"
paprika-pantry recipes show 8D4A0D7E-EXAMPLE-UID --format json
paprika-pantry recipes search risotto
paprika-pantry recipes search "crispy tofu" --min-rating 4 --format json
paprika-pantry recipes features "Mushroom Risotto"
paprika-pantry recipes ingredients "Mushroom Risotto"

paprika-pantry meals list
paprika-pantry meals list --format csv
paprika-pantry groceries list
paprika-pantry groceries list --format csv
paprika-pantry pantry list
paprika-pantry pantry list --format csv

paprika-pantry index stats
paprika-pantry index rebuild
paprika-pantry doctor
paprika-pantry doctor --format json
```

## Source Readiness and Sync Observation

`paprika-pantry` is read-only against the real Paprika database.

The source commands exist to make that legible:

```bash
paprika-pantry source doctor
paprika-pantry source last-sync-time
paprika-pantry doctor
```

The sync-related reporting is observational, not a real sync API.

Today that means:

- `source last-sync-time` reads the locally observed Paprika last-sync marker
- `source launch-app` launches the Mac app
- `source launch-app --wait-for-sync` launches the app and waits for that observed last-sync timestamp to advance

This is useful because Paprika often syncs on launch, even though `paprika-pantry` is not calling a direct sync command.

## Recipe Queries

There are two main recipe paths:

1. direct canonical reads from the local Paprika source
2. sidecar-backed search and derived features built from that source

Use direct reads when you want the canonical recipe record:

```bash
paprika-pantry recipes list
paprika-pantry recipes show "Weeknight Pasta"
```

Use sidecar-backed search when you want query affordances like ingredient filtering, derived time limits, or usage-aware ranking:

```bash
paprika-pantry recipes search risotto --max-total-time-minutes 45
paprika-pantry recipes search tofu --ingredient scallion --exclude-ingredient peanut
```

To inspect the derived layer for one recipe:

```bash
paprika-pantry recipes features "Weeknight Pasta"
paprika-pantry recipes ingredients "Weeknight Pasta"
```

## Meals, Groceries, and Pantry

These commands read directly from local Paprika data:

```bash
paprika-pantry meals list
paprika-pantry groceries list
paprika-pantry pantry list
```

They are meant to be simple extraction commands, not a replacement UI for Paprika.

## Cookbook / Source Rollups

If the sidecar index has been built, you can inspect cookbook or source rollups from canonical recipe source fields:

```bash
paprika-pantry source cookbooks
paprika-pantry source cookbooks --sort average-rating
paprika-pantry source cookbooks --sort recipes --min-recipes 3
paprika-pantry source cookbooks --format csv
```

This is useful for questions like:

- which cookbooks have the most recipes here?
- which sources have the best ratings?
- which cookbook clusters are strong enough to trust?

## Overrides

You can override the managed paths when needed:

```bash
paprika-pantry --home /tmp/paprika-pantry source doctor
paprika-pantry --config /path/to/config.json source doctor
paprika-pantry --db-path /path/to/pantry.sqlite index stats
```

If the real Paprika database is not in the normal discovered path, you can point the source at it with the environment variable used by the source provider:

```bash
PAPRIKA_PANTRY_SOURCE_PAPRIKA_DB=/path/to/Paprika.sqlite paprika-pantry source doctor
```

## What This Tool Is And Is Not

`paprika-pantry` is:

- a local-first Paprika reader
- a query CLI over canonical local Paprika data
- an owned sidecar index for search and derived facts we actually use
- a tool for humans and local agents that need trustworthy evidence quickly

It is not:

- a write path into the real Paprika DB
- a full Paprika replacement app
- a background sync service
- a generic Paprika SDK
- an opaque recommendation engine

## Help

For full command help:

```bash
paprika-pantry --help
paprika-pantry help source
paprika-pantry help recipes
paprika-pantry help meals
paprika-pantry help groceries
paprika-pantry help pantry
paprika-pantry help index
paprika-pantry help doctor
```

Made with Codex and OpenClaw.
