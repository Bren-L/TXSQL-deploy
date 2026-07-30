#!/bin/bash
# =============================================================================
# resolve-dependencies.sh — Layers 2-3: RPM Dependency Closure Resolution
# =============================================================================
# Takes TXSQL RPMs and resolves the COMPLETE recursive dependency closure
# against a fixed OS repository snapshot.
#
# Usage:
#   sudo bash resolve-dependencies.sh \
#     --rpms-dir /path/to/txsql-rpms/ \
#     --platform centos-7.9-x86_64 \
#     --repo-snapshot /path/to/os-repo-snapshot/ \
#     --output dist/reports/centos-7.9-x86_64/deps/
#
# Layers:
#   Layer 2: rpm -qpR on each TXSQL RPM (direct requires)
#   Layer 3: Recursive repoquery resolution (full closure)
#            Separates: system-provided vs bundled-provided vs unresolved
#
# Exit code 3 if any dependency cannot be resolved.
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

RPMS_DIR=""
PLATFORM=""
REPO_SNAPSHOT=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpms-dir)     RPMS_DIR="$2"; shift 2 ;;
        --platform)     PLATFORM="$2"; shift 2 ;;
        --repo-snapshot) REPO_SNAPSHOT="$2"; shift 2 ;;
        --output)       OUTPUT_DIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash resolve-dependencies.sh --rpms-dir <path> --platform <id> --repo-snapshot <path> --output <dir>"
            echo ""
            echo "Resolves the COMPLETE recursive RPM dependency closure for TXSQL."
            echo ""
            echo "  --rpms-dir       Directory containing txsql-{common,client,server}-*.rpm"
            echo "  --platform       Platform ID (e.g., centos-7.9-x86_64)"
            echo "  --repo-snapshot  Path to fixed OS repository snapshot (Packages/ + repodata/)"
            echo "  --output         Report output directory"
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$RPMS_DIR" ]]; then log_error "--rpms-dir is required"; exit 1; fi
if [[ ! -d "$RPMS_DIR" ]]; then log_error "RPMS dir not found: $RPMS_DIR"; exit 1; fi

PLATFORM="${PLATFORM:-unknown-platform}"
OUTPUT_DIR="${OUTPUT_DIR:-dist/reports/${PLATFORM}/deps}"
ensure_dir "$OUTPUT_DIR"

log_title "TXSQL RPM Dependency Resolver"
log_info "Platform:     $PLATFORM"
log_info "RPMs dir:     $RPMS_DIR"
log_info "Repo snapshot: ${REPO_SNAPSHOT:-none (using system repos)}"
log_info "Output:       $OUTPUT_DIR"

# ── Detect package manager ──────────────────────────────────────────────────

if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
    REPOQUERY="dnf repoquery"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
    REPOQUERY="repoquery"
elif command -v repoquery &>/dev/null; then
    PKG_MGR="yum"
    REPOQUERY="repoquery"
else
    log_error "Neither dnf nor yum/repoquery found. Cannot resolve dependencies."
    log_error "This script must run on the TARGET platform or a compatible build host."
    exit 1
fi

log_info "Package manager: $PKG_MGR"

# ── If repo snapshot provided, configure it ─────────────────────────────────

SNAPSHOT_REPO_FILE=""
if [[ -n "$REPO_SNAPSHOT" ]] && [[ -d "$REPO_SNAPSHOT" ]]; then
    log_step "Configuring repo snapshot at $REPO_SNAPSHOT ..."

    # Check if it has repodata
    if [[ ! -f "$REPO_SNAPSHOT/repodata/repomd.xml" ]]; then
        log_warn "No repodata found in snapshot. Generating with createrepo..."
        if command -v createrepo_c &>/dev/null; then
            createrepo_c --database "$REPO_SNAPSHOT"
        elif command -v createrepo &>/dev/null; then
            createrepo --database "$REPO_SNAPSHOT"
        else
            log_error "createrepo not found. Cannot index snapshot."
            exit 1
        fi
    fi

    SNAPSHOT_REPO_FILE="/tmp/txsql-dep-resolve-$$.repo"
    cat > "$SNAPSHOT_REPO_FILE" << EOF
