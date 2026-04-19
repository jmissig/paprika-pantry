BINARY := paprika-pantry
SKILL_NAME := paprika-pantry
SKILL_DIR := skills/$(SKILL_NAME)
BUILD_DIR ?= build
CONFIGURATION ?= debug
PREFIX ?= $(HOME)
BINDIR ?= $(PREFIX)/bin
SKILL_INSTALL ?= skill-install
SKILL_SCOPE ?= user
# OpenClaw's generic/default-ish skill-install target is named "portable".
SKILL_AGENT ?= portable

.PHONY: build release test install install-skill clean show-bin

build:
	swift build --build-path $(BUILD_DIR) --product $(BINARY)

release:
	swift build -c release --build-path $(BUILD_DIR) --product $(BINARY)

test:
	swift test --build-path $(BUILD_DIR)

install: release
	install -d $(BINDIR)
	install -m 0755 $(BUILD_DIR)/release/$(BINARY) $(BINDIR)/$(BINARY)
	@echo "Installed $(BINARY) to $(BINDIR)/$(BINARY)"

install-skill:
	@test -f "$(SKILL_DIR)/SKILL.md" || (echo "Missing $(SKILL_DIR)/SKILL.md" && exit 1)
	@command -v "$(SKILL_INSTALL)" >/dev/null 2>&1 || (echo "skill-install not found at $(SKILL_INSTALL)" && exit 1)
	"$(SKILL_INSTALL)" "$(SKILL_DIR)" --agent "$(SKILL_AGENT)" --scope "$(SKILL_SCOPE)" --force
	@echo "Installed skill $(SKILL_NAME) via OpenClaw"

clean:
	rm -rf $(BUILD_DIR)

show-bin:
	@echo $(BUILD_DIR)/$(CONFIGURATION)/$(BINARY)
