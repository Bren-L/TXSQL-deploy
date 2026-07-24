#!/bin/bash
# =============================================================================
# installer/lib/directories.sh — Create TXSQL Directory Structure
# =============================================================================
[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

create_directories() {
    log_step "Creating TXSQL directories..."
    local dirs=(
        "$TXSQL_DATADIR|0750|${TXSQL_USER}:${TXSQL_GROUP}"
        "$TXSQL_LOGDIR|0750|${TXSQL_USER}:${TXSQL_GROUP}"
        "$TXSQL_RUNDIR|0750|${TXSQL_USER}:${TXSQL_GROUP}"
        "$TXSQL_CONFDIR|0750|root:${TXSQL_GROUP}"
    )
    for entry in "${dirs[@]}"; do
        local dir=$(echo "$entry" | cut -d'|' -f1)
        local perm=$(echo "$entry" | cut -d'|' -f2)
        local owner=$(echo "$entry" | cut -d'|' -f3)
        mkdir -p "$dir"
        chmod "$perm" "$dir"
        chown "$owner" "$dir" 2>/dev/null || true
        [[ -n "${RESTORECON:-}" ]] && restorecon -R "$dir" 2>/dev/null || true
        log_info "Created: $dir ($perm, $owner)"
    done
    # systemd RuntimeDirectory handles /run/txsql; mkdir is idempotent fallback
    set_state "DIRECTORIES_CREATED" "done"
}

create_system_user() {
    log_step "Ensuring txsql system user..."
    if ! getent group "$TXSQL_GROUP" &>/dev/null; then
        groupadd -r "$TXSQL_GROUP" 2>/dev/null || true
        log_info "Group created: $TXSQL_GROUP"
    fi
    if ! id "$TXSQL_USER" &>/dev/null 2>&1; then
        useradd -r -g "$TXSQL_GROUP" -s /sbin/nologin -d "$TXSQL_DATADIR" \
                -c "TXSQL Server" "$TXSQL_USER" 2>/dev/null || true
        log_info "User created: $TXSQL_USER"
    fi
}
