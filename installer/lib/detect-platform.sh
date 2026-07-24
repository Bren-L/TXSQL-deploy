#!/bin/bash
# =============================================================================
# installer/lib/detect-platform.sh — Exact Platform Fingerprint Detection
# =============================================================================
# Detects the current system's platform ID using EXACT matching only.
# No fuzzy matching, no "closest match", no cross-architecture selection.
#
# Sources of truth (in priority order):
#   1. /etc/os-release (ID, VERSION_ID)
#   2. Release RPM version (centos-release, tencentos-release, kylin-release)
#   3. /etc/<distro>-release text file
#   4. uname -m (architecture)
#   5. CPU info (for Kylin aarch64: Kunpeng vs Phytium)
#   6. SP version from kylin-release RPM (for Kylin V10)
#
# Exports:
#   DETECTED_PLATFORM_ID    e.g. "centos-7.9-x86_64"
#   DETECTED_OS_ID          e.g. "centos"
#   DETECTED_OS_VERSION     e.g. "7.9.2009"
#   DETECTED_ARCH           e.g. "x86_64"
#   DETECTED_MATCH_TYPE     "exact" or "none"
# =============================================================================

# Source common if not already loaded
if [[ -z "${TXSQL_PORT:-}" ]]; then
    SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
    source "$SCRIPT_DIR/common.sh" 2>/dev/null || true
fi

# ── Fingerprint database ────────────────────────────────────────────────────
# Each entry: PLATFORM_ID | OS_ID | VERSION_ID | OS_VERSION | ARCH | RELEASE_RPM | RELEASE_FILE | NOTES
# Populated ONLY from real fingerprint collections.
# Format: pipe-separated fields for machine parsing.

declare -a KNOWN_PLATFORMS=()

# ── CentOS 7.9 — VERIFIED from ISO (2026-07-22) ───────────────────────────
# ISO .discinfo: 1603728831.612616 / 7.9 / x86_64
# centos-release RPM: centos-release-7-9.2009.0.el7.centos.x86_64
KNOWN_PLATFORMS+=("centos-7.9-x86_64|centos|7|7.9.2009|x86_64|centos-release|centos-release-7-9.2009.0.el7.centos|VERIFIED_FROM_ISO")

# ── CentOS 7.8 — PROJECTED (no environment) ────────────────────────────────
# Expected: kernel 3.10.0-1127, centos-release-7-8.2003.0.el7.centos
KNOWN_PLATFORMS+=("centos-7.8-x86_64|centos|7|7.8.2003|x86_64|centos-release|centos-release-7-8.2003.0.el7.centos|UNVERIFIED")

# ── TencentOS 2.4 — UNVERIFIED (no environment) ─────────────────────────────
# ID may be 'tencentos' or 'tlinux'. Release RPM may be tencentos-release or tlinux-release.
KNOWN_PLATFORMS+=("tencentos-2.4-x86_64|tencentos|2.4|2.4|x86_64|tencentos-release|tencentos-release-2.4|UNVERIFIED")

# ── TencentOS 3.1 — UNVERIFIED (no environment) ─────────────────────────────
KNOWN_PLATFORMS+=("tencentos-3.1-x86_64|tencentos|3.1|3.1|x86_64|tencentos-release|tencentos-release-3.1|UNVERIFIED")

# ── Kylin V10 SP1 aarch64 — UNVERIFIED ─────────────────────────────────────
KNOWN_PLATFORMS+=("kylin-v10-sp1-aarch64|kylin|V10|V10 SP1|aarch64|kylin-release|kylin-release-V10SP1|UNVERIFIED")

# ── Kylin V10 SP2 aarch64 — UNVERIFIED ─────────────────────────────────────
KNOWN_PLATFORMS+=("kylin-v10-sp2-aarch64|kylin|V10|V10 SP2|aarch64|kylin-release|kylin-release-V10SP2|UNVERIFIED")

# ── Kylin V10 SP3 aarch64 — UNVERIFIED ─────────────────────────────────────
KNOWN_PLATFORMS+=("kylin-v10-sp3-aarch64|kylin|V10|V10 SP3|aarch64|kylin-release|kylin-release-V10SP3|UNVERIFIED")

# ── Detection functions ─────────────────────────────────────────────────────

detect_os_release() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        DETECTED_OS_ID="${ID:-unknown}"
        DETECTED_VERSION_ID="${VERSION_ID:-unknown}"
        log_info "os-release: ID=$DETECTED_OS_ID VERSION_ID=$DETECTED_VERSION_ID"
    else
        log_error "/etc/os-release not found — cannot detect platform"
        exit 10
    fi
}

detect_arch() {
    DETECTED_ARCH=$(uname -m)
    log_info "Architecture: $DETECTED_ARCH"
}

