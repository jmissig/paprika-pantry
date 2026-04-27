# Pattern Intelligence Proposal — paprika-pantry

## Thesis

`paprika-pantry` should be the household cooking evidence layer for Robut: read Paprika’s canonical local database safely, maintain a sidecar for search and derived cooking-pattern facts, and expose stable source/derived outputs that help Robut compose meal-planning, use-up, pairing, taste-reflection, and recommendation answers without becoming an opaque cooking AI.

The next architecture should explicitly support two sibling surfaces:

1. **Explore/audit surface** — SQLite/Datasette-style browsing over Paprika-derived sidecar/index data and safe read-only projections so humans and agents can inspect recipes, meals, ingredients, cookbooks, usage stats, pairings, freshness, and source coverage.
2. **Stable verb / evidence-substrate surface** — stable `paprika-pantry` commands that return bounded JSON/source outputs for LLM grounding: safe defaults, explicit semantics, provenance, drill-down descriptors, correction hooks, and no improvised arbitrary SQL in normal conversation. Robut composes any decision-specific evidence packet above this layer.

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

`paprika-pantry` already covers collection, normalization, summarization, and evidence-backed associations. The important gaps are in scoping, recommendation packets, correction, and lifecycle:

- **Prepare / scope:** dinner suggestion, use-up, “what goes with this?”, “what have we liked?”, and “what should Alice/Julian/family eat?” need different assumptions and evidence windows.
- **Collect / preserve / normalize:** strong through read-only Paprika adapter and sidecar. Continue avoiding blind canonical duplication.
- **Integrate / join cautiously:** pantry/grocery/meal/recipe/cookbook joins are in-domain and useful; joins with Swarm, clime, calendar, or household behavior should be explicit and rare.
- **Summarize / roll up:** strong via cookbook rollups, usage stats, meal-history facts, and ingredient pairings. The next need is representation-ready output with support counts and denominators.
- **Compare / baseline:** partially present. Useful future baselines include recent vs historical cooking, weekday vs weekend, family vs guest meals, seasonality, and “made often but not recently.”
- **Detect change / lapse / resumption:** meal-history gaps will support lapsed favorites and rediscovery; avoid phrasing gaps as failure.
- **Segment / context:** critical. Distinguish weeknight practical, dinner-party, kid/family compromise, Julian preference, Alice preference, household favorite, pantry cleanout, and convenience artifacts.
- **Classify / label provisionally:** labels like `weeknight_anchor`, `lapsed_household_favorite`, `vegetable_forward`, `convenience_repeat`, or `good_side_candidate` should carry evidence, scope, and correction hooks.
- **Co-occurrence / pairings:** a local strength. Pairings should remain descriptive evidence, not automatic suggestions.
- **Surface candidates / exclusions:** missing as first-class query behavior. Robut needs candidate sets with reasons and exclusions, not one hidden winner.
- **Explain / cite / drill down:** outputs should consistently identify contributing recipes, meals, tokens, cookbook/source fields, and sidecar freshness.
- **Simulate / adjust assumptions:** useful for “quick,” “vegetarian,” “use avocados,” “Alice is eating,” “avoid pasta,” or “something not repeated recently.” This belongs first in explicit filters/query fields and later in Guide lenses or an explorable surface assembled above the CLI.
- **Critique / correct:** the largest gap. Corrections need to distinguish convenience vs preference, Julian/Alice/family context, source quality, bad tags, disliked recipes, stale ratings, and “made for guests, not us.”
- **Decay / retire:** pattern labels need generated-at dates and active windows. A 2019 favorite may be an archive clue, not a current dinner suggestion.
- **Export / preserve:** sidecar SQLite and docs are good; a Datasette metadata layer and packet schema would make the evidence easier to inspect and move.

## Two-surface design

### 1. SQLite / Datasette explore-audit surface

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
  - candidate evidence drill-downs.

