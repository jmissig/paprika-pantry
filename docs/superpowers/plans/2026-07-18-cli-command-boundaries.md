# CLI Command Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the source-readiness command to `source status`, move cookbook aggregates to `recipes cookbooks`, and make code, tests, docs, and AGENTS reflect the source/recipes/index/doctor boundaries.

**Architecture:** Keep the existing services and store queries unchanged. Move only command registration, command/report types, and their public command strings so the CLI tree mirrors the existing real-source versus owned-sidecar layers. Preserve top-level `doctor` as the cross-layer diagnostic and `index stats` as focused sidecar status.

**Tech Stack:** Swift 6, swift-argument-parser, XCTest, Markdown

## Global Constraints

- Do not retain aliases for `source doctor` or `source cookbooks`.
- `source` is limited to the real Paprika database/app boundary.
- `recipes` owns canonical recipe reads and recipe-derived sidecar evidence.
- `index` owns sidecar lifecycle and focused status.
- top-level `doctor` cuts across source and sidecar health.
- Preserve cookbook aggregation semantics, flags, text/JSON/CSV output, and sidecar schema.
- Do not add prompts, confirmation flags, dry-run behavior, or a version bump.

---

### Task 1: Rename and move the command/report surface

**Files:**
- Modify: `Sources/PantryKit/CLI/SourceCommands.swift`
- Modify: `Sources/PantryKit/CLI/RecipeCommands.swift`
- Modify: `Sources/PantryKit/Model/SourceReports.swift`
- Create: `Sources/PantryKit/Model/RecipeCookbookReports.swift`
- Create: `Tests/PantryKitTests/CommandShapeTests.swift`
- Modify: `Tests/PantryKitTests/SourceDoctorReportTests.swift`
- Modify: `Tests/PantryKitTests/QueryReportsTests.swift`
- Modify: `Tests/PantryKitTests/OutputFormatTests.swift`

**Interfaces:**
- Produces: `SourceStatusCommand`, registered as `source status`
- Produces: `RecipesCookbooksCommand`, registered as `recipes cookbooks`
- Produces: `SourceStatusReport`, whose `command` is `source status`
- Produces: `RecipesCookbooksReport`, whose `command` is `recipes cookbooks`
- Preserves: `PantrySourceDoctorSnapshot`, `CookbookAggregateSummary`, `PantrySidecarStore.listCookbookAggregates(...)`

- [x] **Step 1: Add failing command-shape and report expectations**

Create `Tests/PantryKitTests/CommandShapeTests.swift`:

```swift
import XCTest
@testable import PantryKit

final class CommandShapeTests: XCTestCase {
    func testSourceContainsOnlyRealSourceCommands() {
        let names = SourceCommand.configuration.subcommands.map { $0.configuration.commandName }
        XCTAssertEqual(names, ["status", "last-sync-time", "stats", "launch-app"])
    }

    func testRecipesContainsCookbookAggregateCommand() {
        let names = RecipesCommand.configuration.subcommands.map { $0.configuration.commandName }
        XCTAssertEqual(names, ["list", "show", "search", "features", "ingredients", "pairings", "cookbooks"])
    }
}
```

In `SourceDoctorReportTests.swift`, instantiate `SourceStatusReport` and assert:

```swift
XCTAssertEqual(report.command, "source status")
XCTAssertTrue(report.humanDescription.contains("source status:"))
```

In `QueryReportsTests.swift` and `OutputFormatTests.swift`, replace `SourceCookbooksReport` with `RecipesCookbooksReport` and change the human-output expectation to:

```swift
XCTAssertTrue(report.humanDescription.contains("recipes cookbooks: 2 cookbook/source groups"))
```

- [x] **Step 2: Run focused tests and verify the old surface fails**

Run:

```bash
swift test --build-path build --filter CommandShapeTests
swift test --build-path build --filter SourceDoctorReportTests
swift test --build-path build --filter QueryReportsTests/testRecipesCookbooksReportIncludesAggregateEvidenceAndUnlabeledBucket
```

Expected: failures because the old registrations still expose `doctor`/`cookbooks` under `source`, `recipes` lacks `cookbooks`, and the renamed report types do not exist.

- [x] **Step 3: Implement the minimal command migration**

In `SourceCommands.swift`:

```swift
subcommands: [
    SourceStatusCommand.self,
    SourceLastSyncTimeCommand.self,
    SourceStatsCommand.self,
    SourceLaunchAppCommand.self,
]
```

Rename `SourceDoctorCommand` to `SourceStatusCommand`, set `commandName: "status"`, and write `SourceStatusReport`.

In `RecipeCommands.swift`, append `RecipesCookbooksCommand.self` to the recipe subcommands and move the existing cookbook options, validation, store query, and output code into that command. It must write `RecipesCookbooksReport` without changing any flags or query arguments.

Move/rename the report structs so their command strings are:

```swift
self.command = "source status"
self.command = "recipes cookbooks"
```

Move `renderedCookbookName`, `renderedRatingDistribution`, and `renderedDecimal` with `RecipesCookbooksReport` if they are used only by recipe-domain reports.

- [x] **Step 4: Run focused tests and command help**

Run:

