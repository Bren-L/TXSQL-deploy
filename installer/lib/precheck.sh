#!/bin/bash
# =============================================================================
# installer/lib/precheck.sh — Environment Pre-Installation Checks
# =============================================================================
# Hard-fails on any issue. Never prompts user to continue.
# Checks: root, OS match, arch, memory, disk, port, existing MySQL, datadir.
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

run_precheck() {
    log_step "Running pre-installation checks..."

    local failed=0

    # ── Root ────────────────────────────────────────────────────────────
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "PRECHECK FAILED: Not running as root"
        ((failed++))
    fi

    # ── Platform already detected ───────────────────────────────────────
    if [[ -z "${DETECTED_PLATFORM_ID:-}" ]]; then
        log_error "PRECHECK FAILED: Platform not detected (run detect-platform.sh first)"
        ((failed++))
    fi

    # ── Architecture ────────────────────────────────────────────────────
    local sys_arch=$(uname -m)
    local expected_arch=$(echo "${DETECTED_PLATFORM_ID:-}" | grep -oP '(x86_64|aarch64)')
    if [[ -n "$expected_arch" ]] && [[ "$sys_arch" != "$expected_arch" ]]; then
        log_error "PRECHECK FAILED: Architecture mismatch (system=$sys_arch, payload=$expected_arch)"
        ((failed++))
    fi

    # ── Memory (minimum 1 GB for mysqld) ────────────────────────────────
    local mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [[ -n "$mem_kb" ]] && [[ "$mem_kb" -lt 900000 ]]; then
        log_error "PRECHECK FAILED: Insufficient memory (${mem_kb}KB < 900MB)"
        log_error "TXSQL requires at least 1 GB RAM."
        ((failed++))
    fi

    # ── Disk space (minimum 2 GB free for data dir) ─────────────────────
    local data_parent=$(dirname "${TXSQL_DATADIR}")
    local avail_kb=$(df "$data_parent" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$avail_kb" ]] && [[ "$avail_kb" -lt 2000000 ]]; then
        log_error "PRECHECK FAILED: Insufficient disk space on $data_parent"
        log_error "Available: $(( avail_kb / 1024 )) MB, Required: 2000 MB"
        ((failed++))
    fi

    # ── Port conflict ───────────────────────────────────────────────────
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":${TXSQL_PORT} "; then
            log_error "PRECHECK FAILED: Port ${TXSQL_PORT} is already in use"
            ss -tlnp 2>/dev/null | grep ":${TXSQL_PORT} " | while read -r line; do
                log_error "  $line"
            done
            ((failed++))
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tlnp 2>/dev/null | grep -q ":${TXSQL_PORT} "; then
            log_error "PRECHECK FAILED: Port ${TXSQL_PORT} is already in use"
            ((failed++))
        fi
    fi

    # ── Check for existing MySQL/MariaDB ────────────────────────────────
    if pgrep -x mysqld &>/dev/null || pgrep -x mariadbd &>/dev/null; then
        log_error "PRECHECK FAILED: Existing MySQL/MariaDB process detected"
        pgrep -xa mysqld 2>/dev/null | while read -r line; do log_error "  $line"; done
        pgrep -xa mariadbd 2>/dev/null | while read -r line; do log_error "  $line"; done
        ((failed++))
    fi

    # Check for system-installed MySQL/MariaDB packages
    if rpm -q mysql-server &>/dev/null 2>&1 || rpm -q mariadb-server &>/dev/null 2>&1; then
        log_error "PRECHECK FAILED: MySQL/MariaDB server package is installed"
        log_error "Remove with: rpm -e mysql-server  (preserves data)"
        ((failed++))
    fi

    # ── Check for existing TXSQL installation ──────────────────────────
    if rpm -q txsql-server &>/dev/null 2>&1; then
        local installed_ver=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' txsql-server 2>/dev/null)
        log_warn "Existing TXSQL installation found: $installed_ver"
        log_info "This is a repeat installation — will preserve existing data."

        # Check if a HIGHER version is already installed
        # (simple version string comparison — refine for production)
        if [[ -n "${TXSQL_VERSION:-}" ]]; then
            if [[ "$installed_ver" > "$TXSQL_VERSION" ]]; then
                log_error "PRECHECK FAILED: Higher TXSQL version already installed ($installed_ver > $TXSQL_VERSION)"
                log_error "Downgrade is not supported. Uninstall first."
                ((failed++))
            fi
        fi
    fi

    # ── Check data directory ────────────────────────────────────────────
    if [[ -d "$TXSQL_DATADIR" ]]; then
        if [[ -f "$TXSQL_DATADIR/auto.cnf" ]] || [[ -f "$TXSQL_DATADIR/mysql/user.frm" ]] || [[ -f "$TXSQL_DATADIR/mysql/user.ibd" ]]; then
            log_info "Existing TXSQL data directory found — will NOT reinitialize"
        elif [[ "$(ls -A "$TXSQL_DATADIR" 2>/dev/null)" ]]; then
            # Directory exists with unknown content
            log_error "PRECHECK FAILED: Data directory exists with unknown content"
            log_error "  $TXSQL_DATADIR"
            log_error "  Directory is not empty and does not appear to be a TXSQL data directory."
            log_error "  Remove it or specify a different --data-dir."
            ((failed++))
        fi
    fi

    # ── Check config directory ──────────────────────────────────────────
    if [[ -f "$TXSQL_CONFIG" ]]; then
        log_info "Configuration file exists: $TXSQL_CONFIG (will preserve)"
    fi

    # ── SELinux ─────────────────────────────────────────────────────────
    if command -v getenforce &>/dev/null; then
        local selinux_mode=$(getenforce 2>/dev/null)
        log_info "SELinux mode: $selinux_mode"
        if [[ "$selinux_mode" == "Enforcing" ]]; then
            log_warn "SELinux is enforcing — contexts will be set via restorecon"
            # We do NOT call setenforce 0
        fi
    fi

    # ── glibc ───────────────────────────────────────────────────────────
    if command -v ldd &>/dev/null; then
        local glibc_ver=$(ldd --version 2>/dev/null | head -1)
        log_info "glibc: $glibc_ver"
    fi

    # ── systemd ─────────────────────────────────────────────────────────
    if ! command -v systemctl &>/dev/null; then
        log_error "PRECHECK FAILED: systemctl not found — systemd required"
        ((failed++))
    fi

    # ── RPM/YUM/DNF ─────────────────────────────────────────────────────
    if ! command -v rpm &>/dev/null; then
        log_error "PRECHECK FAILED: rpm not found"
        ((failed++))
    fi
    if ! command -v yum &>/dev/null && ! command -v dnf &>/dev/null; then
        log_error "PRECHECK FAILED: neither yum nor dnf found"
        ((failed++))
    fi

    # ── Time ────────────────────────────────────────────────────────────
    if command -v timedatectl &>/dev/null; then
        local tz=$(timedatectl 2>/dev/null | grep 'Time zone' | awk '{print $3}')
        log_info "Timezone: $tz"
    fi

    # ── Result ──────────────────────────────────────────────────────────
    if [[ $failed -gt 0 ]]; then
        log_error ""
        log_error "============================================"
        log_error "  PRECHECK FAILED: $failed issue(s) found"
        log_error "============================================"
        log_error "Fix the issues above and re-run the installer."
        log_error "Installation ABORTED."
        exit 30
    fi

    log_info "Precheck PASSED — all checks OK"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_precheck
fi
