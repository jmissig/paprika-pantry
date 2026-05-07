# Pattern Boundary and Corrections — paprika-pantry

This note turns the broader OpenClaw pattern-intelligence work into concrete guidance for `paprika-pantry`.

Related Obsidian notes:
- `LLM Pattern Loop`
- `Pattern Extraction Tooling`
- `Personal Pattern Intelligence`
- `Almanacs and Guides`

Related repo notes:
- `docs/read-only-exploration.md`
- `docs/usage-facts-contract.md`

## Boundary

`paprika-pantry` is the household cooking evidence instrument, not the dinner recommender.

The useful layering is:

```text
Paprika source DB read-only
  -> sidecar search / features / usage / pairings / source rollups
  -> stable CLI source and derived outputs
  -> Robut-composed Cooking Guide / Almanac / meal-planning answer
  -> OpenClaw/Obsidian-held correction suggestions where needed
  -> human-authored Paprika notes when a recipe-specific note should become durable
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
- stable attachment targets: enough recipe/source/meal identity for an upper layer to fetch more detail by UID when it needs it;
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
- annotation inboxes, pending-note queues, or chat-to-recipe correction storage.

Those are Robut/Guide-layer judgments over explicit cooking evidence.

## Human-attached notes, not correction machinery

Near-term correction handling should be simple: a human attaches a plain-English note to the thing Robut is likely to encounter again. The note supplies context; the LLM decides how to use it next time.

Recipe-specific notes already have a human home in Paprika recipe notes, and `paprika-pantry` reads those notes as source data. Do not add a separate `paprika-pantry` annotation layer just to mirror or stage those notes.

The hard part is not schema. The hard part is **what object the note attaches to** and **where Robut will reliably find it later**. For chat-originated suggestions, that routing belongs in the OpenClaw or Obsidian layer, not in `paprika-pantry`.

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
- Meal-window note: “This run was mostly guest dinners, not our normal weeknight pattern.”
- Person/family note: “Julian likes this as lunch leftovers; Alice does not usually want it for dinner.”

Good note targets should be close to the evidence Robut will retrieve later:

- attach convenience/preference caveats to the recipe;
- attach dislike, tolerance, or substitution context to the ingredient;
- attach reliability or importer-quality caveats to the source/cookbook/site;
- attach guest/kid/deadline context to the meal window;
- attach durable Julian/Alice/family distinctions to profile or family memory, not to a random recipe row.

Store recipe-specific notes in Paprika when a human wants them to become durable recipe notes. Store chat-originated suggestions, unresolved routing, and non-recipe context in OpenClaw/Obsidian/profile memory. Never write notes back into the real Paprika database automatically. Do not require humans to choose correction kinds, approval states, or future effects.

If this later becomes machine-readable, keep the durable shape minimal:

```text
attached_to: <recipe/ingredient/source/meal/person-context id or name>
note: <plain English human note>
source: <human/chat/note>
updated_at: <timestamp>
```

That shape belongs outside `paprika-pantry` unless Julian explicitly changes the boundary. `paprika-pantry` can expose recipe IDs, names, source trails, and existing Paprika notes so OpenClaw/Obsidian has good attachment targets.

## Attachment Target Contract

Summary and derived outputs should stay partial. They should say “there is this recipe/source/meal, here is why it appeared, and here is the stable identity you can use to fetch more.” They should not inline full recipe contents just because an agent might want follow-up context.

Use `recipes show <uid>` as the full recipe detail boundary. That command can expose recipe notes because Paprika recipe notes are canonical source data.

For JSON output, prefer structured targets over command strings. A recipe target should identify the Paprika recipe, not prescribe how a caller must fetch it:

```json
{
  "kind": "paprika.recipe",
  "uid": "...",
  "name": "...",
  "sourceName": "...",
  "hasNotes": true
}
```

`has_notes` is optional. Include it only when notes are already cheap in the current read path:

- include for `recipes show`, `recipes features`, `recipes ingredients`;
- include for `recipes list`, because list already loads recipe records;
- include for `recipes search`, because the sidecar search document already stores notes;
- omit for `recipes pairings`, `meals list`, and `source cookbooks` unless a future implementation needs the extra join/fetch for another reason.

Pairing evidence and meal rows should expose recipe UID/name targets as follow-up handles, not full recipe information. Source rollups should expose source targets and aggregate evidence, not expanded recipe lists. Text output should use compact target handles such as `target=paprika.recipe:<uid>`, `recipe_target=paprika.recipe:<uid>`, or `target=paprika.source:<source-name>` so default operator output remains attachable without embedding a follow-up command.

## Actionable next slices

1. **Mechanical recency/lapse examples**
   - Add README and skill examples for existing meal-history query fields: `meal_count`, `last_meal_at`, `days_since_last_meal`, `median_meal_gap_days`.
   - Avoid labels like `favorite`; expose facts Robut can interpret.

2. **OpenClaw/Obsidian note routing**
   - Keep chat-originated correction suggestions outside `paprika-pantry`.
   - Ensure `paprika-pantry` exposes enough stable recipe/source identifiers for OpenClaw or Obsidian notes to point back to Paprika recipes.
   - Do not build correction kinds, approval states, pending-note queues, or future-effect machinery in this repo.

3. **Attachment target consistency**
   - Ensure recipe usage, pairings, source rollups, and future match traces expose stable targets, not embedded follow-up commands.
   - Keep summary/derived outputs partial; callers use UIDs to fetch full recipe details when needed.

4. **Only then consider deterministic filter diagnostics**
   - If Robut repeatedly needs to explain mechanical filter failures, add narrow diagnostics to existing search/list outputs.
   - Do not build a dinner-suggestion, candidate-ranking, or Guide-packet command.
