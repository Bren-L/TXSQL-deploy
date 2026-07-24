#!/bin/bash
# =============================================================================
# scan-scripts.sh — Layer 4: External Command Dependency Scanner
# =============================================================================
# Scans all installer shell scripts for external commands and identifies
# which RPM provides each command. Ensures all required commands are
# available in a minimal OS installation or included in the local repo.
#
# Usage:
#   sudo bash scan-scripts.sh \
#     --scripts-dir installer/ \
#     --platform centos-7.9-x86_64 \
#     --output dist/reports/centos-7.9-x86_64/script-deps/
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

SCRIPTS_DIR=""
PLATFORM=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scripts-dir) SCRIPTS_DIR="$2"; shift 2 ;;
        --platform)    PLATFORM="$2"; shift 2 ;;
        --output)      OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash scan-scripts.sh --scripts-dir <path> --platform <id> --output <dir>"
            echo "Scans shell scripts for external command dependencies."
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$SCRIPTS_DIR" ]]; then
    SCRIPTS_DIR="$(dirname "$0")/../installer"
    log_info "Using default scripts directory: $SCRIPTS_DIR"
fi
if [[ ! -d "$SCRIPTS_DIR" ]]; then
    log_error "Scripts directory not found: $SCRIPTS_DIR"
    exit 1
fi

PLATFORM="${PLATFORM:-unknown-platform}"
OUTPUT_DIR="${OUTPUT_DIR:-dist/reports/${PLATFORM}/script-deps}"
ensure_dir "$OUTPUT_DIR"

log_title "Installer Script Command Dependency Scanner"
log_info "Platform:    $PLATFORM"
log_info "Scripts dir: $SCRIPTS_DIR"
log_info "Output:      $OUTPUT_DIR"

# ── Shell builtins (no dependency) ──────────────────────────────────────────

SHELL_BUILTINS=(
    echo cd pwd ls test '[' '[' ']' shift export unset source
    true false return exit break continue eval exec
    read wait times trap ulimit umask
    alias bg bind builtin caller command compgen complete
    declare dirs disown enable fc fg getopts hash help history
    jobs let local logout mapfile popd pushd printf readarray
    set shopt suspend type typeset
)

# ── Scan scripts for command invocations ────────────────────────────────────

log_step "Scanning scripts for external commands..."

ALL_COMMANDS="$OUTPUT_DIR/all-commands.txt"
UNIQUE_COMMANDS="$OUTPUT_DIR/unique-commands.txt"
: > "$ALL_COMMANDS"

# Find all .sh files
total_scripts=0
while IFS= read -r -d '' script; do
    ((total_scripts++))
    # Extract potential command invocations
    # Pattern: word at start of line or after pipe/&&/||/; that looks like a command
    # More aggressive: extract all words that could be commands
    grep -oP '(?:^|[|&;\s(])\K[a-zA-Z][a-zA-Z0-9_.-]{1,32}(?=\s|[|&;)]|$)' "$script" 2>/dev/null | \
        sort -u >> "$ALL_COMMANDS" || true
done < <(find "$SCRIPTS_DIR" -name "*.sh" -type f -print0)

log_info "Scripts scanned: $total_scripts"

# Deduplicate
sort -u "$ALL_COMMANDS" -o "$ALL_COMMANDS"
unique_count=$(wc -l < "$ALL_COMMANDS" | tr -d ' ')
log_info "Unique command candidates: $unique_count"

# ── Classify each command ───────────────────────────────────────────────────

log_step "Classifying commands..."

CLASSIFIED="$OUTPUT_DIR/classified-commands.txt"
BUILTIN_LIST="$OUTPUT_DIR/builtin-commands.txt"
EXTERNAL_LIST="$OUTPUT_DIR/external-commands.txt"
MISSING_LIST="$OUTPUT_DIR/missing-commands.txt"
RPM_OWNED="$OUTPUT_DIR/rpm-owned-commands.txt"
NOT_RPM="$OUTPUT_DIR/not-from-rpm.txt"
COMMAND_DEPS="$OUTPUT_DIR/installer-command-deps.txt"

: > "$CLASSIFIED"
: > "$BUILTIN_LIST"
: > "$EXTERNAL_LIST"
: > "$MISSING_LIST"
: > "$RPM_OWNED"
: > "$NOT_RPM"
: > "$COMMAND_DEPS"

