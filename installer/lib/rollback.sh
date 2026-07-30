#!/bin/bash
# =============================================================================
# installer/lib/rollback.sh — Safe Rollback on Installation Failure
# =============================================================================
# Undoes partial installation state. Preserves data always.
# Called automatically by the error trap in common.sh.
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

rollback() {
    log_step "Rolling back partial installation..."

    # ── Stop service if running ─────────────────────────────────────────
    if systemctl is-active txsql &>/dev/null 2>&1; then
        log_info "Stopping txsql service..."
        systemctl stop txsql 2>/dev/null || true
    fi
    if systemctl is-enabled txsql &>/dev/null 2>&1; then
        log_info "Disabling txsql service..."
        systemctl disable txsql 2>/dev/null || true
    fi

    # ── Remove RPMs (preserves data dirs by default) ────────────────────
    if rpm -q txsql-server &>/dev/null 2>&1; then
        log_info "Removing txsql-server..."
        rpm -e txsql-server 2>/dev/null || true
    fi
    if rpm -q txsql-client &>/dev/null 2>&1; then
        log_info "Removing txsql-client..."
        rpm -e txsql-client 2>/dev/null || true
    fi
    if rpm -q txsql-common &>/dev/null 2>&1; then
        log_info "Removing txsql-common..."
        rpm -e txsql-common 2>/dev/null || true
    fi

    # ── Remove local repo config ────────────────────────────────────────
    rm -f /etc/yum.repos.d/txsql-offline.repo 2>/dev/null || true
    rm -f /etc/dnf/repos.d/txsql-offline.repo 2>/dev/null || true

    # ── Remove empty directories created by this install ────────────────
    for d in "$TXSQL_RUNDIR"; do
        if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
            rmdir "$d" 2>/dev/null || true
        fi
    done

    # ── Clear install state markers ─────────────────────────────────────
    rm -f "$INSTALL_STATE_FILE" 2>/dev/null || true

    log_info "Rollback complete. Data at $TXSQL_DATADIR preserved."
    log_info "Fix the issue and re-run the installer."
}

# Run rollback
rollback
