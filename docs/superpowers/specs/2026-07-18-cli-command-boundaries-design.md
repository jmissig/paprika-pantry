# CLI Command Boundaries Design

**Status:** Approved for implementation

## Goal

Make the command tree and code organization express four distinct responsibilities:

- `source` inspects or operates on the real local Paprika database and Mac app.
- `recipes` queries canonical recipes and recipe-derived sidecar evidence.
- `index` manages and reports on the owned sidecar index.
- top-level `doctor` diagnoses health across the source and sidecar layers.

The cleanup intentionally removes the old command names rather than retaining compatibility aliases.

## Command Surface

Rename `source doctor` to `source status`.

`source` will contain:

- `source status` — report readiness and health of the configured real Paprika source
- `source last-sync-time` — report the last observed sync time from Paprika's local metadata
- `source stats` — report direct source counts and sampled source coverage
- `source launch-app` — explicitly launch the local Paprika Mac app and optionally observe sync advancement

Move `source cookbooks` to `recipes cookbooks`.

`recipes cookbooks` will retain the existing cookbook/source aggregate behavior, filters, output formats, and sidecar readiness checks. Its placement under `recipes` makes clear that it is a recipe-domain report backed by owned derived data, not a source-readiness command.

Top-level `doctor` remains the cross-layer diagnostic command. `index stats` remains the focused sidecar/index status command.

## Code Organization

- Replace `SourceDoctorCommand` with `SourceStatusCommand` in the source command family.
- Move the cookbook command registration and implementation into the recipe command family.
- Move cookbook aggregate report types and rendering helpers from source-report code into recipe-report code where practical, so implementation boundaries match the public command tree.
- Do not change the underlying cookbook aggregate store/query behavior.
- Do not add aliases for `source doctor` or `source cookbooks`.

## Documentation and Agent Guidance

Update README examples, the bundled `paprika-pantry` skill, tests, and repository docs to use the new names.

Restore the applicable AGENTS guidance from the shared CLI command-shape standard:

- evidence reads such as `source status` remain one-shot
- JSON and non-TTY execution never prompt
- risky writes and repairs require explicit scope plus preview or confirmation
- bounded source launches and sidecar rebuilds remain explicitly invoked and clearly explain their effects

Add a durable namespace rule to AGENTS:

- `source` is limited to the real Paprika database/app boundary
- `recipes` owns canonical recipe reads and recipe-derived evidence
- `index` owns sidecar lifecycle and focused status
- `doctor` cuts across source and sidecar health

## Error and Output Behavior

The renamed and moved commands preserve current text, JSON, and CSV behavior. Existing validation and readiness errors should name the new command paths. Help output must not advertise either removed path.

No interactive prompts, confirmation flags, or dry-run behavior are added. `source launch-app` and `index rebuild` are bounded explicit commands whose help and reports already explain their effects.

## Verification

- Add or update command parsing/help tests for `source status` and `recipes cookbooks`.
- Verify the old command paths are rejected and absent from help.
- Update report expectations that include command names.
- Run `git diff --check` and the full `make test` suite.
- Smoke-check root, `source`, and `recipes` help output from the built binary.

## Non-Goals

- No compatibility aliases or deprecation period.
- No changes to cookbook aggregation semantics or sidecar schema.
- No consolidation of focused source reads into `source status`.
- No broader CLI redesign or version bump as part of this slice.
