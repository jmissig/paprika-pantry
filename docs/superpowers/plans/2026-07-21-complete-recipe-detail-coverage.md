# Complete Paprika Recipe Detail Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the direct Paprika reader expose complete useful recipe detail, with `description` and `notes` preserved as distinct canonical fields, search rebuilt around those semantics, bounded photo metadata, and observable field coverage.

**Architecture:** `PaprikaSQLiteSource` remains the only adapter that knows Paprika Core Data column names and filesystem layout. `SourceRecipe` and `RecipeDetail` expose stable typed fields; the sidecar stores only rebuildable search inputs and keeps description and notes in separate columns. Photo bytes remain in Paprika's files and are never copied into the sidecar.

**Tech Stack:** Swift 6, GRDB/SQLite/FTS5, swift-argument-parser, XCTest, Markdown

## Global Constraints

- `description` and `notes` are independent Paprika fields everywhere; neither may fall back to, overwrite, or masquerade as the other.
- The April 2026 `COALESCE(NULLIF(ZNOTES, ''), ZDESCRIPTIONTEXT)` behavior was a transitional adapter shortcut for an older model that exposed only `notes`; remove it completely rather than preserving it as compatibility behavior.
- `hasNotes` means nonblank Paprika notes only. A description-only recipe must report `hasNotes == false`.
- Search indexes description and notes independently and may match either field.
- Older Paprika schemas that lack an optional column return `nil` or an empty photo collection; they do not fail source initialization.
- Keep Paprika access read-only and keep raw `Z...` schema names inside `PaprikaSQLiteSource`.
- Do not add a `.paprikarecipes` importer, a second canonical recipe database, Paprika writes, or a generic raw-column dump.
- Do not copy image bytes, inline base64, or create a photo mirror. Expose only source metadata and a local path when the Paprika-owned file currently exists.
- The sidecar remains disposable and rebuildable. There is one known installation, on this Mac, so do not add compatibility migration code for the old merged schema: change the baseline schema, delete the installed sidecar during rollout, and rebuild it from Paprika.
- Do not install the binary or bundled skill during routine implementation or verification. Installation is a separate explicit rollout action.

---

### Task 1: Separate canonical description and notes and expose missing text fields

**Files:**
- Modify: `Sources/PantryKit/Source/PantrySource.swift`
- Modify: `Sources/PantryKit/Source/PaprikaSQLiteSource.swift`
- Modify: `Sources/PantryKit/Recipes/RecipeReadService.swift`
- Modify: `Sources/PantryKit/Model/RecipeReports.swift`
- Modify: `Tests/PantryKitTests/PaprikaSQLiteSourceTests.swift`
- Modify: `Tests/PantryKitTests/QueryReportsTests.swift`
- Modify: fixture construction call sites returned by `rg -n "SourceRecipe\(" Tests Sources`

**Interfaces:**
- `SourceRecipe.description: String?`
- `SourceRecipe.notes: String?`
- `SourceRecipe.difficulty: String?`
- `SourceRecipe.nutrition: String?`
- `SourceRecipe.sourceURL: String?`
- `SourceRecipe.imageURL: String?`
- The same six fields on `RecipeDetail`
- Raw JSON keys: `description`, `notes`, `difficulty`, `nutritional_info`, `source_url`, `image_url`

- [ ] **Step 1: Write failing source-model and report tests**

Extend the `ZRECIPE` fixture schema in `PaprikaSQLiteSourceTests.swift` with:

```sql
ZDIFFICULTY VARCHAR,
ZIMAGEURL VARCHAR,
ZNUTRITIONALINFO VARCHAR,
ZSOURCEURL VARCHAR,
```

Make recipe `AAA` contain both fields plus the new detail values:

```sql
ZDESCRIPTIONTEXT = 'A bright bean soup.',
ZNOTES = 'Finish with lemon.',
ZDIFFICULTY = 'Easy',
ZNUTRITIONALINFO = 'Per serving: 320 calories',
ZSOURCEURL = 'https://example.test/weeknight-soup',
ZIMAGEURL = 'https://example.test/weeknight-soup.jpg'
```

Add three active rows used only by a focused regression test:

