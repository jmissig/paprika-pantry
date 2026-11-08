# TODO

Active backlog only. Architectural direction and durable constraints live in `AGENTS.md`.
Completed work should leave this file.

## Next

- [ ] Complete the [2.0 hardening and dependency migration plan](docs/2.0-hardening-plan.md): source/sidecar isolation, concurrency correctness, Swift tools 6.2, GRDB 7, native async commands, and store decomposition.

## Later

- [ ] If measured rebuild timings show `derive.ingredient_pairs` or pairing writes are a meaningful bottleneck, investigate incremental pairing refreshes.
