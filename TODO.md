# TODO

Active backlog only. Architectural direction and durable constraints live in `AGENTS.md`.
Completed work should leave this file.

## Now


## Next

- [ ] Add `first_cooked_at` usage stats
- [ ] Investigate partial index updates behind `paprika-pantry index update` so unchanged recipes do not require a full rebuild.
- [ ] Investigate incremental updates for ingredient pairings so `index rebuild` is not the only way to refresh pairing evidence.

## Later

- [ ] Consider explicit `--columns` support for table/csv-like outputs where scan shape matters.
- [ ] Add substitution candidate tables with provenance and evidence counts.
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