```sql
INSERT INTO ZRECIPE (Z_PK, ZINTRASH, ZNAME, ZDESCRIPTIONTEXT, ZNOTES, ZUID)
VALUES
    (3, 0, 'Description Only', 'Description sentinel.', NULL, 'CCC'),
    (4, 0, 'Notes Only', NULL, 'Notes sentinel.', 'DDD'),
    (5, 0, 'Neither Field', NULL, NULL, 'EEE');
```

Assert all four semantic cases:

```swift
XCTAssertEqual(both.description, "A bright bean soup.")
XCTAssertEqual(both.notes, "Finish with lemon.")
XCTAssertEqual(descriptionOnly.description, "Description sentinel.")
XCTAssertNil(descriptionOnly.notes)
XCTAssertNil(notesOnly.description)
XCTAssertEqual(notesOnly.notes, "Notes sentinel.")
XCTAssertNil(neither.description)
XCTAssertNil(neither.notes)
```

Also assert that `RecipeDetail.target.hasNotes` is `true` for `AAA` and `DDD`, but `false` for `CCC` and `EEE`. In `QueryReportsTests.swift`, assert that `RecipesShowReport.humanDescription` renders separate `description:` and `notes:` blocks and includes difficulty, nutrition, source URL, and image URL labels.

- [ ] **Step 2: Run focused tests and verify the collapsed model fails**

Run:

```bash
swift test --build-path build --filter PaprikaSQLiteSourceTests
swift test --build-path build --filter QueryReportsTests
```

Expected: compile failures because `SourceRecipe` and `RecipeDetail` do not have the new fields, followed by assertion failures until the adapter stops collapsing description into notes.

- [ ] **Step 3: Implement independent canonical fields**

Add the six fields to `SourceRecipe` and `RecipeDetail`, with initializer parameters in the same order:

```swift
public let description: String?
public let notes: String?
public let difficulty: String?
public let nutrition: String?
public let sourceURL: String?
public let imageURL: String?
```

In `PaprikaSQLiteSource.fetchRecipe`, replace `notesExpression` with independent optional expressions:

```swift
\(self.schema.optionalTextExpression(column: "ZDESCRIPTIONTEXT")) AS description,
\(self.schema.optionalTextExpression(column: "ZNOTES")) AS notes,
\(self.schema.optionalTextExpression(column: "ZDIFFICULTY")) AS difficulty,
\(self.schema.optionalTextExpression(column: "ZNUTRITIONALINFO")) AS nutrition,
\(self.schema.optionalTextExpression(column: "ZSOURCEURL")) AS source_url,
\(self.schema.optionalTextExpression(column: "ZIMAGEURL")) AS image_url,
```

Delete `PaprikaSQLiteSchema.notesExpression`. Pass the independent row values into `SourceRecipe`, `RecipeDetail`, and `makeRawJSON`; do not retain any fallback expression in another helper.

Render nonblank fields in this order in `RecipesShowReport.humanDescription`: description, difficulty, nutrition, source URL, image URL, ingredients, directions, notes. Keep ingredients and directions multiline behavior unchanged.

Update every test fixture `SourceRecipe(...)` initializer explicitly with the six new optional arguments. Do not add default values that would hide missed production call sites.

- [ ] **Step 4: Run the canonical-detail tests**

Run:

```bash
swift test --build-path build --filter PaprikaSQLiteSourceTests
swift test --build-path build --filter QueryReportsTests
swift test --build-path build --filter RecipeCommandResolutionTests
swift test --build-path build --filter JSONOutputTests
```

Expected: all focused tests pass; JSON contains separate `description` and `notes`; description-only recipes have `target.hasNotes == false`.

- [ ] **Step 5: Commit the canonical detail boundary**

```bash
git add Sources/PantryKit/Source/PantrySource.swift Sources/PantryKit/Source/PaprikaSQLiteSource.swift Sources/PantryKit/Recipes/RecipeReadService.swift Sources/PantryKit/Model/RecipeReports.swift Tests/PantryKitTests
git commit -m "Separate Paprika recipe descriptions and notes"
```

### Task 2: Change the fresh sidecar schema to independent description and notes search fields

**Files:**
- Modify: `Sources/PantryKit/Store/PantryDatabase.swift`
- Modify: `Sources/PantryKit/Store/PantryStore.swift`
- Modify: `Tests/PantryKitTests/PantrySidecarDatabaseTests.swift`
- Modify: `Tests/PantryKitTests/PantrySidecarStoreTests.swift`

