#!/bin/bash
# =============================================================================
# installer/lib/packages.sh — RPM Installation with Full Dependency Resolution
# =============================================================================
# Install TXSQL RPMs from the local offline repository.
# NEVER uses: --nodeps, --force, --replacefiles, --skip-broken.
# All dependencies MUST be satisfied by the local repo content.
# =============================================================================

[[ -z "${SCRIPT_DIR:-}" ]] && SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh" 2>/dev/null || true

install_txsql_packages() {
    log_step "Installing TXSQL packages..."

    # ── Check repo is configured ─────────────────────────────────────────
    local repo_dir=$(get_state "LOCAL_REPO_CONFIGURED")
    if [[ -z "$repo_dir" ]] || [[ ! -d "$repo_dir" ]]; then
        log_error "Local repository not configured — run configure_local_repo first"
        exit 41
    fi

    # ── Verify RPMs exist ───────────────────────────────────────────────
    local txsql_count=$(find "$repo_dir" -maxdepth 1 -name "txsql-*.rpm" -type f 2>/dev/null | wc -l)
    if [[ $txsql_count -eq 0 ]]; then
        log_error "No TXSQL RPMs found in repository: $repo_dir"
        exit 41
    fi
    log_info "TXSQL RPMs available: $txsql_count"

    # ── Simulate/check transaction first ─────────────────────────────────
    log_info "Running dependency check (simulation)..."

    local install_cmd=""
    if [[ "$PKG_MGR" == "dnf" ]]; then
        # dnf check
        if ! dnf --disablerepo='*' --enablerepo='txsql-offline' \
                install --assumeno --setopt=tsflags=test \
                txsql-server txsql-client txsql-common 2>&1 | tee -a "$INSTALL_LOG"; then
            log_error "Dependency check FAILED — transaction cannot complete"
            log_error "This means the local repository is missing required dependencies."
            log_error "The bundle was not properly built. Check unresolved.txt."
            exit 42
        fi
        install_cmd="dnf --disablerepo='*' --enablerepo='txsql-offline' install -y txsql-server txsql-client txsql-common"
    else
        # yum check
        if ! yum --disablerepo='*' --enablerepo='txsql-offline' \
                install --assumeno txsql-server txsql-client txsql-common 2>&1 | tee -a "$INSTALL_LOG"; then
            log_error "Dependency check FAILED — transaction cannot complete"
            log_error "This means the local repository is missing required dependencies."
            exit 42
        fi
        install_cmd="yum --disablerepo='*' --enablerepo='txsql-offline' install -y txsql-server txsql-client txsql-common"
    fi

    log_info "Dependency check PASSED — all dependencies resolvable"

    # ── Install ─────────────────────────────────────────────────────────
    log_info "Installing TXSQL and all dependencies..."

    if ! eval "$install_cmd" 2>&1 | tee -a "$INSTALL_LOG"; then
        log_error "RPM installation FAILED"
        log_error "Check $INSTALL_LOG for yum/dnf output."
        exit 43
    fi

    # ── Verify installation ─────────────────────────────────────────────
    log_info "Verifying installation..."

    local verify_failed=0

    if ! rpm -q txsql-common &>/dev/null; then
        log_error "txsql-common not installed"
        ((verify_failed++))
    fi
    if ! rpm -q txsql-client &>/dev/null; then
        log_error "txsql-client not installed"
        ((verify_failed++))
    fi
    if ! rpm -q txsql-server &>/dev/null; then
        log_error "txsql-server not installed"
        ((verify_failed++))
    fi

    if [[ $verify_failed -gt 0 ]]; then
        log_error "Package verification FAILED — $verify_failed package(s) missing"
        exit 44
    fi

    # ── Check all ELFs ──────────────────────────────────────────────────
    log_info "Checking ELF dependencies..."

    if [[ -x "$TXSQL_BASEDIR/bin/mysqld" ]]; then
        if ldd "$TXSQL_BASEDIR/bin/mysqld" 2>&1 | grep -q 'not found'; then
            log_error "============================================"
            log_error "  ELF DEPENDENCY FAILURE"
            log_error "============================================"
            ldd "$TXSQL_BASEDIR/bin/mysqld" 2>&1 | grep 'not found' | while read -r line; do
                log_error "  $line"
            done
            log_error "The local repository is missing runtime libraries."
            log_error "Installation ABORTED."
            exit 50
        fi
        log_info "mysqld ELF check PASSED"
    else
        log_warn "mysqld binary not at expected path: $TXSQL_BASEDIR/bin/mysqld"
        log_warn "ELF check skipped — verify manually after install"
    fi

    set_state "PACKAGES_INSTALLED" "done"
    log_info "TXSQL packages installed successfully"
}
