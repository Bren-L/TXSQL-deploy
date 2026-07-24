#!/bin/bash
# =============================================================================
# build-universal-bundle.sh — Multi-Platform Universal Offline Bundle
# =============================================================================
# Aggregates ONLY platforms marked SUPPORTED in PLATFORM_MATRIX.
# Zero SUPPORTED platforms → zero payloads → empty payloads/ in bundle.
#
# Usage:
#   bash build-universal-bundle.sh --version 8.0.30-1.0.0 --output dist/
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ────────────────────────────────────────────────────────

VERSION=""
OUTPUT_DIR=""
PLATFORM_MATRIX_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)        VERSION="$2"; shift 2 ;;
        --output)         OUTPUT_DIR="$2"; shift 2 ;;
        --platform-matrix) PLATFORM_MATRIX_FILE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash build-universal-bundle.sh --version <ver> [--output <dir>]"
            echo ""
            echo "Aggregates SUPPORTED platform payloads into a universal offline bundle."
            echo "Only platforms with status SUPPORTED in docs/PLATFORM_MATRIX.md are included."
            echo "Per the project gate: zero SUPPORTED platforms → zero payloads."
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$VERSION" ]]; then VERSION="0.0.0"; log_warn "No version, using $VERSION"; fi
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
PLATFORM_MATRIX_FILE="${PLATFORM_MATRIX_FILE:-${PROJECT_ROOT}/docs/PLATFORM_MATRIX.md}"

ensure_dir "$OUTPUT_DIR"

log_title "TXSQL Multi-Platform Universal Bundle Builder"
log_info "Version:         $VERSION"
log_info "Output:          $OUTPUT_DIR"
log_info "Platform matrix: $PLATFORM_MATRIX_FILE"

# ── Determine SUPPORTED platforms ──────────────────────────────────────────

log_step "Reading PLATFORM_MATRIX for SUPPORTED platforms..."

SUPPORTED_PLATFORMS=()
ALL_KNOWN_PLATFORMS=(
    "centos-7.8-x86_64"
    "centos-7.9-x86_64"
    "tencentos-2.4-x86_64"
    "tencentos-3.1-x86_64"
    "kylin-v10-sp1-aarch64"
    "kylin-v10-sp2-aarch64"
    "kylin-v10-sp3-aarch64"
)

# Parse PLATFORM_MATRIX.md for SUPPORTED lines
if [[ -f "$PLATFORM_MATRIX_FILE" ]]; then
    while IFS= read -r line; do
        # Match lines like: | centos-7.9-x86_64 | x86_64 | ✅ | ... | **SUPPORTED** |
        if echo "$line" | grep -qE '^\|.*\|\s*\*\*SUPPORTED\*\*\s*\|'; then
            plat=$(echo "$line" | awk -F'|' '{print $2}' | tr -d ' ')
            if [[ -n "$plat" ]]; then
                SUPPORTED_PLATFORMS+=("$plat")
                log_info "SUPPORTED: $plat"
            fi
        fi
    done < "$PLATFORM_MATRIX_FILE"
fi

