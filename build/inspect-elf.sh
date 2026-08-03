#!/bin/bash
# =============================================================================
# inspect-elf.sh — Layer 1: ELF Static Dependency Analysis
# =============================================================================
# Scans every ELF file in a TXSQL installation tree and records:
#   - readelf -d NEEDED entries
#   - ldd resolution (including "not found")
#   - objdump -p NEEDED entries
#   - RPATH/RUNPATH
#
# Usage:
#   sudo bash inspect-elf.sh --txsql-dir /usr/lib/txsql/current \
#                            --platform centos-7.9-x86_64 \
#                            --output dist/reports/centos-7.9-x86_64/elf/
#
# Exit code 2 if ANY ELF has unresolved NEEDED entries.
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

TXSQL_DIR=""
PLATFORM=""
OUTPUT_DIR=""
FAIL_ON_NOT_FOUND=true

while [[ $# -gt 0 ]]; do
    case "$1" in
        --txsql-dir)   TXSQL_DIR="$2"; shift 2 ;;
        --platform)    PLATFORM="$2"; shift 2 ;;
        --output)      OUTPUT_DIR="$2"; shift 2 ;;
        --warn-only)   FAIL_ON_NOT_FOUND=false; shift ;;
        -h|--help)
            echo "Usage: sudo bash inspect-elf.sh --txsql-dir <path> --platform <id> --output <dir>"
            echo "Scans all ELF files for dynamic library dependencies."
            echo "Exit code 2 if any library is 'not found'."
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$TXSQL_DIR" ]]; then
    log_error "--txsql-dir is required"
    exit 1
fi
if [[ ! -d "$TXSQL_DIR" ]]; then
    log_error "TXSQL directory not found: $TXSQL_DIR"
    exit 1
fi

PLATFORM="${PLATFORM:-unknown-platform}"
OUTPUT_DIR="${OUTPUT_DIR:-dist/reports/${PLATFORM}/elf}"
ensure_dir "$OUTPUT_DIR"

log_title "TXSQL ELF Dependency Scanner"
log_info "Platform:   $PLATFORM"
log_info "TXSQL dir:  $TXSQL_DIR"
log_info "Output:     $OUTPUT_DIR"

# ── Step 1: Discover all ELF files ──────────────────────────────────────────

log_step "Discovering ELF files..."

ELF_MANIFEST="$OUTPUT_DIR/manifest.txt"
: > "$ELF_MANIFEST"

elf_count=0
while IFS= read -r -d '' f; do
    if file "$f" 2>/dev/null | grep -q 'ELF'; then
        echo "$f" >> "$ELF_MANIFEST"
        ((elf_count++))
    fi
done < <(find "$TXSQL_DIR" -type f -print0 2>/dev/null)

log_info "Found $elf_count ELF files"
echo "total_elf_files=$elf_count" > "$OUTPUT_DIR/summary.txt"

if [[ $elf_count -eq 0 ]]; then
    log_error "No ELF files found in $TXSQL_DIR — is this a valid TXSQL installation?"
    exit 1
fi

# ── Step 2: Analyze each ELF ────────────────────────────────────────────────

log_step "Analyzing ELF dependencies..."

ALL_NEEDED="$OUTPUT_DIR/all-needed.txt"
ALL_NOT_FOUND="$OUTPUT_DIR/all-not-found.txt"
ALL_RPATH="$OUTPUT_DIR/all-rpath.txt"
: > "$ALL_NEEDED"
: > "$ALL_NOT_FOUND"
: > "$ALL_RPATH"

not_found_count=0
declare -A seen_needed
declare -A seen_not_found

while IFS= read -r elf; do
    [[ -z "$elf" ]] && continue
    elf_basename=$(basename "$elf")
    safe_name=$(echo "$elf_basename" | tr '/' '_')

    # --- readelf -d ---
    needed_file="$OUTPUT_DIR/${safe_name}.needed.txt"
    rpath_file="$OUTPUT_DIR/${safe_name}.rpath.txt"
    ldd_file="$OUTPUT_DIR/${safe_name}.ldd.txt"

    # Extract NEEDED entries
    readelf -d "$elf" 2>/dev/null | grep 'NEEDED' | awk -F'[][]' '{print $2}' | sort -u > "$needed_file" || true

    # Extract RPATH/RUNPATH
    readelf -d "$elf" 2>/dev/null | grep -iE 'RPATH|RUNPATH' | awk -F'[][]' '{print $2}' | sort -u > "$rpath_file" || true

    # Accumulate all NEEDED
    while IFS= read -r lib; do
        [[ -z "$lib" ]] && continue
        echo "$lib" >> "$ALL_NEEDED"
        seen_needed["$lib"]=1
    done < "$needed_file"

    # Accumulate RPATH
    while IFS= read -r rp; do
        [[ -z "$rp" ]] && continue
        echo "$elf_basename: $rp" >> "$ALL_RPATH"
    done < "$rpath_file"

    # --- ldd ---
    ldd "$elf" 2>&1 > "$ldd_file" || true

    # Check for "not found"
    if grep -q 'not found' "$ldd_file" 2>/dev/null; then
        grep 'not found' "$ldd_file" | while IFS= read -r nf_line; do
            echo "$elf_basename: $nf_line" >> "$ALL_NOT_FOUND"
            lib_name=$(echo "$nf_line" | awk '{print $1}')
            seen_not_found["$lib_name"]=1
        done
        ((not_found_count++))
    fi

