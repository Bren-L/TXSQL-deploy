#!/bin/bash
# =============================================================================
# create-local-repo.sh — Create a Local RPM Repository with repodata/
# =============================================================================
# Creates a platform-specific local RPM repository suitable for offline
# installation. Uses createrepo (CentOS 7/yum) or createrepo_c (RHEL 8+/dnf)
# depending on what's available on the BUILD host.
#
# The generated repo is compatible with all target yum/dnf versions.
#
# Usage:
#   sudo bash create-local-repo.sh \
#     --rpm-dir payloads/centos-7.9-x86_64/repository/ \
#     --platform centos-7.9-x86_64
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/common.sh"
enable_error_trap

# ── Parse arguments ─────────────────────────────────────────────────────────

RPM_DIR=""
PLATFORM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpm-dir)  RPM_DIR="$2"; shift 2 ;;
        --platform) PLATFORM="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash create-local-repo.sh --rpm-dir <path> --platform <id>"
            echo "Creates a local RPM repository with repodata/ for offline installation."
            exit 0
            ;;
        *) shift ;;
    esac
done

if [[ -z "$RPM_DIR" ]]; then log_error "--rpm-dir is required"; exit 1; fi
if [[ ! -d "$RPM_DIR" ]]; then log_error "RPM directory not found: $RPM_DIR"; exit 1; fi

PLATFORM="${PLATFORM:-unknown-platform}"

log_title "Local RPM Repository Creator"
log_info "Platform: $PLATFORM"
log_info "RPM dir:  $RPM_DIR"

# ── Validate RPMs exist ────────────────────────────────────────────────────

rpm_count=$(find "$RPM_DIR" -maxdepth 1 -name "*.rpm" ! -name "*.src.rpm" -type f | wc -l)

if [[ $rpm_count -eq 0 ]]; then
    log_error "No RPM files found in $RPM_DIR"
    exit 1
fi

log_info "RPM files found: $rpm_count"

# ── Remove any old repodata ─────────────────────────────────────────────────

if [[ -d "$RPM_DIR/repodata" ]]; then
    log_info "Removing old repodata..."
    rm -rf "$RPM_DIR/repodata"
fi

# ── Detect createrepo tool ──────────────────────────────────────────────────

CREATEREPO=""
CREATEREPO_ARGS="--database"

if command -v createrepo_c &>/dev/null; then
    CREATEREPO="createrepo_c"
    log_info "Using createrepo_c (C implementation)"
    # createrepo_c defaults to good compression
elif command -v createrepo &>/dev/null; then
    CREATEREPO="createrepo"
    log_info "Using createrepo (Python implementation)"
    # --database generates sqlite DBs for faster yum operations
else
    log_error "Neither createrepo nor createrepo_c found."
    log_error "Install: yum install createrepo  (CentOS 7)"
    log_error "     or: dnf install createrepo_c (RHEL 8+)"
    exit 1
fi

# ── Generate repodata ──────────────────────────────────────────────────────

log_step "Generating repository metadata..."

pushd "$RPM_DIR" > /dev/null

# Generate the repodata/ directory
# -d . : use current directory as base
# --database : generate sqlite databases for fast yum queries
# --unique-md-filenames : include hash in filenames (standard)
# --workers N : parallel (createrepo_c only)
if [[ "$CREATEREPO" == "createrepo_c" ]]; then
    $CREATEREPO --database --unique-md-filenames --workers 4 . 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done
else
    $CREATEREPO --database --unique-md-filenames . 2>&1 | while IFS= read -r line; do
        log_info "  $line"
    done
fi

popd > /dev/null

# ── Verify repodata ────────────────────────────────────────────────────────

log_step "Verifying repository metadata..."

if [[ ! -f "$RPM_DIR/repodata/repomd.xml" ]]; then
    log_error "repodata/repomd.xml was NOT created!"
    exit 1
fi

# Parse repomd.xml to verify all data types exist
log_info "Repository metadata types:"
grep -oP '<data type="\K[^"]+' "$RPM_DIR/repodata/repomd.xml" | while IFS= read -r dtype; do
    echo "  - $dtype"
