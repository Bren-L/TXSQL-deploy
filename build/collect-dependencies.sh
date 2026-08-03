#!/bin/bash
# =============================================================================
# collect-dependencies.sh — Layer 3-5: Collect All Required RPMs
# =============================================================================
# Takes the resolved dependency list and collects every RPM file.
# Verifies each RPM with SHA-256.
# Separates RPMs into categories: txsql, bundled-deps, system (do-not-bundle).
#
# Usage:
#   sudo bash collect-dependencies.sh \
#     --bundled-list dist/reports/<plat>/deps/bundled-rpms.txt \
#     --txsql-dir /path/to/txsql-rpms/ \
#     --repo-snapshot /path/to/os-repo/ \
#     --output payloads/<plat>/repository/
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

BUNDLED_LIST=""
TXSQL_DIR=""
REPO_SNAPSHOT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundled-list)  BUNDLED_LIST="$2"; shift 2 ;;
        --txsql-dir)     TXSQL_DIR="$2"; shift 2 ;;
        --repo-snapshot) REPO_SNAPSHOT="$2"; shift 2 ;;
        --output)        OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash collect-dependencies.sh --bundled-list <file> --txsql-dir <path> --repo-snapshot <path> --output <dir>"
            echo "Collects every RPM needed for the offline local repository."
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$BUNDLED_LIST" ]]; then log_error "--bundled-list is required"; exit 1; fi
if [[ ! -f "$BUNDLED_LIST" ]]; then log_error "Bundled list not found: $BUNDLED_LIST"; exit 1; fi
if [[ -z "$TXSQL_DIR" ]]; then log_error "--txsql-dir is required"; exit 1; fi
if [[ -z "$OUTPUT_DIR" ]]; then log_error "--output is required"; exit 1; fi

ensure_dir "$OUTPUT_DIR"

log_title "TXSQL Dependency RPM Collector"

# ── Collect TXSQL RPMs ─────────────────────────────────────────────────────

log_step "Collecting TXSQL RPMs..."

cp -v "$TXSQL_DIR"/*.rpm "$OUTPUT_DIR/" 2>/dev/null || log_warn "No TXSQL RPMs found in $TXSQL_DIR"
txsql_count=$(find "$OUTPUT_DIR" -maxdepth 1 -name "txsql-*.rpm" | wc -l)
log_info "TXSQL RPMs collected: $txsql_count"

# ── Collect bundled dependency RPMs ─────────────────────────────────────────

log_step "Collecting bundled dependency RPMs..."

COLLECT_LOG="$OUTPUT_DIR/../collect-log.txt"
MANIFEST_FILE="$OUTPUT_DIR/../RPM-MANIFEST"
: > "$COLLECT_LOG"
: > "$MANIFEST_FILE"

collected=0
missing=0
total_needed=$(wc -l < "$BUNDLED_LIST" | tr -d ' ')

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue  # skip comments

    # Extract package name (strip NEVRA to base name)
    pkg_base=$(echo "$line" | cut -d- -f1)

    # Skip TXSQL packages (already collected)
    if [[ "$pkg_base" == txsql-* ]]; then
        continue
    fi

    # Search for the RPM in the repo snapshot
    found=false
    rpm_path=""

    # Try exact NEVRA match first
    if [[ -n "$REPO_SNAPSHOT" ]] && [[ -d "$REPO_SNAPSHOT" ]]; then
        # Search for the RPM by name pattern
        rpm_path=$(find "$REPO_SNAPSHOT" -name "${pkg_base}-*.rpm" -type f 2>/dev/null | head -1)
    fi

    if [[ -n "$rpm_path" ]]; then
        cp -v "$rpm_path" "$OUTPUT_DIR/" >> "$COLLECT_LOG" 2>&1 || true
        rpm_nevra=$(rpm_nevra "$rpm_path")
        rpm_sha=$(rpm_sha256 "$rpm_path")
        echo "$rpm_nevra  SHA256:$rpm_sha  SOURCE:$rpm_path" >> "$MANIFEST_FILE"
        ((collected++)) || true
        found=true
    fi

    # If not found in snapshot, check if it's in system RPM cache
    if ! $found && [[ -d /var/cache/yum ]] || [[ -d /var/cache/dnf ]]; then
        rpm_path=$(find /var/cache -name "${pkg_base}-*.rpm" -type f 2>/dev/null | head -1)
        if [[ -n "$rpm_path" ]]; then
            cp -v "$rpm_path" "$OUTPUT_DIR/" >> "$COLLECT_LOG" 2>&1 || true
            rpm_nevra=$(rpm_nevra "$rpm_path")
            rpm_sha=$(rpm_sha256 "$rpm_path")
            echo "$rpm_nevra  SHA256:$rpm_sha  SOURCE:cache" >> "$MANIFEST_FILE"
            ((collected++)) || true
            found=true
        fi
    fi

    if ! $found; then
        log_warn "MISSING: $line"
        echo "MISSING: $line" >> "$COLLECT_LOG"
        ((missing++)) || true
    fi
done < "$BUNDLED_LIST"

log_info "Collected: $collected / $total_needed"
log_info "Missing:   $missing"

# ── SHA-256 verification ────────────────────────────────────────────────────

log_step "Verifying RPM integrity (SHA-256)..."

SHA256SUMS_FILE="$OUTPUT_DIR/SHA256SUMS"
generate_sha256sums "$OUTPUT_DIR" "$SHA256SUMS_FILE"

# Verify each collected RPM
corrupt=0
find "$OUTPUT_DIR" -name "*.rpm" -type f | while IFS= read -r rpm; do
    if ! rpm -K --nosignature "$rpm" &>/dev/null; then
        log_warn "RPM integrity check failed: $(basename "$rpm")"
        echo "CORRUPT: $rpm" >> "$COLLECT_LOG"
    fi
done

# ── Generate manifest ───────────────────────────────────────────────────────

log_step "Generating RPM manifest..."

FULL_MANIFEST="$OUTPUT_DIR/../MANIFEST"
{
    echo "# TXSQL Offline RPM Manifest"
    echo "# Platform: ${PLATFORM:-unknown}"
    echo "# Generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "#"
    echo "# Format: NEVRA | SHA256 | Source"
    echo "#"
    echo "# === TXSQL RPMs ==="
    find "$OUTPUT_DIR" -maxdepth 1 -name "txsql-*.rpm" -type f | while IFS= read -r rpm; do
        echo "$(rpm_nevra "$rpm") | SHA256:$(rpm_sha256 "$rpm") | BUILT"
    done
    echo "#"
    echo "# === Bundled Dependencies ==="
    cat "$MANIFEST_FILE" 2>/dev/null || echo "# (none)"
    echo "#"
    echo "# === Collections Stats ==="
    echo "# Collected: $collected"
    echo "# Missing:   $missing"
    echo "# TXSQL:     $txsql_count"
} > "$FULL_MANIFEST"

# ── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "=============================================================================="
echo "  RPM Collection Summary"
echo "=============================================================================="
echo "  TXSQL RPMs:      $txsql_count"
echo "  Bundled deps:    $collected / $total_needed"
echo "  Missing:         $missing"
echo "  Output:          $OUTPUT_DIR"
echo ""

if [[ $missing -gt 0 ]]; then
    log_error "============================================"
    log_error "  $missing RPM(s) COULD NOT BE COLLECTED"
    log_error "============================================"
    log_error "Missing RPMs must be obtained before the offline repo is complete."
    log_error "See: $COLLECT_LOG"
    exit 4
fi

log_info "All RPMs collected successfully."
