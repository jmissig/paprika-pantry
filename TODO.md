# TODO

Active backlog only. Architectural direction and durable constraints live in `AGENTS.md`.
Completed work should leave this file.

## Now

- [ ] Add practical interpretation examples for mechanical recency/lapse evidence, especially `last_meal_at` and `median_meal_gap_days`, without labeling recipes as favorites.

## Next
- [ ] If real timings show `derive.ingredient_pairs` or pairing writes are slow, investigate incremental updates for ingredient pairings so `index rebuild` is not the only way to refresh pairing evidence.

## Later

- [ ] Consider explicit `--columns` support for table/csv-like outputs where scan shape matters.
- [ ] Add substitution evidence tables with provenance and support counts, if repeated use-up/substitution questions justify them.
- [ ] Decide whether higher-level ingredient task phrasing should emerge from the general query surface or justify a dedicated command shape.
- [ ] Tighten derived output so confidence limits and contributing evidence stay obvious.

## Not now

- No writes to the real Paprika DB.
- No remote-auth or mirror-first product direction.
- No blind duplication of canonical Paprika rows into the sidecar.
- No `paprika-pantry` annotation layer, pending-note queue, or correction database; chat-originated suggestions belong in OpenClaw/Obsidian.
- No background daemon or scheduler.
- No multi-account support.
- No generic Paprika SDK extraction.
- No opaque recommendation logic without evidence or inspectable provenance.