**Interfaces:**
- `recipe_search_documents.description TEXT`
- `recipe_search_documents.notes TEXT`
- `recipe_search_fts.description`
- `recipe_search_fts.notes`
- `RecipeSearchDocument.description: String?`
- `has_notes` continues to derive only from `recipe_search_documents.notes`

- [ ] **Step 1: Write failing fresh-schema and search-semantics tests**

In `PantrySidecarDatabaseTests.swift`, extend the current-schema test to require `description` in both search tables:

```swift
XCTAssertTrue(try columns(in: "recipe_search_documents", db: db).contains("description"))
XCTAssertTrue(try columns(in: "recipe_search_fts", db: db).contains("description"))
```

Do not add an old-schema upgrade fixture or a migration test. The only installed sidecar will be removed and recreated during rollout.

In `PantrySidecarStoreTests.swift`, build four recipes with the same semantic matrix from Task 1. After `rebuildRecipeIndexes`, assert:

```swift
XCTAssertEqual(try store.searchRecipes(query: "Description sentinel").map(\.uid), ["CCC"])
XCTAssertEqual(try store.searchRecipes(query: "Notes sentinel").map(\.uid), ["DDD"])
XCTAssertEqual(try store.searchRecipes(query: "bright bean").map(\.uid), ["AAA"])
XCTAssertEqual(try store.searchRecipes(query: "finish lemon").map(\.uid), ["AAA"])
XCTAssertEqual(try store.searchRecipes(query: "Description sentinel").first?.target.hasNotes, false)
XCTAssertEqual(try store.searchRecipes(query: "Notes sentinel").first?.target.hasNotes, true)
```

- [ ] **Step 2: Run focused tests and verify the baseline schema fails**

Run:

```bash
swift test --build-path build --filter PantrySidecarDatabaseTests
swift test --build-path build --filter PantrySidecarStoreTests
```

Expected: failures because the baseline sidecar schema has no description column and FTS cannot match description independently.

- [ ] **Step 3: Change the baseline sidecar schema and update indexing**

Edit the original `recipe-search-v1` table definitions so every newly created sidecar has independent fields:

```swift
try db.create(table: "recipe_search_documents") { table in
    table.column("uid", .text).notNull().primaryKey()
    table.column("name", .text).notNull()
    table.column("categories", .text).notNull().defaults(to: "")
    table.column("source_name", .text)
    table.column("ingredients", .text)
    table.column("description", .text)
    table.column("notes", .text)
    table.column("source_fingerprint", .text)
    table.column("indexed_at", .text).notNull()
}

try db.create(virtualTable: "recipe_search_fts", using: FTS5()) { table in
    table.column("uid").notIndexed()
    table.column("name")
    table.column("categories")
    table.column("source_name")
    table.column("ingredients")
    table.column("description")
    table.column("notes")
    table.tokenizer = .unicode61()
}
```

Do not register `recipe-search-description-v1` or any other compatibility migration. Supporting an old on-disk sidecar after rollout is not a product requirement for this single-install tool.

Add `description` to `RecipeSearchDocument`, populate it from `SourceRecipe.description`, and include it in both insert statements. Leave the existing `has_notes` SQL expression bound exclusively to `recipe_search_documents.notes`.

- [ ] **Step 4: Run fresh-schema and search tests**

Run:

```bash
swift test --build-path build --filter PantrySidecarDatabaseTests
swift test --build-path build --filter PantrySidecarStoreTests
```

Expected: all focused tests pass; a fresh sidecar contains both columns; rebuilt search matches description and notes independently.

- [ ] **Step 5: Commit the sidecar schema change**

```bash
git add Sources/PantryKit/Store/PantryDatabase.swift Sources/PantryKit/Store/PantryStore.swift Tests/PantryKitTests/PantrySidecarDatabaseTests.swift Tests/PantryKitTests/PantrySidecarStoreTests.swift
git commit -m "Index recipe descriptions separately from notes"
```

### Task 3: Expose bounded primary and additional photo metadata

