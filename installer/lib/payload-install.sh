#!/bin/bash
# =============================================================================
# installer/lib/payload-install.sh — Single-Platform Payload Installer
# =============================================================================
# This is the install.sh INSIDE each platform payload.
# Called by the top-level dispatch install.sh after platform detection.
# Executes: repo config → RPM install → dirs → config → init → service
# =============================================================================
set -euo pipefail

PAYLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PAYLOAD_DIR

# Source lib from parent bundle or from payload
if [[ -f "$PAYLOAD_DIR/../lib/common.sh" ]]; then
    source "$PAYLOAD_DIR/../lib/common.sh"
elif [[ -f "$(dirname "$PAYLOAD_DIR")/lib/common.sh" ]]; then
    source "$(dirname "$PAYLOAD_DIR")/lib/common.sh"
else
    echo "[FATAL] Cannot find common.sh" >&2; exit 1
fi
enable_install_trap

log_title "TXSQL Payload Installer — ${DETECTED_PLATFORM_ID:-unknown}"
log_info "Payload: $PAYLOAD_DIR"

# Phase: Local Repository
if skip_if_done "LOCAL_REPO_CONFIGURED"; then :; else
    source "${SCRIPT_DIR}/lib/local-repository.sh" 2>/dev/null || \
        source "$PAYLOAD_DIR/../lib/local-repository.sh"
    configure_local_repo "$PAYLOAD_DIR"
    mark_done "LOCAL_REPO_CONFIGURED"
fi

# Phase: Install Packages
if skip_if_done "PACKAGES_INSTALLED"; then :; else
    source "${SCRIPT_DIR}/lib/packages.sh" 2>/dev/null || \
        source "$PAYLOAD_DIR/../lib/packages.sh"
    install_txsql_packages
    mark_done "PACKAGES_INSTALLED"
fi

# Phase: ELF check
if skip_if_done "ELF_CHECKED"; then :; else
    log_step "Checking all ELF dependencies..."
    if [[ -x "$TXSQL_BASEDIR/bin/mysqld" ]]; then
        local not_found=$(ldd "$TXSQL_BASEDIR/bin/mysqld" 2>&1 | grep -c 'not found' || echo 0)
        if [[ "$not_found" -gt 0 ]]; then
            log_error "mysqld has $not_found unresolved libraries"
            ldd "$TXSQL_BASEDIR/bin/mysqld" 2>&1 | grep 'not found'
            exit 50
        fi
    fi
    for elf in $(find "$TXSQL_BASEDIR" -type f -exec file {} \; 2>/dev/null | grep ELF | cut -d: -f1 | head -100); do
        if ldd "$elf" 2>&1 | grep -q 'not found'; then
            log_error "Unresolved: $elf"
            ldd "$elf" 2>&1 | grep 'not found'
            exit 50
        fi
    done
    log_info "All ELF dependencies resolved"
    mark_done "ELF_CHECKED"
fi

# Phase: Directories & User
if skip_if_done "DIRECTORIES_CREATED"; then :; else
    source "${SCRIPT_DIR}/lib/directories.sh" 2>/dev/null || \
        source "$PAYLOAD_DIR/../lib/directories.sh"
    create_system_user
    create_directories
    mark_done "DIRECTORIES_CREATED"
fi

# Phase: Configuration
if skip_if_done "CONFIG_READY"; then :; else
    log_step "Generating configuration..."
    if [[ ! -f "$TXSQL_CONFIG" ]]; then
        cat > "$TXSQL_CONFIG" << EOF
[mysqld]
user=${TXSQL_USER}
datadir=${TXSQL_DATADIR}
socket=${TXSQL_SOCKET}
port=${TXSQL_PORT}
log-error=${TXSQL_LOGDIR}/error.log
pid-file=${TXSQL_RUNDIR}/mysqld.pid
basedir=${TXSQL_BASEDIR}
!includedir ${TXSQL_CONFDIR}
EOF
        chmod 0640 "$TXSQL_CONFIG"
        chown "root:${TXSQL_GROUP}" "$TXSQL_CONFIG"
        log_info "Created: $TXSQL_CONFIG"
    else
        log_info "Config exists: $TXSQL_CONFIG (preserved)"
    fi
    mark_done "CONFIG_READY"
