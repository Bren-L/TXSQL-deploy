# TXSQL Offline Deployment — Makefile
# =============================================================================
# Top-level build orchestration.  Each target delegates to build/*.sh scripts.

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Configuration ───────────────────────────────────────────────────────────

VERSION      ?= $(shell cat VERSION 2>/dev/null | grep TXSQL_RELEASE | cut -d= -f2 || echo "0.0.0")
TXSQL_SOURCE ?= $(error TXSQL_SOURCE is not set. Usage: make <target> TXSQL_SOURCE=/path/to/txsql/source)
PLATFORM     ?= centos-7.8-x86_64
OUTPUT_DIR   ?= $(CURDIR)/dist
BUILD_DIR    ?= $(CURDIR)/build/tmp

# ── Platform validation ─────────────────────────────────────────────────────

VALID_PLATFORMS := centos-7.9-x86_64 openeuler-22.03-x86_64 kylin-v11-x86_64

define validate_platform
	@if ! echo "$(VALID_PLATFORMS)" | grep -qw "$(PLATFORM)"; then \
		echo "ERROR: Invalid PLATFORM '$(PLATFORM)'"; \
		echo "Valid: $(VALID_PLATFORMS)"; \
		exit 1; \
	fi
endef

# ── Phony targets ───────────────────────────────────────────────────────────

.PHONY: all help validate inspect-source build build-rpm bundle bundle-all test clean

all: help

help: ## Show this help
	@echo "TXSQL Offline Deployment — Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make inspect-source  TXSQL_SOURCE=/path/to/txsql"
	@echo "  make build            PLATFORM=centos-7.8-x86_64"
	@echo "  make bundle           PLATFORM=centos-7.8-x86_64"
	@echo "  make bundle-all"
	@echo "  make test             PLATFORM=centos-7.8-x86_64"
	@echo "  make clean"
	@echo ""
	@echo "Variables:"
	@echo "  TXSQL_SOURCE   Path to TXSQL source tree (required for inspect/build)"
	@echo "  PLATFORM       Target platform ID (default: centos-7.8-x86_64)"
	@echo "  OUTPUT_DIR     Output directory (default: dist/)"
	@echo ""
	@echo "Valid PLATFORM values:"
	@echo "  $(VALID_PLATFORMS)"

validate: ## Validate project structure and required tools
	@echo "=== Validating project structure ==="
	@test -d platforms || (echo "ERROR: platforms/ missing" && exit 1)
	@test -d build || (echo "ERROR: build/ missing" && exit 1)
	@test -d packaging/rpm || (echo "ERROR: packaging/rpm/ missing" && exit 1)
	@test -d installer || (echo "ERROR: installer/ missing" && exit 1)
	@test -d config || (echo "ERROR: config/ missing" && exit 1)
	@test -d systemd || (echo "ERROR: systemd/ missing" && exit 1)
	@echo "=== Checking required tools ==="
	@command -v rpmbuild >/dev/null 2>&1 || echo "WARNING: rpmbuild not found (needed for build-rpm)"
	@command -v createrepo >/dev/null 2>&1 || command -v createrepo_c >/dev/null 2>&1 || echo "WARNING: createrepo/createrepo_c not found"
	@command -v cmake >/dev/null 2>&1 || echo "WARNING: cmake not found (needed for build-txsql)"
	@echo "=== Validate complete ==="

inspect-source: ## Analyze TXSQL source tree and produce source-profile.env
	@test -d "$(TXSQL_SOURCE)" || (echo "ERROR: TXSQL_SOURCE='$(TXSQL_SOURCE)' is not a directory" && exit 1)
	@test -f "$(TXSQL_SOURCE)/CMakeLists.txt" || (echo "ERROR: CMakeLists.txt not found in TXSQL_SOURCE" && exit 1)
	@echo "=== Inspecting TXSQL source at $(TXSQL_SOURCE) ==="
	@bash build/inspect-source.sh --source-dir "$(TXSQL_SOURCE)" --output "$(BUILD_DIR)"

build: validate ## Build TXSQL for a specific platform
	$(call validate_platform)
	@echo "=== Building TXSQL for $(PLATFORM) ==="
	@bash build/build-txsql.sh --platform "$(PLATFORM)" --source-dir "$(TXSQL_SOURCE)" --output "$(BUILD_DIR)"

build-rpm: build ## Build RPM packages for a specific platform
	$(call validate_platform)
	@echo "=== Building RPMs for $(PLATFORM) ==="
	@bash build/build-rpm.sh --platform "$(PLATFORM)" --build-dir "$(BUILD_DIR)" --output "$(BUILD_DIR)/rpms"

bundle: build-rpm ## Generate offline installation bundle for a specific platform
	$(call validate_platform)
	@echo "=== Creating offline bundle for $(PLATFORM) ==="
	@bash build/build-platform-bundle.sh --platform "$(PLATFORM)" --version "$(VERSION)" --output "$(OUTPUT_DIR)"

bundle-all: ## Generate all-platforms bundle (requires all platforms built)
	@echo "=== Creating all-platforms bundle ==="
	@bash build/build-universal-bundle.sh --version "$(VERSION)" --output "$(OUTPUT_DIR)"

test: ## Run acceptance tests for a platform (requires target VM)
	$(call validate_platform)
	@echo "=== Running tests for $(PLATFORM) ==="
	@bash tests/acceptance/run-tests.sh --platform "$(PLATFORM)"

clean: ## Clean build artifacts
	@echo "=== Cleaning build artifacts ==="
	@rm -rf "$(BUILD_DIR)"
	@echo "=== Clean complete ==="

distclean: clean ## Clean everything including dist/
	@echo "=== Deep cleaning ==="
	@rm -rf "$(OUTPUT_DIR)"/*
	@echo "=== Distclean complete ==="