**Files:**
- Modify: `Sources/PantryKit/Source/PantrySource.swift`
- Modify: `Sources/PantryKit/Source/PaprikaSQLiteSource.swift`
- Modify: `Sources/PantryKit/Recipes/RecipeReadService.swift`
- Modify: `Sources/PantryKit/Model/RecipeReports.swift`
- Modify: `Tests/PantryKitTests/PaprikaSQLiteSourceTests.swift`
- Modify: `Tests/PantryKitTests/QueryReportsTests.swift`
- Modify: fixture construction call sites returned by `rg -n "SourceRecipe\(" Tests Sources`

**Interfaces:**
- `SourceRecipePhoto.Kind`: `primary`, `additional`
- `SourceRecipePhoto.kind: Kind`
- `SourceRecipePhoto.uid: String?`
- `SourceRecipePhoto.filename: String`
- `SourceRecipePhoto.largeFilename: String?`
- `SourceRecipePhoto.name: String?`
- `SourceRecipePhoto.order: Int?`
- `SourceRecipePhoto.photoHash: String?`
- `SourceRecipePhoto.isDownloaded: Bool`
- `SourceRecipePhoto.isUploaded: Bool`
- `SourceRecipePhoto.localPath: String?`
- `SourceRecipePhoto.largeLocalPath: String?`
- `SourceRecipe.photos: [SourceRecipePhoto]`
- `RecipeDetail.photos: [SourceRecipePhoto]`

- [ ] **Step 1: Write failing photo metadata tests**

Extend the test fixture's `ZRECIPE` columns with `ZPHOTO`, `ZPHOTOLARGE`, `ZPHOTOHASH`, `ZPHOTOISDOWNLOADED`, and `ZPHOTOISUPLOADED`. Add optional `ZRECIPEPHOTO` with the real metadata columns used by the adapter:

```sql
CREATE TABLE ZRECIPEPHOTO (
    Z_PK INTEGER PRIMARY KEY,
    ZISDOWNLOADED INTEGER,
    ZISUPLOADED INTEGER,
    ZORDERFLAG INTEGER,
    ZRECIPE INTEGER,
    ZFILENAME VARCHAR,
    ZNAME VARCHAR,
    ZPHOTOHASH VARCHAR,
    ZUID VARCHAR
)
```

Create fixture files at:

```text
Data/Photos/AAA/primary.jpg
Data/Photos/AAA/primary-large.jpg
Data/Photos/AAA/step-1.jpg
```

Populate one primary photo with both filename variants and two additional rows, leaving the second additional file absent. Assert deterministic ordering, metadata preservation, that the primary photo resolves both local paths, and that `localPath` is non-`nil` only for additional files that exist.

Add a compatibility test with no `ZRECIPEPHOTO` table and no photo columns; `fetchRecipe` must succeed with `photos == []`.

- [ ] **Step 2: Run focused tests and verify photo metadata is absent**

Run:

```bash
swift test --build-path build --filter PaprikaSQLiteSourceTests
swift test --build-path build --filter QueryReportsTests
```

Expected: compile failures because `SourceRecipePhoto` and `photos` do not exist.

- [ ] **Step 3: Implement read-only photo metadata discovery**

Add the `SourceRecipePhoto` type and `photos` fields. Extend `PaprikaSQLiteSchema` with optional `recipePhotoColumns`, populated only when `ZRECIPEPHOTO` exists.

Build the primary photo from optional `ZRECIPE` fields. Fetch additional rows only when `ZRECIPEPHOTO` contains `ZRECIPE`, `ZFILENAME`, and `ZUID`; order by `ZORDERFLAG`, then `ZUID`. Resolve a candidate path as:

```swift
databaseURL
    .deletingLastPathComponent() // Data/Database
    .deletingLastPathComponent() // Data
    .appendingPathComponent("Photos", isDirectory: true)
    .appendingPathComponent(recipeUID, isDirectory: true)
    .appendingPathComponent(filename)
```

Resolve `ZPHOTOLARGE` through the same path rule into `largeFilename` and `largeLocalPath` for the primary photo. Set either local path to the standardized path only when `FileManager.fileExists(atPath:)` is true. Do not read, hash, copy, or decode the image.

Text output should include `photos: N`, followed by one compact line per photo containing kind, filename, download state, and local path when present. Codable JSON should expose the complete structured photo array.