done

# Get the primary data location and verify it exists
primary_location=$(grep -A5 '<data type="primary"' "$RPM_DIR/repodata/repomd.xml" | grep '<location' | sed 's/.*href="//;s/".*//')
if [[ -n "$primary_location" ]] && [[ -f "$RPM_DIR/$primary_location" ]]; then
    log_info "Primary metadata exists: $primary_location"
else
    log_error "Primary metadata NOT found!"
    exit 1
fi

# Count packages in metadata
pkg_in_meta=$(grep -c '<package ' "$RPM_DIR/$primary_location" 2>/dev/null || echo 0)
if [[ "$pkg_in_meta" -gt 0 ]]; then
    log_info "Packages in metadata: $pkg_in_meta"
else
    log_error "No packages found in primary metadata!"
    exit 1
fi

# ── Generate repo config file ──────────────────────────────────────────────

log_step "Generating .repo configuration..."

REPO_FILE="$RPM_DIR/txsql-offline.repo"

cat > "$REPO_FILE" << EOF
[txsql-offline]
name=TXSQL Offline Repository — ${PLATFORM}
baseurl=file://${RPM_DIR}
enabled=1
gpgcheck=0
priority=1
skip_if_unavailable=0
metadata_expire=-1
EOF

# For DNF platforms, add additional options
if command -v dnf &>/dev/null; then
    cat >> "$REPO_FILE" << EOF
module_hotfixes=1
max_parallel_downloads=4
EOF
fi

log_info "Repo config written to: $REPO_FILE"

# ── Generate SHA256SUMS for entire repo ────────────────────────────────────

log_step "Generating SHA256SUMS..."

generate_sha256sums "$RPM_DIR" "$RPM_DIR/SHA256SUMS"

# ── Generate repo info file ────────────────────────────────────────────────

log_step "Generating repository info..."

REPO_INFO="$RPM_DIR/REPO-INFO"
{
    echo "TXSQL Offline Repository"
    echo "========================"
    echo "Platform:    $PLATFORM"
    echo "Generated:   $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "Tool:        $CREATEREPO"
    echo "RPM count:   $rpm_count"
    echo "Pkg in meta: $pkg_in_meta"
    echo "repomd.xml:  $(sha256sum "$RPM_DIR/repodata/repomd.xml" | awk '{print $1}')"
    echo ""
    echo "Repository URL for installer:"
    echo "  file://${RPM_DIR}"
    echo ""
    echo "To use this repo on the target system:"
    echo "  1. Copy the entire directory to the target"
    echo "  2. Create /etc/yum.repos.d/txsql-offline.repo with:"
    echo "     [txsql-offline]"
    echo "     name=TXSQL Offline Repository"
    echo "     baseurl=file:///path/to/repository"
    echo "     enabled=1"
    echo "     gpgcheck=0"
    echo "  3. Disable all other repos"
    echo "  4. yum/dnf install txsql-server txsql-client"
} > "$REPO_INFO"

log_info "Repository info written to: $REPO_INFO"

# ── Result ──────────────────────────────────────────────────────────────────

REPO_SIZE=$(du -sh "$RPM_DIR" | awk '{print $1}')

echo ""
echo "=============================================================================="
echo "  Repository Created Successfully"
echo "=============================================================================="
echo ""
echo "  Platform:      $PLATFORM"
echo "  Location:      $RPM_DIR"
echo "  Size:          $REPO_SIZE"
echo "  RPMs:          $rpm_count"
echo "  Pkgs in meta:  $pkg_in_meta"
echo "  Metadata tool: $CREATEREPO"
echo ""
echo "Repository contents:"
ls -lh "$RPM_DIR"/
echo ""
echo "To test the repository:"
echo "  1. sudo cp $REPO_FILE /etc/yum.repos.d/"
echo "  2. sudo yum-config-manager --disable '*'  # disable online repos"
echo "  3. sudo yum-config-manager --enable txsql-offline"
echo "  4. sudo yum makecache"
echo "  5. sudo yum search txsql"
echo ""
