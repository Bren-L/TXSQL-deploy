#!/bin/bash
# =============================================================================
# install-remote.sh — TXSQL Remote Installer
# =============================================================================
# Downloads the TXSQL offline bundle from GitHub Releases and runs the
# offline installer.  Designed for the "curl | bash" one-liner pattern.
#
# Usage (as root):
#   curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash
#
# Or manually:
#   sudo bash install-remote.sh
#
# Supports: CentOS 7.9 x86_64 (more platforms coming)
# =============================================================================

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────

GITHUB_REPO="Bren-L/TXSQL-deploy"
RELEASE_TAG="v8.0.30-1.0.0"
TARBALL="txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${TARBALL}"
WORK_DIR="/tmp/txsql-install-$$"

# ── Colors ─────────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root."
    echo "Usage: curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash"
    exit 1
fi

# ── Platform detection ─────────────────────────────────────────────────────────

log_step "Detecting platform..."

if [ ! -f /etc/centos-release ]; then
    log_error "This installer currently only supports CentOS 7.9 x86_64."
    log_error "Detected OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 || echo 'unknown')"
    echo ""
    echo "For other platforms, see: https://github.com/Bren-L/TXSQL-deploy"
    exit 1
fi

CENTOS_VERSION=$(rpm -q --qf '%{VERSION}' centos-release 2>/dev/null || echo "0")
ARCH=$(uname -m)

log_info "CentOS ${CENTOS_VERSION}, ${ARCH}"

if [ "${CENTOS_VERSION}" != "7" ]; then
    log_warn "This installer is tested on CentOS 7.9. Your version: ${CENTOS_VERSION}"
    echo "Proceeding anyway, but YMMV."
fi

if [ "${ARCH}" != "x86_64" ]; then
    log_error "This installer requires x86_64. Detected: ${ARCH}"
    exit 1
fi

# ── Download ───────────────────────────────────────────────────────────────────

log_step "Downloading TXSQL offline bundle..."
log_info "Source: ${DOWNLOAD_URL}"

mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

if ! curl -fsSL -o "${TARBALL}" "${DOWNLOAD_URL}"; then
    log_error "Download failed."
    log_error "Please check your network and try again, or download manually from:"
    log_error "  https://github.com/${GITHUB_REPO}/releases"
    rm -rf "${WORK_DIR}"
    exit 1
fi

log_info "Download complete ($(du -h "${TARBALL}" | cut -f1))."

# ── Extract ────────────────────────────────────────────────────────────────────

log_step "Extracting..."
tar xzf "${TARBALL}"
EXTRACT_DIR=$(ls -d txsql-offline-*/ 2>/dev/null | head -1)

if [ -z "${EXTRACT_DIR}" ]; then
    log_error "Failed to find extracted directory."
    rm -rf "${WORK_DIR}"
    exit 1
fi

cd "${EXTRACT_DIR}"

# ── Install ────────────────────────────────────────────────────────────────────

log_step "Running offline installer..."
log_info "================================================"

if [ -f install.sh ]; then
    bash install.sh
    INSTALL_RC=$?
else
    log_error "install.sh not found in the extracted bundle."
    log_error "The release package may be corrupted. Please open an issue at:"
    log_error "  https://github.com/Bren-L/TXSQL-deploy/issues"
    rm -rf "${WORK_DIR}"
    exit 1
fi

# ── Cleanup ────────────────────────────────────────────────────────────────────

rm -rf "${WORK_DIR}"

if [ "${INSTALL_RC}" -eq 0 ]; then
    log_info "================================================"
    log_info "TXSQL installation complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Get the temporary password:  sudo cat /root/.txsql_credentials"
    echo "  2. Connect to MySQL:             mysql -u root -p -S /var/lib/txsql/mysql.sock"
    echo "  3. Check service status:         sudo systemctl status txsql"
    echo ""
    log_info "Docs: https://github.com/Bren-L/TXSQL-deploy"
else
    log_error "Installation failed with exit code ${INSTALL_RC}."
    log_error "For help, see: https://github.com/Bren-L/TXSQL-deploy"
    exit "${INSTALL_RC}"
fi
