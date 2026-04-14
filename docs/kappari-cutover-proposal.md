# Kappari Cutover Proposal for `paprika-pantry`

## Summary

This proposal starts from a harder-won conclusion:

- we probably do not want to own Paprika auth and protocol archaeology long term
- but kappari does **not yet look like a finished backend surface** we can simply swap in as-is
- so we should keep the local mirror, sync bookkeeping, and local query surface
- throw out the current direct-auth product direction
- insert a narrow source abstraction
- treat kappari primarily as reference code, protocol knowledge, and possibly a helper layer later

This is still a deliberate architectural reset, but not a blind "replace everything with kappari" move.
The real goal is to stop owning the wrong complexity while keeping control of the local product we actually want.

## What we built so far

### Good work that still matters

These parts still fit the likely future design and should mostly survive:

- local SQLite schema and migrations
- `PantryStore`
- recipe mirror row/model shape
- normalized category links
- tombstone handling
- sync-run recording and reporting
- local read commands:
  - `sync status`
  - `recipes list`
  - `recipes show`
  - `db stats`
- output/report rendering
- most recipe-mirror tests

### Work that is now strategically wrong to keep owning

These parts were reasonable experiments, but should no longer define the architecture:

- `AuthStrategy`
- `PantryAuthenticator`
- `SimpleAccountAuthenticator`
- `PantryConfig`
- `PantrySession`
- `PantryAuthStore`
- `auth` command family
- `PaprikaAccountRemoteClient`
- `PaprikaSimpleAccountRemoteClient`
- `PaprikaTokenRemoteClient`
- direct token-based sync wiring in `SyncRunCommand`
- tests centered on login, session persistence, and direct Paprika HTTP contracts

## Current repo review: keep / replace / delete

### Keep largely intact

#### Local mirror core

- `Sources/PantryKit/Store/PantryDatabase.swift`
- `Sources/PantryKit/Store/PantryStore.swift`
- `Sources/PantryKit/Model/RecipeMirrorReports.swift`
- `Sources/PantryKit/CLI/RecipeCommands.swift`
- `Sources/PantryKit/CLI/DBCommands.swift`
- large parts of `Sources/PantryKit/Sync/PantrySyncEngine.swift`

These files are the real center of gravity.

#### General CLI/runtime plumbing

- `Sources/PantryKit/CLI/CommandContext.swift`
- `Sources/PantryKit/CLI/RuntimeOptions.swift`
- `Sources/PantryKit/Support/JSONOutput.swift`
- `Sources/PantryKit/Support/Console*`
- most of `Sources/PantryKit/Support/PantryPaths.swift`

Paths may need renaming if `config.json` and `session.json` disappear, but the general path-resolution approach is still fine.

### Replace, not preserve

#### Remote abstraction

Current file:

- `Sources/PantryKit/Remote/PaprikaRemoteClient.swift`

Keep the idea, but rename and reframe it.
It should stop being Paprika-specific at the protocol level and become the internal source seam.

Recommended replacement:

- `Sources/PantryKit/Source/PantrySource.swift`
- optionally later: `Sources/PantryKit/Source/KappariSource.swift`
- maybe `Sources/PantryKit/Source/KappariCLI.swift` or `KappariJSONContract.swift`

The sync engine should depend on `PantrySource`, not on a Paprika HTTP client.

Important update after reviewing the canonical kappari repo:

- kappari currently looks more like documented reverse-engineering code plus a Python library than a stable product/backend surface
- I do not currently see a ready-made CLI/query/report layer or a stable JSON contract to consume directly
- that means `PantrySource` is the important immediate move, while `KappariSource` remains a later option rather than an assumption

#### Sync wiring

Current file:

- `Sources/PantryKit/Sync/PantrySyncEngine.swift`

Keep most of the mirror logic, but rename the dependency and terminology:

- `remoteClient` -> `source`
- keep methods like `listRecipeStubs`, `listRecipeCategories`, `fetchRecipe`
- treat returned models as source models, not Paprika protocol models

