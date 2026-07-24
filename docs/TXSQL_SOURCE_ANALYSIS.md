# TXSQL Source Analysis — Part 1 of 3

> **Status**: COMPLETE (within available resources)
> **Date**: 2026-07-22
> **Source Availability**: NOT FOUND — TXSQL source code not on this workstation.

---

## 1. Executive Summary

TXSQL source code was **not located** on this workstation. The placeholder
`<TXSQL_SOURCE_PATH>` was not resolvable to any filesystem path. The SSH VM
at `192.168.44.133` (configured as host "abc" in `~/.ssh/config`) is
unreachable (connection timed out).

### What was searched:
- `C:\Users\20976\Desktop\` — no TXSQL directories or tarballs
- `C:\Users\20976\.qclaw\workspaces\` — no TXSQL content
- All drives via `find` — no `CMakeLists.txt` matching `*txsql*` or `*mysql*`
- SSH host `abc` (192.168.44.133) — connection timed out
- VMware VMs found but inaccessible (no SSH credentials)

### What IS available:
- CentOS 7.9 ISO (`E:\镜像\CentOS-7-x86_64-DVD-2009 (1).iso`) — authoritative baseline
- 13 VMware VMs (3 running, 10 powered off) — root password unknown
- TBase offline RPM mirror (275 RPMs) — reference for offline repo structure
- OpenTenBase-Packages reference project — fully analyzed

---

## 2. CentOS 7 Baseline: Authoritative Data from ISO

The CentOS 7.9 DVD ISO was mounted and its `repodata/primary.xml.gz` and
`comps.xml.gz` were extracted. This provides authoritative version data:

### 2.1 ISO Identity

```
.discinfo:    1603728831.612616 / 7.9 / x86_64
CentOS_BuildTag: 20201029-1700
.treeinfo:    name=CentOS-7, family=CentOS, version=7, arch=x86_64
Total packages on DVD: 4070
@core group:   86 packages (defined in comps.xml)
```

### 2.2 Key System Package Versions

| Package | NEVRA |
|---------|-------|
| glibc | glibc-2.17-317.el7.x86_64 |
| kernel | kernel-3.10.0-1160.el7.x86_64 |
| systemd | systemd-219-78.el7.x86_64 |
| bash | bash-4.2.46-34.el7.x86_64 |
| rpm | rpm-4.11.3-45.el7.x86_64 |
| yum | yum-3.4.3-168.el7.centos.noarch |
| openssl-libs | openssl-libs-1.0.2k-19.el7.x86_64 |
| libstdc++ | libstdc++-4.8.5-44.el7.x86_64 |
| libgcc | libgcc-4.8.5-44.el7.x86_64 |
| ncurses-libs | ncurses-libs-5.9-14.20130511.el7_4.x86_64 |
| libaio | libaio-0.3.109-13.el7.x86_64 |
| cyrus-sasl-lib | cyrus-sasl-lib-2.1.26-23.el7.x86_64 |
| openldap | openldap-2.4.44-22.el7.x86_64 |
| libcurl | libcurl-7.29.0-59.el7.x86_64 |
| numactl-libs | numactl-libs-2.0.12-5.el7.x86_64 |
| zlib | zlib-1.2.7-18.el7.x86_64 |
| lz4 | lz4-1.8.3-1.el7.x86_64 |
| xz-libs | xz-libs-5.2.2-1.el7.x86_64 |
| libtirpc | libtirpc-0.2.4-0.16.el7.x86_64 |
| pam | pam-1.1.8-23.el7.x86_64 |
| nss-softokn-freebl | nss-softokn-freebl-3.44.0-8.el7_7.x86_64 |
| nss-util | nss-util-3.44.0-4.el7_7.x86_64 |
| util-linux | util-linux-2.23.2-65.el7.x86_64 |
| coreutils | coreutils-8.22-24.el7.x86_64 |
| shadow-utils | shadow-utils-4.6-5.el7.x86_64 |

### 2.3 Build Toolchain from ISO

| Package | NEVRA | Notes |
|---------|-------|-------|
| gcc | gcc-4.8.5-44.el7.x86_64 | **TOO OLD for MySQL 8.0** |
| gcc-c++ | gcc-c++-4.8.5-44.el7.x86_64 | No C++17 support |
| cmake | cmake-2.8.12.2-2.el7.x86_64 | **TOO OLD** (MySQL 8.0 needs ≥3.11) |
| bison | bison-3.0.4-2.el7.x86_64 | OK |
| flex | flex-2.5.37-6.el7.x86_64 | OK |
| make | make-3.82-24.el7.x86_64 | OK |

### 2.4 Critical Finding: GCC 4.8.5 Cannot Build MySQL 8.0/TXSQL

**MySQL 8.0.30 requires GCC ≥ 7.3** (C++17 required for `std::variant`,
`std::optional`, `if constexpr`, structured bindings).

The CentOS 7 system GCC is **4.8.5** — released in 2015, predates C++17 by years.

**Mandatory**: devtoolset from CentOS Software Collections (SCL):
- `devtoolset-8` → GCC 8.3.1 (recommended, matches RHEL 8)
- `devtoolset-9` → GCC 9.3.1
- `devtoolset-10` → GCC 10.2.1

devtoolset is NOT on the CentOS 7 DVD. Sources:
- CentOS SCLo repository: `mirror.centos.org/centos/7/sclo/`
- CentOS Extras: `mirror.centos.org/centos/7/extras/`
- EPEL: `dl.fedoraproject.org/pub/epel/7/`

For offline build, devtoolset RPMs must be pre-downloaded and included
in the build environment.

Similarly, CMake from the ISO is 2.8.12.2 — far too old. MySQL 8.0 needs
CMake ≥ 3.11. Must download `cmake3` from EPEL or build from source.

---

## 3. Source Audit Checklist (For When TXSQL Source is Available)

When TXSQL source becomes available, execute this checklist:

### 3.1 Identity
```bash
cd <TXSQL_SOURCE>
git log -1 --format='%H %ai %s'          # → TXSQL_COMMIT, TXSQL_COMMIT_DATE
git branch -a                             # → TXSQL_BRANCH
git describe --tags --always              # → TXSQL_VERSION
grep MYSQL_VERSION CMakeLists.txt         # → MYSQL_BASE_VERSION
```

### 3.2 CMake Configuration
```bash
cmake_minimum_required  → from CMakeLists.txt
CMAKE_CXX_STANDARD      → from CMakeLists.txt (expect 17 or 20)
BOOST_VERSION           → from cmake/boost.cmake
WITH_SSL / WITH_ZLIB    → from cmake/*.cmake (system vs bundled)
```

### 3.3 Build Options
```bash
grep -r 'OPTION\|option(' CMakeLists.txt cmake/ | grep -iE 'with|enable'
```

Key flags to identify: `WITH_BOOST`, `WITH_SSL`, `WITH_ZLIB`, `WITH_CURL`,
`WITH_JEMALLOC`, `WITH_LZ4`, `WITH_ZSTD`, `WITH_SASL`, `WITH_LDAP`,
`WITH_TIRPC`, `ENABLED_LOCAL_INFILE`, `DOWNLOAD_BOOST`.

### 3.4 Third-Party Versions
```bash
ls extra/          # List all bundled libraries
grep VERSION extra/openssl/opensslv.h 2>/dev/null || echo "no bundled openssl"
grep VERSION extra/zlib/zlib.h 2>/dev/null || echo "no bundled zlib"
```

### 3.5 Plugins
```bash
grep 'PLUGIN_' CMakeLists.txt plugin/*/CMakeLists.txt | grep -iE 'DEFAULT|MANDATORY|STATIC'
```

### 3.6 Package Scripts
```bash
cat txsql_package.pl       # TXSQL packaging script (if exists)
cat ci_txsql_package.pl    # CI packaging variant (if exists)
cat build.sh               # Build script (if exists)
```

---

## 4. Expected Compatibility Matrix

Based on MySQL 8.0.30 upstream and CentOS 7.9 baseline:

| Component | MySQL 8.0.30 Requires | CentOS 7.9 Provides | Status |
|-----------|----------------------|---------------------|--------|
| GCC | ≥ 7.3 | 4.8.5 | ❌ NEEDS DEVTOOLSET |
| CMake | ≥ 3.11 | 2.8.12.2 | ❌ NEEDS cmake3 from EPEL |
| Bison | ≥ 3.0 | 3.0.4 | ✅ OK |
| Boost | 1.77.0 | not on ISO | ❌ NEEDS DOWNLOAD |
| glibc | ≥ 2.17 | 2.17 | ✅ OK (minimum met) |
| OpenSSL | ≥ 1.0.2 | 1.0.2k | ⚠️ OK but EOL; TXSQL may want 1.1.1 |
| libaio | ≥ 0.3.109 | 0.3.109 | ✅ OK |
| ncurses | ≥ 5.7 | 5.9 | ✅ OK |
| libtirpc | needed for newer glibc | 0.2.4 | ✅ Available |

### Risk: GLIBC 2.17 Ceiling

A binary compiled on CentOS 7 (glibc 2.17) will work on:
- CentOS 7.8/7.9 (glibc 2.17) ✅
- TencentOS 2.4 (glibc 2.17, if RHEL 7 based) ✅ likely
- TencentOS 3.1 (glibc 2.28) ✅ (forward compat, newer glibc is backward compat)

But NOT the reverse: a binary compiled on TencentOS 3.1 (glibc 2.28) will
**fail** on CentOS 7 with "version `GLIBC_2.XX' not found".