fi

# Phase: Initialize (only if datadir is empty/new)
if skip_if_done "DATADIR_READY"; then :; else
    log_step "Checking data directory..."
    if [[ -f "$TXSQL_DATADIR/auto.cnf" ]] || [[ -f "$TXSQL_DATADIR/mysql/user.ibd" ]]; then
        log_info "Data directory already initialized — skipping init"
    else
        log_info "Initializing data directory..."
        rm -rf "${TXSQL_DATADIR:?}"/* 2>/dev/null || true
        mysqld --initialize-insecure --user="$TXSQL_USER" \
               --datadir="$TXSQL_DATADIR" --basedir="$TXSQL_BASEDIR" 2>&1 | tee -a "$INSTALL_LOG"
        # Generate temp password from log (mysql 8.0 prints it)
        local temp_pw=$(grep 'temporary password' "$TXSQL_LOGDIR/error.log" 2>/dev/null | tail -1 | awk '{print $NF}')
        if [[ -n "$temp_pw" ]]; then
            echo "TEMP_PW=$temp_pw" > /tmp/txsql-init-pw
            chmod 600 /tmp/txsql-init-pw
        fi
    fi
    mark_done "DATADIR_READY"
fi

# Phase: systemd Service
if skip_if_done "SERVICE_READY"; then :; else
    log_step "Setting up systemd service..."
    local svc_file="/usr/lib/systemd/system/txsql.service"
    if [[ ! -f "$svc_file" ]]; then
        cat > "$svc_file" << EOF
[Unit]
Description=TXSQL Server
After=network.target

[Service]
Type=forking
User=${TXSQL_USER}
Group=${TXSQL_GROUP}
PIDFile=${TXSQL_RUNDIR}/mysqld.pid
ExecStart=${TXSQL_BASEDIR}/bin/mysqld --daemonize
ExecStop=${TXSQL_BASEDIR}/bin/mysqladmin -u root -S ${TXSQL_SOCKET} shutdown
Restart=on-failure
RestartSec=5
RuntimeDirectory=txsql
RuntimeDirectoryMode=0750
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    fi
    systemctl daemon-reload
    systemctl enable txsql
    log_info "systemd service installed"

    # Start TXSQL with skip-networking for initial setup
    log_info "Starting TXSQL (skip-networking for initial setup)..."
    if ! systemctl start txsql; then
        log_error "Failed to start txsql"
        journalctl -u txsql -n 50 --no-pager 2>/dev/null || true
        exit 90
    fi
    mark_done "SERVICE_READY"
fi

# Phase: Credentials
if skip_if_done "CREDENTIALS_READY"; then :; else
    log_step "Setting up credentials..."
    if [[ ! -f "$TXSQL_CREDENTIALS" ]]; then
        local root_pw=$(openssl rand -base64 24 2>/dev/null || date +%s | sha256sum | base64 | head -c 24)
        mysql -u root -S "$TXSQL_SOCKET" --connect-expired-password \
              -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_pw';" 2>/dev/null || true
        echo "TXSQL_ROOT_PASSWORD=$root_pw" > "$TXSQL_CREDENTIALS"
        chmod 0600 "$TXSQL_CREDENTIALS"
        log_info "Credentials written to: $TXSQL_CREDENTIALS"
    else
        log_info "Credentials exist: $TXSQL_CREDENTIALS (preserved)"
    fi
    mark_done "CREDENTIALS_READY"
fi

# Phase: SQL verification
if skip_if_done "SQL_READY"; then :; else
    log_step "Running SQL verification..."
    local root_pw=$(grep TXSQL_ROOT_PASSWORD "$TXSQL_CREDENTIALS" 2>/dev/null | cut -d= -f2)
    mysql -u root -p"$root_pw" -S "$TXSQL_SOCKET" -e "SELECT VERSION(); SELECT @@port; SELECT @@datadir;" 2>&1 | tee -a "$INSTALL_LOG"
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        log_error "SQL verification FAILED"
        exit 100
    fi
    log_info "SQL verification PASSED"
    mark_done "SQL_READY"
fi

log_info "Payload installation complete."
exit 0
