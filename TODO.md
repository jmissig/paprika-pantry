# TODO

Active backlog only. Architectural direction and durable constraints live in `AGENTS.md`.
Completed work should leave this file.

## Now

- [ ] Use [docs/pattern-boundary-and-corrections.md](docs/pattern-boundary-and-corrections.md) to keep the next slices focused on cooking evidence primitives and simple attached notes, not dinner recommendations or correction machinery.
- [ ] Add mechanical recency/lapse query affordances over existing meal-history facts (`meal_count`, `last_meal_at`, query-time `days_since_last_meal`, `median_meal_gap_days`) without labeling recipes as favorites.
- [ ] Draft plain-English human-attached note examples for recipes, ingredients, sources, meal windows, and person/family contexts.

## Next
- [ ] Use [docs/pattern-intelligence-proposal.md](docs/pattern-intelligence-proposal.md) to guide cooking source/derived-output contracts and future Robut-composed House Cooking Almanac/Guide material.
- [ ] If real timings show `derive.ingredient_pairs` or pairing writes are slow, investigate incremental updates for ingredient pairings so `index rebuild` is not the only way to refresh pairing evidence.

## Later

- [ ] Consider explicit `--columns` support for table/csv-like outputs where scan shape matters.
- [ ] Add substitution evidence tables with provenance and support counts, if repeated use-up/substitution questions justify them.
- [ ] Decide whether higher-level ingredient task phrasing should emerge from the general query surface or justify a dedicated command shape.
- [ ] Tighten pattern-report output so confidence limits and contributing evidence stay obvious.

## Not now

- No writes to the real Paprika DB.
- No remote-auth or mirror-first product direction.
- No blind duplication of canonical Paprika rows into the sidecar.
- No background daemon or scheduler.
- No multi-account support.
- No generic Paprika SDK extraction.
- No opaque recommendation logic without evidence or inspectable provenance.
