#!/bin/bash
# =============================================================================
# TXSQL 8.0.30 Offline One-Click Installer
# =============================================================================
# Self-contained installer supporting both RPM-based (CentOS) and
# binary-based (openEuler) deployment from offline tarball.
#
# Usage:
#   sudo bash install.sh </dev/null
#   sudo bash install.sh --port 3307 --data-dir /data/txsql
#
# NEVER: accesses internet, prompts for input, uses --nodeps/--force
# =============================================================================

set -euo pipefail

# ── Script location ───────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_DIR="$SCRIPT_DIR"
INSTALL_LOG="/var/log/txsql/install.log"
STATE_FILE="/var/lib/txsql/.install_state"

# ── Default paths ─────────────────────────────────────────────────────────

TXSQL_VERSION="8.0.30"
TXSQL_PORT=3306
TXSQL_USER="root"
TXSQL_GROUP="root"
TXSQL_BASEDIR="/usr/lib/txsql/current"
TXSQL_REALDIR="/usr/lib/txsql/${TXSQL_VERSION}"
TXSQL_DATADIR="/var/lib/txsql/data"
TXSQL_LOGDIR="/var/log/txsql"
TXSQL_RUNDIR="/run/txsql"
TXSQL_SOCKET="/run/txsql/mysql.sock"
TXSQL_CONFIG="/etc/txsql/my.cnf"
TXSQL_CONFDIR="/etc/txsql/conf.d"
TXSQL_CREDENTIALS="/root/.txsql_credentials"
CURRENT_PHASE=""

# ── Color output ──────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }
log_fatal() { echo -e "${RED}[FATAL]${NC} $*" >&2; }
log_title() { echo ""; echo -e "${BOLD}$*${NC}"; echo "$(printf '=%.0s' $(seq 1 ${#*}))"; }

# ── Log to file ────────────────────────────────────────────────────────────

log_file_init() {
    mkdir -p "$(dirname "$INSTALL_LOG")" 2>/dev/null || true
    echo "=== TXSQL Install $(date) ===" > "$INSTALL_LOG"
}
log_to_file() { echo "$(date '+%H:%M:%S') $*" >> "$INSTALL_LOG" 2>/dev/null || true; }

# ── State tracking (idempotency) ──────────────────────────────────────────

state_init() {
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    touch "$STATE_FILE" 2>/dev/null || true
}
state_done() { echo "$1=done" >> "$STATE_FILE"; }
state_is_done() { grep -q "^$1=done" "$STATE_FILE" 2>/dev/null; }

# ── Error trap ─────────────────────────────────────────────────────────────

on_error() {
    local rc=$?
    log_fatal "Installation failed at phase '${CURRENT_PHASE:-unknown}', exit code $rc"
    log_fatal "Check log: $INSTALL_LOG"
    exit "$rc"
}

# ── Phase runner ──────────────────────────────────────────────────────────

run_phase() {
    local name="$1"; shift
    if state_is_done "$name"; then
        log_info "Phase '$name' already completed — skipping"
        return 0
    fi
    CURRENT_PHASE="$name"
    log_step "[$name] Starting..."
    "$@"
    state_done "$name"
    log_info "[$name] Done."
}
CURRENT_PHASE=""

# ══════════════════════════════════════════════════════════════════════════
# Phase: Root check
# ══════════════════════════════════════════════════════════════════════════

run_root_check() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_fatal "This script must be run as root."
        echo "Usage: sudo bash install.sh </dev/null"
        exit 1
    fi
    log_info "Running as root: OK"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Arg parse
# ══════════════════════════════════════════════════════════════════════════

run_arg_parse() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)      TXSQL_PORT="$2"; shift 2 ;;
            --data-dir)  TXSQL_DATADIR="$2"; shift 2 ;;
            --log-dir)   TXSQL_LOGDIR="$2"; shift 2 ;;
            --socket)    TXSQL_SOCKET="$2"; shift 2 ;;
            --config)    TXSQL_CONFIG="$2"; shift 2 ;;
            --basedir)   TXSQL_BASEDIR="$2"; shift 2 ;;
            --user)      TXSQL_USER="$2"; shift 2 ;;
            --group)     TXSQL_GROUP="$2"; shift 2 ;;
            -h|--help)
                echo "TXSQL Offline Installer"
                echo "Usage: sudo bash install.sh [OPTIONS] </dev/null"
                echo ""
                echo "Options:"
                echo "  --port PORT       MySQL port (default: 3306)"
                echo "  --data-dir PATH   Data directory (default: /var/lib/txsql/data)"
                echo "  --socket PATH     Unix socket (default: /run/txsql/mysql.sock)"
                echo "  --config PATH     Config file (default: /etc/txsql/my.cnf)"
                exit 0
                ;;
            *) log_warn "Unknown option: $1"; shift ;;
        esac
    done
    # Recompute log path
    INSTALL_LOG="${TXSQL_LOGDIR}/install.log"
    log_file_init
    log_info "port=$TXSQL_PORT data=$TXSQL_DATADIR socket=$TXSQL_SOCKET"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Platform check