```bash
swift test --build-path build --filter CommandShapeTests
swift test --build-path build --filter SourceDoctorReportTests
swift test --build-path build --filter QueryReportsTests/testRecipesCookbooksReportIncludesAggregateEvidenceAndUnlabeledBucket
swift test --build-path build --filter OutputFormatTests/testRecipesCookbooksReportRendersCSVRows
swift build --build-path build --product paprika-pantry
build/debug/paprika-pantry source --help
build/debug/paprika-pantry recipes --help
```

Expected: focused tests pass; source help lists `status`, `last-sync-time`, `stats`, and `launch-app` only; recipes help lists `cookbooks`; neither help text lists either removed command path.

- [x] **Step 5: Commit the command migration**

```bash
git add Sources/PantryKit/CLI/SourceCommands.swift Sources/PantryKit/CLI/RecipeCommands.swift Sources/PantryKit/Model/SourceReports.swift Sources/PantryKit/Model/RecipeReports.swift Tests/PantryKitTests/CommandShapeTests.swift Tests/PantryKitTests/SourceDoctorReportTests.swift Tests/PantryKitTests/QueryReportsTests.swift Tests/PantryKitTests/OutputFormatTests.swift
git commit -m "Clarify source and recipe command boundaries"
```

### Task 2: Restore AGENTS rules and update public documentation

**Files:**
- Modify: `AGENTS.md`
- Modify: `README.md`
- Modify: `skills/paprika-pantry/SKILL.md`
- Modify: `skills/paprika-pantry/references/read-only-exploration.md`
- Modify: `docs/read-only-exploration.md`
- Modify: `docs/pattern-boundary-and-corrections.md`
- Modify: `docs/usage-facts-contract.md`
- Modify: `docs/superpowers/plans/2026-07-18-cli-command-boundaries.md`

**Interfaces:**
- Consumes: the exact command names from Task 1
- Produces: durable namespace guidance and current public examples

- [x] **Step 1: Restore and sharpen AGENTS command guidance**

Change the one-shot example to name `source status` explicitly and retain the bounded-action rule:

```markdown
- human setup/auth/config flows may be guided, but evidence reads such as `recipes`, `meals`, `groceries`, `pantry`, and `source status` should stay one-shot
- JSON, non-TTY, and `--non-interactive` / `--no-input` modes must never prompt
- risky writes and repairs need explicit scope plus preview or confirmation; bounded source launches and index rebuilds must be explicitly invoked and explain their effects
```

Add the namespace boundary:

```markdown
- `source` is limited to readiness, freshness, coverage, and bounded app operations at the real Paprika database/app boundary
- `recipes` owns canonical recipe reads plus recipe-derived sidecar evidence such as search, features, ingredients, pairings, and cookbook/source aggregates
- `index` owns sidecar lifecycle and focused sidecar status
- top-level `doctor` diagnoses health across the source and sidecar layers
```

Replace remaining live AGENTS examples of `source doctor` and `source cookbooks` with `source status` and `recipes cookbooks`.

- [x] **Step 2: Update README, bundled skill, and focused docs**

Replace all live examples and prose references:

```text
source doctor    -> source status
source cookbooks -> recipes cookbooks
```

Keep the design spec and implementation plan references to removed commands because they document the migration itself.

- [x] **Step 3: Verify documentation has no stale live command paths**

Run:

```bash
rg -n "source doctor|source cookbooks" AGENTS.md README.md skills docs \
  --glob '!docs/superpowers/specs/2026-07-18-cli-command-boundaries-design.md' \
  --glob '!docs/superpowers/plans/2026-07-18-cli-command-boundaries.md'
git diff --check
```

Expected: `rg` returns no matches and `git diff --check` exits successfully.

- [x] **Step 4: Commit the guidance and documentation**

```bash
git add AGENTS.md README.md skills/paprika-pantry/SKILL.md skills/paprika-pantry/references/read-only-exploration.md docs/read-only-exploration.md docs/pattern-boundary-and-corrections.md docs/usage-facts-contract.md docs/superpowers/plans/2026-07-18-cli-command-boundaries.md
git commit -m "Document pantry CLI namespace boundaries"
```

### Task 3: Full verification

**Files:**
- Verify only; modify earlier task files only if verification exposes a defect

**Interfaces:**
- Consumes: all changes from Tasks 1 and 2
- Produces: evidence that the new command surface is complete and old paths are gone

- [x] **Step 1: Run the full repository suite**

Run:

```bash
git diff --check
make test
```

Expected: no whitespace errors and all 93 tests pass (91 existing tests plus two command-shape tests).

- [x] **Step 2: Smoke-check the final command tree**

Run:

```bash
make build
build/debug/paprika-pantry --help
build/debug/paprika-pantry source --help
build/debug/paprika-pantry recipes --help
build/debug/paprika-pantry source doctor
build/debug/paprika-pantry source cookbooks
```

Expected: root help still lists `source`, `recipes`, `index`, and `doctor`; source help lists `status` but not `doctor` or `cookbooks`; recipes help lists `cookbooks`; both removed invocations exit nonzero as unknown subcommands.

- [x] **Step 3: Verify repository state**

Run:

```bash
git status --short --branch
git log -3 --oneline
```

Expected: the worktree is clean and the two implementation commits follow design commit `b01f8ca`.
