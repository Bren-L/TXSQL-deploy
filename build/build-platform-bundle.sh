#!/bin/bash
# =============================================================================
# build-platform-bundle.sh — Assemble Final Offline Distribution Bundle
# =============================================================================
# Combines:
#   - Local RPM repository (with repodata/)
#   - Installer scripts (install.sh, uninstall.sh, lib/)
#   - Config templates (my.cnf.tpl, bootstrap.cnf.tpl)
#   - Systemd unit (txsql.service)
#   - Documentation
#   - SHA256SUMS covering everything
#
# Output: dist/txsql-offline-<version>-<platform-id>.tar.gz
#
# Usage:
#   bash build-platform-bundle.sh \
#     --platform centos-7.9-x86_64 \
#     --version 8.0.30-1.0.0 \
#     --repo-dir payloads/centos-7.9-x86_64/repository/ \
#     --output dist/
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

PLATFORM=""
VERSION=""
REPO_DIR=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)  PLATFORM="$2"; shift 2 ;;
        --version)   VERSION="$2"; shift 2 ;;
        --repo-dir)  REPO_DIR="$2"; shift 2 ;;
        --output)    OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: bash build-platform-bundle.sh --platform <id> --version <ver> --repo-dir <path> --output <dir>"
            echo "Creates: txsql-offline-<version>-<platform-id>.tar.gz"
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$PLATFORM" ]]; then log_error "--platform is required"; exit 1; fi
if [[ -z "$VERSION" ]]; then VERSION="0.0.0"; log_warn "No version specified, using $VERSION"; fi

REPO_DIR="${REPO_DIR:-payloads/${PLATFORM}/repository}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
ensure_dir "$OUTPUT_DIR"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_title "TXSQL Offline Bundle Builder"
log_info "Platform: $PLATFORM"
log_info "Version:  $VERSION"
log_info "Repo:     $REPO_DIR"
log_info "Output:   $OUTPUT_DIR"

# ── Validate repository ─────────────────────────────────────────────────────

log_step "Validating repository..."

if [[ ! -d "$REPO_DIR" ]]; then
    log_error "Repository directory not found: $REPO_DIR"
    log_error "Run create-local-repo.sh first."
    exit 1
fi

if [[ ! -f "$REPO_DIR/repodata/repomd.xml" ]]; then
    log_error "Repository has no repodata/repomd.xml — run create-local-repo.sh first."
    exit 1
fi

rpm_count=$(find "$REPO_DIR" -maxdepth 1 -name "*.rpm" ! -name "*.src.rpm" -type f | wc -l)
if [[ $rpm_count -eq 0 ]]; then
    log_error "Repository has no RPM files."
    exit 1
fi

log_info "Repository valid: $rpm_count RPMs, repodata present"

# ── Create bundle staging directory ─────────────────────────────────────────

BUNDLE_NAME="txsql-offline-${VERSION}-${PLATFORM}"
BUNDLE_DIR="$OUTPUT_DIR/$BUNDLE_NAME"

log_step "Creating bundle staging: $BUNDLE_DIR"

# Clean any previous staging
rm -rf "$BUNDLE_DIR"
ensure_dir "$BUNDLE_DIR"

# ── Copy repository ─────────────────────────────────────────────────────────

log_step "Copying repository..."
cp -a "$REPO_DIR" "$BUNDLE_DIR/repository/"
log_info "Repository copied ($rpm_count RPMs)"

# ── Copy installer ──────────────────────────────────────────────────────────

log_step "Copying installer..."

