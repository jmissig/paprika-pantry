---
name: paprika-pantry
description: Local read/query access to Paprika recipe, meal, grocery, and pantry data plus derived cooking-pattern evidence. Use when answering questions about what recipes exist, what has been cooked, what ingredients are on hand, or what cooking preferences can be inferred from local Paprika data.
---

# paprika-pantry

Local, read-only access to Paprika's data plus derived usage patterns. Paprika is an app that helps you organize your recipes, make meal plans, and create grocery lists.

## Model

Entities:
- recipe (canonical, often includes cookbook/web site source)
- meal (planned or cooked occurrence, distinct from a recipe)
- grocery item (shopping list entry)
- pantry item (on-hand inventory)

Data types:
- canonical: direct Paprika facts (recipes, meals, ratings, etc.)
- derived: patterns from behavior (repeat cooking, recency, source affinity, ingredient patterns)

## Core behavior

- retrieve first, then interpret
- prefer canonical data for facts
- use derived data for patterns/preferences
- keep facts separate from inference
- structured output often available for LLM processing

## Core commands (illustrative)

- `paprika-pantry doctor --format json`
- `paprika-pantry recipes search "..." --format json`
- `paprika-pantry recipes show "..." --format json`
- `paprika-pantry meals list --format json`
- `paprika-pantry pantry list --format json`
- `paprika-pantry source cookbooks --format json`
- `paprika-pantry recipes pairings --token tomato --sort meals --format json`

Not exhaustive. Use `--help` and adapt to the current interface.

## Recipe policy

When asked for a recipe:
1. query local Paprika first
2. present best matches (count depends on context)

If no results:
- broaden once
- if still none: say so, then offer:
  - pantry-based idea
  - novel recipe
  - external search (perhaps based on sources found in paprika-pantry)

Do not skip local lookup unless explicitly requested.


## Read-only exploration mode

Normal answers should use stable CLI verbs first. Before writing SQL, run `paprika-pantry --help` and relevant subcommand help when semantics are unclear.

Use read-only SQL/Datasette only for exploration questions: source coverage, sidecar freshness, provenance examples, debugging surprising output, or discovering a repeated pattern that may deserve a future CLI verb. For canned SQL and Datasette setup, read `references/read-only-exploration.md` from this skill folder.

Read-only SQL rules:
- open the sidecar read-only / immutable
- keep queries narrow and explain the exploration question
- report counts, freshness, and caveats
- do not treat ad hoc SQL as the normal chat contract
- do not infer recommendations, substitutions, or preferences beyond returned evidence

## Index freshness

Use `paprika-pantry index update` for routine refreshes. Use `paprika-pantry index rebuild` when ingredient pairing evidence needs refreshing; pairings are heavier and may intentionally lag routine indexes. If `recipes pairings` warns that pairing evidence is stale or missing, say that clearly before interpreting it.

## Preference reasoning

Infer taste from:
- repeat cooking cadence
- recency
- ratings/favorites
- source/cookbook patterns
- ingredient & ingredient-combo recurrence

For ingredient pairings, treat `recipes pairings` output as inspectable evidence only: counts, meal usage, ratings/favorites, and recipe examples. Do not turn it into unsupported substitution or flavor claims.

Use this to reason about:
- what is actually liked
- trusted sources
- recurring flavor patterns
- changes over time

Rules:
- describe evidence briefly
- separate fact vs inference
- surface conflicts (e.g. high rating, no repeats)
- frequency ≠ absolute quality

## Taste reasoning style

Use concise culinary or sensory language to describe patterns.

- ground descriptions in observed data
- do not introduce unsupported ingredients or flavors
- avoid absolute or authoritative claims

Make it feel experiential, but keep it evidence-based.

## Response

- concise
- evidence-backed
- indicate inferred vs observed
- acknowledge weak or missing data

## Style

retrieve → interpret → respond  
few strong results over long lists  
tool provides evidence, not conclusions