detect_release_rpm() {
    # Try common release RPM names
    for rpm_name in centos-release redhat-release-server tencentos-release \
                    tlinux-release kylin-release openEuler-release; do
        if rpm -q "$rpm_name" &>/dev/null 2>&1; then
            RELEASE_RPM_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' "$rpm_name" 2>/dev/null)
            log_info "Release RPM: $rpm_name = $RELEASE_RPM_VERSION"
            DETECTED_RELEASE_RPM="$rpm_name"
            DETECTED_RELEASE_RPM_VERSION="$RELEASE_RPM_VERSION"
            return 0
        fi
    done
    log_warn "No recognized release RPM found"
    DETECTED_RELEASE_RPM="unknown"
    DETECTED_RELEASE_RPM_VERSION="unknown"
}

detect_os_version_full() {
    # Get the full version string from the distro's release file
    local release_file=""
    for f in /etc/centos-release /etc/redhat-release /etc/system-release \
             /etc/kylin-release /etc/tlinux-release /etc/openEuler-release; do
        if [[ -f "$f" ]]; then
            release_file="$f"
            break
        fi
    done
    if [[ -n "$release_file" ]]; then
        DETECTED_OS_VERSION_FULL=$(cat "$release_file" 2>/dev/null | head -1)
        log_info "Release file ($release_file): $DETECTED_OS_VERSION_FULL"
    else
        DETECTED_OS_VERSION_FULL="$DETECTED_OS_ID $DETECTED_VERSION_ID"
    fi
}

detect_kylin_sp() {
    # Kylin V10 needs SP-level detection
    if [[ "$DETECTED_OS_ID" == "kylin" ]] && [[ "$DETECTED_VERSION_ID" == "V10"* ]]; then
        local sp_version=""
        # Method 1: from kylin-release RPM
        if rpm -q kylin-release &>/dev/null 2>&1; then
            sp_version=$(rpm -q --queryformat '%{VERSION}' kylin-release 2>/dev/null)
            log_info "Kylin release RPM version: $sp_version"
        fi
        # Method 2: from VERSION in os-release
        if [[ -z "$sp_version" ]] && [[ -n "${VERSION:-}" ]]; then
            sp_version="$VERSION"
            log_info "Kylin VERSION from os-release: $sp_version"
        fi
        # Method 3: from /etc/kylin-release text
        if [[ -z "$sp_version" ]] && [[ -f /etc/kylin-release ]]; then
            sp_version=$(cat /etc/kylin-release | grep -oP 'SP\d+' | head -1)
            log_info "Kylin SP from release file: $sp_version"
        fi

        if [[ -n "$sp_version" ]]; then
            DETECTED_KYLIN_SP="$sp_version"
            log_info "Kylin SP detected: $DETECTED_KYLIN_SP"
        else
            log_error "Kylin V10 detected but SP version could not be determined"
            log_error "Provide kylin-release RPM info or /etc/kylin-release content"
            DETECTED_KYLIN_SP="unknown-sp"
        fi
    fi
}

detect_cpu_model() {
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_implementer cpu_part
        cpu_implementer=$(grep -m1 'CPU implementer' /proc/cpuinfo 2>/dev/null | awk '{print $3}')
        cpu_part=$(grep -m1 'CPU part' /proc/cpuinfo 2>/dev/null | awk '{print $3}')
        if [[ "$cpu_implementer" == "0x48" ]]; then
            DETECTED_CPU="Kunpeng-920"
        elif [[ "$cpu_implementer" == "0x70" ]]; then
            DETECTED_CPU="Phytium-FT2000+"
        elif [[ -n "$cpu_implementer" ]]; then
            DETECTED_CPU="ARMv8-impl:${cpu_implementer}-part:${cpu_part:-unknown}"
        else
            DETECTED_CPU=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
        fi
    else
        DETECTED_CPU="unknown"
    fi
    log_info "CPU: $DETECTED_CPU"
}

# ── Main detection logic ────────────────────────────────────────────────────

