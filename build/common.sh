#!/bin/bash
# =============================================================================
# common.sh — Shared functions for all build scripts
# =============================================================================
# Source this file in every build/*.sh script:
#   source "$(dirname "$0")/common.sh"
# =============================================================================

set -euo pipefail

# ── Color output ────────────────────────────────────────────────────────────

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ── Logging functions ──────────────────────────────────────────────────────

log_info()  { echo -e "${GREEN}[INFO]${NC}  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $(date '+%H:%M:%S') $*"; }
log_title() { echo ""; echo -e "${BOLD}$*${NC}"; echo "$(printf '=%.0s' $(seq 1 ${#*}))"; }

# ── Error handling ──────────────────────────────────────────────────────────

on_error() {
    local exit_code=$?
    local line_no=$1
    log_error "Command failed at line ${line_no} with exit code ${exit_code}"
    exit "${exit_code}"
}

# Enable trap-based error reporting (call in main scripts, not in sourced libs)
enable_error_trap() {
    trap 'on_error ${LINENO}' ERR
}

# ── Path resolution ─────────────────────────────────────────────────────────

# Project root (parent of build/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly PROJECT_ROOT

# ── Argument parsing helpers ─────────────────────────────────────────────────

# Parse --platform, --source-dir, --output, --version from command line.
# Sets PLATFORM, SOURCE_DIR, OUTPUT_DIR, VERSION variables.
parse_common_args() {
    PLATFORM=""
    SOURCE_DIR=""
    OUTPUT_DIR="${PROJECT_ROOT}/dist"
    VERSION=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform)   PLATFORM="$2"; shift 2 ;;
            --source-dir) SOURCE_DIR="$2"; shift 2 ;;
            --source)     SOURCE_DIR="$2"; shift 2 ;;
            --output)     OUTPUT_DIR="$2"; shift 2 ;;
            --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
            --version)    VERSION="$2"; shift 2 ;;
            --build-dir)  BUILD_DIR="$2"; shift 2 ;;
            -h|--help)
                echo "Usage: $(basename "$0") [--platform <id>] [--source-dir <path>] [--output <path>] [--version <ver>]"
                exit 0
                ;;
            *)
                log_warn "Unknown argument: $1"
                shift
                ;;
        esac
    done

    # Defaults
    PLATFORM="${PLATFORM:-centos-7.9-x86_64}"
    BUILD_DIR="${BUILD_DIR:-${PROJECT_ROOT}/build/tmp/${PLATFORM}}"
    OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/dist}"
}

# ── Platform helpers ─────────────────────────────────────────────────────────

# Load platform.env for the given platform ID.
# Sets PLATFORM_ID, OS_ID, OS_VERSION_ID, etc.
load_platform_env() {
    local platform_id="${1:-$PLATFORM}"
    local env_file="${PROJECT_ROOT}/platforms/${platform_id}/platform.env"

    if [[ ! -f "$env_file" ]]; then
        log_error "Platform env not found: $env_file"
        log_error "Available platforms:"
        ls -d "${PROJECT_ROOT}"/platforms/*/ 2>/dev/null | while read -r d; do
            echo "  $(basename "$d")"
        done
        exit 1
    fi

    log_info "Loading platform: ${platform_id}"
    # shellcheck source=/dev/null
    source "$env_file"
}

# ── Validation helpers ──────────────────────────────────────────────────────

require_command() {
    local cmd="$1"
    local pkg_hint="${2:-${cmd}}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: ${cmd}"
        log_error "Install with: yum install -y ${pkg_hint}"
        exit 1
    fi
}

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

require_dir() {
    local dir="$1"
    local name="${2:-directory}"
    if [[ ! -d "$dir" ]]; then
        log_error "${name} not found: ${dir}"
        exit 1
    fi
}

require_file() {
    local file="$1"
    local name="${2:-file}"
    if [[ ! -f "$file" ]]; then
        log_error "${name} not found: ${file}"
        exit 1
    fi
}

# ── Output helpers ──────────────────────────────────────────────────────────

# Create output directory with parents
ensure_dir() {
    local dir="$1"
    mkdir -p "$dir"
}

# ── Checksum helpers ────────────────────────────────────────────────────────

# Generate SHA256SUMS for all files in a directory
generate_sha256sums() {
    local dir="$1"
    local output="${2:-${dir}/SHA256SUMS}"

    log_info "Generating SHA256SUMS for ${dir} ..."
    (cd "$dir" && find . -type f ! -name SHA256SUMS -print0 | \
        xargs -0 sha256sum | sort -k2) > "$output"
    log_info "SHA256SUMS written to: ${output}"
}

# Verify SHA256SUMS
verify_sha256sums() {
    local dir="$1"
    local sums_file="${2:-${dir}/SHA256SUMS}"

    log_info "Verifying SHA256SUMS ..."
    if ! (cd "$dir" && sha256sum -c "$sums_file"); then
        log_error "SHA-256 verification FAILED"
        return 1
    fi
    log_info "SHA-256 verification PASSED"
}

# ── RPM helpers ─────────────────────────────────────────────────────────────

# Get NEVRA from an RPM file
rpm_nevra() {
    local rpm_file="$1"
    rpm -qp --queryformat '%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}\n' "$rpm_file" 2>/dev/null
}

# Get SHA-256 of an RPM file
rpm_sha256() {
    local rpm_file="$1"
    sha256sum "$rpm_file" | awk '{print $1}'
}

# ── Cleanup helpers ─────────────────────────────────────────────────────────

# Register a cleanup function to run on script exit
cleanup_stack=()

on_exit() {
    for cmd in "${cleanup_stack[@]}"; do
        eval "$cmd" || true
    done
}

register_cleanup() {
    cleanup_stack+=("$1")
    trap on_exit EXIT
}