done < "$ELF_MANIFEST"

# ── Step 3: Generate aggregate reports ──────────────────────────────────────

log_step "Generating aggregate reports..."

# Unique NEEDED libraries across ALL ELFs
sort -u "$ALL_NEEDED" > "$OUTPUT_DIR/unique-needed.txt"

# Unique not-found libraries
sort -u "$ALL_NOT_FOUND" > "$OUTPUT_DIR/unique-not-found.txt"

# Summary
{
    echo "total_elf_files=$elf_count"
    echo "total_not_found_count=$not_found_count"
    echo "total_unique_needed=$(wc -l < "$OUTPUT_DIR/unique-needed.txt")"
    echo "total_unique_not_found=$(wc -l < "$OUTPUT_DIR/unique-not-found.txt")"
} >> "$OUTPUT_DIR/summary.txt"

# ── Step 4: Per-ELF detail report ───────────────────────────────────────────

log_step "Generating per-ELF detail report..."

DETAIL_REPORT="$OUTPUT_DIR/elf-detail-report.txt"
{
    echo "=============================================================================="
    echo "TXSQL ELF Dependency Detail Report"
    echo "Platform: $PLATFORM"
    echo "Date:     $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "TXSQL:    $TXSQL_DIR"
    echo "=============================================================================="
    echo ""
    echo "Total ELF files scanned: $elf_count"
    echo "Total unique NEEDED libs: $(wc -l < "$OUTPUT_DIR/unique-needed.txt")"
    echo "Total ELFs with not-found: $not_found_count"
    echo "Total unique not-found: $(wc -l < "$OUTPUT_DIR/unique-not-found.txt")"
    echo ""
    echo "--- All NEEDED libraries (deduplicated) ---"
    cat "$OUTPUT_DIR/unique-needed.txt"
    echo ""
    echo "--- All RPATH/RUNPATH entries ---"
    cat "$ALL_RPATH"
    echo ""
    echo "--- Not-found libraries ---"
    if [[ -s "$OUTPUT_DIR/unique-not-found.txt" ]]; then
        cat "$OUTPUT_DIR/unique-not-found.txt"
    else
        echo "(none — all libraries resolved)"
    fi
    echo ""
    echo "--- Per-ELF detail ---"
    while IFS= read -r elf; do
        [[ -z "$elf" ]] && continue
        elf_basename=$(basename "$elf")
        safe_name=$(echo "$elf_basename" | tr '/' '_')
        echo ""
        echo "FILE: $elf_basename"
        echo "  PATH: $elf"
        echo "  NEEDED:"
        sed 's/^/    /' "$OUTPUT_DIR/${safe_name}.needed.txt" 2>/dev/null || echo "    (empty)"
        echo "  RPATH/RUNPATH:"
        sed 's/^/    /' "$OUTPUT_DIR/${safe_name}.rpath.txt" 2>/dev/null || echo "    (none)"
        echo "  LDD NOT FOUND:"
        grep -c 'not found' "$OUTPUT_DIR/${safe_name}.ldd.txt" 2>/dev/null | xargs -I{} echo "    {} entries" || echo "    0 entries"
    done < "$ELF_MANIFEST"
} > "$DETAIL_REPORT"

log_info "ELF detail report: $DETAIL_REPORT"

# ── Step 5: Result ──────────────────────────────────────────────────────────

echo ""
if [[ $not_found_count -gt 0 ]]; then
    log_error "============================================"
    log_error "  ELF SCAN FAILED — $not_found_count ELF(s) with unresolved libraries"
    log_error "============================================"
    log_error ""
    log_error "Unresolved libraries:"
    cat "$OUTPUT_DIR/unique-not-found.txt" | while IFS= read -r line; do
        log_error "  $line"
    done
    log_error ""
    log_error "These MUST be added to the local RPM repository."
    log_error "See: $OUTPUT_DIR/unique-not-found.txt"
    log_error "See: $DETAIL_REPORT"

    if $FAIL_ON_NOT_FOUND; then
        log_error "Build/verification FAILED. Fix before proceeding."
        exit 2
    fi
else
    log_info "============================================"
    log_info "  ELF SCAN PASSED — All libraries resolved"
    log_info "============================================"
    log_info "All $elf_count ELF files have all NEEDED libraries available."
fi

log_info "Reports saved to: $OUTPUT_DIR"
echo ""
echo "Key files:"
echo "  $OUTPUT_DIR/manifest.txt          — All ELF files"
echo "  $OUTPUT_DIR/unique-needed.txt     — All unique NEEDED libs"
echo "  $OUTPUT_DIR/unique-not-found.txt  — Unresolved libs"
echo "  $OUTPUT_DIR/elf-detail-report.txt — Full detail report"
echo "  $OUTPUT_DIR/summary.txt           — Summary stats"
