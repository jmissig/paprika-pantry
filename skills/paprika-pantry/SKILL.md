---
name: paprika-pantry
description: Local read/query access to Paprika data and cooking-pattern evidence.
---

# paprika-pantry

Local, read-only access to Paprika's data plus derived usage patterns. Paprika is an app that helps you organize your recipes, make meal plans, and create grocery lists.

## Model

Entities:
- recipe (canonical, often includes cookbook/web site source)
- meal (cooked/planned instance)
- groceries (shopping list)
- pantry (on-hand)

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

## Preference reasoning

Infer taste from:
- repeat cooking cadence
- recency
- ratings/favorites
- source/cookbook patterns
- ingredient & ingredient-combo recurrence

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
