---
name: paprika-pantry
description: "Use when answering questions about Paprika recipes, planned or past meals, ingredients on hand, groceries, pantry contents, recipe updates, or household cooking patterns."
---

# paprika-pantry

Use Paprika as read-only context: recipes, descriptions, notes, meals, ratings, inventory, and history.

## Start from the person's question

- **Update, sync, or export.** No export is normally needed. Run `source launch-app --wait-for-sync`, then `index update`. Request an export only after direct access is diagnosed as unavailable.
- **Today's menu.** Read `meals list`, select the scheduled meals, then fetch linked recipes needed to answer. Future meals are plans, not cooking history.
- **Find something to make.** Apply the stated constraints and inspect the best few. Use description, notes, difficulty, or nutrition only to distinguish choices.
- **Use this ingredient.** Search exact and related uses, then inspect recipe detail. Distinguish mechanical conversion, such as canned beans to dried, from substitution.
- **What have we made or liked?** Combine ratings, favorites, meal count, recency, categories, source, and notes. Compare time windows when asked about change. Identify untried recipes; repetition may reflect convenience.
- **What do we have or need?** Read pantry and groceries first. Paprika's recorded state may differ from the kitchen.

## Answer workflow

1. Retrieve relevant rows with `--format json`; use `--help` instead of guessing filters.
2. Resolve recipe targets by UID. Use `recipes show <uid>` when full recipe text, quantities, photos, or the finished dish matter.
3. Inspect the strongest candidates, then give a few useful results with distinguishing evidence and uncertainty.

Do not make the person run a follow-up command to understand the answer.

If search finds nothing, broaden once while preserving the important constraint. Then offer a pantry idea, a new recipe, or external search.

## Evidence and interpretation

- Canonical facts include recipes, ratings, notes, meals, groceries, and pantry records. Derived evidence includes repetition, recency, source rollups, and ingredient co-occurrence.
- Treat `description` as publisher context and `notes` as household recipe notes. They are separate; a description-only recipe has no notes.
- Separate observation from inference. Frequency is not quality; surface conflicts such as a high rating without repeats.
- Pairings are co-occurrence evidence, not flavor or substitution rules. If they are stale, say so; use `index rebuild` only when the question needs fresh pairings.
- Use full detail selectively: description for the dish, notes for household changes, difficulty or nutrition when relevant, and links or photos when useful. Photo paths remain Paprika-owned.

Use concise culinary language grounded in the retrieved recipe. Do not invent ingredients, flavors, preferences, or reasons for a pattern.

## Command map

- Refresh: `source launch-app --wait-for-sync`, then `index update`
- Find/read: `recipes list`, `recipes search`, `recipes show <uid>`
- Meals/inventory: `meals list`, `groceries list`, `pantry list`
- Patterns: `recipes cookbooks`, `recipes pairings`
- Diagnose: `source status`, `doctor`, `index stats`

Treat `paprika.recipe`, `paprika.meal`, and `paprika.source` targets as identity handles, not commands.

Use read-only SQL or Datasette only for source-coverage, provenance, freshness, or debugging questions; see `references/read-only-exploration.md`. Never write to the Paprika database.
