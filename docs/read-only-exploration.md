# Read-Only Exploration Surface

> Skill copy: this exploration guide is also bundled at `skills/paprika-pantry/references/read-only-exploration.md` so agents can use it without access to the source repo. Keep the two copies in sync when editing exploration guidance.

`paprika-pantry` has two normal ways to look at cooking evidence:

1. **Stable CLI verbs** for normal Robut/chat answers and scripts.
2. **Read-only SQLite/Datasette exploration** for inspection, debugging, and discovering what a future CLI verb should expose.

Use the CLI first when the question fits an existing command. Use read-only SQL when the question is about source coverage, sidecar shape, surprising output, missing evidence, or a one-off investigation that should not become the normal chat contract yet.

## Boundaries

Read-only exploration is for looking, not deciding.

Do:

- open the sidecar database read-only;
- inspect counts, freshness, examples, and support rows;
- use SQL to debug whether the CLI output is missing evidence or over-weighting stale evidence;
- turn repeated useful SQL patterns into future CLI verbs or docs.

Do not:

- write to the real Paprika database;
- write to the sidecar during inspection;
- use ad hoc SQL as the default Robut answer path when a stable CLI command exists;
- treat sidecar-derived rows as recommendations or human preferences;
- infer flavor, substitution, or household taste beyond the evidence returned.

When unsure, run `paprika-pantry --help` and the relevant subcommand help before writing SQL. The CLI help documents current semantics better than a stale query snippet will.

## Launch Datasette read-only

The default sidecar lives at:

```text
~/Library/Application Support/paprika-pantry/pantry.sqlite
```

Open it read-only with Datasette:

```bash
datasette "$HOME/Library/Application Support/paprika-pantry/pantry.sqlite" --immutable
```

For a safer scratch copy:

```bash
mkdir -p .tmp
cp "$HOME/Library/Application Support/paprika-pantry/pantry.sqlite" .tmp/pantry-exploration.sqlite
datasette .tmp/pantry-exploration.sqlite --immutable
```

If the configured home or database path is different, check:

```bash
paprika-pantry doctor --format json
paprika-pantry index stats --format json
```

## Normal CLI before SQL

Prefer these commands before dropping into SQL:

```bash
paprika-pantry doctor --format json
paprika-pantry index stats --format json
paprika-pantry source stats --format json
paprika-pantry source cookbooks --format json
paprika-pantry recipes list --format json
paprika-pantry recipes search "risotto" --format json
paprika-pantry recipes show "Mushroom Risotto" --format json
paprika-pantry recipes features "Mushroom Risotto" --format json
paprika-pantry recipes ingredients "Mushroom Risotto" --format json
paprika-pantry recipes pairings --token tomato --sort meals --format json
paprika-pantry meals list --format json
```

Use SQL when you need to inspect across tables, validate counts, or understand why a CLI answer looks wrong.

## Core sidecar tables

Useful sidecar tables:

- `recipe_search_documents` — recipe search rows and canonical-ish fields copied for the owned index.
- `recipe_features` — derived prep/cook/total time and ingredient-line counts.
- `recipe_usage_stats` — meal-history-derived usage facts: counts, first/last cooked, gaps, share.
- `recipe_ingredient_lines` — conservative normalized ingredient-line records.
- `recipe_ingredient_tokens` — conservative ingredient tokens per recipe/line.
- `ingredient_pair_summaries` — aggregate token co-occurrence evidence from `index rebuild`.
- `ingredient_pair_recipe_evidence` — recipe-level evidence contributing to pair summaries.
- `recipe_usage_summary` — global usage denominator/summary row.
- `index_runs` — index freshness and success/failure history.
- `source_state` — observed source/Paprika sync state captured during indexing.

The sidecar is rebuildable. Paprika remains the canonical source for recipes, meals, groceries, and pantry items.

## Canned inspection queries

### Index freshness

```sql
SELECT
  index_name,
  status,
  started_at,
  finished_at,
  recipe_count,
  error_message
FROM index_runs
ORDER BY started_at DESC
LIMIT 20;
```

Use this before trusting derived rows. Pairing evidence may intentionally lag routine recipe indexes.

### Source sync state captured by the sidecar

```sql
SELECT
  source_type,
  source_location,
  observed_at,
  paprika_last_sync_at,
  paprika_sync_signal_source
FROM source_state
ORDER BY observed_at DESC;
```

This is observational. `paprika-pantry` does not write to or directly sync Paprika.

### Derived table sizes

```sql
SELECT 'recipe_search_documents' AS table_name, COUNT(*) AS rows FROM recipe_search_documents
UNION ALL SELECT 'recipe_features', COUNT(*) FROM recipe_features
UNION ALL SELECT 'recipe_usage_stats', COUNT(*) FROM recipe_usage_stats
UNION ALL SELECT 'recipe_ingredient_lines', COUNT(*) FROM recipe_ingredient_lines
UNION ALL SELECT 'recipe_ingredient_tokens', COUNT(*) FROM recipe_ingredient_tokens
UNION ALL SELECT 'ingredient_pair_summaries', COUNT(*) FROM ingredient_pair_summaries
UNION ALL SELECT 'ingredient_pair_recipe_evidence', COUNT(*) FROM ingredient_pair_recipe_evidence;
```

Good first check when a command says an index is missing or stale.

### Recently indexed or changed sidecar rows

