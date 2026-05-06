# Pattern Boundary and Corrections — paprika-pantry

This note turns the broader OpenClaw pattern-intelligence work into concrete guidance for `paprika-pantry`.

Related Obsidian notes:
- `LLM Pattern Loop`
- `Pattern Extraction Tooling`
- `Personal Pattern Intelligence`
- `Almanacs and Guides`

Related repo notes:
- `docs/pattern-intelligence-proposal.md`
- `docs/read-only-exploration.md`
- `docs/recipe-meal-history-facts-phase-1-spec.md`

## Boundary

`paprika-pantry` is the household cooking evidence instrument, not the dinner recommender.

The useful layering is:

```text
Paprika source DB read-only
  -> sidecar search / features / usage / pairings / source rollups
  -> stable CLI source and derived outputs
  -> Robut-composed Cooking Guide / Almanac / meal-planning answer
  -> human correction or policy where needed
```

Datasette/read-only SQL is the microscope for inspection and debugging. CLI verbs are domain-shaped instruments. Robut composes the Guide.

## What belongs in `paprika-pantry`

Good tool-layer work:

- source and sidecar freshness;
- recipe, meal, grocery, pantry, cookbook/source, ingredient, and pairing queries;
- mechanical filters: ingredients, categories, rating, favorite, time, source, recency, usage count;
- descriptive meal-history facts: first/last cooked, meal count, gaps, median gap, share, days since last meal at query time;
- descriptive pairings with recipe-level provenance;
- source/cookbook rollups with support counts;
- drill-down handles to recipes, ingredients, features, meals, and pair evidence;
- deterministic filter diagnostics only when they explain mechanical query behavior, not when they shape a meal recommendation.

## What stays above `paprika-pantry`

Do not make the CLI decide:

- “cook this tonight”;
- “family favorite” as a truth claim;
- “Julian likes this” or “Alice dislikes this” unless grounded in human-approved correction/profile state;
- weeknight/guest/kid suitability as final meaning;
- cross-domain joins with weather, calendar, Swarm, pantry mood, or person context;
- polished Cooking Guide prose;
- durable taste/profile changes.

Those are Robut/Guide-layer judgments over explicit cooking evidence.

## Human-attached notes, not correction machinery

Near-term correction handling should be simple: a human attaches a plain-English note to the thing Robut is likely to encounter again. The note supplies context; the LLM decides how to use it next time.

The hard part is not schema. The hard part is **what object the note attaches to** and **where Robut will reliably find it later**.

Useful attachment targets for `paprika-pantry`:

- a recipe, for convenience-vs-preference, “still liked,” or “not for weeknights”;
- an ingredient, for dislike/tolerance/substitution notes;
- a source/cookbook/site, for quality or household-fit caveats;
- a meal-history fact/window, for “this was guests/kids/deadline, not preference”;
- a person/family context, for Julian/Alice/family distinction.

Example notes:

- Recipe note: “We made this often because it was easy, not because anyone loved it.”
- Recipe note: “Still liked; it just fell out of rotation.”
- Ingredient note: “Alice dislikes raw cilantro, but cooked coriander is fine.”
- Source note: “This cookbook is reliable for technique but usually too salty.”

Store the note somewhere human-readable first: Obsidian, profile memory, or a small sidecar only when retrieval needs it. Never write notes back into the real Paprika database automatically. Do not require humans to choose correction kinds, approval states, or future effects.

If this later becomes machine-readable, keep the durable shape minimal:

```text
attached_to: <recipe/ingredient/source/meal/person-context id or name>
note: <plain English human note>
source: <human/chat/note>
updated_at: <timestamp>
```

That is enough for Robut to find the note and reason from it.

## Actionable next slices

1. **Mechanical recency/lapse affordances**
   - Add sort/filter/report support around existing meal-history facts: `meal_count`, `last_meal_at`, `days_since_last_meal`, `median_meal_gap_days`.
   - Avoid labels like `favorite`; expose facts Robut can interpret.

2. **Attached-note examples**
   - Add examples of plain-English notes attached to recipes, ingredients, sources, meal windows, and person/family contexts.
   - Decide where Robut will reliably find those notes later: Obsidian/profile memory first, sidecar only if needed.

3. **Drill-down consistency**
   - Ensure recipe usage, pairings, source rollups, and future match traces expose stable drill-down commands/source trails.

4. **Only then consider deterministic filter diagnostics**
   - If Robut repeatedly needs to explain mechanical filter failures, add narrow diagnostics to existing search/list outputs.
   - Do not build a dinner-suggestion, candidate-ranking, or Guide-packet command.