Therefore: **CentOS 7.8 or 7.9 MUST be the build host for x86_64.**

---

## 5. TXSQL-Specific Unknowns

Until source is audited:

| Unknown | Impact | How to Resolve |
|---------|--------|---------------|
| TXSQL version (8.0.30, 8.0.35, etc.) | Affects GCC/Boost requirements | Audit MYSQL_VERSION file |
| ColumnStore engine | May need additional deps (protobuf, arrow, parquet) | Check plugin/columnstore/ directory |
| Thread pool | May need libaio 0.3.111+ | Check plugin/thread_pool/ |
| Tencentsm vs OpenSSL | Tencent's crypto may replace OpenSSL | Check cmake/ssl.cmake, WITH_TENCENTSM |
| Parallel query | CPU feature requirements | Check source, may need AVX2 |
| jemalloc version | Bundled version, licensing | Check extra/jemalloc/ |
| libcurl requirement | If bundled or system | Check cmake/curl.cmake |

---

## 6. Build Environment Requirements (Projected)

### Build Host: CentOS 7.9 x86_64

```bash
# System repos needed offline:
# - CentOS 7.9 DVD (base RPMs)
# - CentOS SCLo (devtoolset-8)
# - EPEL 7 (cmake3)

# Required build dependencies (projected):
yum install -y \
  devtoolset-8-gcc devtoolset-8-gcc-c++ devtoolset-8-binutils \
  cmake3 bison flex perl ncurses-devel libaio-devel \
  openssl-devel cyrus-sasl-devel openldap-devel libtirpc-devel \
  zlib-devel lz4-devel libcurl-devel numactl-devel \
  rpm-build createrepo

# Enable devtoolset-8 in build environment:
scl enable devtoolset-8 bash
```