```sql
SELECT
  uid,
  name,
  source_name,
  indexed_at,
  source_fingerprint
FROM recipe_search_documents
ORDER BY indexed_at DESC, name COLLATE NOCASE
LIMIT 50;
```

This inspects the sidecar's copy/update state, not Paprika's full recipe edit history.

### Recipe usage and lapsed candidates

```sql
SELECT
  d.name,
  d.source_name,
  u.meal_count,
  u.first_cooked_at,
  u.last_meal_at,
  u.days_spanned_by_meals,
  u.median_meal_gap_days,
  u.meal_share
FROM recipe_usage_stats u
JOIN recipe_search_documents d ON d.uid = u.uid
WHERE u.meal_count > 0
ORDER BY u.last_meal_at ASC, u.meal_count DESC, d.name COLLATE NOCASE
LIMIT 50;
```

This surfaces old cooked recipes. It does not mean they are disliked, forgotten, or good dinner suggestions; Robut should interpret contextually.

### Frequently cooked recipes

```sql
SELECT
  d.name,
  d.source_name,
  d.star_rating,
  d.is_favorite,
  u.meal_count,
  u.first_cooked_at,
  u.last_meal_at,
  u.median_meal_gap_days,
  u.meal_share
FROM recipe_usage_stats u
JOIN recipe_search_documents d ON d.uid = u.uid
ORDER BY u.meal_count DESC, u.last_meal_at DESC, d.name COLLATE NOCASE
LIMIT 50;
```

Frequency is evidence of repeat use, not absolute preference. Convenience, guests, kids, season, or habit may be involved.

### Source/cookbook usage support

Prefer the CLI first:

```bash
paprika-pantry source cookbooks --sort meals --format json
```

If debugging the rollup, inspect directly:

```sql
SELECT
  COALESCE(NULLIF(d.source_name, ''), '(unlabeled source/cookbook)') AS source_name,
  COUNT(*) AS recipes,
  SUM(CASE WHEN d.star_rating IS NOT NULL THEN 1 ELSE 0 END) AS rated_recipes,
  SUM(CASE WHEN d.is_favorite THEN 1 ELSE 0 END) AS favorites,
  SUM(COALESCE(u.meal_count, 0)) AS meals,
  MIN(u.first_cooked_at) AS first_cooked_at,
  MAX(u.last_meal_at) AS last_meal_at
FROM recipe_search_documents d
LEFT JOIN recipe_usage_stats u ON u.uid = d.uid
GROUP BY COALESCE(NULLIF(d.source_name, ''), '(unlabeled source/cookbook)')
ORDER BY meals DESC, recipes DESC, source_name COLLATE NOCASE
LIMIT 50;
```

Cookbook/source rollups are useful support, not proof that every recipe from that source is good for the current situation.

### Ingredient token coverage for one recipe

```sql
SELECT
  d.name,
  l.line_number,
  l.source_text,
  GROUP_CONCAT(t.token, ', ') AS tokens
FROM recipe_search_documents d
JOIN recipe_ingredient_lines l ON l.recipe_uid = d.uid
LEFT JOIN recipe_ingredient_tokens t
  ON t.recipe_uid = l.recipe_uid
 AND t.line_number = l.line_number
WHERE d.name LIKE '%risotto%'
GROUP BY d.uid, l.line_number, l.source_text
ORDER BY d.name COLLATE NOCASE, l.line_number;
```

Ingredient tokens are conservative indexing evidence. They are not a full culinary ontology.

### Ingredient pair support

Prefer the CLI first:

```bash
paprika-pantry recipes pairings --token tomato --sort meals --format json
```

If debugging pairings directly:

```sql
SELECT
  token_a,
  token_b,
  recipe_count,
  cooked_recipe_count,
  cooked_meal_count,
  favorite_recipe_count,
  rated_recipe_count,
  average_star_rating,
  first_meal_at,
  last_meal_at
FROM ingredient_pair_summaries
WHERE token_a = 'tomato' OR token_b = 'tomato'
ORDER BY cooked_meal_count DESC, recipe_count DESC, token_a, token_b
LIMIT 50;
```

Pairings are co-occurrence evidence from recipe ingredient tokens plus usage stats. They are not substitution advice and not a claim that flavors work together outside the observed recipe evidence.

### Pairing provenance examples

```sql
SELECT
  e.token_a,
  e.token_b,
  d.name,
  d.source_name,
  e.meal_count,
  e.star_rating,
  e.is_favorite,
  e.token_a_line_numbers_json,
  e.token_b_line_numbers_json
FROM ingredient_pair_recipe_evidence e
JOIN recipe_search_documents d ON d.uid = e.recipe_uid
WHERE (e.token_a = 'tomato' OR e.token_b = 'tomato')
ORDER BY e.meal_count DESC, d.name COLLATE NOCASE
LIMIT 50;
```

Use this when a pair summary looks surprising. The examples are usually more useful than the aggregate alone.

## Agent guidance

When using exploration SQL as Robut or a coding agent:

1. State the exploration question first.
2. Check whether a CLI command already answers it.
3. If SQL is needed, keep it read-only and narrow.
4. Report counts, freshness, and caveats with the result.
5. Do not turn one-off SQL into a stable user-facing behavior unless it graduates into a CLI command or documented workflow.

Good exploration question:

> Why did `recipes pairings --token tomato --sort meals` rank this pair highly?

Bad exploration question:

> What should Julian cook tonight?

For the bad question, use stable CLI outputs first, then let Robut compose a situated answer with visible assumptions.