[txsql-dep-snapshot]
name=TXSQL Dependency Resolution Snapshot
baseurl=file://${REPO_SNAPSHOT}
enabled=1
gpgcheck=0
priority=1
EOF

    if [[ "$PKG_MGR" == "dnf" ]]; then
        cp "$SNAPSHOT_REPO_FILE" /etc/yum.repos.d/ 2>/dev/null || \
            cp "$SNAPSHOT_REPO_FILE" /etc/dnf/repos.d/ 2>/dev/null || \
            log_warn "Could not install snapshot repo file (may need sudo)"

        # Disable all other repos
        dnf config-manager --save --setopt="*.enabled=0" 2>/dev/null || true
        dnf config-manager --set-enabled txsql-dep-snapshot 2>/dev/null || true
    else
        cp "$SNAPSHOT_REPO_FILE" /etc/yum.repos.d/ 2>/dev/null || \
            log_warn "Could not install snapshot repo file"

        # Disable all other repos
        yum-config-manager --disable '*' 2>/dev/null || true
        yum-config-manager --enable txsql-dep-snapshot 2>/dev/null || true
    fi

    # Register cleanup
    register_cleanup "rm -f /etc/yum.repos.d/txsql-dep-snapshot.repo /etc/dnf/repos.d/txsql-dep-snapshot.repo 2>/dev/null; $PKG_MGR clean all 2>/dev/null || true"
fi

# ── Find TXSQL RPMs ─────────────────────────────────────────────────────────

log_step "Finding TXSQL RPMs..."

TXSQL_COMMON=$(find "$RPMS_DIR" -maxdepth 1 -name "txsql-common-*.rpm" ! -name "*.src.rpm" 2>/dev/null | head -1)
TXSQL_CLIENT=$(find "$RPMS_DIR" -maxdepth 1 -name "txsql-client-*.rpm" ! -name "*.src.rpm" 2>/dev/null | head -1)
TXSQL_SERVER=$(find "$RPMS_DIR" -maxdepth 1 -name "txsql-server-*.rpm" ! -name "*.src.rpm" 2>/dev/null | head -1)

if [[ -z "$TXSQL_COMMON" ]] && [[ -z "$TXSQL_CLIENT" ]] && [[ -z "$TXSQL_SERVER" ]]; then
    log_error "No TXSQL RPMs found in $RPMS_DIR"
    log_error "Expected: txsql-common-*.rpm, txsql-client-*.rpm, txsql-server-*.rpm"
    exit 1
fi

for rpm in "$TXSQL_COMMON" "$TXSQL_CLIENT" "$TXSQL_SERVER"; do
    if [[ -n "$rpm" ]]; then
        log_info "Found: $(basename "$rpm") ($(rpm_nevra "$rpm"))"
    fi
done

# ── Layer 2: Direct RPM Requires ────────────────────────────────────────────

log_step "Layer 2: Extracting direct RPM Requires..."

DIRECT_REQUIRES="$OUTPUT_DIR/direct-requires.txt"
COMBINED_DIRECT="$OUTPUT_DIR/direct-requires-combined.txt"
: > "$DIRECT_REQUIRES"
: > "$COMBINED_DIRECT"

declare -A direct_deps

for rpm in "$TXSQL_COMMON" "$TXSQL_CLIENT" "$TXSQL_SERVER"; do
    [[ -z "$rpm" ]] && continue
    rpm_name=$(basename "$rpm")
    echo "=== $rpm_name ===" >> "$DIRECT_REQUIRES"

    # Extract Requires (filter out rpmlib, config, and self-references)
    rpm -qpR "$rpm" 2>/dev/null | \
        grep -vE '^rpmlib|^config\(|^/|^rtld|^txsql-' | \
        sort -u | while IFS= read -r req; do
            [[ -z "$req" ]] && continue
            echo "  $req" >> "$DIRECT_REQUIRES"
            echo "$req" >> "$COMBINED_DIRECT"
            direct_deps["$req"]=1
        done