- [ ] **Step 4: Run photo and detail output tests**

Run:

```bash
swift test --build-path build --filter PaprikaSQLiteSourceTests
swift test --build-path build --filter QueryReportsTests
swift test --build-path build --filter JSONOutputTests
```

Expected: all focused tests pass; no image bytes appear in output or the sidecar.

- [ ] **Step 5: Commit bounded photo support**

```bash
git add Sources/PantryKit/Source/PantrySource.swift Sources/PantryKit/Source/PaprikaSQLiteSource.swift Sources/PantryKit/Recipes/RecipeReadService.swift Sources/PantryKit/Model/RecipeReports.swift Tests/PantryKitTests
git commit -m "Expose Paprika recipe photo metadata"
```

### Task 4: Add semantic coverage reporting and update architecture/skill guidance

**Files:**
- Modify: `Sources/PantryKit/Source/PantrySource.swift`
- Modify: `Sources/PantryKit/Source/PaprikaSQLiteSource.swift`
- Modify: `Sources/PantryKit/Source/SourceStatsService.swift`
- Modify: `Sources/PantryKit/Model/SourceReports.swift`
- Modify: `Tests/PantryKitTests/SourceStatsServiceTests.swift`
- Modify: `Tests/PantryKitTests/SourceDoctorReportTests.swift`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `skills/paprika-pantry/SKILL.md`
- Modify: `skills/paprika-pantry/references/read-only-exploration.md`
- Modify: `docs/read-only-exploration.md`
- Modify: `docs/usage-facts-contract.md`

**Interfaces:**
- `SourceRecipeFieldCoverage` with counts for descriptions, notes, both, difficulty, nutrition, source URLs, image URLs, primary photos, recipes with additional photos, and total additional photos
- `PantrySource.recipeFieldCoverage() async throws -> SourceRecipeFieldCoverage`
- `source stats` text/JSON exposes the named coverage counts

- [ ] **Step 1: Write failing coverage and documentation expectations**

Add `SourceRecipeFieldCoverage` expectations in `SourceStatsServiceTests.swift` using an in-memory source with the four semantic description/notes cases. Assert:

```swift
XCTAssertEqual(snapshot.recipeFieldCoverage.descriptionCount, 2)
XCTAssertEqual(snapshot.recipeFieldCoverage.notesCount, 2)
XCTAssertEqual(snapshot.recipeFieldCoverage.descriptionAndNotesCount, 1)
```

Add populated examples for the other fields and photos, then assert every count. In `SourceDoctorReportTests.swift`, assert human output contains:

```text
recipes_with_description:
recipes_with_notes:
recipes_with_description_and_notes:
recipes_with_difficulty:
recipes_with_nutrition:
recipes_with_source_url:
recipes_with_image_url:
recipes_with_primary_photo:
recipes_with_additional_photos:
additional_photos_total:
```

- [ ] **Step 2: Run focused tests and verify coverage is missing**

Run:

```bash
swift test --build-path build --filter SourceStatsServiceTests
swift test --build-path build --filter SourceDoctorReportTests
```

Expected: compile failures because field coverage is not part of the source or report models.

- [ ] **Step 3: Implement coverage and update durable guidance**

Add `recipeFieldCoverage()` as a `PantrySource` requirement. Supply a protocol-extension implementation that fetches active recipes and counts typed fields, so `InMemoryPantrySource` remains useful in tests. Implement an optimized `PaprikaSQLiteSource` witness using one read-only aggregate query over active `ZRECIPE` rows plus a grouped `ZRECIPEPHOTO` subquery when that optional table is present.

The optimized SQL must use schema-generated optional expressions and stable aliases; raw Paprika column names must not escape the adapter. Pass the coverage through `SourceStatsSnapshot` and `SourceStatsReport`, with the exact text labels from Step 1.

Update docs as follows:

- `README.md`: describe `recipes show` as exposing distinct description and notes, difficulty, nutrition, URLs, and photo metadata.
- `AGENTS.md`: record that the early export/mirror model was retired on 2026-04-17 in favor of direct read-only `Paprika.sqlite`, and that `pantry.sqlite` is only a rebuildable derived sidecar.
- `skills/paprika-pantry/SKILL.md`: remove the temporary missing-field warning; tell agents to treat description as publisher/source context and notes as household-authored recipe notes.
- `skills/paprika-pantry/references/read-only-exploration.md`: add the separate `description` sidecar column and explain that `hasNotes` is notes-only.
- `docs/read-only-exploration.md` and `docs/usage-facts-contract.md`: document the same canonical/derived boundary without household-specific counts or recipe content.

