# paprika-pantry

`paprika-pantry` is a command-line tool for querying the local database used by Paprika 3 for Mac. It includes skills that help OpenClaw, ChatGPT, and Claude use the tool to answer questions about recipes, meals, groceries, pantry items, and cooking patterns.

It opens Paprika's database read-only: it does not authenticate to Paprika Cloud, call a Paprika web API, or write back to the app's data.

It is built around a few normal tasks:

- inspect whether the local Paprika source is readable and current
- read recipes, meals, groceries, and pantry items directly from canonical Paprika data
- build and query paprika-pantry's local index for recipe search and derived cooking patterns
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

To install the repo's agent skill for OpenClaw (the default), Codex, or Claude Code:

```bash
make install-skill
make install-skill SKILL_TARGET=codex
make install-skill SKILL_TARGET=claude
```

The default destinations are:

- OpenClaw: `$OPENCLAW_HOME/skills/paprika-pantry`, with `OPENCLAW_HOME` defaulting to `~/.openclaw`
- Codex: `$CODEX_HOME/skills/paprika-pantry`, with `CODEX_HOME` defaulting to `~/.codex`
- Claude Code: `$CLAUDE_CONFIG_DIR/skills/paprika-pantry`, with `CLAUDE_CONFIG_DIR` defaulting to `~/.claude`

Set the corresponding home/config variable to install elsewhere. `SKILLS_DIR` can also override the final skills directory directly.

## First Run

Paprika 3 for macOS must be installed on the same Mac and must have created its local database, normally by completing at least one app sync. `paprika-pantry` reads that on-disk database directly; no Paprika account credentials are needed by this tool.

The normal first check is:

```bash
paprika-pantry source status
```

That checks that the Paprika 3 Mac app is installed, its local SQLite database was found, and the database looks like the format `paprika-pantry` expects. `paprika-pantry doctor` cuts across both that real source and paprika-pantry's owned sidecar index.

## Update Index

To refresh paprika-pantry's local index after Paprika has synced, do:

```bash
paprika-pantry source last-sync-time
paprika-pantry index update
```

`index update` is the normal path: it refreshes search, derived recipe features, usage stats, and ingredient tokens. `index rebuild` does that plus the heavier ingredient-pairing evidence used by `recipes pairings`; run it occasionally when you want pairings refreshed too.

On Macs where Paprika is not being actively used, you can nudge a sync first, then update:

```bash
paprika-pantry source launch-app --wait-for-sync
paprika-pantry index update
```

After that, the usual commands are things like:

```bash
paprika-pantry recipes list
paprika-pantry recipes search risotto
paprika-pantry recipes cookbooks
paprika-pantry index stats
paprika-pantry doctor
```

## Output Formats

Commands default to compact human-readable output.

- `--format text` forces compact operator-oriented text
- `--format json` forces machine-readable JSON
- `--json` is a shortcut for `--format json`
- `--format csv` is supported only on row-oriented reports for now

Prefer `--format json` in docs, scripts, and agent usage.

Recipe, meal, pairing-evidence, and source-rollup rows include stable attachment handles for OpenClaw/Obsidian notes or follow-up reads. JSON uses structured `target` or `recipeTarget` objects. Text uses compact handles like `target=paprika.recipe:<uid>` or `recipe_target=paprika.recipe:<uid>`. These identify Paprika objects; they are not embedded commands and they are not full recipe records.

Examples:

```bash
paprika-pantry recipes list --format json
paprika-pantry recipes search risotto --format json
paprika-pantry groceries list --format csv
paprika-pantry recipes cookbooks --format csv
```

Not every command flattens honestly to CSV. Detail and diagnostic commands continue to support text and JSON output only, and will fail clearly if asked for CSV.

## Common Commands

Most people will use these:

```bash
paprika-pantry doctor
paprika-pantry source status
paprika-pantry source last-sync-time
paprika-pantry source stats
paprika-pantry recipes cookbooks
paprika-pantry recipes cookbooks --sort recipes --min-recipes 2 --format csv
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
paprika-pantry recipes list --min-meal-count 2 --sort recent
paprika-pantry recipes list --min-days-since-last-meal 90 --sort lapsed
paprika-pantry recipes list --format csv

paprika-pantry recipes show "Mushroom Risotto"
paprika-pantry recipes show 8D4A0D7E-EXAMPLE-UID --format json
paprika-pantry recipes search risotto
paprika-pantry recipes search "crispy tofu" --min-rating 4 --format json
paprika-pantry recipes search tostada --max-days-since-last-meal 60 --format json
paprika-pantry recipes features "Mushroom Risotto"
paprika-pantry recipes ingredients "Mushroom Risotto"
paprika-pantry recipes pairings --token tomato --sort meals

paprika-pantry meals list
paprika-pantry meals list --format csv
paprika-pantry groceries list
paprika-pantry groceries list --format csv
paprika-pantry pantry list
paprika-pantry pantry list --format csv

paprika-pantry index stats
paprika-pantry index update
paprika-pantry index rebuild
paprika-pantry doctor
paprika-pantry doctor --format json
```

