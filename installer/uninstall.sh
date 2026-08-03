#!/bin/bash
# =============================================================================
# TXSQL 8.0.30 Uninstaller
# =============================================================================
# Usage:
#   sudo bash uninstall.sh           # Keep data, logs, config
#   sudo bash uninstall.sh --purge   # Remove everything
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

echo ""
echo "TXSQL 8.0.30 Uninstaller"
echo "========================="
echo "Mode: $($PURGE && echo 'PURGE (remove all)' || echo 'SAFE (keep data/logs/config)')"
echo ""

# 1. Stop service
log_info "Stopping txsql service..."
systemctl stop txsql 2>/dev/null && log_info "Service stopped" || log_info "Not running"

# 2. Disable service
log_info "Disabling txsql service..."
systemctl disable txsql 2>/dev/null && log_info "Service disabled" || log_info "Not enabled"

# 3. Remove service file
rm -f /usr/lib/systemd/system/txsql.service /etc/systemd/system/txsql.service 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

# 4. Remove local repo config
rm -f /etc/yum.repos.d/txsql-offline.repo /etc/dnf/repos.d/txsql-offline.repo 2>/dev/null || true

# Restore backed-up repos
if ls /etc/yum.repos.d.backup/*.repo &>/dev/null 2>&1; then
    log_info "Restoring original yum repos..."
    mv /etc/yum.repos.d.backup/*.repo /etc/yum.repos.d/ 2>/dev/null || true
    rmdir /etc/yum.repos.d.backup 2>/dev/null || true
fi

# 5. Remove RPMs (CentOS) or binaries (openEuler)
if rpm -q txsql-server &>/dev/null 2>&1; then
    log_info "Removing TXSQL RPMs..."
    rpm -e txsql-server 2>/dev/null && log_info "  txsql-server removed" || true
fi
if rpm -q txsql-client &>/dev/null 2>&1; then
    rpm -e txsql-client 2>/dev/null && log_info "  txsql-client removed" || true
fi
if rpm -q txsql-common &>/dev/null 2>&1; then
    rpm -e txsql-common 2>/dev/null && log_info "  txsql-common removed" || true
fi

# Remove binary deployment (openEuler)
if [[ -d /usr/lib/txsql/8.0.30 ]] && ! rpm -q txsql-server &>/dev/null 2>&1; then
    log_info "Removing TXSQL binary installation..."
    rm -rf /usr/lib/txsql/8.0.30
    rm -f /usr/lib/txsql/current
    log_info "Binaries removed"
fi

# Clean empty /usr/lib/txsql if nothing left
if [[ -d /usr/lib/txsql ]] && [[ -z "$(ls -A /usr/lib/txsql 2>/dev/null)" ]]; then
    rmdir /usr/lib/txsql 2>/dev/null || true
fi

# 6. Remove run directory
rm -rf /run/txsql 2>/dev/null || true

# 7. Remove state file
rm -f /var/lib/txsql/.install_state 2>/dev/null || true

# 8. Purge mode: remove data, logs, config, credentials
if $PURGE; then
    log_warn "PURGE mode: removing data, logs, config, and credentials..."
    rm -rf /var/lib/txsql/data 2>/dev/null && log_info "  Data removed" || true
    rm -rf /var/log/txsql 2>/dev/null && log_info "  Logs removed" || true
    rm -rf /etc/txsql 2>/dev/null && log_info "  Config removed" || true
    rm -f /root/.txsql_credentials 2>/dev/null && log_info "  Credentials removed" || true

    # Clean empty parent dirs
    rmdir /var/lib/txsql 2>/dev/null || true
else
    log_info "Preserved: $TXSQL_DATADIR (data)"
    log_info "Preserved: /var/log/txsql (logs)"
    log_info "Preserved: /etc/txsql (config)"
    log_info "Preserved: /root/.txsql_credentials"
fi

# 9. Remove PATH config
rm -f /etc/profile.d/txsql.sh 2>/dev/null && log_info "PATH config removed" || true

# 10. User/group removal skipped — running as root
log_info "Running as root — no user/group to remove"

echo ""
echo "============================================"
echo "  TXSQL Uninstall Complete"
echo "============================================"
echo "Mode: $($PURGE && echo 'PURGE' || echo 'SAFE')"
echo ""
echo "Tip: Run 'hash -r' or start a new shell"
echo "     to clear cached PATH to mysql."
$PURGE || {
    echo ""
    echo "Data, logs, and config were preserved."
    echo "Re-install will detect existing data and not reinitialize."
    echo "To remove everything: sudo bash uninstall.sh --purge"
}
echo ""
exit 0
