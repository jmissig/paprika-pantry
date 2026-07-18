BINARY := paprika-pantry
SKILL_NAME := paprika-pantry
SKILL_DIR := skills/$(SKILL_NAME)
VERSION_FILE := VERSION
VERSION_SYNC_FILE := Sources/PantryKit/CLI/PantryCLI.swift
VERSION := $(shell tr -d '\n' < $(VERSION_FILE))
BUILD_DIR ?= build
CONFIGURATION ?= debug
PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
SKILL_TARGET ?= openclaw
OPENCLAW_HOME ?= $(HOME)/.openclaw
CODEX_HOME ?= $(HOME)/.codex
CLAUDE_CONFIG_DIR ?= $(HOME)/.claude

ifeq ($(SKILL_TARGET),openclaw)
SKILLS_DIR ?= $(OPENCLAW_HOME)/skills
else ifeq ($(SKILL_TARGET),codex)
SKILLS_DIR ?= $(CODEX_HOME)/skills
else ifeq ($(SKILL_TARGET),claude)
SKILLS_DIR ?= $(CLAUDE_CONFIG_DIR)/skills
else
$(error Unsupported SKILL_TARGET '$(SKILL_TARGET)'; expected openclaw, codex, or claude)
endif

SKILL_DEST := $(SKILLS_DIR)/$(SKILL_NAME)

.PHONY: build release test install install-skill sync-version clean show-bin

sync-version:
	@test -f "$(VERSION_FILE)" || (echo "Missing $(VERSION_FILE)" && exit 1)
	python3 -c 'from pathlib import Path; import re; version = Path("$(VERSION_FILE)").read_text().strip() or "0.0.0"; path = Path("$(VERSION_SYNC_FILE)"); text = path.read_text(); text, count = re.subn(r"// VERSION-SYNC-START\n.*?\n// VERSION-SYNC-END", "// VERSION-SYNC-START\nprivate let pantryCLIVersion = \"%s\"\n// VERSION-SYNC-END" % version, text, count=1, flags=re.S); assert count == 1, "version marker not found"; path.write_text(text)'

build: sync-version
	swift build --build-path $(BUILD_DIR) --product $(BINARY)

release: sync-version
	swift build -c release --build-path $(BUILD_DIR) --product $(BINARY)

test: sync-version
	swift test --build-path $(BUILD_DIR)

install: release
	install -d $(BINDIR)
	install -m 0755 $(BUILD_DIR)/release/$(BINARY) $(BINDIR)/$(BINARY)
	@echo "Installed $(BINARY) to $(BINDIR)/$(BINARY)"

install-skill:
	@test -f "$(SKILL_DIR)/SKILL.md" || (echo "Missing $(SKILL_DIR)/SKILL.md" && exit 1)
	@test -f "$(VERSION_FILE)" || (echo "Missing $(VERSION_FILE)" && exit 1)
	mkdir -p "$(SKILLS_DIR)"
	rm -rf "$(SKILL_DEST)"
	cp -R "$(SKILL_DIR)" "$(SKILL_DEST)"
	python3 -c 'from pathlib import Path; import re; path = Path("$(SKILL_DEST)/SKILL.md"); text = path.read_text(); text = re.sub(r"\n<!-- repo-version: .*? -->\n?", "\n", text); text = text.rstrip() + "\n\n<!-- repo-version: $(VERSION) -->\n"; path.write_text(text)'
	@echo "Installed skill $(SKILL_NAME) for $(SKILL_TARGET) to $(SKILL_DEST)"

clean:
	rm -rf $(BUILD_DIR)

show-bin:
	@echo $(BUILD_DIR)/$(CONFIGURATION)/$(BINARY)
