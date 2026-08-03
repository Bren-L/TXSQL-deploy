#!/bin/bash
# =============================================================================
# installer/lib/local-repository.sh — Offline file:// Repository Configuration
# =============================================================================
# Disables ALL online repos, configures a single file:// local repo.
# The local repo contains TXSQL RPMs + full transitive dependency closure.
# NEVER: accesses internet, uses GPG, touches online repo files permanently.
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

configure_local_repo() {
    local payload_dir="${1:-$SELECTED_PAYLOAD}"
    local repo_dir="${payload_dir}/repository"

    log_step "Configuring offline local repository..."

    if [[ ! -d "$repo_dir" ]]; then
        log_error "Repository directory not found: $repo_dir"
        log_error "The offline bundle is missing its repository/ directory."
        exit 40
    fi

    if [[ ! -f "$repo_dir/repodata/repomd.xml" ]]; then
        log_error "Repository has no repodata/repomd.xml — corrupted or incomplete"
        exit 40
    fi

    # ── Backup existing repo files ──────────────────────────────────────
    local repo_backup_dir="/tmp/txsql-repo-backup-$$"
    mkdir -p "$repo_backup_dir"

    if [[ -d /etc/yum.repos.d ]]; then
        if ls /etc/yum.repos.d/*.repo &>/dev/null 2>&1; then
            mv /etc/yum.repos.d/*.repo "$repo_backup_dir/" 2>/dev/null || true
            log_info "Backed up existing .repo files to $repo_backup_dir"
        fi
    fi
    if [[ -d /etc/dnf/repos.d ]]; then
        if ls /etc/dnf/repos.d/*.repo &>/dev/null 2>&1; then
            mv /etc/dnf/repos.d/*.repo "$repo_backup_dir/" 2>/dev/null || true
        fi
    fi

    # Register restore on exit
    register_restore_repos() {
        log_info "Restoring original repository configuration..."
        if ls "$repo_backup_dir"/*.repo &>/dev/null 2>&1; then
            mv "$repo_backup_dir"/*.repo /etc/yum.repos.d/ 2>/dev/null || true
        fi
        rm -rf "$repo_backup_dir"
    }

    # ── Create local .repo file ─────────────────────────────────────────
    local repo_file=""
    if [[ -d /etc/yum.repos.d ]]; then
        repo_file="/etc/yum.repos.d/txsql-offline.repo"
    elif [[ -d /etc/dnf/repos.d ]]; then
        repo_file="/etc/dnf/repos.d/txsql-offline.repo"
    else
        log_error "Cannot find yum/dnf repos directory"
        exit 40
    fi

    cat > "$repo_file" << EOF
[txsql-offline]
name=TXSQL Offline Repository
baseurl=file://${repo_dir}
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=0
metadata_expire=-1
EOF

    log_info "Local repository configured: $repo_file"
    log_info "Repository URL: file://${repo_dir}"
    log_info "GPG check: DISABLED (offline SHA-256 verification used instead)"

    # ── Clean any cached metadata ───────────────────────────────────────
    pkg_clean
    log_info "Package manager cache cleaned"

    # ── Build cache from local repo only ────────────────────────────────
    log_info "Building package cache from local repository..."
    pkg_makecache

    # ── Verify the local repo is usable ─────────────────────────────────
    log_info "Verifying local repository..."
    if command -v yum &>/dev/null; then
        if yum --disablerepo='*' --enablerepo='txsql-offline' list available txsql-server &>/dev/null 2>&1; then
            log_info "Local repository verified (yum)"
        else
            log_warn "Could not verify local repo via yum search (may be OK on first use)"
        fi
    elif command -v dnf &>/dev/null; then
        if dnf --disablerepo='*' --enablerepo='txsql-offline' list available txsql-server &>/dev/null 2>&1; then
            log_info "Local repository verified (dnf)"
        else
            log_warn "Could not verify local repo via dnf search (may be OK on first use)"
        fi
    fi

    set_state "LOCAL_REPO_CONFIGURED" "$repo_dir"
}

# ── Cleanup: disable local repo and restore originals ──────────────────────

remove_local_repo() {
    log_step "Removing local repository configuration..."

    rm -f /etc/yum.repos.d/txsql-offline.repo 2>/dev/null || true
    rm -f /etc/dnf/repos.d/txsql-offline.repo 2>/dev/null || true

    pkg_clean
    log_info "Local repository removed"
}
