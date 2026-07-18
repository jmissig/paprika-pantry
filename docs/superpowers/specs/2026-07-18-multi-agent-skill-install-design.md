# Multi-Agent Skill Install Design

## Goal

Let this repository install its bundled `paprika-pantry` skill into OpenClaw, Codex, or Claude Code using one Makefile target, while keeping OpenClaw as the default.

## Interface

`make install-skill` accepts `SKILL_TARGET=openclaw|codex|claude`:

- `openclaw` installs to `$OPENCLAW_HOME/skills/paprika-pantry`, defaulting to `~/.openclaw/skills/paprika-pantry`.
- `codex` installs to `$CODEX_HOME/skills/paprika-pantry`, defaulting to `~/.codex/skills/paprika-pantry`.
- `claude` installs to `$CLAUDE_CONFIG_DIR/skills/paprika-pantry`, defaulting to `~/.claude/skills/paprika-pantry`.

The target-specific environment variable may override each default. An unsupported `SKILL_TARGET` fails with a clear Make error before any filesystem changes.

The existing install behavior remains otherwise unchanged: the repository skill directory is copied into the selected agent's skill root and its repository version marker is refreshed.

## Documentation

The README will show one install example for each target. Its introduction and first-run guidance will also state that `paprika-pantry`:

- reads the SQLite database maintained by the locally installed Paprika 3 macOS app;
- opens that database read-only;
- requires the Mac app to have created and locally synced the database; and
- does not authenticate to Paprika Cloud or use a Paprika web API.

## Verification

Use Make dry runs with temporary target-specific homes to confirm all three destination paths and the version-marker step. Verify an unsupported target fails before running install commands. Run `git diff --check` and the normal test suite before completion.

## Scope

Do not depend on `/Users/robut/Source/skills`, vendor its general-purpose installer, change skill precedence, or add multi-skill/package-manager behavior.