done

total_direct=$(sort -u "$COMBINED_DIRECT" | wc -l)
log_info "Total unique direct Requires: $total_direct"

# ── Categorize Known System-Only Requirements ────────────────────────────────

log_step "Categorizing system vs bundled dependencies..."

SYSTEM_ALWAYS=(
    '/bin/sh' '/bin/bash' '/sbin/ldconfig'
    'ld-linux-x86-64.so.2' 'ld-linux-aarch64.so.1'
    'ld-linux.so.2' 'ld-linux.so.3'
    'libc.so.6' 'libc.so.6(GLIBC_2' 'libpthread.so.0' 'libdl.so.2'
    'libm.so.6' 'libresolv.so.2' 'librt.so.1'
    'libnss_files.so.2' 'libnss_dns.so.2'
    'libpam.so.0' 'libselinux.so.1' 'libcap.so.2'
    'libsystemd.so.0'
    'rtld(GNU_HASH)'
)

BASE_PROVIDED="$OUTPUT_DIR/base-provided.txt"
BUNDLED_NEEDED="$OUTPUT_DIR/bundled-needed.txt"
: > "$BASE_PROVIDED"
: > "$BUNDLED_NEEDED"

while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue
    is_system=false
    for sys_pat in "${SYSTEM_ALWAYS[@]}"; do
        if [[ "$dep" == "$sys_pat"* ]]; then
            echo "$dep  # system (pattern: $sys_pat)" >> "$BASE_PROVIDED"
            is_system=true
            break
        fi
    done
    if ! $is_system; then
        echo "$dep" >> "$BUNDLED_NEEDED"
    fi
done < <(sort -u "$COMBINED_DIRECT")

base_count=$(wc -l < "$BASE_PROVIDED")
bundle_count=$(wc -l < "$BUNDLED_NEEDED")
log_info "System-provided (from patterns): $base_count"
log_info "Need to resolve (recursive):     $bundle_count"

# ── Layer 3: Recursive Resolution ───────────────────────────────────────────

log_step "Layer 3: Recursive dependency resolution..."

RECURSIVE_REQUIRES="$OUTPUT_DIR/recursive-requires.txt"
UNRESOLVED="$OUTPUT_DIR/unresolved.txt"
RESOLVED_NEVRA="$OUTPUT_DIR/resolved-nevra.txt"
DEPENDENCY_TREE="$OUTPUT_DIR/dependency-tree.txt"
: > "$RECURSIVE_REQUIRES"
: > "$UNRESOLVED"
: > "$RESOLVED_NEVRA"
: > "$DEPENDENCY_TREE"

# We resolve for TXSQL package NAMES (not the individual RPM capabilities)
# Get the package names from the RPMs
txsql_pkg_names=""
for rpm in "$TXSQL_COMMON" "$TXSQL_CLIENT" "$TXSQL_SERVER"; do
    [[ -z "$rpm" ]] && continue
    pkg_name=$(rpm -qp --queryformat '%{NAME}' "$rpm" 2>/dev/null)
    txsql_pkg_names="$txsql_pkg_names $pkg_name"
done

if [[ -z "$txsql_pkg_names" ]]; then
    log_error "Could not determine TXSQL package names"
    exit 1
fi

log_info "Resolving closure for:$txsql_pkg_names"

# Method 1: Use repoquery --requires --resolve --recursive
# This is the most reliable method and works on both yum and dnf platforms