### Delete wholesale

#### Auth layer

Delete:

- `Sources/PantryKit/Auth/PantryAuthenticator.swift`
- `Sources/PantryKit/Auth/SimpleAccountAuthenticator.swift`
- `Sources/PantryKit/CLI/AuthCommands.swift`
- `Sources/PantryKit/Model/AuthReports.swift`
- `Sources/PantryKit/Model/PantryConfig.swift`
- `Sources/PantryKit/Model/PantrySession.swift`
- `Sources/PantryKit/Support/PantryAuthStore.swift`

#### Direct Paprika HTTP layer

Delete:

- `Sources/PantryKit/Remote/PaprikaAccountRemoteClient.swift`
- `Sources/PantryKit/Remote/PaprikaTokenRemoteClient.swift`

#### Tests to remove

Delete or fully replace:

- `Tests/PantryKitTests/AuthStatusReportTests.swift`
- `Tests/PantryKitTests/PantryAuthStoreTests.swift`
- `Tests/PantryKitTests/PaprikaSimpleAccountRemoteClientTests.swift`
- `Tests/PantryKitTests/PaprikaTokenRemoteClientTests.swift`

These tests validate the part we are choosing not to own.

## Proposed new architecture

Near-term safer shape:

```text
Paprika cloud / Paprika local DB knowledge
  -> source abstraction (`PantrySource`)
  -> RecipeMirrorSyncEngine
  -> PantryStore / SQLite mirror
  -> local CLI reports and queries
```

Possible later shape, if kappari grows into a better runtime boundary:

```text
Paprika cloud / Paprika local DB
  -> kappari
  -> KappariSource
  -> RecipeMirrorSyncEngine
  -> PantryStore / SQLite mirror
  -> local CLI reports and queries
```

## New internal seam

Create one narrow internal source protocol:

```swift
public protocol PantrySource: Sendable {
    func listRecipeStubs() async throws -> [SourceRecipeStub]
    func listRecipeCategories() async throws -> [SourceRecipeCategory]
    func fetchRecipe(uid: String) async throws -> SourceRecipe
}
```

The sync engine should know nothing about:

- bearer tokens
- Paprika login endpoints
- licensed-client behavior
- kappari internals

It should only know the source contract.

## Recommended kappari stance

After inspecting the canonical kappari repo, the cautious stance is:

- treat kappari as a strong **reference implementation and documentation source**
- treat it as a possible helper/runtime dependency later
- do **not** currently assume it already exposes the stable product surface we need

If we eventually build `KappariSource`, the preferred version would be:

- call kappari through a tiny wrapper boundary
- require stable JSON output for the exact data we need
- decode that JSON into `SourceRecipeStub`, `SourceRecipeCategory`, and `SourceRecipe`

But that should now be read as a contingent later move, not the immediate default.

Principles still hold:

- do not scrape human-readable CLI output
- do not make `paprika-pantry` know Paprika auth if we can avoid it
- do not expose raw kappari output as our own public model

## Command surface after cutover

### Keep

- `paprika-pantry sync run`
- `paprika-pantry sync status`
- `paprika-pantry recipes list`
- `paprika-pantry recipes show <uid|name>`
- `paprika-pantry db stats`

### Add

- `paprika-pantry source doctor`

Purpose:

- verify whichever source backend is active
- if/when using kappari, verify it is installed or reachable
- if/when using kappari, verify the expected contract works
- surface source errors clearly

### Remove or demote

Remove the first-class `auth` command family:

- `auth login`
- `auth status`
- `auth logout`

If some source-specific auth check is needed, it belongs behind `source doctor`, not as local credential ownership in `paprika-pantry`.

## Concrete file plan

### New files

- `Sources/PantryKit/Source/PantrySource.swift`
- `Sources/PantryKit/CLI/SourceCommands.swift`
- `Tests/PantryKitTests/SourceDoctorCommandTests.swift`

Possible later additions:

- `Sources/PantryKit/Source/KappariSource.swift`
- `Sources/PantryKit/Source/KappariSourceModels.swift`
- `Tests/PantryKitTests/KappariSourceTests.swift`

### Files to rewrite

- `Sources/PantryKit/CLI/PantryCLI.swift`
  - remove `AuthCommand`
  - add `SourceCommand`
  - update discussion text

- `Sources/PantryKit/CLI/SyncCommands.swift`
  - remove session loading
  - construct the chosen source backend
  - feed it to the sync engine
  - update error text from auth-oriented to source-oriented

- `Sources/PantryKit/Sync/PantrySyncEngine.swift`
  - replace `PaprikaRemoteClient` dependency with `PantrySource`
  - rename remote models to source models

- `Sources/PantryKit/Support/PantryPaths.swift`
  - either remove `configFile` and `sessionFile`, or repurpose config to source settings only
  - keep `databaseFile`

### Files to delete

- everything in `Sources/PantryKit/Auth/`
- `Sources/PantryKit/CLI/AuthCommands.swift`
- `Sources/PantryKit/Model/AuthReports.swift`
- `Sources/PantryKit/Model/PantryConfig.swift`
- `Sources/PantryKit/Model/PantrySession.swift`
- `Sources/PantryKit/Support/PantryAuthStore.swift`
- `Sources/PantryKit/Remote/PaprikaAccountRemoteClient.swift`
- `Sources/PantryKit/Remote/PaprikaTokenRemoteClient.swift`

## Test plan after cutover

### Keep

Keep with minor adjustments:

- `PantryPathsTests`
- `PantryStoreTests`
- `RecipeCommandResolutionTests`
- `RecipeMirrorReportsTests`
- `RecipeMirrorSyncEngineTests`
- `JSONOutputTests`

### Replace

Replace remote/auth tests with source tests:

- test `PantrySource`-driven sync behavior
- test source error handling for whichever backend is active
- test `sync run` reports source failures cleanly
- test `source doctor`
- if later needed, test `KappariSource` JSON decoding and mapping

## Migration stance

We should treat this as a hard pivot, not a compatibility dance.

Recommended stance:

- do not preserve `authStrategy`
- do not preserve session/config compatibility for old login state
- do not preserve direct Paprika HTTP as a peer first-class backend
- if an experimental direct backend survives at all, keep it explicitly non-default and out of the main mental model

## Risks

### Main risk

Kappari may remain better as reference code than as a runtime backend for a while.

Concretely:

- it may not provide a stable machine-readable surface for the exact operations we need
- it may not expose a clean CLI/report layer at all
- using it from Swift may create more cross-language awkwardness than value if we force it too early

### Response

If that happens, the right next move is:

- keep the `PantrySource` seam
- keep the local mirror architecture
- use kappari as implementation guidance where helpful
- only add a thin kappari wrapper if and when that wrapper is actually cleaner than owning the equivalent source code locally

Not:

- resurrect and continue expanding direct Paprika auth ownership inside `paprika-pantry` as the long-term product plan
- or blindly declare kappari the backend before it has earned that role

## Recommended implementation order

1. introduce `PantrySource` and source models
2. rewrite `RecipeMirrorSyncEngine` to depend on `PantrySource`
3. implement a fake/in-memory source for tests
4. move existing sync-engine tests onto the source abstraction
5. add `source doctor`
6. remove auth commands and auth/session persistence
7. delete direct Paprika HTTP code and tests
8. update docs and TODO to reflect the source-first architecture
9. only then decide whether the first real source backend should be:
   - a thin kappari wrapper, or
   - local code informed by kappari’s reverse-engineering work

## Bottom line

The local mirror work was the right bet.
The auth work was useful reconnaissance, but it should now be discarded as product architecture.

`paprika-pantry` should own:

- local schema
- local sync state
- local mirror integrity
- local query/report UX

It should not own as first-class product identity:

- Paprika authentication
- Paprika licensed-client behavior
- Paprika protocol archaeology

Kappari is currently most valuable as understanding, documentation, and possible future leverage, not yet obviously as the finished backend.
