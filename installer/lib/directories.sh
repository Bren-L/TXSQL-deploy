#!/bin/bash
# =============================================================================
# installer/lib/directories.sh — Create TXSQL Directory Structure
# =============================================================================
[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

create_directories() {
    log_step "Creating TXSQL directories..."
    local dirs=(
        "$TXSQL_DATADIR|0750"
        "$TXSQL_LOGDIR|0750"
        "$TXSQL_RUNDIR|0750"
        "$TXSQL_CONFDIR|0750"
    )
    for entry in "${dirs[@]}"; do
        local dir=$(echo "$entry" | cut -d'|' -f1)
        local perm=$(echo "$entry" | cut -d'|' -f2)
        mkdir -p "$dir"
        chmod "$perm" "$dir"
        [[ -n "${RESTORECON:-}" ]] && restorecon -R "$dir" 2>/dev/null || true
        log_info "Created: $dir ($perm)"
    done
    # systemd RuntimeDirectory handles /run/txsql; mkdir is idempotent fallback
    set_state "DIRECTORIES_CREATED" "done"
}

# create_system_user() removed — running as root, no dedicated user needed
