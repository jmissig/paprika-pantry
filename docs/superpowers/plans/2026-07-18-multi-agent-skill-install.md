# Multi-Agent Skill Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `make install-skill` target OpenClaw, Codex, or Claude Code and clarify that the CLI reads the local Paprika 3 Mac app's SQLite database read-only.

**Architecture:** Keep the installer in the existing Makefile. Resolve one `SKILLS_DIR` from `SKILL_TARGET` and the target-specific home variable, then reuse the existing copy/version-marker recipe. Document the three invocations and the local-Mac source boundary in `README.md`.

**Tech Stack:** GNU Make, Markdown, Swift Package Manager verification

## Global Constraints

- OpenClaw remains the default target.
- Supported values are exactly `openclaw`, `codex`, and `claude`.
- Do not depend on `/Users/robut/Source/skills` or vendor its installer.
- Preserve the existing skill copy and repository-version marker behavior.
- Do not add a permanent test harness for this Makefile/docs-only change; use dry runs and temporary homes.

---

### Task 1: Add target-aware Make installation

**Files:**
- Modify: `Makefile`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: `SKILL_TARGET`, `OPENCLAW_HOME`, `CODEX_HOME`, `CLAUDE_CONFIG_DIR`
- Produces: `SKILLS_DIR` and `SKILL_DEST` for the selected agent

- [x] **Step 1: Verify the unsupported-target behavior is absent**

Run: `make -n install-skill SKILL_TARGET=invalid`

Expected: the current Makefile does not reject `invalid` as an unsupported target.

- [x] **Step 2: Add target resolution**

Add Make conditionals that default `SKILL_TARGET` to `openclaw`, resolve the three documented home variables and skill roots, and call `$(error Unsupported SKILL_TARGET ...)` for any other value. Replace `OPENCLAW_SKILLS_DIR` in the install recipe with `SKILLS_DIR`.

- [x] **Step 3: Verify all target paths**

Run:

```bash
make -n install-skill SKILL_TARGET=openclaw OPENCLAW_HOME=/tmp/paprika-openclaw
make -n install-skill SKILL_TARGET=codex CODEX_HOME=/tmp/paprika-codex
make -n install-skill SKILL_TARGET=claude CLAUDE_CONFIG_DIR=/tmp/paprika-claude
make -n install-skill SKILL_TARGET=invalid
```

Expected: the first three dry runs target `/tmp/paprika-{agent}/skills/paprika-pantry`; the fourth fails before printing install commands.

- [x] **Step 4: Keep project guidance current**

Document that `make install-skill` defaults to the shared managed OpenClaw root, while `SKILL_TARGET=codex|claude` selects the corresponding agent root and workspace-local skills remain higher-precedence user overrides.

### Task 2: Document install targets and local database source

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the Makefile interface from Task 1
- Produces: public install examples and source-boundary documentation

- [x] **Step 1: Clarify the introduction and first-run requirements**

State that the CLI reads the SQLite database maintained by the locally installed Paprika 3 macOS app, opens it read-only, requires a local app database, and does not use Paprika Cloud authentication or a Paprika web API.

- [x] **Step 2: Add install examples**

Document:

```bash
make install-skill
make install-skill SKILL_TARGET=codex
make install-skill SKILL_TARGET=claude
```

List the default target directories and the corresponding override variables.

- [x] **Step 3: Verify the repository**

Run:

```bash
git diff --check
make test
```

Expected: no whitespace errors and 91 tests pass with zero failures.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md Makefile README.md docs/superpowers/plans/2026-07-18-multi-agent-skill-install.md
git commit -m "Support multi-agent skill installation"
```