if command -v repoquery &>/dev/null; then
    log_info "Using repoquery for recursive resolution..."

    # repoquery --recursive gives the full closure
    # --resolve outputs NEVRA
    # We capture both the "whatrequires" and "recursive" views

    for pkg_name in $txsql_pkg_names; do
        log_info "  Resolving $pkg_name..."

        # Get recursive closure (all packages needed)
        if repoquery --requires --resolve --recursive "$pkg_name" \
            --queryformat '%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}' \
            > "$OUTPUT_DIR/recursive-${pkg_name}.txt" 2>/dev/null; then
            cat "$OUTPUT_DIR/recursive-${pkg_name}.txt" >> "$RECURSIVE_REQUIRES"
        else
            log_warn "    repoquery failed for $pkg_name, trying dnf..."
            # Fallback to dnf repoquery
            if command -v dnf &>/dev/null; then
                dnf repoquery --requires --resolve --recursive "$pkg_name" \
                    --queryformat '%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}' \
                    > "$OUTPUT_DIR/recursive-${pkg_name}.txt" 2>/dev/null || true
                cat "$OUTPUT_DIR/recursive-${pkg_name}.txt" >> "$RECURSIVE_REQUIRES"
            fi
        fi

        # Also get dependency tree for documentation
        if repoquery --tree-requires "$pkg_name" > "$OUTPUT_DIR/tree-${pkg_name}.txt" 2>/dev/null; then
            cat "$OUTPUT_DIR/tree-${pkg_name}.txt" >> "$DEPENDENCY_TREE"
        fi
    done
elif command -v dnf &>/dev/null; then
    log_info "Using dnf repoquery for recursive resolution..."

    for pkg_name in $txsql_pkg_names; do
        log_info "  Resolving $pkg_name..."
        dnf repoquery --requires --resolve --recursive "$pkg_name" \
            --queryformat '%{NAME}-%{EPOCH}:%{VERSION}-%{RELEASE}.%{ARCH}' \
            > "$OUTPUT_DIR/recursive-${pkg_name}.txt" 2>/dev/null || true
        cat "$OUTPUT_DIR/recursive-${pkg_name}.txt" >> "$RECURSIVE_REQUIRES"
    done
else
    log_error "Neither repoquery nor dnf available. Cannot perform recursive resolution."
    log_error "Install yum-utils (CentOS 7) or dnf-utils (RHEL 8+)."
    exit 1
fi

# Deduplicate
sort -u "$RECURSIVE_REQUIRES" -o "$RECURSIVE_REQUIRES"

recursive_count=$(wc -l < "$RECURSIVE_REQUIRES" | tr -d ' ')
log_info "Total unique packages in recursive closure: $recursive_count"

# ── Check for unresolved ────────────────────────────────────────────────────

log_step "Checking for unresolved dependencies..."

# Pull out package names from the direct requires that aren't in the recursive list
# (These are the "capability" requires like libc.so.6(GLIBC_2.14)(64bit) that need mapping)

unresolved_count=0
{
    echo "# Unresolved Dependencies"
    echo "# Platform: $PLATFORM"
    echo "# Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "#"
} > "$UNRESOLVED"

# For each bundled-needed entry, check if it's satisfied in the recursive closure
while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue

    # Skip versioned library deps (these are satisfied if the base lib is there)
    dep_name=$(echo "$dep" | sed 's/(.*//' | tr -d ' ')
    [[ -z "$dep_name" ]] && continue

    # Check if this dep is satisfied by anything in the closure
    if grep -qF "$dep_name" "$RECURSIVE_REQUIRES" 2>/dev/null; then
        continue  # resolved
    fi

    # For library deps (lib*.so*), check if they should be in base-provided
    if [[ "$dep_name" == lib*.so* ]]; then
        # Check if it would be provided by glibc or similar base package
        is_base=false
        for base_pkg in glibc libgcc libstdc++ openssl-libs libcurl ncurses-libs \
                        libaio cyrus-sasl-lib openldap numactl-libs zlib lz4 \
                        xz-libs libtirpc pam; do
            if grep -q "$base_pkg" "$RECURSIVE_REQUIRES" 2>/dev/null; then
                is_base=true
                break
            fi
        done
        if $is_base; then
            echo "$dep  # resolved via base package" >> "$BASE_PROVIDED"
            continue
        fi
    fi

    echo "$dep" >> "$UNRESOLVED"
    ((unresolved_count++)) || true