while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue

    # Skip if it's a shell builtin
    is_builtin=false
    for builtin_cmd in "${SHELL_BUILTINS[@]}"; do
        if [[ "$cmd" == "$builtin_cmd" ]]; then
            echo "$cmd  # shell builtin" >> "$BUILTIN_LIST"
            echo "BUILTIN: $cmd" >> "$CLASSIFIED"
            is_builtin=true
            break
        fi
    done
    $is_builtin && continue

    # Check if it's a known function name or variable reference (not a command)
    # Skip single letters (likely variables), obvious variable names
    if [[ "$cmd" =~ ^[A-Z_]+$ ]] || [[ ${#cmd} -le 1 ]]; then
        echo "SKIP: $cmd (probably variable)" >> "$CLASSIFIED"
        continue
    fi

    # Check if the command exists on this system
    if cmd_path=$(command -v "$cmd" 2>/dev/null); then
        echo "EXTERNAL: $cmd -> $cmd_path" >> "$EXTERNAL_LIST"

        # Find which RPM owns it
        if rpm_owner=$(rpm -qf "$cmd_path" 2>/dev/null); then
            echo "$cmd -> $cmd_path -> RPM: $rpm_owner" >> "$RPM_OWNED"
            echo "RPM: $rpm_owner # for command: $cmd ($cmd_path)" >> "$COMMAND_DEPS"
        else
            echo "$cmd -> $cmd_path -> NOT_FROM_RPM" >> "$NOT_RPM"
        fi
    else
        echo "MISSING: $cmd" >> "$MISSING_LIST"
    fi

    echo "EXTERNAL: $cmd" >> "$CLASSIFIED"
done < "$ALL_COMMANDS"

# ── Generate report ─────────────────────────────────────────────────────────

log_step "Generating command dependency report..."

REPORT="$OUTPUT_DIR/command-dependency-report.txt"
{
    echo "=============================================================================="
    echo "Installer Script Command Dependency Report"
    echo "Platform:     $PLATFORM"
    echo "Date:         $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "Scripts dir:  $SCRIPTS_DIR"
    echo "=============================================================================="
    echo ""
    echo "Total scripts scanned:  $total_scripts"
    echo "Unique commands found:  $unique_count"
    echo "Shell builtins:         $(wc -l < "$BUILTIN_LIST")"
    echo "External commands:      $(wc -l < "$EXTERNAL_LIST")"
    echo "RPM-owned:              $(wc -l < "$RPM_OWNED")"
    echo "Not-from-RPM:           $(wc -l < "$NOT_RPM")"
    echo "Missing (not on host):  $(wc -l < "$MISSING_LIST")"
    echo ""
    echo "=============================================================================="
    echo "RPM-Owned Commands (each needed by installer)"
    echo "=============================================================================="
    cat "$COMMAND_DEPS" | sort -u
    echo ""
    echo "=============================================================================="
    echo "Not-from-RPM Commands (investigate each)"
    echo "=============================================================================="
    cat "$NOT_RPM"
    echo ""
    echo "=============================================================================="
    echo "Missing Commands (not found on this host)"
    echo "=============================================================================="
    if [[ -s "$MISSING_LIST" ]]; then
        cat "$MISSING_LIST"
    else
        echo "(none)"
    fi
    echo ""
    echo "=============================================================================="
    echo "RPM Package Summary for Installer Dependencies"
    echo "=============================================================================="
    cat "$COMMAND_DEPS" | awk -F'#' '{print $2}' | sort -u | while IFS= read -r rpm_dep; do
        echo "$rpm_dep"
    done
} > "$REPORT"

# ── Verify critical commands are available ──────────────────────────────────

log_step "Verifying critical installer commands..."

CRITICAL_COMMANDS=(
    awk sed grep find sha256sum
    systemctl useradd groupadd getent
    rpm yum dnf
    tar gzip
    readlink realpath
    install mkdir chmod chown
    cat head tail sort uniq wc
    id ps pgrep
    ss netstat
    tee flock
    basename dirname
)

critical_missing=0
for cmd in "${CRITICAL_COMMANDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        rpm_owner=$(rpm -qf "$(command -v "$cmd")" 2>/dev/null || echo "unknown")
        echo "CRITICAL-OK: $cmd  (RPM: $rpm_owner)"
    else
        # Check if it has an alternative
        if [[ "$cmd" == "dnf" ]] && command -v yum &>/dev/null; then
            echo "CRITICAL-ALT: $cmd -> yum (yum available)"
        elif [[ "$cmd" == "yum" ]] && command -v dnf &>/dev/null; then
            echo "CRITICAL-ALT: $cmd -> dnf (dnf available)"
        elif [[ "$cmd" == "ss" ]] && command -v netstat &>/dev/null; then
            echo "CRITICAL-ALT: $cmd -> netstat"
        else
            echo "CRITICAL-MISSING: $cmd"
            ((critical_missing++)) || true
        fi
    fi
done | tee "$OUTPUT_DIR/critical-commands.txt"

# ── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "=============================================================================="
echo "  Command Dependency Scan Summary"
echo "=============================================================================="
echo "  Scripts:          $total_scripts"
echo "  External commands: $(wc -l < "$EXTERNAL_LIST")"
echo "  RPM-owned:         $(wc -l < "$RPM_OWNED")"
echo "  Critical missing:  $critical_missing"
echo ""

if [[ $critical_missing -gt 0 ]]; then
    log_error "============================================"
    log_error "  $critical_missing CRITICAL COMMAND(S) MISSING"
    log_error "============================================"
    log_error "These commands are required by the installer but not available."
    log_error "See: $OUTPUT_DIR/critical-commands.txt"
else
    log_info "All critical installer commands available."
fi

log_info "Reports saved to: $OUTPUT_DIR"
echo ""
echo "Key files:"
echo "  $OUTPUT_DIR/command-dependency-report.txt  — Full report"
echo "  $OUTPUT_DIR/installer-command-deps.txt     — RPMs for commands"
echo "  $OUTPUT_DIR/critical-commands.txt          — Critical command status"
echo "  $OUTPUT_DIR/missing-commands.txt           — Missing (investigate)"
