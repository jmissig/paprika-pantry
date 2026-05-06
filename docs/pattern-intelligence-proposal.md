# Pattern Intelligence Proposal — paprika-pantry

## Thesis

`paprika-pantry` should be the household cooking evidence layer for Robut: read Paprika’s canonical local database safely, maintain a sidecar for search and derived cooking-pattern facts, and expose stable source/derived outputs that Robut can use while composing meal-planning, use-up, pairing, and taste-reflection answers above the CLI. The tool should not become an opaque cooking AI or dinner recommender.

The next architecture should explicitly support two sibling surfaces:

1. **Explore/inspect surface** — SQLite/Datasette-style browsing over Paprika-derived sidecar/index data and safe read-only projections so humans and agents can inspect recipes, meals, ingredients, cookbooks, usage stats, pairings, freshness, and source coverage.
2. **Stable verb / evidence-substrate surface** — stable `paprika-pantry` commands that return bounded JSON/source outputs for LLM grounding: safe defaults, explicit semantics, provenance, drill-down descriptors, explicit correction-policy inputs when approved, and no improvised arbitrary SQL in normal conversation. Robut composes any decision-specific evidence packet above this layer.

This adapts broader Dogsheep/Datasette and personal-informatics practice to the local cooking domain: keep the data owner in control, preserve evidence, make derived facts inspectable, and let Robut handle conversational judgment.

## Source research notes

This proposal adapts the Obsidian research notes:

- `Pattern Extraction Tooling` — `/Users/robut/Library/Mobile Documents/iCloud~md~obsidian/Documents/ChingMi/OpenClaw/Pattern Extraction Tooling.md`
- `LLM Pattern Loop` — `/Users/robut/Library/Mobile Documents/iCloud~md~obsidian/Documents/ChingMi/OpenClaw/LLM Pattern Loop.md`
- `Personal Pattern Intelligence` — `/Users/robut/Library/Mobile Documents/iCloud~md~obsidian/Documents/ChingMi/OpenClaw/Personal Pattern Intelligence.md`
- `Pattern Intelligence Research Index` — `/Users/robut/Library/Mobile Documents/iCloud~md~obsidian/Documents/ChingMi/OpenClaw/Pattern Intelligence Research Index.md`
- `Almanacs and Guides` — `/Users/robut/Library/Mobile Documents/iCloud~md~obsidian/Documents/ChingMi/OpenClaw/Almanacs and Guides.md`

## Vocabulary boundary

Keep the tool-side language precise, but do not leak it into the human-facing experience. In repo implementation docs, terms like SQLite, sidecar, source bundle, provenance, derived observation, and drill-down are still useful. Use evidence packet for the Robut-composed decision artifact, not as the default name for every CLI response. In Robut-facing or human-facing artifacts, prefer the warmer vocabulary from `Almanacs and Guides`:

- **Almanac** for durable sourced understanding over time;
- **Guide** for situated help with a task or question;
- **Lens** for a mode/filter/assumption;
- **Option** for a candidate item/action;
- **Source trail** for provenance/drill-down;
- **Edit** for human correction or policy override.

Implementation rule of thumb: compute facts freely when they are traceable and rebuildable; change meaning only with human authority.

## Current strengths

`paprika-pantry` is a strong fit for pattern intelligence because cooking questions naturally need evidence plus human judgment.

Current strengths:

- read-only access to the real local Paprika SQLite database;
- clear source-of-truth boundary: Paprika is canonical, the sidecar is owned/rebuildable;
- command families for source health, recipes, meals, groceries, pantry, and index maintenance;
- local index for search, derived recipe features, usage stats, ingredient tokens, and pairings;
- source/cookbook rollups and freshness reporting;
- existing docs that keep pairings as evidence, not recommendations;
- a phase-1 spec for meal-history facts: counts, first/last meal, gaps, median gaps, spans, shares, and query-time days since last meal.

This fits the broader pattern pipeline:

```text
Paprika.sqlite read-only
  -> stable adapter/domain model
  -> sidecar/index derived facts
  -> cooking evidence pieces / source bundles
  -> Robut-composed packets, conversation, tradeoffs, and correction
```

## Gaps relative to the 17-verb pattern map

`paprika-pantry` already covers collection, normalization, summarization, and evidence-backed associations. The important gaps are in explicit scoping fields, correction examples, freshness/provenance consistency, and lifecycle facts:

- **Prepare / scope:** dinner, use-up, “what goes with this?”, “what have we cooked?”, and person/family contexts need explicit assumptions and evidence windows chosen above the CLI.
- **Collect / preserve / normalize:** strong through read-only Paprika adapter and sidecar. Continue avoiding blind canonical duplication.
- **Integrate / join cautiously:** pantry/grocery/meal/recipe/cookbook joins are in-domain and useful; joins with Swarm, clime, calendar, or household behavior should be explicit and rare.
- **Summarize / roll up:** strong via cookbook rollups, usage stats, meal-history facts, and ingredient pairings. The next need is representation-ready output with support counts and denominators.
- **Compare / baseline:** partially present. Useful future baselines include recent vs historical cooking, weekday vs weekend, family vs guest meals, seasonality, and “made often but not recently.”
- **Detect change / lapse / resumption:** meal-history gaps should expose recency and absence facts; avoid phrasing gaps as failure or preference.
- **Segment / context:** critical, but mostly above the CLI. The tool should expose facts that help Robut distinguish weeknight practicality, dinner-party context, kid/family compromise, person-specific preference, pantry cleanout, and convenience artifacts.
- **Avoid tool-owned preference labels:** labels like `weeknight_anchor`, `lapsed_household_favorite`, `vegetable_forward`, `convenience_repeat`, or `good_side_candidate` belong in Robut/Guide/profile layers unless backed by explicit human-approved correction/profile state. The tool should expose the underlying facts, windows, counts, and drill-downs.
- **Co-occurrence / pairings:** a local strength. Pairings should remain descriptive evidence, not automatic suggestions.
- **Explain deterministic query behavior:** if needed, expose why mechanical filters matched or failed. Do not create a tool-owned candidate/recommendation surface.
- **Explain / cite / drill down:** outputs should consistently identify contributing recipes, meals, tokens, cookbook/source fields, and sidecar freshness.
- **Simulate / adjust assumptions:** useful for “quick,” “vegetarian,” “use avocados,” “Alice is eating,” “avoid pasta,” or “something not repeated recently.” This belongs first in explicit filters/query fields and later in Guide lenses or an explorable surface assembled above the CLI.
- **Critique / correct:** the largest gap. Corrections need to distinguish convenience vs preference, Julian/Alice/family context, source quality, bad tags, disliked recipes, stale ratings, and “made for guests, not us.”
- **Decay / retire:** derived observations need generated-at dates and active windows. A 2019 high-use recipe may be an archive clue, not a current preference.
- **Export / preserve:** sidecar SQLite and docs are good; Datasette metadata and stable primitive schemas would make the evidence easier to inspect and move.

## Two-surface design

### 1. SQLite / Datasette explore-inspect surface

Purpose: make cooking evidence browsable and debuggable without exposing arbitrary SQL as the normal LLM interface.

Recommended scope:

- document a read-only Datasette workflow over the sidecar/index DB, and only safe read-only projections from Paprika source if needed;
- add canned queries/facets around:
  - recipes by category, rating, favorite, source/cookbook;
  - meals by date, recipe, meal type;
  - usage stats by count, recency, gap, share;
  - ingredient token usage and pairings;
  - source/cookbook reliability rollups;
  - stale index/pairing freshness;
  - source/derived evidence drill-downs.

The exploration surface is ideal for exploratory questions like “which cookbooks do we actually cook from?” or “what ingredient pairings are supported by real meals?” It can also debug whether a Robut-composed Guide is missing a source or over-weighting stale data.

It should not become the default path for Robut’s dinner advice. Normal chat should use stable verbs and source/derived fields with known semantics.

### 2. Stable verb / evidence-substrate surface

Purpose: provide grounded cooking context for Robut. The CLI supplies source/derived pieces; Robut owns tradeoff reasoning and any final packet, Guide, or answer.

Current commands already provide many ingredients:

```bash
paprika-pantry recipes search risotto --format json
paprika-pantry recipes features "Mushroom Risotto" --format json
paprika-pantry recipes ingredients "Mushroom Risotto" --format json
paprika-pantry recipes pairings --token tomato --sort meals --format json
paprika-pantry meals list --format json
paprika-pantry pantry list --format json
paprika-pantry source cookbooks --format json
paprika-pantry index stats --format json
```

Above the CLI, Robut can compose these outputs into a decision-specific evidence bundle rather than a final verdict. Keep the repo-side contract focused on primitives Robut can assemble, for example:

```json
{
  "kind": "paprika_pantry.recipe_usage_facts.v0",
  "filters": {
    "ingredient_contains": ["avocado"],
    "max_total_time_minutes": 45
  },
  "freshness": {
    "paprika_last_sync_observed_at": "2026-04-26T09:40:00-07:00",
    "sidecar_updated_at": "2026-04-26T09:45:00-07:00"
  },
  "rows": [
    {
      "recipe_uid": "...",
      "name": "Black Bean Tostadas",
      "matched_ingredients": ["avocado"],
      "meal_count": 5,
      "last_meal_at": "2026-02-23T18:30:00-08:00",
      "days_since_last_meal": 62,
      "rating": 4,
      "favorite": false,
      "uncertainty": ["pantry quantity not verified unless pantry source is current"],
      "drilldowns": [
        "paprika-pantry recipes show ... --format json",
        "paprika-pantry recipes ingredients ... --format json"
      ]
    }
  ],
  "filter_diagnostics": [
    {"recipe_uid": "...", "filter": "max_total_time_minutes", "result": "excluded", "observed_minutes": 180}
  ]
}
```

These source/derived outputs support Robut’s above-CLI reasoning without pretending the CLI knows what the family wants tonight.

## Recommended next slices

Small, practical slices that build on current work:

1. **Finish/use meal-history facts** — the `first_cooked_at`/meal-history layer is foundational for recency, gap, and rediscovery evidence.
2. **Document Datasette/read-only exploration workflow** — start with the sidecar/index DB; include sample questions and canned queries.
3. **Define evidence primitive contracts in docs before code** — recipe usage, source/cookbook rollups, pairings, ingredients, pantry/grocery state, freshness, and drill-down fields.
4. **Add correction model examples soon** — define correction scopes before sidecar implementation: recipe, ingredient, source, category/tag, person, family, context, time window.
5. **Tighten derived-output reporting** — confidence limits, denominators, freshness, and contributing evidence should be obvious.
6. **Deterministic filter diagnostics only if needed** — explain mechanical “matched/filtered out” behavior without creating a dinner-suggestion command.
7. **Source-quality facts** — keep cookbook/source rollups descriptive, so Robut can cite them as evidence above the CLI.

## Correction model

Cooking data is especially prone to confusing “we made it” with “we loved it.” A correction layer should be explicit and scoped.

Useful correction dimensions:

- **convenience vs preference:** made because ingredients were on hand, near a deadline, or good enough for kids, not because it is a favorite;
- **person context:** Julian-only, Alice-only, family-shared, kid-driven, guest meal;
- **meal context:** weeknight, weekend project, lunch, side, dinner party, pantry cleanout;
- **source quality:** reliable cookbook/source, aspirational source, bad importer/tag quality, recipe needs edits;
- **ingredient preference:** disliked ingredient, tolerated in small amounts, good pairing, substitution works;
- **lifecycle:** still current, lapsed but loved, loved then not now, never suggest again for a context;
- **evidence quality:** rating stale, meal history sparse, category inferred, duplicate recipe.

Corrections should never write to the real Paprika database unless a human explicitly chooses to edit Paprika itself. They can start as Obsidian/profile-note corrections or future sidecar `human_corrections` rows with provenance and scope.

## Privacy and agency boundaries

- Keep Paprika read-only. No writes to the real source DB.
- Do not treat household cooking as a single permanent taste vector. Alice, Julian, kids/family, guests, convenience, and diet/time constraints can differ.
- Avoid moralizing food. Do not infer health, discipline, virtue, or failure from meal patterns unless the human asks for that frame.
- Do not over-join with non-food household data by default. Weather may matter for grilling/outings; calendar may matter for time budget; cameras almost never matter.
- Keep pairings and rankings inspectable. Embeddings may help search later, but recommendations need symbolic evidence.
- Preserve source freshness. A stale Paprika sync or sidecar index should be visible in every output Robut might use for a Guide or recommendation above the CLI.

## Success test

Good `paprika-pantry` tool outputs should let Robut build cooking Guides above the CLI using:

- stable source/derived facts, not one hidden winner;
- evidence from recipes, meals, ingredients, pantry/grocery state, source rollups, and pairings as appropriate;
- freshness and sidecar/source status;
- explicit uncertainty and mechanical filter limits;
- drill-down commands back to contributing recipes/meals/facts;
- human-approved correction/profile state only when it is explicitly scoped.

If humans can browse/inspect the sidecar through a Datasette-style surface while Robut normally consumes stable evidence outputs, `paprika-pantry` will sit cleanly in the broader local pattern-intelligence stack.
