#!/bin/bash
# =============================================================================
# installer/lib/common.sh — Shared functions for all installer modules
# =============================================================================
# Source this in every installer/lib/*.sh and install.sh.
# Provides: logging, state tracking, error handling, path resolution.
# =============================================================================

set -euo pipefail

# ── Color output ────────────────────────────────────────────────────────────

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ── Logging ─────────────────────────────────────────────────────────────────

INSTALL_LOG="${TXSQL_LOGDIR:-/var/log/txsql}/install.log"
LOG_PREFIX="$(date '+%Y-%m-%d %H:%M:%S')"

log_to_file() {
    echo "${LOG_PREFIX} $*" >> "$INSTALL_LOG" 2>/dev/null || true
}

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; log_to_file "[INFO]  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; log_to_file "[WARN]  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; log_to_file "[ERROR] $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; log_to_file "[STEP]  $*"; }
log_title() { echo ""; echo -e "${BOLD}$*${NC}"; echo "$(printf '=%.0s' $(seq 1 ${#*}))"; log_to_file "=== $* ==="; }

# ── Install state tracking ──────────────────────────────────────────────────

INSTALL_STATE_FILE="${TXSQL_INSTALL_STATE:-/var/lib/txsql/.install_state}"

init_state_file() {
    mkdir -p "$(dirname "$INSTALL_STATE_FILE")" 2>/dev/null || true
    if [[ ! -f "$INSTALL_STATE_FILE" ]]; then
        : > "$INSTALL_STATE_FILE"
        chmod 644 "$INSTALL_STATE_FILE" 2>/dev/null || true
    fi
}

set_state() {
    local key="$1"
    local value="${2:-1}"
    init_state_file
    if grep -q "^${key}=" "$INSTALL_STATE_FILE" 2>/dev/null; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$INSTALL_STATE_FILE" 2>/dev/null || true
    else
        echo "${key}=${value}" >> "$INSTALL_STATE_FILE"
    fi
    log_to_file "STATE: ${key}=${value}"
}

get_state() {
    local key="$1"
    local default="${2:-0}"
    if [[ -f "$INSTALL_STATE_FILE" ]]; then
        grep "^${key}=" "$INSTALL_STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "$default"
    else
        echo "$default"
    fi
}

is_state_set() {
    local key="$1"
    local val
    val=$(get_state "$key" "0")
    [[ "$val" != "0" ]]
}

# ── Error handling ─────────────────────────────────────────────────────────

on_install_error() {
    local exit_code=$?
    log_error "Installation failed at phase ${CURRENT_PHASE:-unknown}, exit code ${exit_code}"
    log_error "Log file: $INSTALL_LOG"
    # Attempt rollback
    if [[ -f "${SCRIPT_DIR:-.}/lib/rollback.sh" ]]; then
        log_info "Running rollback..."
        bash "${SCRIPT_DIR:-.}/lib/rollback.sh" || true
    fi
    exit "$exit_code"
}

enable_install_trap() {
    trap on_install_error ERR
}

# ── Default paths ───────────────────────────────────────────────────────────

: "${TXSQL_PORT:=3306}"
: "${TXSQL_USER:=root}"
: "${TXSQL_GROUP:=root}"
: "${TXSQL_BASEDIR:=/usr/lib/txsql/current}"
: "${TXSQL_DATADIR:=/var/lib/txsql/data}"
: "${TXSQL_LOGDIR:=/var/log/txsql}"
: "${TXSQL_RUNDIR:=/run/txsql}"
: "${TXSQL_SOCKET:=/run/txsql/mysql.sock}"
: "${TXSQL_CONFIG:=/etc/txsql/my.cnf}"
: "${TXSQL_CONFDIR:=/etc/txsql/conf.d}"
: "${TXSQL_CREDENTIALS:=/root/.txsql_credentials}"

# ── Script directory resolution ─────────────────────────────────────────────

# SCRIPT_DIR is the directory containing the running script
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")" && pwd)"
fi

# BUNDLE_ROOT is the root of the unpacked bundle
BUNDLE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd 2>/dev/null || echo "$SCRIPT_DIR")"

# ── Validation helpers ──────────────────────────────────────────────────────

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "This script must be run as root. Please use: sudo bash $0"
        exit 1
    fi
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
}

# ── Idempotency helper ──────────────────────────────────────────────────────

skip_if_done() {
    local phase="$1"
    if is_state_set "$phase"; then
        log_info "Phase '$phase' already completed — skipping"
        return 0
    fi
    CURRENT_PHASE="$phase"
    return 1
}

mark_done() {
    local phase="$1"
    set_state "$phase" "done"
    log_info "Phase '$phase' completed"
}

# ── Package manager detection ───────────────────────────────────────────────

detect_pkg_manager() {
    if command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    else
        echo "unknown"
    fi
}

PKG_MGR=$(detect_pkg_manager)

pkg_install() {
    if [[ "$PKG_MGR" == "dnf" ]]; then
        dnf install -y "$@"
    elif [[ "$PKG_MGR" == "yum" ]]; then
        yum install -y "$@"
    else
        log_error "No supported package manager found"
        exit 1
    fi
}

pkg_makecache() {
    if [[ "$PKG_MGR" == "dnf" ]]; then
        dnf makecache 2>/dev/null || true
    else
        yum makecache 2>/dev/null || true
    fi
}

pkg_clean() {
    if [[ "$PKG_MGR" == "dnf" ]]; then
        dnf clean all 2>/dev/null || true
    else
        yum clean all 2>/dev/null || true
    fi
}
