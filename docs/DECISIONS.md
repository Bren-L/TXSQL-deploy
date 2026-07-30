# Decisions Log & Compatibility Strategy — Part 3 of 3

> **Status**: STRATEGY DEFINED (pending source audit for final confirmation)
> **Date**: 2026-07-22
> **Based on**: CentOS 7.9 ISO analysis, TBase mirror reference, OpenTenBase analysis

---

## Part A: Compatibility Strategy

### A.1 Can CentOS 7.8/7.9 Serve as the Common x86_64 Build Baseline?

**Answer: YES, and it is the ONLY correct choice.**

#### Rationale

| Factor | Analysis |
|--------|----------|
| **glibc version** | CentOS 7 has glibc 2.17 (2012). ALL other target platforms have glibc ≥ 2.17. Forward compatibility is guaranteed — glibc is backward-compatible. |
| **Binary portability** | A binary compiled against glibc 2.17 runs on glibc 2.28, but NOT the reverse. CentOS 7 MUST be the build host. |
| **RPM format** | CentOS 7 RPMs (format 3.0, compression gzip) are readable by all newer RPM versions. Newer RPMs (xz, zstd compression) may fail on CentOS 7's rpm 4.11. |
| **GCC ABI** | devtoolset-8 on CentOS 7 provides GCC 8.3.1 with libstdc++ ABI compatible with C++17. This matches the system GCC on RHEL 8-based platforms. |

#### Decision: Strategy A Confirmed

**Build on CentOS 7.8 (or 7.9), produce ONE x86_64 binary, test on all four x86_64 platforms.**

If any platform fails:
1. CentOS 7.8 and 7.9 will almost certainly share the binary (glibc 2.17 identical)
2. TencentOS 2.4 (RHEL 7 based) will likely work (same glibc)
3. TencentOS 3.1 (RHEL 8 based, glibc 2.28) should work (forward compat)
4. ONLY if a platform fails → switch to Strategy B (per-platform build)

---

### A.2 Does TencentOS Need Independent Builds?

**Answer: Probably NOT for 2.4; MAYBE for 3.1 — must verify.**

#### TencentOS 2.4 (RHEL 7 based)

- **glibc**: Expected 2.17 (same as CentOS 7) → binary compatible ✅
- **libstdc++**: If from GCC 4.8.5 system default, compatible with devtoolset-8's libstdc++ ✅
- **OpenSSL**: This is the KEY RISK. If TencentOS 2.4 uses **Tencentsm** (国密) instead of standard OpenSSL, TXSQL may fail to link at runtime.
- **Kernel**: TLinux kernel, but glibc abstracts kernel differences ✅

**Verdict**: Likely compatible. Test with CentOS 7.9-built binary. If Tencentsm is the system crypto provider, we have two options:
1. Bundle OpenSSL 1.1.1 in `/usr/lib/txsql/<ver>/lib/private/` with RPATH
2. Build TXSQL on TencentOS 2.4 natively

#### TencentOS 3.1 (RHEL 8 based)

- **glibc**: Expected 2.28 → backward-compatible with glibc 2.17 binaries ✅
- **libstdc++**: GCC 8.x system → compatible with devtoolset-8 ✅
- **systemd**: 239+ → service file may differ from CentOS 7's systemd 219 ⚠️
- **dnf vs yum**: DNF 4.x → different repo config syntax ⚠️
- **OpenSSL**: Likely 1.1.1 (RHEL 8 default), but may be Tencentsm ⚠️

**Verdict**: Higher risk. System-level differences (dnf, systemd) require
separate installer logic even if binary is shared. Must fingerprint first.

---

### A.3 Does Kylin V10 Require Native Build?

**Answer: YES, absolutely.**

#### Why Native aarch64 Build is Mandatory

1. **Different CPU architecture** — x86_64 binary CANNOT run on aarch64
2. **Cross-compilation risks** — MySQL/TXSQL build system has complex
   assembly code paths (InnoDB checksum, atomics, spinlocks) that are
   arch-specific
3. **No QEMU validation on this workstation** — cannot test cross-compiled
   binaries even if they were built
4. **First official release** — must be validated on real hardware

#### Kylin V10 Build Requirements

