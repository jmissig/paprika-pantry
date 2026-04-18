# TODO

- [ ] Build an explicit `paprika-pantry` SKILL for agents so coding agents and local assistants have a clear, repo-native usage contract.

Active backlog only. Architectural direction and durable constraints live in `AGENTS.md`.
Completed work should leave this file.

## Now

- [ ] Align output philosophy with `protect-cadence` and `karivis`: compact human output by default, `--format json` as the preferred structured interface, `--json` as shorthand, and clean human/json/csv behavior under one explicit format model.
- [ ] Add source/cookbook usage summaries derived from linked meal history where the evidence is strong enough to report cleanly.
- [ ] Add ingredient co-occurrence / pairing tables with inspectable evidence.


## Next

- [ ] Add `first_cooked_at` usage stats

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