done < "$BUNDLED_NEEDED"

# ── Generate final report ───────────────────────────────────────────────────

log_step "Generating dependency report..."

RESOLVED_NEVRA_FINAL="$OUTPUT_DIR/resolved-nevra.txt"
sort -u "$RECURSIVE_REQUIRES" -o "$RESOLVED_NEVRA_FINAL" 2>/dev/null || true

# Separate into categories
SYSTEM_ONLY="$OUTPUT_DIR/system-only-packages.txt"
BUNDLED_RPMS="$OUTPUT_DIR/bundled-rpms.txt"
: > "$SYSTEM_ONLY"
: > "$BUNDLED_RPMS"

SYSTEM_PKGS="glibc systemd rpm yum dnf bash kernel pam nss-softokn nss-util selinux-policy"
SYSTEM_PKGS+=" coreutils util-linux shadow-utils setup filesystem basesystem"

while IFS= read -r nevra; do
    [[ -z "$nevra" ]] && continue
    pkg_base=$(echo "$nevra" | cut -d- -f1)
    is_sys=false
    for sys_pkg in $SYSTEM_PKGS; do
        if [[ "$pkg_base" == "$sys_pkg" ]]; then
            echo "$nevra  # SYSTEM — must not bundle" >> "$SYSTEM_ONLY"
            is_sys=true
            break
        fi
    done
    if ! $is_sys; then
        echo "$nevra" >> "$BUNDLED_RPMS"
    fi
done < "$RESOLVED_NEVRA_FINAL"

# ── Result ──────────────────────────────────────────────────────────────────

echo ""
echo "=============================================================================="
echo "  Dependency Resolution Summary"
echo "=============================================================================="
echo ""
echo "  Platform:             $PLATFORM"
echo "  TXSQL RPMs:           $(ls "$RPMS_DIR"/*.rpm 2>/dev/null | wc -l) found"
echo "  Direct Requires:       $total_direct"
echo "  System-provided:       $base_count"
echo "  Bundled needed:        $bundle_count"
echo "  Recursive closure:     $recursive_count packages"
echo "  System-only:           $(wc -l < "$SYSTEM_ONLY") packages"
echo "  Bundled RPMs:          $(wc -l < "$BUNDLED_RPMS") packages"
echo "  Unresolved:            $unresolved_count"

if [[ $unresolved_count -gt 0 ]]; then
    echo ""
    log_error "============================================"
    log_error "  UNRESOLVED DEPENDENCIES: $unresolved_count"
    log_error "============================================"
    cat "$UNRESOLVED" | while IFS= read -r line; do
        log_error "  $line"
    done
    log_error ""
    log_error "These dependencies could not be resolved in the repository snapshot."
    log_error "Build/verification FAILED. Fix before proceeding."
    exit 3
fi

log_info "All dependencies resolved."
log_info ""
log_info "Reports saved to: $OUTPUT_DIR"
echo ""
echo "Key files:"
echo "  $OUTPUT_DIR/direct-requires.txt      — Layer 2: direct RPM Requires"
echo "  $OUTPUT_DIR/recursive-requires.txt   — Layer 3: full recursive closure"
echo "  $OUTPUT_DIR/base-provided.txt        — System-provided (DO NOT bundle)"
echo "  $OUTPUT_DIR/bundled-rpms.txt         — RPMs to include in local repo"
echo "  $OUTPUT_DIR/unresolved.txt           — UNRESOLVED (must be empty)"
echo "  $OUTPUT_DIR/dependency-tree.txt      — Dependency tree"
echo "  $OUTPUT_DIR/resolved-nevra.txt       — All resolved NEVRAs"
echo "  $OUTPUT_DIR/system-only-packages.txt — System packages (never bundle)"