## Read-Only Exploration

For one-off inspection, debugging, or agent investigation across sidecar tables, see [docs/read-only-exploration.md](docs/read-only-exploration.md).

Use the CLI first when a stable command answers the question. Use read-only SQL/Datasette for exploration: coverage checks, freshness checks, provenance examples, and debugging surprising derived evidence.

## Source Readiness and Sync Observation

`paprika-pantry` is read-only against the real Paprika database.

The source-related commands exist to make that legible:

```bash
paprika-pantry source status
paprika-pantry doctor
paprika-pantry source last-sync-time
```

`source status` reports on the real Paprika database/app boundary. Top-level `doctor` combines that source diagnosis with sidecar index health.

The sync-related reporting is observational, not a real sync API.

Today that means:

- `source last-sync-time` reads the locally observed Paprika last-sync marker
- `source launch-app` launches the Mac app
- `source launch-app --wait-for-sync` launches the app and waits for that observed last-sync timestamp to advance

This is useful because Paprika often syncs on launch, even though `paprika-pantry` is not calling a direct sync command.

## Recipe Queries

There are two main recipe paths:

1. direct canonical reads from the local Paprika source
2. local index-backed search and derived features built from that source

Use direct reads when you want the canonical recipe record:

```bash
paprika-pantry recipes list
paprika-pantry recipes show "Weeknight Pasta"
```

`recipes show <uid>` is the full recipe detail boundary. It preserves publisher/source description separately from household-authored notes and also exposes difficulty, nutrition, source/image URLs, and bounded photo metadata when Paprika contains them. Photo output contains filenames, status, and existing Paprika-owned local paths—not copied image bytes. List, search, meal, pairing, and source-rollup outputs stay partial: they expose why a row matched plus stable target identity such as a recipe UID.

Use paprika-pantry's local index when you want query affordances like ingredient filtering, derived time limits, or usage-aware ranking:

```bash
paprika-pantry recipes search risotto --max-total-time-minutes 45
paprika-pantry recipes search tofu --ingredient scallion --exclude-ingredient peanut
```

To inspect the derived layer for one recipe:

```bash
paprika-pantry recipes features "Weeknight Pasta"
paprika-pantry recipes ingredients "Weeknight Pasta"
```

To inspect ingredient token pairings across recipes:

```bash
paprika-pantry recipes pairings --token tomato --sort meals
```

Pairings are evidence, not recommendations. They come from `index rebuild`, and the command will warn if the pairing evidence is older than the routine index.

Meal-history fields are also evidence. Recipe list/search can filter by linked meal count, days since last meal, and median meal gap, but those facts do not mean a recipe is loved, disliked, forgotten, or a good dinner suggestion by themselves.

## Meals, Groceries, and Pantry

These commands read directly from local Paprika data:

```bash
paprika-pantry meals list
paprika-pantry groceries list
paprika-pantry pantry list
```

They are meant to be simple extraction commands, not a replacement UI for Paprika.

## Cookbook / Source Rollups

If paprika-pantry's local index has been built, you can inspect cookbook or source rollups from canonical recipe source fields:

```bash
paprika-pantry recipes cookbooks
paprika-pantry recipes cookbooks --sort average-rating
paprika-pantry recipes cookbooks --sort recipes --min-recipes 3
paprika-pantry recipes cookbooks --format csv
```

This is useful for questions like:

- which cookbooks have the most recipes here?
- which sources have the best ratings?
- which cookbook clusters are strong enough to trust?

## What This Tool Is and Is Not

`paprika-pantry` is:

- a local-first Paprika reader
- a query CLI over canonical local Paprika data
- a local index for search and derived facts we actually use
- a tool for humans and local agents that need trustworthy evidence quickly

It is not:

- a write path into the real Paprika DB
- a full Paprika replacement app
- a background sync service
- a generic Paprika SDK
- an opaque recommendation engine

---

Made with Codex and OpenClaw.