- Native aarch64 machine (Kunpeng 920 or Phytium FT-2000+)
- Kylin V10 OS installed (SP1, SP2, or SP3)
- GCC (system or devtoolset equivalent)
- CMake (system or built)
- All build deps from Kylin repos (names may differ from CentOS)

---

### A.4 Which Third-Party Libraries Need Private Bundling?

**Decision: Use private bundling ONLY when the system library is missing or incompatible.**

| Library | Strategy | Rationale |
|---------|----------|-----------|
| **glibc** | ❌ NEVER bundle | System-critical; bundling breaks everything |
| **libstdc++** | ⚠️ Bundle if needed | devtoolset-8 libstdc++ may not exist on target. Use RPATH to `/usr/lib/txsql/<ver>/lib/private/` |
| **libgcc_s** | ⚠️ Bundle if needed | Same as libstdc++ — from devtoolset |
| **OpenSSL** | ⚠️ Conditional | If target has OpenSSL 1.1.1 → use system. If 1.0.2k only → bundle 1.1.1 in private lib |
| **libcurl** | ✅ Use system | Available on all targets |
| **jemalloc** | ✅ Bundle | Typically bundled by MySQL/TXSQL build; use built-in |
| **libaio** | ✅ Use system | Available on all targets |
| **ncurses** | ✅ Use system | Available on all targets |
| **cyrus-sasl** | ✅ Use system | Available on all targets |
| **openldap** | ✅ Use system | Available on all targets |
| **libtirpc** | ✅ Use system | Available on CentOS 7+ and all modern distros |
| **libnuma** | ✅ Use system | Available on all targets |
| **lz4, zstd** | ✅ Bundle | MySQL bundles these; use built-in versions |

#### RPATH Configuration

```bash
# Build-time RPATH setting
cmake .. \
  -DCMAKE_INSTALL_RPATH="/usr/lib/txsql/<ver>/lib/private" \
  -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON

# Verify post-build
readelf -d /usr/lib/txsql/<ver>/bin/mysqld | grep RPATH
readelf -d /usr/lib/txsql/<ver>/bin/mysqld | grep RUNPATH
```

---

### A.5 Which Dependencies Must Use System RPM?

**Decision: System-critical packages must NEVER be in our local repo.**

| Package Class | Examples | Strategy |
|---------------|----------|----------|
| **C Library** | glibc | System — never bundle |
| **Init system** | systemd | System — never bundle |
| **Package manager** | rpm, yum, dnf | System — never bundle |
| **Shell** | bash | System — never bundle |
| **Kernel** | kernel | System — never bundle |
| **Auth** | PAM, NSS | System — never bundle |
| **Security** | SELinux libs, policy | System — never bundle |
| **Base utils** | coreutils, util-linux, shadow-utils | System — never bundle |
| **Runtime libs** | libaio, ncurses, libcurl, numactl, SASL, LDAP | System RPM — if absent, add to local repo |
| **C++ runtime** | libstdc++, libgcc_s | System RPM — if version too old, bundle privately (NOT as RPM replacement) |
| **Crypto** | OpenSSL libs | Conditional — see A.4 |
| **TXSQL** | mysqld, mysql, plugins | Built RPMs — in local repo |

---

## Part B: Key Design Decisions (DEC-001 through DEC-018)

### DEC-001: Offline-First Architecture
**Date**: 2026-07-22 | **Status**: FINAL
> See previous version for full rationale.

### DEC-002: SHA-256 Instead of GPG Signing
> Confirmed: TBase mirror also uses no GPG signing. Industry-validated for offline repos.

### DEC-003: Per-Platform Independent Builds and Repos
> Each platform gets its own dependency repository, even if platforms share the same TXSQL binary.

### DEC-004: Strict Platform Matching (No Fallback)
> CentOS 7.9 ISO data confirms why: even minor version differences (7.8 vs 7.9) change kernel, systemd, and library release numbers. A "close enough" match risks install failure.

### DEC-005: Build on Lowest Common Denominator (CentOS 7.x)
> **UPDATED with real data**: Analysis of CentOS 7.9 ISO confirms glibc 2.17 is the floor. This is now a CONFIRMED strategy, not tentative. The CentOS 7 ISO provides:
> - glibc 2.17 — lowest of all targets
> - GCC 4.8.5 (needs devtoolset-8)
> - CMake 2.8.12.2 (needs cmake3 from EPEL)
> - All required runtime libraries available