# ══════════════════════════════════════════════════════════════════════════

run_platform_check() {
    # Read expected platform from bundle metadata
    if [[ -f "$BUNDLE_DIR/PLATFORM" ]]; then
        local expected=$(grep 'PLATFORM_ID=' "$BUNDLE_DIR/PLATFORM" 2>/dev/null | cut -d= -f2)
        log_info "Bundle platform: $expected"
    fi

    # Detect current OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release 2>/dev/null || true
        log_info "Current OS: ${ID:-unknown} ${VERSION_ID:-unknown}"
    fi
    log_info "Architecture: $(uname -m)"
    log_info "Kernel: $(uname -r)"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Precheck
# ══════════════════════════════════════════════════════════════════════════

run_precheck() {
    local failed=0

    # Memory (need >= 900MB for mysqld)
    local mem_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
    if [[ -n "$mem_kb" ]] && [[ "$mem_kb" -lt 900000 ]]; then
        log_error "Insufficient memory: ${mem_kb}KB < 900MB"
        failed=$((failed + 1))
    else
        log_info "Memory: $(( mem_kb / 1024 )) MB"
    fi

    # Disk space (need >= 2GB)
    local data_parent=$(dirname "$TXSQL_DATADIR")
    local avail_kb=$(df "$data_parent" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -n "$avail_kb" ]] && [[ "$avail_kb" -lt 2000000 ]]; then
        log_error "Insufficient disk: $(( avail_kb / 1024 )) MB < 2000 MB"
        failed=$((failed + 1))
    else
        log_info "Disk free: $(( avail_kb / 1024 )) MB"
    fi

    # Port conflict
    if command -v ss &>/dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":${TXSQL_PORT} "; then
            log_error "Port ${TXSQL_PORT} is already in use:"
            ss -tlnp 2>/dev/null | grep ":${TXSQL_PORT} " || true
            failed=$((failed + 1))
        fi
    fi
    if [[ $failed -eq 0 ]]; then
        log_info "Port ${TXSQL_PORT}: free"
    fi

    # Existing MySQL/MariaDB process
    if pgrep -x mysqld &>/dev/null || pgrep -x mariadbd &>/dev/null; then
        log_error "Existing MySQL/MariaDB process detected"
        failed=$((failed + 1))
    fi

    # Existing data (not an error, just informational)
    if [[ -f "$TXSQL_DATADIR/auto.cnf" ]]; then
        log_info "Existing TXSQL data found — will NOT reinitialize"
    fi

    if [[ $failed -gt 0 ]]; then
        log_fatal "Precheck FAILED: $failed issue(s) found. Fix and re-run."
        exit 30
    fi
    log_info "Precheck PASSED"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Deploy — Detect and execute RPM or Binary install
# ══════════════════════════════════════════════════════════════════════════

DEPLOY_MODE=""  # "rpm" or "binary"

run_deploy() {
    if [[ -d "$BUNDLE_DIR/repository" ]] && [[ -f "$BUNDLE_DIR/repository/repodata/repomd.xml" ]]; then
        DEPLOY_MODE="rpm"
        log_info "Deployment mode: RPM (local yum/dnf repository)"
        deploy_rpm
    elif [[ -d "$BUNDLE_DIR/bin" ]] && [[ -f "$BUNDLE_DIR/bin/mysqld" ]]; then
        DEPLOY_MODE="binary"
        log_info "Deployment mode: Binary (direct copy)"
        deploy_binary
    else
        log_fatal "No recognizable deployment payload found."
        log_fatal "Expected: repository/repodata/repomd.xml (RPM) or bin/mysqld (binary)"
        exit 25
    fi
}

# ── RPM deployment ────────────────────────────────────────────────────────

deploy_rpm() {
    local repo_dir="$BUNDLE_DIR/repository"

    log_step "Configuring local RPM repository..."

    # Backup existing repos
    if ls /etc/yum.repos.d/*.repo &>/dev/null 2>&1; then
        mkdir -p /etc/yum.repos.d.backup
        mv /etc/yum.repos.d/*.repo /etc/yum.repos.d.backup/ 2>/dev/null || true
        log_info "Backed up existing repo files"
    fi

    # Create offline repo
    cat > /etc/yum.repos.d/txsql-offline.repo << YUMEOF
[txsql-offline]
name=TXSQL 8.0.30 Offline Repository
baseurl=file://${repo_dir}
enabled=1
gpgcheck=0
priority=1
YUMEOF

    # Determine package manager
    local pkg_mgr=""
    if command -v dnf &>/dev/null; then pkg_mgr="dnf"; else pkg_mgr="yum"; fi

    # Clean and rebuild cache
    $pkg_mgr clean all 2>/dev/null || true
    $pkg_mgr makecache 2>&1 | tail -1
    log_info "Local repository ready"

    # Install
    log_step "Installing TXSQL RPM packages..."
    if ! $pkg_mgr --disablerepo='*' --enablerepo='txsql-offline' install -y \
         txsql-server txsql-client txsql-common 2>&1 | tail -20; then
        log_fatal "RPM installation failed"
        exit 42
    fi

    # Verify
    if ! rpm -q txsql-server &>/dev/null; then
        log_fatal "txsql-server not installed"
        exit 43
    fi
    log_info "RPM installation complete"
}

# ── Binary deployment (openEuler etc.) ────────────────────────────────────

deploy_binary() {
    log_step "Installing TXSQL binaries..."

    # Create target directories
    mkdir -p "$TXSQL_REALDIR/bin" "$TXSQL_REALDIR/lib" "$TXSQL_REALDIR/share"

    # Copy binaries
    log_info "Copying binaries..."
    cp -a "$BUNDLE_DIR/bin/"* "$TXSQL_REALDIR/bin/" 2>/dev/null || true
    chmod 0755 "$TXSQL_REALDIR/bin/"*

    # Copy libraries
    if [[ -d "$BUNDLE_DIR/lib/libmysqlclient"* ]]; then
        cp -a "$BUNDLE_DIR/lib/"*.so* "$TXSQL_REALDIR/lib/" 2>/dev/null || true
    fi
    if [[ -d "$BUNDLE_DIR/lib/private" ]]; then
        mkdir -p "$TXSQL_REALDIR/lib/private"
        cp -a "$BUNDLE_DIR/lib/private/"* "$TXSQL_REALDIR/lib/private/" 2>/dev/null || true
    fi

    # Copy share files
    if [[ -d "$BUNDLE_DIR/share" ]]; then
        cp -a "$BUNDLE_DIR/share/"* "$TXSQL_REALDIR/share/" 2>/dev/null || true
    fi

    # Fix ownership (tar preserves source UID/GID which may not exist on target)
    log_info "Fixing file ownership..."
    chown -R root:root "$TXSQL_REALDIR" 2>/dev/null || true

    # Fix SELinux context
    if command -v restorecon &>/dev/null; then
        restorecon -R "$TXSQL_REALDIR" 2>/dev/null || true
        log_info "SELinux contexts restored"
    fi

    # Set RUNPATH on binaries so they find bundled libs
    log_info "Setting RUNPATH on binaries..."
    if command -v patchelf &>/dev/null; then
        for elf in "$TXSQL_REALDIR/bin/"*; do
            if file "$elf" 2>/dev/null | grep -q ELF; then
                patchelf --set-rpath "\$ORIGIN/../lib/private:\$ORIGIN/../lib" "$elf" 2>/dev/null || true
            fi
        done
    fi

    # Create symlink: /usr/lib/txsql/current → 8.0.30
    if [[ ! -L "$TXSQL_BASEDIR" ]]; then
        ln -sfn "$TXSQL_REALDIR" "$TXSQL_BASEDIR"
        log_info "Symlink: $TXSQL_BASEDIR → $TXSQL_REALDIR"
    fi

    log_info "Binary installation complete"
    log_info "mysqld: $($TXSQL_BASEDIR/bin/mysqld --version 2>/dev/null || echo 'check manually')"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: User & directories
# ══════════════════════════════════════════════════════════════════════════

run_user_and_dirs() {
    log_step "Creating directories..."

    # Create directories (owned by root)
    local dirs=(
        "$TXSQL_DATADIR|0750"
        "$TXSQL_LOGDIR|0750"
        "$TXSQL_CONFDIR|0750"
    )
    for entry in "${dirs[@]}"; do
        local dir=$(echo "$entry" | cut -d'|' -f1)
        local perm=$(echo "$entry" | cut -d'|' -f2)
        mkdir -p "$dir"
        chmod "$perm" "$dir"
    done

    # /run/txsql is handled by systemd RuntimeDirectory, but create as fallback
    mkdir -p "$TXSQL_RUNDIR"
    chmod 0750 "$TXSQL_RUNDIR" 2>/dev/null || true

    log_info "Directories ready"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Configuration
# ══════════════════════════════════════════════════════════════════════════

run_config() {
    log_step "Generating configuration..."

    # If config exists from RPM, back it up and overwrite with correct values
    if [[ -f "$TXSQL_CONFIG" ]]; then
        cp "$TXSQL_CONFIG" "${TXSQL_CONFIG}.rpm-orig" 2>/dev/null || true
        log_info "Backed up RPM config to ${TXSQL_CONFIG}.rpm-orig"
    fi

    mkdir -p "$TXSQL_CONFDIR"

    cat > "$TXSQL_CONFIG" << EOF
[client]
socket=${TXSQL_SOCKET}

[mysqld]
user=${TXSQL_USER}
basedir=${TXSQL_BASEDIR}
datadir=${TXSQL_DATADIR}
socket=${TXSQL_SOCKET}
port=${TXSQL_PORT}
pid-file=${TXSQL_RUNDIR}/mysqld.pid
log-error=${TXSQL_LOGDIR}/error.log
log_timestamps=SYSTEM
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
innodb_buffer_pool_size=128M
innodb_log_file_size=48M
innodb_flush_method=O_DIRECT
innodb_file_per_table=1
max_connections=200
bind-address=127.0.0.1
!includedir ${TXSQL_CONFDIR}
EOF

    chmod 0640 "$TXSQL_CONFIG"
    log_info "Created: $TXSQL_CONFIG"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Initialize DB
# ══════════════════════════════════════════════════════════════════════════

run_init_db() {
    log_step "Checking data directory..."

    if [[ -f "$TXSQL_DATADIR/auto.cnf" ]] || [[ -f "$TXSQL_DATADIR/mysql/user.ibd" ]]; then
        log_info "Data directory already initialized — skipping init"
        return 0
    fi

    log_info "Initializing data directory..."
    rm -rf "${TXSQL_DATADIR:?}"/* 2>/dev/null || true

    local init_log="/tmp/txsql-init-$$.log"
    if ! "$TXSQL_BASEDIR/bin/mysqld" --initialize-insecure \
         --user="$TXSQL_USER" --datadir="$TXSQL_DATADIR" \
         --basedir="$TXSQL_BASEDIR" > "$init_log" 2>&1; then
        log_fatal "Database initialization FAILED"
        cat "$init_log"
        rm -f "$init_log"
        exit 80
    fi

    # Extract temp password (MySQL 8.0 prints it to error log)
    local temp_pw=""
    if [[ -f "$TXSQL_LOGDIR/error.log" ]]; then
        temp_pw=$(grep 'temporary password' "$TXSQL_LOGDIR/error.log" 2>/dev/null | tail -1 | awk '{print $NF}' || true)
    fi
    if [[ -n "$temp_pw" ]]; then
        echo "$temp_pw" > /tmp/txsql-init-temp-pw
        chmod 600 /tmp/txsql-init-temp-pw
        log_info "Temporary password saved to /tmp/txsql-init-temp-pw"
    fi

    rm -f "$init_log"
    log_info "Database initialized"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Systemd service
# ══════════════════════════════════════════════════════════════════════════

run_service() {
    log_step "Setting up systemd service..."

    local svc_file="/usr/lib/systemd/system/txsql.service"

    # Generate service file based on deployment mode
    if [[ "$DEPLOY_MODE" == "binary" ]]; then
        # Binary mode: Type=simple, no --daemonize (avoid component loading crash)
        cat > "$svc_file" << EOF
[Unit]
Description=TXSQL Server ${TXSQL_VERSION}
After=network.target

[Service]
Type=simple
User=${TXSQL_USER}
Group=${TXSQL_GROUP}
ExecStart=${TXSQL_BASEDIR}/bin/mysqld --defaults-file=${TXSQL_CONFIG}
ExecStop=${TXSQL_BASEDIR}/bin/mysqladmin --defaults-file=${TXSQL_CONFIG} -u root -S ${TXSQL_SOCKET} shutdown
Restart=on-failure
RestartSec=5
RuntimeDirectory=txsql
RuntimeDirectoryMode=0750

[Install]
WantedBy=multi-user.target
EOF
        log_info "Generated txsql.service (binary mode, Type=simple)"
    elif [[ -f "$BUNDLE_DIR/systemd/txsql.service" ]]; then
        cp "$BUNDLE_DIR/systemd/txsql.service" "$svc_file"
        log_info "Installed bundled txsql.service"
    else
        # RPM mode: Type=forking with --daemonize
        cat > "$svc_file" << EOF
[Unit]
Description=TXSQL Server ${TXSQL_VERSION}
After=network.target

[Service]
Type=forking
User=${TXSQL_USER}
Group=${TXSQL_GROUP}
PIDFile=${TXSQL_RUNDIR}/mysqld.pid
ExecStart=${TXSQL_BASEDIR}/bin/mysqld --defaults-file=${TXSQL_CONFIG} --daemonize --pid-file=${TXSQL_RUNDIR}/mysqld.pid
ExecStop=${TXSQL_BASEDIR}/bin/mysqladmin --defaults-file=${TXSQL_CONFIG} -u root -S ${TXSQL_SOCKET} shutdown
Restart=on-failure
RestartSec=5
RuntimeDirectory=txsql
RuntimeDirectoryMode=0750
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        log_info "Generated txsql.service (RPM mode, Type=forking)"
    fi

    systemctl daemon-reload
    systemctl enable txsql 2>/dev/null || true

    log_step "Starting TXSQL..."
    if ! systemctl start txsql 2>&1; then
        # systemctl may return non-zero if service auto-restarts before stabilizing
        log_warn "systemctl start returned non-zero — checking if service is running..."
    fi
    sleep 2

    # Wait for socket
    local waited=0
    while [[ ! -S "$TXSQL_SOCKET" ]] && [[ $waited -lt 60 ]]; do
        sleep 1; waited=$((waited + 1))
    done
    if [[ ! -S "$TXSQL_SOCKET" ]]; then
        log_fatal "Socket did not appear after 60s: $TXSQL_SOCKET"
        journalctl -u txsql -n 30 --no-pager 2>/dev/null || true
        exit 91
    fi
    log_info "TXSQL started and listening"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: PATH setup — make mysql command available system-wide
# ══════════════════════════════════════════════════════════════════════════

run_setup_path() {
    log_step "Setting up system PATH..."

    # 1. Write /etc/profile.d/txsql.sh for new login shells
    cat > /etc/profile.d/txsql.sh << EOF
# TXSQL — system-wide PATH
export PATH="${TXSQL_BASEDIR}/bin:\$PATH"
EOF
    chmod 0644 /etc/profile.d/txsql.sh

    # 2. Create symlinks in /usr/local/bin — effective immediately
    #    (no need to source anything, /usr/local/bin is in the default PATH)
    log_info "Creating symlinks in /usr/local/bin/..."
    local count=0
    for bin in "$TXSQL_BASEDIR"/bin/*; do
        local name="${bin##*/}"
        # Skip internal / test binaries
        case "$name" in
            comp_err|ibd2sdi|innochecksum|lz4_decompress|zlib_decompress|\
            mysql_ssl_rsa_setup|mysql_tzinfo_to_sql|resolve_stack_dump|resolveip)
                continue ;;
        esac
        ln -sfn "$bin" "/usr/local/bin/$name"
        count=$((count + 1))
    done
    log_info "$count symlinks created — \`mysql\` available immediately"

    # 3. Apply to current shell (for install.sh's own verify step)
    source /etc/profile.d/txsql.sh
    export PATH="${TXSQL_BASEDIR}/bin:$PATH"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: Credentials
