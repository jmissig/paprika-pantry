# paprika-pantry

Search your Paprika recipes, check meal plans and grocery lists, and explore what
you've cooked before—from the command line or through an AI assistant.

`paprika-pantry` works with Paprika 3 and 4 for Mac. It reads your local data without
changing it, and doesn't need your Paprika account credentials. It also includes
skills for OpenClaw, Codex, and Claude Code.

## Install

Requires macOS 13 or later and Swift 6.2 or later to build.

From this repository, build and install:

```bash
make install
```

The command is installed at `~/bin/paprika-pantry`. Add `~/bin` to your `PATH` if
needed. To choose another location, use `make install PREFIX="$HOME/.local"`.

To install the instructions for your AI assistant, choose one:

```bash
make install-skill                       # OpenClaw
make install-skill SKILL_TARGET=codex     # Codex
make install-skill SKILL_TARGET=claude    # Claude Code
```

## Get started

Open Paprika on this Mac and let it finish syncing. Then check access and build
the search index:

```bash
paprika-pantry source status
paprika-pantry index rebuild
```

Now try:

```bash
paprika-pantry recipes search risotto
paprika-pantry recipes show "Mushroom Risotto"
paprika-pantry meals list
```

If something isn't working, run `paprika-pantry doctor` for a diagnosis and next step.
You can still read recipes with `recipes list` and `recipes show` if the index is
missing or unavailable; cooking-history extras may be omitted. Search and indexed
filters need a working index. If an index belongs to a newer paprika-pantry version,
use that version or choose a separate `--home` rather than overwriting it.

## Find something to cook

```bash
# Favorites and highly rated recipes
paprika-pantry recipes list --favorite
paprika-pantry recipes list --min-rating 4

# Dinner with ingredients you want to use—or avoid
paprika-pantry recipes list --category Dinner --ingredient basil
paprika-pantry recipes search tofu --exclude-ingredient peanut

# Something quick, or something you haven't made recently
paprika-pantry recipes list --max-total-time-minutes 30 --sort fewest-ingredients
paprika-pantry recipes list --min-days-since-last-meal 90 --sort lapsed

# Read a recipe, including its notes and original source
paprika-pantry recipes show "Weeknight Pasta"
```

Use a recipe's ID instead of its name if multiple recipes share a name.

Cooking history is a useful clue, not a rating: a recipe last made 90 days ago,
with a usual gap of 14 days, has been out of rotation. That doesn't tell us whether
you still like it. Favorites, ratings, and your notes provide the rest of the picture.

## Check plans and shopping lists

```bash
paprika-pantry meals list
paprika-pantry groceries list
paprika-pantry pantry list
```

These read the information saved in Paprika. With Paprika 4, meals also show recipe
scale and ingredient-only entries; pantry items include locations and notes when
available. A planned meal isn't proof it was cooked, and a pantry entry isn't a
fresh inventory check.

## Collections and recipe sources

We call Paprika 4's **Cookbooks** **Collections**. To list those collections:

```bash
paprika-pantry recipes collections
```

Ordinary recipe lists include recipes from all collections. Recipe details show
the collection when known.

The separate `recipes cookbooks` command groups recipes by their original source,
such as a published cookbook or website:

```bash
paprika-pantry recipes cookbooks
paprika-pantry recipes cookbooks --sort average-rating
```

To see which ingredients appear together in saved recipes:

```bash
paprika-pantry recipes pairings --token tomato --sort meals
```

These pairings describe your recipe collection; they aren't flavor recommendations.

## Keep results up to date

After Paprika finishes syncing, refresh search and cooking history:

```bash
paprika-pantry index update
```

Run `paprika-pantry index rebuild` when you also want to refresh ingredient pairings.
It does more work and can take longer.

You can also ask paprika-pantry to open Paprika and wait for a newer sync time:

```bash
paprika-pantry source launch-app --wait-for-sync
paprika-pantry index update
```

This relies on Paprika syncing after launch; it doesn't directly control cloud
sync. App discovery selects Paprika Recipe Manager 3 or 4 to match the detected
database layout; it does not fall back to the other version. End-to-end sync-on-launch
remains unverified with Paprika 4; if the marker does not advance, check sync in Paprika.

## Upgrading to 2.0 or Paprika 4

Both Paprika 3 and 4 are supported; you don't need to upgrade Paprika to use this
release. After upgrading paprika-pantry from 1.x, or after upgrading Paprika to 4,
rebuild the index once:

```bash
paprika-pantry source status
paprika-pantry index rebuild
paprika-pantry doctor
```

This rebuilds paprika-pantry's own search data, not your Paprika library. You can
still read recipes and lists before rebuilding, but searches and cooking-history
features may ask you to rebuild first. Afterward, return to `index update` for
normal refreshes.

Don't reuse the updated index with paprika-pantry 1.x. If you need to try an older
version, give it a separate data directory with `--home`.

## Export results and find more options

Output is readable text by default. Use JSON for scripts or CSV for spreadsheets:

```bash
paprika-pantry recipes search risotto --format json
paprika-pantry recipes list --format csv
paprika-pantry groceries list --format csv
```

CSV is available for lists; recipe details and diagnostics support text and JSON.
For more filters and options, use `paprika-pantry --help` or a command's own help,
such as `paprika-pantry recipes list --help`.

---

Made with Codex and OpenClaw.
