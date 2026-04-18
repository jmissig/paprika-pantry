## Architecture Review 2026-04-18

### Main issues

1. The source configuration layer still models abandoned source kinds (`paprika-token`, `kappari`) even though the product is now a local-first read-only Paprika SQLite adapter. That dead plumbing leaks into config, doctor output, tests, and source-state persistence.
2. Several source and derived-data types still use sync-era naming like `hash`, `remoteHash`, and `source_remote_hash`. In the current architecture these values are local source fingerprints from Paprika rows, not remote sync identities.
3. `PantryStore` has become a large mixed-responsibility sidecar object that combines migrations, index rebuild orchestration, search queries, cookbook rollups, source-state persistence, and row decoding in one place.
4. The CLI and report layer are mostly coherent, but some names still describe the old architecture rather than the direct-source plus owned-sidecar design the tool actually ships today.

### Refactor plan

1. Collapse source configuration around the only supported canonical source: the local Paprika SQLite database opened read-only. Delete legacy unsupported source kinds and simplify the provider/doctor path accordingly.
2. Rename sync-era hash terminology to local-source fingerprint terminology across source models, derived models, sidecar schema, and reports while preserving behavior.
3. Split the sidecar implementation by responsibility so migrations, index rebuild/write paths, read/query paths, and stored source-state handling are legible and easier to maintain.
4. Keep Paprika Core Data oddities inside the SQLite adapter boundary and avoid pushing those details into the domain, sidecar, or CLI layers.
5. Update tests and docs to match the new structure, then run the full SwiftPM test suite after the refactor phases.