detect_platform() {
    log_step "Detecting platform..."

    detect_os_release
    detect_arch
    detect_release_rpm
    detect_os_version_full
    detect_kylin_sp
    detect_cpu_model

    # Build candidate platform IDs and try exact match
    local candidates=()

    # Primary candidate: <os-id>-<version>-<arch>
    # For CentOS 7.9: centos-7.9-x86_64
    if [[ "$DETECTED_OS_ID" == "centos" ]] && [[ "$DETECTED_VERSION_ID" == "7"* ]]; then
        # CentOS 7 — need minor version from centos-release RPM or release file
        local minor_ver=""
        if [[ -n "${RELEASE_RPM_VERSION:-}" ]]; then
            minor_ver=$(echo "$RELEASE_RPM_VERSION" | grep -oP '7\.\d+' | head -1)
        fi
        if [[ -z "$minor_ver" ]]; then
            minor_ver=$(echo "$DETECTED_OS_VERSION_FULL" | grep -oP '7\.\d+' | head -1)
        fi
        if [[ -n "$minor_ver" ]]; then
            candidates+=("centos-${minor_ver}-${DETECTED_ARCH}")
        else
            log_error "CentOS 7 detected but minor version (.8/.9) could not be determined"
            log_error "Cannot do fuzzy CentOS 7 matching — exact version required."
            candidates+=("centos-7.unknown-${DETECTED_ARCH}")
        fi
    fi

    # For TencentOS
    if [[ "$DETECTED_OS_ID" == "tencentos" ]] || [[ "$DETECTED_OS_ID" == "tlinux" ]]; then
        local tenc_os_id="tencentos"
        if [[ "$DETECTED_OS_ID" == "tlinux" ]]; then
            tenc_os_id="tencentos"  # Normalize tlinux → tencentos for our platform IDs
        fi
        local tenc_ver="$DETECTED_VERSION_ID"
        if [[ -n "${RELEASE_RPM_VERSION:-}" ]]; then
            tenc_ver=$(echo "$RELEASE_RPM_VERSION" | grep -oP '\d+\.\d+' | head -1)
        fi
        candidates+=("${tenc_os_id}-${tenc_ver}-${DETECTED_ARCH}")
    fi

    # For Kylin V10
    if [[ "$DETECTED_OS_ID" == "kylin" ]] && [[ "$DETECTED_VERSION_ID" == "V10"* ]]; then
        local sp="${DETECTED_KYLIN_SP:-unknown}"
        # Normalize SP string: "SP1" → "sp1"
        sp=$(echo "$sp" | tr '[:upper:]' '[:lower:]' | sed 's/ //g')
        candidates+=("kylin-v10-${sp}-${DETECTED_ARCH}")
    fi

    # Generic candidate (last resort)
    candidates+=("${DETECTED_OS_ID}-${DETECTED_VERSION_ID}-${DETECTED_ARCH}")

    log_info "Candidate platform IDs:"
    for c in "${candidates[@]}"; do
        log_info "  - $c"
    done

    # Try exact match against known platforms
    DETECTED_PLATFORM_ID=""
    DETECTED_MATCH_TYPE="none"

    for candidate in "${candidates[@]}"; do
        for entry in "${KNOWN_PLATFORMS[@]}"; do
            local plat_id=$(echo "$entry" | cut -d'|' -f1)
            if [[ "$candidate" == "$plat_id" ]]; then
                DETECTED_PLATFORM_ID="$plat_id"
                local plat_status=$(echo "$entry" | cut -d'|' -f8)
                log_info "EXACT MATCH: $plat_id (status: $plat_status)"
                DETECTED_MATCH_TYPE="exact"
                break 2
            fi
        done
    done

    if [[ -z "$DETECTED_PLATFORM_ID" ]]; then
        log_error "============================================"
        log_error "  PLATFORM DETECTION FAILED"
        log_error "============================================"
        log_error ""
        log_error "Detected OS:    $DETECTED_OS_ID $DETECTED_VERSION_ID"
        log_error "Detected arch:  $DETECTED_ARCH"
        log_error "Release RPM:    ${DETECTED_RELEASE_RPM:-unknown} = ${DETECTED_RELEASE_RPM_VERSION:-unknown}"
        log_error "Release text:   $DETECTED_OS_VERSION_FULL"
        [[ -n "${DETECTED_KYLIN_SP:-}" ]] && log_error "Kylin SP:       $DETECTED_KYLIN_SP"
        log_error "CPU:            $DETECTED_CPU"
        log_error ""
        log_error "Known platforms:"
        for entry in "${KNOWN_PLATFORMS[@]}"; do
            log_error "  $(echo "$entry" | cut -d'|' -f1) ($(echo "$entry" | cut -d'|' -f8))"
        done
        log_error ""
        log_error "This system does NOT match any known platform exactly."
        log_error "Installation ABORTED — no fuzzy fallback."
        log_error ""
        log_error "To add this platform:"
        log_error "  1. Run: bash scripts/collect-fingerprints.sh"
        log_error "  2. Add fingerprint to installer/lib/detect-platform.sh"
        log_error "  3. Build & test on this platform"
        log_error "  4. Mark SUPPORTED in PLATFORM_MATRIX"
        exit 10
    fi

    # Architecture cross-check
    local expected_arch=$(echo "$DETECTED_PLATFORM_ID" | grep -oP '(x86_64|aarch64)')
    if [[ "$expected_arch" != "$DETECTED_ARCH" ]]; then
        log_error "ARCHITECTURE MISMATCH"
        log_error "Platform $DETECTED_PLATFORM_ID expects $expected_arch, but system is $DETECTED_ARCH"
        log_error "Cannot install $expected_arch payload on $DETECTED_ARCH system."
        exit 11
    fi

    # Export detection results
    export DETECTED_PLATFORM_ID
    export DETECTED_OS_ID
    export DETECTED_OS_VERSION="$DETECTED_VERSION_ID"
    export DETECTED_ARCH
    export DETECTED_MATCH_TYPE
    export DETECTED_CPU

    log_info "Platform detected: $DETECTED_PLATFORM_ID ($DETECTED_MATCH_TYPE)"
    set_state "PLATFORM_DETECTED" "$DETECTED_PLATFORM_ID"
}

# Run detection if this script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    detect_platform
    echo ""
    echo "Platform ID:  $DETECTED_PLATFORM_ID"
    echo "OS ID:        $DETECTED_OS_ID"
    echo "Arch:         $DETECTED_ARCH"
    echo "Match type:   $DETECTED_MATCH_TYPE"
    [[ -n "${DETECTED_CPU:-}" ]] && echo "CPU:          $DETECTED_CPU"
fi
