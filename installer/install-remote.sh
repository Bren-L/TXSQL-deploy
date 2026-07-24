#!/bin/bash
# =============================================================================
# install-remote.sh — TXSQL 远程一键部署
# =============================================================================
# 两步完成 TXSQL 部署：
#   Step 1: 从 GitHub Release 下载离线包并解压
#   Step 2: 执行离线安装脚本
#
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash
#
# 支持平台: CentOS 7.9 x86_64
# GitHub: https://github.com/Bren-L/TXSQL-deploy
# =============================================================================

set -euo pipefail

# ── 配置 ────────────────────────────────────────────────────────────────────────

GITHUB_REPO="Bren-L/TXSQL-deploy"
RELEASE_TAG="v8.0.30-1.0.0"
TARBALL="txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz"
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${RELEASE_TAG}/${TARBALL}"

# ── 颜色 ────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "\n${CYAN}========================================${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}========================================${NC}\n"; }

# ── 前置检查 ────────────────────────────────────────────────────────────────────

if [ "$(id -u)" -ne 0 ]; then
    log_error "请以 root 运行。"
    echo "用法: curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash"
    exit 1
fi

# =============================================================================
# Step 1: 下载并解压（从 GitHub Release）
# =============================================================================

log_step "Step 1/2: 下载并解压离线安装包"

WORK_DIR="/tmp/txsql-install-$$"
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

log_info "下载地址: ${DOWNLOAD_URL}"
curl -fsSL -o "${TARBALL}" "${DOWNLOAD_URL}"
log_info "下载完成 ($(du -h "${TARBALL}" | cut -f1))"

log_info "解压中..."
tar xzf "${TARBALL}"

EXTRACT_DIR=$(ls -d txsql-offline-*/ 2>/dev/null | head -1)
if [ -z "${EXTRACT_DIR}" ]; then
    log_error "解压失败，未找到安装目录。"
    log_error "请前往 https://github.com/${GITHUB_REPO}/releases 手动下载。"
    rm -rf "${WORK_DIR}"
    exit 1
fi

cd "${EXTRACT_DIR}"
log_info "解压完成: $(pwd)"

# =============================================================================
# Step 2: 安装部署
# =============================================================================

log_step "Step 2/2: 安装部署 TXSQL"

bash install.sh
INSTALL_RC=$?

# ── 清理临时文件 ────────────────────────────────────────────────────────────────

rm -rf "${WORK_DIR}"

if [ "${INSTALL_RC}" -eq 0 ]; then
    log_info "================================================"
    log_info "  TXSQL 部署成功!"
    log_info "================================================"
    echo ""
    echo "  查看 root 密码:  sudo cat /root/.txsql_credentials"
    echo "  连接数据库:      mysql -u root -p -S /var/lib/txsql/mysql.sock"
    echo "  服务管理:        sudo systemctl status txsql"
    echo ""
    echo "  GitHub: https://github.com/${GITHUB_REPO}"
else
    log_error "安装失败 (exit code: ${INSTALL_RC})"
    log_error "帮助: https://github.com/${GITHUB_REPO}"
    exit "${INSTALL_RC}"
fi