# ══════════════════════════════════════════════════════════════════════════

run_credentials() {
    log_step "Setting up credentials..."

    if [[ -f "$TXSQL_CREDENTIALS" ]]; then
        log_info "Credentials exist: $TXSQL_CREDENTIALS (preserved)"
        return 0
    fi

    # Generate random root password
    local root_pw=$(openssl rand -base64 24 2>/dev/null || \
                    date +%s | sha256sum | base64 | head -c 24 2>/dev/null || \
                    echo "Txsql-$(date +%s)-$(shuf -i 1000-9999 -n 1)")

    # Try with temp password first (if --initialize was used)
    local temp_pw=""
    if [[ -f /tmp/txsql-init-temp-pw ]]; then
        temp_pw=$(cat /tmp/txsql-init-temp-pw 2>/dev/null || true)
    fi

    # Set root password
    local MYSQL_BIN="${TXSQL_BASEDIR}/bin/mysql"

    if [[ -n "$temp_pw" ]]; then
        if "$MYSQL_BIN" -u root -p"$temp_pw" -S "$TXSQL_SOCKET" --connect-expired-password \
           -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_pw';" 2>/dev/null; then
            log_info "Root password set (via temp password)"
        else
            log_warn "Could not set password via temp password — trying without"
        fi
    fi

    # Try without password (--initialize-insecure mode)
    if ! "$MYSQL_BIN" -u root -p"$root_pw" -S "$TXSQL_SOCKET" -e "SELECT 1" &>/dev/null 2>&1; then
        "$MYSQL_BIN" -u root -S "$TXSQL_SOCKET" \
               -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_pw';" 2>/dev/null || true
        log_info "Root password set (was empty)"
    fi

    # Save credentials
    mkdir -p "$(dirname "$TXSQL_CREDENTIALS")" 2>/dev/null || true
    cat > "$TXSQL_CREDENTIALS" << EOF
# TXSQL Root Credentials — keep secure!
# Generated: $(date)
TXSQL_ROOT_PASSWORD=$root_pw
EOF
    chmod 0600 "$TXSQL_CREDENTIALS"
    rm -f /tmp/txsql-init-temp-pw

    log_info "Credentials saved: $TXSQL_CREDENTIALS"
}