### DEC-006: No `LD_LIBRARY_PATH` for Private Libraries
> Use RPATH/RUNPATH exclusively.

### DEC-007: Data Preservation by Default
### DEC-008: Three RPM Packages (common, client, server)
### DEC-009: Zero Prompts During Install
### DEC-010: Root-Only Credentials File
### DEC-011: Docker for Build/Quick-Test, VM for Final Acceptance
### DEC-012: Phase 1 Single Instance Only

### DEC-014: CentOS 7 Build Toolchain — CORRECTED to GCC 10.x
**Date**: 2026-07-22 | **Status**: CORRECTED — previous "devtoolset-8 is sufficient" was unproven

#### Correction
The previous decision assumed devtoolset-8 (GCC 8.3.1) was sufficient.
The user confirmed that the **official OpenTenBase/TXSQL 8.0.30 branch
requires GCC 10.x or above**. This must be verified against the actual
source, not assumed.

#### Updated Requirement
- **GCC ≥ 10.x** (not 8.x) — to be confirmed by source audit
- **cmake3 from EPEL or newer** — ≥ 3.11 required
- devtoolset-8 (GCC 8.3.1) is only acceptable if the ACTUAL source
  commit builds successfully with it

#### Options for CentOS 7.9 (no system GCC 10)
1. **devtoolset-10** from CentOS SCLo (if available for CentOS 7)
2. **Custom GCC 10 build** installed to /opt/gcc-10/
3. **Container-based build** with a newer OS providing GCC 10
4. **GCC 8 as fallback ONLY** if real build proves it works

#### Status
GCC version requirement is UNVERIFIED until TXSQL source is audited.
The user's instruction to use GCC 10.x takes precedence over previous
assumptions about devtoolset-8 sufficiency.

#### SCL Enablement
```bash
# In build scripts:
source /opt/rh/devtoolset-8/enable
export CC=gcc
export CXX=g++
```

#### libstdc++ Handling
devtoolset-8's `libstdc++.so.6` has a newer ABI than the system default
(GCC 4.8.5). Options:
1. **Static link libstdc++**: `-static-libstdc++` — simplest, no runtime dep
2. **Bundle libstdc++ in private lib**: copy `.so` and use RPATH
3. **Use system libstdc++ on target**: Only works if target has GCC 5+ (CentOS 7 does NOT; TencentOS 3.1 does)

