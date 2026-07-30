#!/bin/bash
# =============================================================================
# collect-fingerprints.sh — TXSQL Platform Fingerprint Collector
# =============================================================================
# Run as root on each target operating system.
# Safe: read-only operations only.
#
# Usage:
#   sudo bash collect-fingerprints.sh [--output /path/to/output]
# =============================================================================

set -euo pipefail

OUTDIR="${OUTDIR:-/tmp/txsql-fingerprints-$(date +%Y%m%d-%H%M%S)}"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output|-o) OUTDIR="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: sudo bash collect-fingerprints.sh [--output /path/to/output]"
            echo "Collects OS fingerprints for TXSQL platform identification."
            echo "Safe: read-only, no system modification."
            exit 0
            ;;
        *) shift ;;
    esac
done

mkdir -p "$OUTDIR"
echo "Collecting TXSQL platform fingerprints..."
echo "Output directory: $OUTDIR"
echo ""

MISSING_FILE="$OUTDIR/missing.txt"
: > "$MISSING_FILE"

note_missing() {
    echo "NOT_FOUND: $*" >> "$MISSING_FILE"
}

section() {
    echo ""
    echo "=== $1 ==="
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. OS Identification
# ─────────────────────────────────────────────────────────────────────────────
section "OS Release Files"

for f in /etc/os-release /etc/redhat-release /etc/centos-release \
         /etc/system-release /etc/kylin-release /etc/tlinux-release \
         /etc/openEuler-release /etc/euleros-release; do
    if [ -f "$f" ]; then
        cp "$f" "$OUTDIR/$(basename "$f")"
        echo "  Collected: $f"
    else
        note_missing "$f"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 2. Kernel and Architecture
# ─────────────────────────────────────────────────────────────────────────────
section "Kernel and Architecture"

uname -a        > "$OUTDIR/kernel-uname-a.txt"   && echo "  uname -a"
uname -m        > "$OUTDIR/kernel-uname-m.txt"   && echo "  uname -m"
uname -r        > "$OUTDIR/kernel-uname-r.txt"   && echo "  uname -r"

if [ -f /proc/cpuinfo ]; then
    cp /proc/cpuinfo "$OUTDIR/cpuinfo.txt"
    echo "  /proc/cpuinfo"
else
    note_missing "/proc/cpuinfo"
fi

if [ -f /proc/meminfo ]; then
    cp /proc/meminfo "$OUTDIR/meminfo.txt"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. Package Manager
# ─────────────────────────────────────────────────────────────────────────────
section "Package Manager"

rpm --version    > "$OUTDIR/rpm-version.txt"   2>/dev/null || note_missing "rpm"
echo "  rpm version"

yum --version    > "$OUTDIR/yum-version.txt"   2>/dev/null || note_missing "yum"
dnf --version    > "$OUTDIR/dnf-version.txt"   2>/dev/null || note_missing "dnf"

rpm -qf /etc/os-release > "$OUTDIR/rpm-qf-os-release.txt" 2>/dev/null || \
    echo "CANNOT_DETERMINE" > "$OUTDIR/rpm-qf-os-release.txt"
echo "  release package owner"

# Full RPM list
echo "  Collecting full RPM list (this may take a moment)..."
rpm -qa 2>/dev/null | sort > "$OUTDIR/rpm-qa.txt" || note_missing "rpm -qa"

# ─────────────────────────────────────────────────────────────────────────────
# 4. System Components
# ─────────────────────────────────────────────────────────────────────────────
section "System Components"

systemctl --version      > "$OUTDIR/systemctl-version.txt" 2>/dev/null || note_missing "systemctl"
echo "  systemctl"

getconf GNU_LIBC_VERSION > "$OUTDIR/glibc-getconf.txt" 2>/dev/null || note_missing "getconf"
ldd --version             > "$OUTDIR/ldd-version.txt"   2>/dev/null || note_missing "ldd"
echo "  glibc / ldd"

openssl version           > "$OUTDIR/openssl-version.txt" 2>/dev/null || note_missing "openssl"
echo "  openssl"

getenforce                > "$OUTDIR/selinux-getenforce.txt" 2>/dev/null || note_missing "getenforce"
echo "  SELinux"

# ─────────────────────────────────────────────────────────────────────────────
# 5. Filesystem and Locale
# ─────────────────────────────────────────────────────────────────────────────
section "Filesystem and Locale"

mount         > "$OUTDIR/mount.txt" 2>/dev/null
df -T         > "$OUTDIR/df-T.txt"  2>/dev/null
locale        > "$OUTDIR/locale.txt" 2>/dev/null || note_missing "locale"
echo "  mount, df -T, locale"

# ─────────────────────────────────────────────────────────────────────────────
# 6. Core Library Paths
# ─────────────────────────────────────────────────────────────────────────────
section "Core Library Locations"

{
    for lib in libc.so.6 libstdc++.so.6 libgcc_s.so.1 \
               libcrypto.so libssl.so libcurl.so \
               libncurses.so libncursesw.so libtinfo.so \
               libaio.so libsasl2.so libldap.so \
               libnuma.so libjemalloc.so liblz4.so libzstd.so \
               libtirpc.so libdl.so libpthread.so libm.so \
               libresolv.so libnss_files.so libnss_dns.so \
               libpam.so libcap.so libselinux.so \
               libz.so libbz2.so liblzma.so; do
        found=$(find /usr/lib64 /usr/lib /lib64 /lib -maxdepth 1 -name "${lib}*" -type f 2>/dev/null | head -1)
        if [ -n "$found" ]; then
            echo "FOUND: $lib -> $found"
        else
            echo "MISSING: $lib"
        fi
    done
} > "$OUTDIR/core-libs-paths.txt"
echo "  core libraries"

# ─────────────────────────────────────────────────────────────────────────────
# 7. Base Packages
# ─────────────────────────────────────────────────────────────────────────────
section "Base Packages"

rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | \
    grep -iE 'glibc|libstdc|libgcc|openssl|curl|ncurses|libaio|cyrus|openldap|systemd|kernel|selinux|pam|nss|zlib|lz4|jemalloc|numactl|libtirpc|util-linux|coreutils|shadow|bash|rpm|yum|dnf|gawk|sed|grep|findutils|tar|gzip|procps|iproute|net-tools' | \
    sort > "$OUTDIR/base-packages.txt"
echo "  base packages filtered"

# ─────────────────────────────────────────────────────────────────────────────
# 8. YUM/DNF Repositories
# ─────────────────────────────────────────────────────────────────────────────
section "Repository Configuration"

if [ -d /etc/yum.repos.d/ ]; then
    ls -la /etc/yum.repos.d/ > "$OUTDIR/yum-repos-d.txt"
    echo "  /etc/yum.repos.d/ listing"
else
    note_missing "/etc/yum.repos.d/"
fi

yum repolist all 2>/dev/null > "$OUTDIR/yum-repolist.txt" || \
    dnf repolist all 2>/dev/null > "$OUTDIR/yum-repolist.txt" || \
    note_missing "yum/dnf repolist"
echo "  repository list"

# ─────────────────────────────────────────────────────────────────────────────
# 9. Specific Release Package Info
# ─────────────────────────────────────────────────────────────────────────────
section "Release Package Details"

for pkg in centos-release redhat-release-server tencentos-release \
           tlinux-release kylin-release openEuler-release; do
    if rpm -q "$pkg" &>/dev/null 2>&1; then
        rpm -qi "$pkg" > "$OUTDIR/${pkg}-info.txt" 2>/dev/null
        echo "  $pkg: $(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$pkg")"
    fi
done

# ─────────────────────────────────────────────────────────────────────────────
# 10. Python Version
# ─────────────────────────────────────────────────────────────────────────────
section "Python"

python --version  > "$OUTDIR/python-version.txt" 2>/dev/null || \
python2 --version > "$OUTDIR/python-version.txt" 2>/dev/null || \
python3 --version > "$OUTDIR/python-version.txt" 2>/dev/null || \
note_missing "python"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  Fingerprint collection complete"
echo "========================================="
echo ""
echo "Output: $OUTDIR"
echo "Files: $(find "$OUTDIR" -type f | wc -l)"
echo ""
echo "Files collected:"
find "$OUTDIR" -type f ! -name missing.txt -printf "  %f\n" | sort

if [ -s "$MISSING_FILE" ]; then
    echo ""
    echo "Missing items (expected on some platforms):"
    cat "$MISSING_FILE" | while read -r line; do
        echo "  $line"
    done
fi

echo ""
echo "To use these fingerprints:"
echo "  1. Copy the output to the project:"
echo "     platforms/<platform-id>/fingerprints/"
echo "  2. Update PLATFORM_MATRIX.md"
echo "  3. Implement detect-platform.sh matching rules"