# ══════════════════════════════════════════════════════════════════════════
# Phase: SQL verification
# ══════════════════════════════════════════════════════════════════════════

run_verify() {
    log_step "Running SQL verification..."

    echo ""
    MYSQL_BIN="${TXSQL_BASEDIR}/bin/mysql"
    "$MYSQL_BIN" -u root -S "$TXSQL_SOCKET" -e "
        SELECT VERSION() AS version;
        SELECT @@port AS port;
        SELECT @@datadir AS datadir;
        SELECT @@socket AS socket;
    " 2>/dev/null || {
        log_warn "SQL verification query failed — check manually"
        log_warn "Run: ${MYSQL_BIN} -u root -S ${TXSQL_SOCKET}"
        return 0
    }
    echo ""
    log_info "SQL verification PASSED"
}

# ══════════════════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════════════════

main() {
    trap on_error ERR
    log_file_init
    state_init

    log_title "TXSQL ${TXSQL_VERSION} Offline Installer"
    echo "Bundle: $BUNDLE_DIR"
    echo "Log:    $INSTALL_LOG"
    echo ""

    run_phase "ROOT_CHECK"       run_root_check
    run_phase "ARG_PARSE"        run_arg_parse "$@"
    run_phase "PLATFORM_CHECK"   run_platform_check
    run_phase "PRECHECK"         run_precheck
    run_phase "DEPLOY"           run_deploy
    run_phase "USER_DIRS"        run_user_and_dirs
    run_phase "CONFIG"           run_config
    run_phase "INIT_DB"          run_init_db
    run_phase "SERVICE"          run_service
    run_phase "SETUP_PATH"       run_setup_path
    run_phase "CREDENTIALS"      run_credentials
    run_phase "VERIFY"           run_verify

    echo ""
    echo "============================================"
    echo "  TXSQL Installation Complete!"
    echo "============================================"
    echo ""
    echo "  Version:  ${TXSQL_VERSION}"
    echo "  Port:     ${TXSQL_PORT}"
    echo "  Socket:   ${TXSQL_SOCKET}"
    echo "  Data:     ${TXSQL_DATADIR}"
    echo "  Config:   ${TXSQL_CONFIG}"
    echo ""
    echo "  Connect:  mysql -u root -S ${TXSQL_SOCKET}"
    echo "  Password: cat ${TXSQL_CREDENTIALS}"
    echo "  Status:   systemctl status txsql"
    echo ""
    exit 0
}

main "$@"