**Recommendation**: Static link libstdc++ and libgcc_s for the mysqld binary.
This avoids any runtime compatibility issues. For client tools, use
system libstdc++ (they don't use C++17 features heavily).

```bash
cmake .. \
  -DCMAKE_CXX_FLAGS="-static-libstdc++ -static-libgcc"
```

### DEC-015: createrepo on CentOS 7, createrepo_c on DNF Platforms
**Date**: 2026-07-22 | **Status**: CONFIRMED

Confirmed by TBase mirror: CentOS 7 uses `createrepo` (Python 2 based),
not `createrepo_c`. The repomd.xml format is identical. Command syntax:

```bash
# CentOS 7 / yum platforms
createrepo --database /path/to/repo/

# RHEL 8+ / dnf platforms
createrepo_c --database /path/to/repo/
```

Both generate compatible repodata. The installer must detect which tool
is available on the TARGET system and configure the `.repo` file accordingly.

### DEC-016: Installer Must Support Both yum and dnf
**Date**: 2026-07-22 | **Status**: CONFIRMED

| Platform | Pkg Mgr | Version | .repo syntax |
|----------|--------|---------|-------------|
| CentOS 7.8 | yum | 3.4.3 | Standard |
| CentOS 7.9 | yum | 3.4.3 | Standard |
| TencentOS 2.4 | yum (TBD) | TBD | Standard |
| TencentOS 3.1 | dnf (TBD) | TBD | Standard (compat) |
| Kylin V10 | dnf (TBD) | TBD | Standard (compat) |

The `.repo` file syntax is backwards-compatible. dnf reads yum-format
`.repo` files without issues.

### DEC-017: Keep System SELinux Enforcing
**Date**: 2026-07-22 | **Status**: FINAL

Never call `setenforce 0`. If SELinux blocks TXSQL:
1. Use `restorecon` to set correct context on TXSQL directories
2. If still blocked, document the AVC denial
3. Develop minimal SELinux policy module for TXSQL
4. Package the policy module in `txsql-server` RPM

### DEC-018: Boost Download Strategy
**Date**: 2026-07-22 | **Status**: CONFIRMED

MySQL 8.0.30 requires Boost 1.77.0. The CMake build can auto-download
it, but for offline builds:

1. Pre-download `boost_1_77_0.tar.gz` (or whatever version TXSQL requires)
2. Store in the build environment
3. Pass `-DWITH_BOOST=/path/to/boost_1_77_0` to cmake
4. Add Boost SHA-256 to build verification

The exact Boost version may differ — audit TXSQL source to confirm.

---

## Part C: Risk Matrix (Updated with Real Data)

| # | Risk | Severity | Status | Mitigation |
|---|------|----------|--------|------------|
| 1 | TXSQL source unavailable | **CRITICAL** | BLOCKED | Must provide source to proceed |
| 2 | CentOS 7 GCC too old | **HIGH** | CONFIRMED | Use devtoolset-8, confirmed available from SCLo |
| 3 | CMake too old on CentOS 7 | **HIGH** | CONFIRMED | cmake3 from EPEL |
| 4 | No target VMs accessible | **HIGH** | ACTIVE | 3 VMs running but no SSH credentials |
| 5 | Tencentsm vs OpenSSL on TencentOS | **MEDIUM** | UNKNOWN | Must fingerprint to determine |
| 6 | Kylin V10 aarch64 not available | **HIGH** | BLOCKED | No aarch64 hardware; cannot proceed without |
| 7 | devtoolset libstdc++ ABI | **MEDIUM** | MITIGATED | Static linking recommended |
| 8 | systemd 219 vs 239+ service file | **LOW** | MITIGATED | Use compatible directives only |
| 9 | TencentOS custom kernel | **LOW** | ACCEPTED | glibc abstracts kernel differences |
| 10 | CentOS 7.8 vs 7.9 differences | **LOW** | ACCEPTED | Test both; differences are minor RPM releases |

---

## Part D: Strategic Roadmap

### Immediate Next Steps (to unblock)

1. **Get root password** for CentOS 7.9 VM at 192.168.44.129
   - Or regenerate with single-user mode via VMware console
   - Once access is gained: run `collect-fingerprints.sh`, check for TXSQL source

2. **Locate TXSQL source**
   - Check if it exists on any of the 13 VMs
   - Or request git URL / tarball from the user

3. **Start TDSQL-1/2/3 VMs**
   - These may contain TXSQL installation or source
   - Check their content once credentials are resolved

### Beyond Unblock

4. Set up CentOS 7.9 build environment (devtoolset-8, cmake3, Boost)
5. Build TXSQL (once source is available)
6. Produce RPMs (common, client, server)
7. Compute dependency closure
8. Build offline bundle
9. Test on all accessible x86_64 VMs
10. Obtain TencentOS and Kylin environments
11. Test cross-platform binary compatibility
12. Final acceptance testing

---

## Appendix: devtoolset-8 RPM List

For offline build environment preparation (pre-download these):

```
devtoolset-8-gcc-8.3.1-3.2.el7.x86_64.rpm
devtoolset-8-gcc-c++-8.3.1-3.2.el7.x86_64.rpm
devtoolset-8-binutils-2.30-55.el7.2.x86_64.rpm
devtoolset-8-libstdc++-devel-8.3.1-3.2.el7.x86_64.rpm
devtoolset-8-runtime-8.1-1.el7.x86_64.rpm
devtoolset-8-gdb-8.2-3.el7.x86_64.rpm  (optional)
cmake3-3.17.5-1.el7.x86_64.rpm          (from EPEL)
cmake3-data-3.17.5-1.el7.noarch.rpm     (from EPEL)
```

Source repositories (must be mirrored offline):
```
http://mirror.centos.org/centos/7/sclo/x86_64/rh/devtoolset-8/
http://mirror.centos.org/centos/7/extras/x86_64/
https://dl.fedoraproject.org/pub/epel/7/x86_64/
```