### Build Script (projected):

```bash
#!/bin/bash
source /opt/rh/devtoolset-8/enable  # GCC 8.3.1

cmake3 .. \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX=/usr/lib/txsql/<version> \
  -DMYSQL_DATADIR=/var/lib/txsql/data \
  -DSYSCONFDIR=/etc/txsql \
  -DWITH_BOOST=/path/to/boost_1_77_0 \
  -DWITH_SSL=system \
  -DWITH_ZLIB=bundled \
  -DWITH_LZ4=bundled \
  -DWITH_ZSTD=bundled \
  -DWITH_JEMALLOC=bundled \
  -DWITH_CURL=system \
  -DWITH_SASL=system \
  -DWITH_LDAP=system \
  -DWITH_NUMA=ON \
  -DENABLED_LOCAL_INFILE=ON \
  -DWITH_PARTITION_STORAGE_ENGINE=ON \
  -DWITH_INNODB_MEMCACHED=ON

# NOTE: All options MUST be verified against actual TXSQL CMakeLists.txt
```

---

## 7. Next Steps

1. **Resolve TXSQL source** — provide git URL, tarball, or accessible VM path.
2. **Execute Section 3 audit** — fill all recorded fields.
3. **Download devtoolset-8 + cmake3 RPMs** — build the offline build environment.
4. **Download Boost 1.77.0** — verify required version against actual source.
5. **Proceed to Phase 3** — determine exact source commit and toolchain.

---

## 8. Risk Register

| # | Risk | Severity | Status |
|---|------|----------|--------|
| 1 | TXSQL source unavailable | CRITICAL | BLOCKED |
| 2 | CentOS 7 GCC 4.8.5 too old | HIGH | CONFIRMED — needs devtoolset |
| 3 | CMake 2.8 on CentOS 7 too old | HIGH | CONFIRMED — needs cmake3 from EPEL |
| 4 | GLIBC 2.17 sufficient for MySQL 8.0? | MEDIUM | Likely OK — MySQL 8.0 supports CentOS 7 |
| 5 | OpenSSL 1.0.2k EOL | MEDIUM | TXSQL may bundle OpenSSL 1.1.1 |
| 6 | devtoolset libstdc++ ABI | MEDIUM | Need to verify at runtime with TXSQL binaries |
| 7 | Boost 1.77.0 download offline | LOW | Pre-download and store in build repo |