if [[ ${#SUPPORTED_PLATFORMS[@]} -eq 0 ]]; then
    log_error "============================================"
    log_error "  ZERO platforms are marked SUPPORTED."
    log_error "  Cannot generate a universal bundle with no"
    log_error "  payloads — that would NOT be a deployable"
    log_error "  product. The 26K tarball generated previously"
    log_error "  was moved to artifacts/framework-preview/."
    log_error ""
    log_error "  Per project rules:"
    log_error "  '全集成包只允许包含已经通过独立平台验收的载荷'"
    log_error ""
    log_error "  Build ABORTED. Add SUPPORTED platforms first."
    log_error "============================================"
    exit 1
fi

# ── Create bundle staging ──────────────────────────────────────────────────

BUNDLE_NAME="txsql-offline-${VERSION}-all-supported-platforms"
BUNDLE_DIR="$OUTPUT_DIR/$BUNDLE_NAME"
rm -rf "$BUNDLE_DIR"
ensure_dir "$BUNDLE_DIR"

log_info "Bundle staging: $BUNDLE_DIR"

# ── Copy dispatch installer ────────────────────────────────────────────────

log_step "Copying dispatch installer..."

# Copy the multi-platform install.sh (dispatcher)
if [[ -f "$PROJECT_ROOT/installer/install.sh" ]]; then
    cp "$PROJECT_ROOT/installer/install.sh" "$BUNDLE_DIR/install.sh"
    chmod +x "$BUNDLE_DIR/install.sh"
    log_info "install.sh (multi-platform dispatcher)"
else
    log_warn "installer/install.sh not found — will create stub"
fi

# Copy uninstall.sh
if [[ -f "$PROJECT_ROOT/installer/uninstall.sh" ]]; then
    cp "$PROJECT_ROOT/installer/uninstall.sh" "$BUNDLE_DIR/uninstall.sh"
    chmod +x "$BUNDLE_DIR/uninstall.sh"
    log_info "uninstall.sh"
fi

# Copy lib/ modules
if [[ -d "$PROJECT_ROOT/installer/lib" ]]; then
    ensure_dir "$BUNDLE_DIR/lib"
    cp -a "$PROJECT_ROOT/installer/lib"/*.sh "$BUNDLE_DIR/lib/" 2>/dev/null || true
    chmod +x "$BUNDLE_DIR/lib"/*.sh 2>/dev/null || true
    log_info "lib/ modules: $(ls "$BUNDLE_DIR/lib/"*.sh 2>/dev/null | wc -l) files"
fi

# ── Copy payloads (only SUPPORTED platforms) ───────────────────────────────

log_step "Aggregating SUPPORTED platform payloads..."

PAYLOADS_DIR="$BUNDLE_DIR/payloads"
ensure_dir "$PAYLOADS_DIR"

payloads_copied=0

if [[ ${#SUPPORTED_PLATFORMS[@]} -gt 0 ]]; then
    for plat in "${SUPPORTED_PLATFORMS[@]}"; do
        plat_payload="$PROJECT_ROOT/payloads/$plat"
        if [[ -d "$plat_payload" ]]; then
            log_info "  Copying payload: $plat"
            cp -a "$plat_payload" "$PAYLOADS_DIR/$plat/"
            payloads_copied=$((payloads_copied + 1))
        else
            log_error "  SUPPORTED platform $plat has no payload at: $plat_payload"
            log_error "  Run: make bundle PLATFORM=$plat"
            log_error "  A platform marked SUPPORTED must have a verified payload."
        fi
    done
else
    log_info "  No SUPPORTED platforms — no payloads to aggregate."
    log_info "  payloads/ directory is intentionally empty."
fi

# ── Copy shared scripts ────────────────────────────────────────────────────

log_step "Copying shared scripts..."

ensure_dir "$BUNDLE_DIR/scripts"

# Copy fingerprint collector
if [[ -f "$PROJECT_ROOT/build/collect-fingerprints.sh" ]]; then
    cp "$PROJECT_ROOT/build/collect-fingerprints.sh" "$BUNDLE_DIR/scripts/"
    log_info "collect-fingerprints.sh"
fi

# ── Write metadata ─────────────────────────────────────────────────────────

log_step "Writing bundle metadata..."

# VERSION
{
    echo "TXSQL_VERSION=$VERSION"
    echo "BUNDLE_TYPE=all-supported-platforms"
    echo "BUNDLE_DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "SUPPORTED_PLATFORMS=${#SUPPORTED_PLATFORMS[@]}"
} > "$BUNDLE_DIR/VERSION"

# PLATFORM_LIST
{
    echo "# Platforms included in this universal bundle"
    echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "# Included platforms: ${#SUPPORTED_PLATFORMS[@]}"
    if [[ ${#SUPPORTED_PLATFORMS[@]} -gt 0 ]]; then
        echo ""
        echo "# Format: PLATFORM_ID | ARCH | STATUS"
        for plat in "${SUPPORTED_PLATFORMS[@]}"; do
            echo "$plat | $(echo "$plat" | grep -oP '(x86_64|aarch64)') | SUPPORTED"
        done
    else
        echo "# ZERO platforms are SUPPORTED. payloads/ is empty."
        echo "# Platforms will be added as they pass the 25-test acceptance gate."
    fi
} > "$BUNDLE_DIR/PLATFORM_LIST"

# BUILDINFO
{
    echo "BUILD_DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "BUILD_HOST=$(hostname -f 2>/dev/null || hostname)"
    echo "BUILD_TYPE=universal"
    echo "VERSION=$VERSION"
    echo "INCLUDED_PLATFORMS=${#SUPPORTED_PLATFORMS[@]}"
    echo "PAYLOADS_COPIED=$payloads_copied"
    if [[ ${#SUPPORTED_PLATFORMS[@]} -gt 0 ]]; then
        echo "PLATFORMS=${SUPPORTED_PLATFORMS[*]}"
    else
        echo "PLATFORMS=(none — zero SUPPORTED platforms)"
    fi
} > "$BUNDLE_DIR/BUILDINFO"

# MANIFEST — every file in the bundle
(cd "$BUNDLE_DIR" && find . -type f | sort) > "$BUNDLE_DIR/MANIFEST"

# ── Copy config templates and docs ─────────────────────────────────────────

log_step "Copying shared resources..."

# config templates
if [[ -d "$PROJECT_ROOT/config" ]]; then
    ensure_dir "$BUNDLE_DIR/config"
    cp -a "$PROJECT_ROOT/config"/* "$BUNDLE_DIR/config/" 2>/dev/null || true
fi

# systemd
if [[ -f "$PROJECT_ROOT/systemd/txsql.service" ]]; then
    ensure_dir "$BUNDLE_DIR/systemd"
    cp "$PROJECT_ROOT/systemd/txsql.service" "$BUNDLE_DIR/systemd/"
fi

# essential docs
ensure_dir "$BUNDLE_DIR/docs"
for doc in PLATFORM_MATRIX.md ARCHITECTURE.md INSTALL.md UNINSTALL.md TROUBLESHOOTING.md; do
    if [[ -f "$PROJECT_ROOT/docs/$doc" ]]; then
        cp "$PROJECT_ROOT/docs/$doc" "$BUNDLE_DIR/docs/"
    fi
done

# ── Generate SHA256SUMS ────────────────────────────────────────────────────

log_step "Generating SHA256SUMS..."

generate_sha256sums "$BUNDLE_DIR" "$BUNDLE_DIR/SHA256SUMS"

# ── Create tarball ─────────────────────────────────────────────────────────

log_step "Creating distribution tarball..."

TARBALL="$OUTPUT_DIR/${BUNDLE_NAME}.tar.gz"
tar czf "$TARBALL" -C "$OUTPUT_DIR" "$BUNDLE_NAME"

TARBALL_SIZE=$(du -sh "$TARBALL" | awk '{print $1}')
TARBALL_SHA256=$(sha256sum "$TARBALL" | awk '{print $1}')
echo "$TARBALL_SHA256  ${BUNDLE_NAME}.tar.gz" > "${TARBALL}.sha256"

log_info "Tarball: $TARBALL ($TARBALL_SIZE)"
log_info "SHA-256: $TARBALL_SHA256"

# ── Clean staging ──────────────────────────────────────────────────────────

rm -rf "$BUNDLE_DIR"

# ── Result ─────────────────────────────────────────────────────────────────

echo ""
echo "=============================================================================="
echo "  Universal Multi-Platform Bundle: ${BUNDLE_NAME}.tar.gz"
echo "=============================================================================="
echo ""
echo "  File:             $TARBALL"
echo "  Size:             $TARBALL_SIZE"
echo "  SHA-256:          $TARBALL_SHA256"
echo "  SUPPORTED payloads: ${#SUPPORTED_PLATFORMS[@]} / 5+  (Phase 1 targets)"
echo ""

if [[ ${#SUPPORTED_PLATFORMS[@]} -eq 0 ]]; then
    echo "  ⚠️  ZERO SUPPORTED PLATFORMS — payloads/ is empty."
    echo "  This bundle will NOT install on any platform."
    echo ""
    echo "  To add platforms:"
    echo "    1. Build & verify a platform: make bundle PLATFORM=<id>"
    echo "    2. Run full 25-test acceptance on that platform"
    echo "    3. Mark platform as SUPPORTED in docs/PLATFORM_MATRIX.md"
    echo "    4. Rebuild universal bundle: make bundle-all"
else
    for plat in "${SUPPORTED_PLATFORMS[@]}"; do
        echo "  ✅ $plat"
    done
fi
echo ""
