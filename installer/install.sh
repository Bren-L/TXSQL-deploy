#!/bin/bash
# =============================================================================
# install.sh — TXSQL Multi-Platform Dispatch Installer
# =============================================================================
# This is the TOP-LEVEL installer for the universal multi-platform bundle.
# It does NOT install TXSQL directly — that's the payload's job.
#
# This script:
#   1. Detects the platform (exact match only)
#   2. Finds the correct payload/<platform-id>/ directory
#   3. Delegates to payload/<platform-id>/install.sh
#
# For single-platform bundles, the payload/ directory contains one platform.
#
# Usage:
#   sudo ./install.sh </dev/null
#   sudo ./install.sh --port 3307 --data-dir /data/txsql
#
# NEVER: accesses internet, prompts for input, does fuzzy matching.
# =============================================================================

set -euo pipefail

# ── Determine script location ───────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "$SCRIPT_DIR")"
export SCRIPT_DIR BUNDLE_ROOT

# ── Load common library ─────────────────────────────────────────────────────

if [[ -f "$SCRIPT_DIR/lib/common.sh" ]]; then
    source "$SCRIPT_DIR/lib/common.sh"
else
    echo "[FATAL] Cannot find lib/common.sh — bundle is corrupted."
    exit 1
fi

enable_install_trap

# ── Banner ──────────────────────────────────────────────────────────────────

log_title "TXSQL Offline Installation"
log_info "Bundle root: $BUNDLE_ROOT"
log_info "Log file:    $INSTALL_LOG"

# Ensure log directory exists
mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true

# ── Phase 0: Root check ────────────────────────────────────────────────────

if skip_if_done "ROOT_CHECK"; then :; else
    require_root
    mark_done "ROOT_CHECK"
fi

# ── Phase 1: Argument parsing ──────────────────────────────────────────────

if skip_if_done "ARGS_PARSED"; then :; else
    log_step "Parsing arguments..."

    # Parse user-provided overrides (all optional)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)       TXSQL_PORT="$2"; shift 2 ;;
            --data-dir)   TXSQL_DATADIR="$2"; shift 2 ;;
            --log-dir)    TXSQL_LOGDIR="$2"; shift 2 ;;
            --socket)     TXSQL_SOCKET="$2"; shift 2 ;;
            --config)     TXSQL_CONFIG="$2"; shift 2 ;;
            --basedir)    TXSQL_BASEDIR="$2"; shift 2 ;;
            --user)       TXSQL_USER="$2"; shift 2 ;;
            --group)      TXSQL_GROUP="$2"; shift 2 ;;
            -h|--help)
                echo "TXSQL Offline Installer"
                echo ""
                echo "Usage: sudo ./install.sh [OPTIONS] </dev/null"
                echo ""
                echo "Options:"
                echo "  --port PORT         MySQL port (default: 3306)"
                echo "  --data-dir PATH     Data directory (default: /var/lib/txsql/data)"
                echo "  --log-dir PATH      Log directory (default: /var/log/txsql)"
                echo "  --socket PATH       Unix socket path (default: /run/txsql/mysql.sock)"
                echo "  --config PATH       Config file (default: /etc/txsql/my.cnf)"
                echo ""
                echo "No interactive prompts. Redirect stdin from /dev/null."
                exit 0
                ;;
            *) log_warn "Unknown option: $1"; shift ;;
        esac
    done

    # Recompute INSTALL_LOG with possibly-changed TXSQL_LOGDIR
    INSTALL_LOG="${TXSQL_LOGDIR}/install.log"

    log_info "TXSQL_PORT=$TXSQL_PORT"
    log_info "TXSQL_DATADIR=$TXSQL_DATADIR"
    log_info "TXSQL_LOGDIR=$TXSQL_LOGDIR"
    log_info "TXSQL_USER=$TXSQL_USER"
    log_info "TXSQL_GROUP=$TXSQL_GROUP"

    mark_done "ARGS_PARSED"
fi

# ── Phase 2: Platform detection (EXACT MATCH ONLY) ─────────────────────────

if skip_if_done "PLATFORM_DETECTED"; then :; else
    if [[ -f "$SCRIPT_DIR/lib/detect-platform.sh" ]]; then
        source "$SCRIPT_DIR/lib/detect-platform.sh"
        detect_platform
    else
        log_error "Platform detection module not found: $SCRIPT_DIR/lib/detect-platform.sh"
        exit 1
    fi
    mark_done "PLATFORM_DETECTED"
fi

# ── Phase 3: Select payload ─────────────────────────────────────────────────

if skip_if_done "PAYLOAD_SELECTED"; then
    SELECTED_PAYLOAD=$(get_state "SELECTED_PAYLOAD")
    log_info "Payload already selected: $SELECTED_PAYLOAD"