- [ ] **Step 4: Run coverage tests and documentation checks**

Run:

```bash
swift test --build-path build --filter SourceStatsServiceTests
swift test --build-path build --filter SourceDoctorReportTests
rg -n "combine description|description with notes|description.*fallback|notes.*fallback|does not separately expose description" README.md AGENTS.md skills docs --glob '!docs/superpowers/plans/2026-07-21-complete-recipe-detail-coverage.md'
git diff --check
```

Expected: focused tests pass; `rg` returns no stale live guidance; `git diff --check` succeeds.

- [ ] **Step 5: Commit coverage and guidance**

```bash
git add Sources/PantryKit/Source/PantrySource.swift Sources/PantryKit/Source/PaprikaSQLiteSource.swift Sources/PantryKit/Source/SourceStatsService.swift Sources/PantryKit/Model/SourceReports.swift Tests/PantryKitTests/SourceStatsServiceTests.swift Tests/PantryKitTests/SourceDoctorReportTests.swift README.md AGENTS.md skills/paprika-pantry docs
git commit -m "Report complete Paprika recipe field coverage"
```

### Task 5: Full verification and explicit rollout handoff

**Files:**
- Verify only; modify earlier task files only if verification exposes a defect

**Interfaces:**
- Consumes: all four implementation commits
- Produces: evidence that direct detail, fresh sidecar creation, search semantics, photos, and coverage work together without changing Paprika

- [ ] **Step 1: Run repository verification**

Run:

```bash
git diff --check
make build
make test
```

Expected: build succeeds, the entire XCTest suite passes, and there are no whitespace errors.

- [ ] **Step 2: Run a disposable fresh-schema/rebuild smoke check**

Use a temporary config and sidecar path, never the ambient default sidecar:

```bash
smoke_root=$(mktemp -d)
PAPRIKA_PANTRY_HOME="$smoke_root" build/debug/paprika-pantry source status --format json
PAPRIKA_PANTRY_HOME="$smoke_root" build/debug/paprika-pantry index update --format json
PAPRIKA_PANTRY_HOME="$smoke_root" build/debug/paprika-pantry source stats --format json
```

Expected: source status reports read-only/query-only access; index update succeeds; source stats reports independent nonzero description and notes coverage where present. Do not print or commit private recipe bodies.

- [ ] **Step 3: Verify live aggregate semantics without storing household data**

Run bounded read-only aggregate checks against the configured source and disposable sidecar. Confirm:

- description count and notes count are independent;
- the both-fields count is no larger than either individual count;
- description-only search results report `hasNotes == false`;
- notes-only search results report `hasNotes == true`;
- photo local paths, when emitted, point inside Paprika's `Data/Photos` tree;
- no image bytes or Paprika rows were copied into the sidecar.

Record only pass/fail evidence in the implementation handoff, not recipe names, bodies, or household-specific aggregate values.

- [ ] **Step 4: Verify scope and repository state**

Run:

```bash
git status --short --branch
git log -5 --oneline
git diff HEAD~4..HEAD --stat
```

Expected: exactly four reviewable implementation commits follow this plan; no installed binary, installed skill, export importer, or Paprika write path is part of the diff.

- [ ] **Step 5: Leave the single-install rollout pending explicit approval**

Report that code and tests are ready. Do not install or remove the ambient sidecar until Julian explicitly asks for rollout. The approved rollout procedure should be:

```bash
make install
make install-skill
trash '/Users/robut/Library/Application Support/paprika-pantry/pantry.sqlite'
paprika-pantry index rebuild --format json
```

Before moving the file to Trash, re-run `paprika-pantry index stats --format json` and verify that its reported database path is exactly `/Users/robut/Library/Application Support/paprika-pantry/pantry.sqlite`. The full rebuild intentionally regenerates search, derived features, usage, ingredient tokens, and ingredient-pair evidence from the read-only Paprika source.