The audit surface is ideal for exploratory questions like “which cookbooks do we actually cook from?” or “what ingredient pairings are supported by real meals?” It can also debug whether a recommendation packet is missing a source or over-weighting stale data.

It should not become the default path for Robut’s dinner advice. Normal chat should use stable verbs and packet fields with known semantics.

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

A future packet should compose these into a decision-specific evidence bundle rather than a final verdict. Example dinner/use-up packet:

```json
{
  "kind": "paprika_pantry.cooking_context.v0",
  "intent": "dinner_suggestions",
  "assumptions": {
    "context": "family_weeknight",
    "time_budget_minutes": 45,
    "use_up": ["avocado"],
    "avoid_recent_repeats": true
  },
  "freshness": {
    "paprika_last_sync_observed_at": "2026-04-26T09:40:00-07:00",
    "sidecar_updated_at": "2026-04-26T09:45:00-07:00",
    "pairings_updated_at": "2026-04-20T18:00:00-07:00"
  },
  "candidates": [
    {
      "recipe_uid": "...",
      "name": "Black Bean Tostadas",
      "roles": ["use_up_avocado", "weeknight_candidate"],
      "evidence": [
        {"kind": "ingredient_match", "value": "uses avocado"},
        {"kind": "meal_history", "value": "cooked 5 times, last 62 days ago"},
        {"kind": "source_quality", "value": "source/cookbook has strong household rating"}
      ],
      "uncertainty": ["pantry quantity not verified unless pantry source is current"],
      "drilldowns": [
        "paprika-pantry recipes show ... --format json",
        "paprika-pantry recipes ingredients ... --format json"
      ],
      "corrections_supported": [
        "convenience_not_preference",
        "julian_only",
        "alice_only",
        "family_favorite",
        "not_for_weeknight",
        "bad_source_quality"
      ]
    }
  ],
  "exclusions": [
    {"name": "Long Braise", "reason": "exceeds 45 minute budget"},
    {"name": "Recent Pasta", "reason": "recent repeat"}
  ]
}
```

These outputs support Robut saying “I’d do X if you want quick and use-up; Y if you want a lapsed favorite” without pretending the CLI knows what the family wants tonight.

## Recommended next slices

Small, practical slices that build on current work:

1. **Finish/use meal-history facts** — the `first_cooked_at`/meal-history TODO is foundational for lapsed favorites, recency, and rediscovery.
2. **Document Datasette/read-only audit workflow** — start with the sidecar/index DB; include sample questions and canned queries.
3. **Define packet contracts in docs before code** — `dinner_suggestions`, `use_up`, `pairings_context`, and `taste_profile_update` packets with required freshness/provenance/drill-down fields.
4. **Add correction model sketch** — define correction scopes before implementation: recipe, ingredient, source, category/tag, person, family, context, time window.
5. **Tighten pattern-report output** — align with the existing TODO: confidence limits and contributing evidence should be obvious.
6. **Candidate/exclusion language** — add outputs that can explain “why this” and “why not,” even before implementing ranking-heavy suggestions.
7. **Source-quality descriptors** — keep cookbook/source rollups descriptive, but make it easy for Robut to cite them as evidence when recommending.

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
- Preserve source freshness. A stale Paprika sync or sidecar index should be visible in every packet that could influence a recommendation.

## Success test

Good `paprika-pantry` pattern outputs should let Robut answer cooking questions with:

- a small candidate set, not one hidden winner;
- evidence from recipes, meals, ingredients, pantry/grocery state, source rollups, and pairings as appropriate;
- freshness and sidecar/source status;
- exclusions and uncertainty;
- drill-down commands back to contributing recipes/meals/facts;
- correction hooks for convenience vs preference and person/family context.

If humans can browse/audit the sidecar through a Datasette-style surface while Robut normally consumes stable evidence outputs, `paprika-pantry` will sit cleanly in the broader local pattern-intelligence stack.