else
    log_step "Selecting platform payload..."

    # Look for payload matching detected platform
    PAYLOAD_DIR=""

    # Check payloads/ subdirectory (universal bundle layout)
    if [[ -d "$BUNDLE_ROOT/payloads/$DETECTED_PLATFORM_ID" ]]; then
        PAYLOAD_DIR="$BUNDLE_ROOT/payloads/$DETECTED_PLATFORM_ID"
    fi

    # Also check if this is a single-platform bundle (payload at root level)
    if [[ -z "$PAYLOAD_DIR" ]] && [[ -f "$BUNDLE_ROOT/PLATFORM" ]]; then
        local bundle_plat=$(cat "$BUNDLE_ROOT/PLATFORM" 2>/dev/null | grep 'PLATFORM_ID=' | cut -d= -f2)
        if [[ "$bundle_plat" == "$DETECTED_PLATFORM_ID" ]]; then
            PAYLOAD_DIR="$BUNDLE_ROOT"
        fi
    fi

    if [[ -z "$PAYLOAD_DIR" ]]; then
        log_error "============================================"
        log_error "  NO PAYLOAD FOUND FOR: $DETECTED_PLATFORM_ID"
        log_error "============================================"
        log_error ""
        log_error "Your system was detected as: $DETECTED_PLATFORM_ID"
        log_error ""
        log_error "Available payloads in this bundle:"
        if [[ -d "$BUNDLE_ROOT/payloads" ]]; then
            ls "$BUNDLE_ROOT/payloads/" 2>/dev/null | while read -r d; do
                log_error "  - $d"
            done
        else
            log_error "  (no payloads/ directory)"
        fi
        log_error ""
        log_error "Possible reasons:"
        log_error "  1. This platform has not been tested and marked SUPPORTED"
        log_error "  2. You need a different offline bundle"
        log_error "  3. You are running on an unsupported OS"
        log_error ""
        log_error "Installation ABORTED. No cross-platform fallback."
        exit 20
    fi

    log_info "Selected payload: $PAYLOAD_DIR"
    set_state "SELECTED_PAYLOAD" "$PAYLOAD_DIR"
    export SELECTED_PAYLOAD="$PAYLOAD_DIR"
fi

# ── Phase 4: SHA-256 verification ──────────────────────────────────────────

if skip_if_done "MEDIA_VERIFIED"; then :; else
    log_step "Verifying payload integrity..."

    if [[ -f "$SELECTED_PAYLOAD/SHA256SUMS" ]]; then
        log_info "Verifying SHA256SUMS for $SELECTED_PAYLOAD ..."
        if ! (cd "$SELECTED_PAYLOAD" && sha256sum -c SHA256SUMS 2>&1 | tee -a "$INSTALL_LOG"); then
            log_error "SHA-256 verification FAILED — media may be corrupted or tampered"
            log_error "Installation ABORTED."
            exit 21
        fi
        log_info "SHA-256 verification PASSED"
    else
        log_warn "No SHA256SUMS file found in payload — skipping integrity check"
    fi
    mark_done "MEDIA_VERIFIED"
fi

# ── Phase 5: Precheck ──────────────────────────────────────────────────────

if skip_if_done "PRECHECK_PASSED"; then :; else
    if [[ -f "$SCRIPT_DIR/lib/precheck.sh" ]]; then
        source "$SCRIPT_DIR/lib/precheck.sh"
        run_precheck
    else
        log_warn "precheck.sh not found — skipping"
    fi
    mark_done "PRECHECK_PASSED"
fi

# ── Phase 6: Delegate to payload installer ──────────────────────────────────

if skip_if_done "PAYLOAD_INSTALLED"; then :; else
    log_step "Delegating to payload installer..."

    local payload_installer="$SELECTED_PAYLOAD/install.sh"

    if [[ ! -f "$payload_installer" ]]; then
        # If payload has no install.sh, install directly from repository
        log_info "Payload has no install.sh — using direct RPM installation"

        if [[ -f "$SCRIPT_DIR/lib/local-repository.sh" ]]; then
            source "$SCRIPT_DIR/lib/local-repository.sh"
            configure_local_repo "$SELECTED_PAYLOAD"
        fi

        if [[ -f "$SCRIPT_DIR/lib/packages.sh" ]]; then
            source "$SCRIPT_DIR/lib/packages.sh"
            install_txsql_packages
        fi
    else
        log_info "Running: $payload_installer"
        # Pass through all our configuration
        TXSQL_PORT="$TXSQL_PORT" \
        TXSQL_DATADIR="$TXSQL_DATADIR" \
        TXSQL_LOGDIR="$TXSQL_LOGDIR" \
        TXSQL_SOCKET="$TXSQL_SOCKET" \
        TXSQL_CONFIG="$TXSQL_CONFIG" \
        TXSQL_USER="$TXSQL_USER" \
        TXSQL_GROUP="$TXSQL_GROUP" \
        DETECTED_PLATFORM_ID="$DETECTED_PLATFORM_ID" \
            bash "$payload_installer"
    fi
    mark_done "PAYLOAD_INSTALLED"
fi

# ── Phase 7: Post-install verification ─────────────────────────────────────

if skip_if_done "SQL_READY"; then :; else
    # Only run if the payload didn't already do this
    if [[ -f "$SCRIPT_DIR/lib/healthcheck.sh" ]]; then
        source "$SCRIPT_DIR/lib/healthcheck.sh"
        run_healthcheck
    fi
    if [[ -f "$SCRIPT_DIR/lib/sql-test.sh" ]]; then
        source "$SCRIPT_DIR/lib/sql-test.sh"
        run_sql_test
    fi
    mark_done "SQL_READY"
fi

# ── Done ────────────────────────────────────────────────────────────────────

echo ""
log_info "============================================"
log_info "  TXSQL Installation Complete"
log_info "============================================"
log_info ""
log_info "Platform:    $DETECTED_PLATFORM_ID"
log_info "Port:        $TXSQL_PORT"
log_info "Data dir:    $TXSQL_DATADIR"
log_info "Socket:      $TXSQL_SOCKET"
log_info "Config:      $TXSQL_CONFIG"
log_info "Credentials: $TXSQL_CREDENTIALS"
log_info "Log:         $INSTALL_LOG"
log_info ""
log_info "To connect:"
log_info "  sudo cat $TXSQL_CREDENTIALS"
log_info "  mysql -u root -p -S $TXSQL_SOCKET"
echo ""

exit 0