INSTALLER_SRC="$PROJECT_ROOT/installer"
if [[ -d "$INSTALLER_SRC" ]]; then
    cp -a "$INSTALLER_SRC"/*.sh "$BUNDLE_DIR/" 2>/dev/null || true
    if [[ -d "$INSTALLER_SRC/lib" ]]; then
        mkdir -p "$BUNDLE_DIR/lib"
        cp -a "$INSTALLER_SRC/lib"/*.sh "$BUNDLE_DIR/lib/" 2>/dev/null || true
    fi
fi

# Always copy install.sh and uninstall.sh from project root if they exist
for f in install.sh uninstall.sh; do
    if [[ -f "$BUNDLE_DIR/$f" ]]; then
        log_info "  $f (from installer/)"
    else
        log_warn "  $f NOT FOUND — installer not yet written"
    fi
done

# ── Copy config templates ───────────────────────────────────────────────────

log_step "Copying configuration templates..."

CONFIG_SRC="$PROJECT_ROOT/config"
if [[ -d "$CONFIG_SRC" ]]; then
    mkdir -p "$BUNDLE_DIR/config"
    cp -a "$CONFIG_SRC"/* "$BUNDLE_DIR/config/" 2>/dev/null || true
    log_info "Config templates copied"
else
    log_warn "config/ directory not found"
fi

# ── Copy systemd unit ───────────────────────────────────────────────────────

log_step "Copying systemd unit..."

SYSTEMD_SRC="$PROJECT_ROOT/systemd"
if [[ -d "$SYSTEMD_SRC" ]] && [[ -f "$SYSTEMD_SRC/txsql.service" ]]; then
    mkdir -p "$BUNDLE_DIR/systemd"
    cp "$SYSTEMD_SRC/txsql.service" "$BUNDLE_DIR/systemd/"
    log_info "txsql.service copied"
else
    log_warn "systemd/txsql.service not found"
fi

# ── Copy docs ──────────────────────────────────────────────────────────────

log_step "Copying documentation..."

DOCS_SRC="$PROJECT_ROOT/docs"
if [[ -d "$DOCS_SRC" ]]; then
    mkdir -p "$BUNDLE_DIR/docs"
    for doc in ARCHITECTURE.md PLATFORM_MATRIX.md INSTALL.md UNINSTALL.md TROUBLESHOOTING.md; do
        if [[ -f "$DOCS_SRC/$doc" ]]; then
            cp "$DOCS_SRC/$doc" "$BUNDLE_DIR/docs/"
        fi
    done
    log_info "Documentation copied"
fi

# ── Write metadata files ────────────────────────────────────────────────────

log_step "Writing metadata..."

# VERSION
echo "TXSQL_VERSION=$VERSION" > "$BUNDLE_DIR/VERSION"
echo "BUNDLE_DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$BUNDLE_DIR/VERSION"

# PLATFORM
echo "PLATFORM_ID=$PLATFORM" > "$BUNDLE_DIR/PLATFORM"

# SOURCE_COMMIT (if available)
if [[ -f "$PROJECT_ROOT/SOURCE_COMMIT" ]]; then
    cp "$PROJECT_ROOT/SOURCE_COMMIT" "$BUNDLE_DIR/SOURCE_COMMIT"
fi

# BUILDINFO
{
    echo "BUILD_DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "BUILD_HOST=$(hostname -f 2>/dev/null || hostname)"
    echo "BUILD_KERNEL=$(uname -r)"
    echo "BUILD_ARCH=$(uname -m)"
    echo "PLATFORM=$PLATFORM"
    echo "VERSION=$VERSION"
    echo "RPM_COUNT=$rpm_count"
} > "$BUNDLE_DIR/BUILDINFO"

# MANIFEST — list of every file in the bundle
(cd "$BUNDLE_DIR" && find . -type f | sort) > "$BUNDLE_DIR/MANIFEST"

# ── Strip comments/blank lines from scripts (production optimization) ──────

# Not done — keep scripts readable for debugging.

# ── Generate SHA256SUMS ─────────────────────────────────────────────────────

log_step "Generating SHA256SUMS..."

generate_sha256sums "$BUNDLE_DIR" "$BUNDLE_DIR/SHA256SUMS"

# ── Create tarball ──────────────────────────────────────────────────────────

log_step "Creating distribution tarball..."

TARBALL="$OUTPUT_DIR/${BUNDLE_NAME}.tar.gz"

tar czf "$TARBALL" -C "$OUTPUT_DIR" "$BUNDLE_NAME"

TARBALL_SIZE=$(du -sh "$TARBALL" | awk '{print $1}')

# SHA-256 of the tarball itself
TARBALL_SHA256=$(sha256sum "$TARBALL" | awk '{print $1}')
echo "$TARBALL_SHA256  ${BUNDLE_NAME}.tar.gz" > "$OUTPUT_DIR/${BUNDLE_NAME}.tar.gz.sha256"

log_info "Tarball: $TARBALL ($TARBALL_SIZE)"
log_info "SHA-256: $TARBALL_SHA256"

# ── Clean staging (keep tarball only) ──────────────────────────────────────

rm -rf "$BUNDLE_DIR"
log_info "Staging directory removed (tarball only)"

# ── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "=============================================================================="
echo "  Bundle Created: ${BUNDLE_NAME}.tar.gz"
echo "=============================================================================="
echo ""
echo "  File:     $TARBALL"
echo "  Size:     $TARBALL_SIZE"
echo "  SHA-256:  $TARBALL_SHA256"
echo "  Platform: $PLATFORM"
echo "  Version:  $VERSION"
echo "  RPMs:     $rpm_count"
echo ""
echo "To install on target system:"
echo "  1. Copy $TARBALL to target"
echo "  2. tar xzf ${BUNDLE_NAME}.tar.gz"
echo "  3. cd ${BUNDLE_NAME}"
echo "  4. sudo ./install.sh </dev/null"
echo ""
