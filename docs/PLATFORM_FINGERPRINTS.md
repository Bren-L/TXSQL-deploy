# Platform Fingerprints — Part 2 of 3

> **Status**: PARTIAL — CentOS 7.9 baseline obtained from ISO; live fingerprints not collected.
> **Date**: 2026-07-22
> **Method**: ISO extraction (authoritative) + VMware VM enumeration (no access)

---

## 1. Data Collection Methods Used

### Method A: ISO Extraction (CentOS 7.9 — ✅ COMPLETE)

The CentOS 7.9 DVD ISO at `E:\镜像\CentOS-7-x86_64-DVD-2009 (1).iso` was
extracted using 7-Zip. Files extracted:

| File | Content | Size |
|------|---------|------|
| `.discinfo` | Version identity (7.9, x86_64) | 29 B |
| `CentOS_BuildTag` | Build timestamp (20201029-1700) | 14 B |
| `.treeinfo` | Distribution metadata | 354 B |
| `repodata/repomd.xml` | Repository structure | 3,733 B |
| `repodata/primary.xml.gz` | All 4,070 packages | 1.6 MB |
| `repodata/comps.xml.gz` | Package groups (@core: 86 pkgs) | 157 KB |

This gives us the **authoritative package set** for a minimal CentOS 7.9
installation. However, ISO data is static — it does NOT represent:
- A running system's package selection (only @core gets installed)
- Post-install `yum update` state
- Custom packages installed after OS deployment
- Running services and their state

### Method B: VMware VM Enumeration (Partial — NO ACCESS)

13 VMware VMs were identified. 3 were started via `vmrun`. All 3 are
reachable via SSH port but authentication failed (root password unknown).

### Method C: TBase Offline Mirror (Reference — ✅ ANALYZED)

A 515 MB offline RPM repository for TBase on CentOS 7 was extracted
from `Centos7.tar.gz`. Contains 275 RPMs in 14 categories. Provides
a real-world reference for offline repo structure.

---

## 2. Platform: centos-7.9-x86_64

### 2.1 Status: UNVERIFIED (live fingerprint not collected)

### 2.2 ISO-Authoritative Baseline

```
PLATFORM_ID:           centos-7.9-x86_64
OS_ID:                 centos
OS_VERSION_ID:         7
OS_VERSION:            7.9.2009
OS_ARCH:               x86_64
OS_PRETTY:             CentOS Linux 7.9.2009 (Core)
ISO_BUILD_DATE:        2020-10-29 17:00 UTC
ISO_PACKAGE_COUNT:     4,070
CORE_GROUP_PACKAGES:   86
```

### 2.3 Key Package Versions

| Category | Package | Version | Notes |
|----------|---------|---------|-------|
| C Library | glibc | 2.17-317.el7 | Will be the build baseline |
| Kernel | kernel | 3.10.0-1160.el7 | |
| Init | systemd | 219-78.el7 | Older systemd; service syntax differs from 239+ |
| Shell | bash | 4.2.46-34.el7 | |
| Pkg Mgr | rpm | 4.11.3-45.el7 | Older RPM format |
| Pkg Mgr | yum | 3.4.3-168.el7.centos | No dnf on CentOS 7 |
| Compiler | gcc | 4.8.5-44.el7 | **TOO OLD** — needs devtoolset |
| C++ Lib | libstdc++ | 4.8.5-44.el7 | From GCC 4.8.5 ABI |
| Crypto | openssl-libs | 1.0.2k-19.el7 | EOL; TXSQL may bundle 1.1.1 |
| TLS | libcurl | 7.29.0-59.el7 | |
| Terminal | ncurses-libs | 5.9-14.20130511.el7_4 | |
| Async I/O | libaio | 0.3.109-13.el7 | |
| SASL | cyrus-sasl-lib | 2.1.26-23.el7 | |
| LDAP | openldap | 2.4.44-22.el7 | |
| NUMA | numactl-libs | 2.0.12-5.el7 | |
| Compression | zlib | 1.2.7-18.el7 | |
| Compression | lz4 | 1.8.3-1.el7 | |
| Compression | xz-libs | 5.2.2-1.el7 | |
| RPC | libtirpc | 0.2.4-0.16.el7 | SunRPC replacement |
| Auth | pam | 1.1.8-23.el7 | |
| NSS | nss-softokn-freebl | 3.44.0-8.el7_7 | |
| Utils | util-linux | 2.23.2-65.el7 | |
| Utils | coreutils | 8.22-24.el7 | |
| Users | shadow-utils | 4.6-5.el7 | |

### 2.4 @core Group (Minimal Install)

The 86 packages in the @core group represent a minimal CentOS 7.9
installation. Key packages: `bash`, `coreutils`, `glibc`, `rpm`, `yum`,
`systemd`, `openssh-server`, `openssh-clients`, `sudo`, `firewalld`,
`selinux-policy-targeted`, `rsyslog`, `cronie`, `vim-minimal`,
`NetworkManager`.

### 2.5 Build Toolchain Gap Analysis

| Tool | Required (MySQL 8.0) | CentOS 7.9 ISO | Missing | Source |
|------|---------------------|----------------|---------|--------|
| GCC C/C++ | ≥ 7.3 | 4.8.5 | ❌ | devtoolset-8 from SCLo |
| CMake | ≥ 3.11 | 2.8.12.2 | ❌ | cmake3 from EPEL |
| Bison | ≥ 3.0 | 3.0.4 | ✅ | ISO |
| Flex | ≥ 2.5 | 2.5.37 | ✅ | ISO |
| Perl | ≥ 5.6 | (not on ISO) | ⚠️ | ISO or base repo |
| Boost | 1.77.0 | not on ISO | ❌ | Pre-download |
| OpenSSL devel | 1.0.2+ | on ISO | ✅ | ISO |
| ncurses-devel | any | on ISO | ✅ | ISO |
| libaio-devel | any | on ISO | ✅ | ISO |

### 2.6 VM Environment

```
VM Path:        E:\虚拟机\CentOS-7.9\CentOS 7.9.vmx
Status:         RUNNING (started via vmrun 2026-07-22)
IP Address:     192.168.44.129 (confirmed via SSH port probe)
MAC Address:    00:0c:29:ce:27:7e (confirmed via DHCP lease)
SSH Access:     NO — root password unknown
VMware Tools:   NOT running (verified via vmrun getGuestIPAddress)
vCPU:           16
RAM:            16 GB
OS Type:        centos7-64
Network:        NAT (VMnet8, 192.168.44.0/24)
ISO:            E:\镜像\CentOS-7-x86_64-DVD-2009 (1).iso
```

---

## 3. Platform: centos-7.8-x86_64

### 3.1 Status: UNVERIFIED (no environment available)

No CentOS 7.8 ISO or VM found on this workstation.

Expected differences from 7.9:
- kernel: 3.10.0-1127.el7 (vs 1160 on 7.9)
- systemd: 219-67.el7 (vs 219-78 on 7.9)
- centos-release: 7-8.2003.0.el7.centos
- glibc: same 2.17 but different release number
- Most library minor versions identical or very close

**Cannot confirm without actual system or ISO.**

### 3.2 Key Unknowns

- Exact kernel version (3.10.0-1127.?.el7)
- glibc release number
- systemd release number
- rpm release number
- Any security backports that affect library ABIs

---

## 4. Platform: tencentos-2.4-x86_64

### 4.1 Status: UNVERIFIED (no environment available)

No TencentOS 2.4 ISO, VM image, or machine found.

### 4.2 Expected Characteristics (Based on RHEL 7 Lineage)

If TencentOS 2.4 is derived from CentOS 7.x:
- glibc: likely 2.17
- GCC system: likely 4.8.5
- Kernel: TLinux-customized 3.10.x or 4.x
- RPM: likely 4.11.x
- Package manager: likely yum

### 4.3 Key Unknowns

| Unknown | Why It Matters |
|---------|---------------|
| OS ID in /etc/os-release ('tencentos' vs 'tlinux') | Detection logic |
| tencentos-release RPM version | Platform identification |
| OpenSSL variant (standard vs Tencentsm) | Runtime dependency — different library name |
| Tencentsm library name and path | libs may be in /usr/lib64/sm/ or similar |
| Kernel version and features | NUMA, AIO, cgroups behavior |
| Default SELinux state | Installer behavior |
| yum vs dnf | Repo configuration syntax |
| createrepo vs createrepo_c | Repo metadata generation |

### 4.4 Verification Plan

When a TencentOS 2.4 environment becomes available:
1. Boot the system
2. Run `collect-fingerprints.sh`
3. Compare glibc ABI with CentOS 7.9 baseline
4. If glibc 2.17: binary compiled on CentOS 7.9 should work
5. Check Tencentsm: if present and TXSQL links to it, must bundle
6. Test TXSQL binary from CentOS 7.9 build
7. Run full acceptance test suite

---

## 5. Platform: tencentos-3.1-x86_64

### 5.1 Status: UNVERIFIED (no environment available)

No TencentOS 3.1 ISO, VM image, or machine found.

### 5.2 Expected Characteristics (Based on RHEL 8 Lineage)

If TencentOS 3.1 is derived from CentOS 8.x:
- glibc: likely 2.28
- GCC system: likely 8.x
- Kernel: TLinux-customized 5.x
- RPM: likely 4.14.x
- Package manager: likely dnf
- systemd: likely 239+

### 5.3 Binary Compatibility Risk

A TXSQL binary compiled on CentOS 7.9 (glibc 2.17) **should work** on
TencentOS 3.1 (glibc 2.28) because glibc is backward-compatible. However:

- libstdc++ ABI: GCC 4.8.5 (devtoolset-8) vs GCC 8.x → should be compatible
- OpenSSL: 1.0.2k vs 1.1.1 → if TXSQL links to OpenSSL 1.1.1 (bundled), fine
- Kernel interfaces: /proc and /sys differences → typically fine
- systemd: 219 vs 239+ → service file may need adjustments

### 5.4 Key Unknowns

Same as TencentOS 2.4, plus:
- DNF modularity impact on dependency resolution
- Default package set differences (RHEL 8 minimal ≠ RHEL 7 minimal)
- `createrepo_c` vs `createrepo` for repodata generation

---

## 6. Platform: kylin-v10-aarch64

### 6.1 Status: UNVERIFIED (no aarch64 environment available)

No Kylin V10 environment found. This workstation is x86_64. No QEMU
user-mode emulation available.

### 6.2 Absolute Requirements

- **Native aarch64 hardware**: Kunpeng 920 or Phytium FT-2000+ machine
  with Kylin V10 installed
- **SP version must be determined**: SP1, SP2, or SP3
- **Build MUST be native**: No cross-compilation from x86_64 for the
  first official release
- **Each SP is a separate platform** until proven compatible

### 6.3 Key Unknowns

| Unknown | Critical For |
|---------|-------------|
| Exact SP (SP1/SP2/SP3) | Platform ID |
| kylin-release RPM version | Detection logic |
| CPU model (Kunpeng 920, Phytium, etc.) | Build optimization, NUMA config |
| glibc version | ABI baseline |
| GCC version | Build toolchain |
| OpenSSL version (standard vs Kylin-customized) | Runtime deps |
| RPM version | Package format |
| dnf vs yum | Installer repo config |
| systemd version | Service unit compatibility |
| Default filesystem | Data directory mount options |
| SELinux policy | Service context requirements |
| Package manager behavior | Repoquery, dependency resolution |

### 6.4 Verification Plan

1. Obtain Kylin V10 aarch64 environment (physical or cloud)
2. Run `collect-fingerprints.sh`
3. Set up native build environment (GCC, CMake, etc.)
4. Build TXSQL natively on aarch64
5. Run full acceptance test suite
6. Each SP tested independently

---

## 7. VMware VM Inventory

All discovered VMware virtual machines on this workstation:

| VM Path | OS | Status | vCPU | RAM | IP | Access |
|---------|-----|--------|------|-----|-----|--------|
| `/e/虚拟机/CentOS-7.9/` | CentOS 7.9 | 🟢 Running | 16 | 16 GB | 192.168.44.129 | ❌ No SSH creds |
| `/e/虚拟机/CentOS-7-PG/` | CentOS 7 (PG) | 🟢 Running | 8 | 8 GB | 192.168.44.142 | ❌ No SSH creds |
| `/e/虚拟机/OTB/` | CentOS 7 (OTB) | 🟢 Running | 8 | 8 GB | 192.168.44.149 | ❌ No SSH creds |
| `/e/虚拟机/TDSQL-1/` | CentOS 7 | ⚫ Off | 8 | 5 GB | — | ❌ |
| `/e/虚拟机/TDSQL-2/` | CentOS 7 | ⚫ Off | 8 | 5 GB | — | ❌ |
| `/e/虚拟机/TDSQL-3/` | CentOS 7 | ⚫ Off | ? | ? | — | ❌ |
| `/e/虚拟机/TpenTenBase/` | CentOS 7 | ⚫ Off | ? | ? | — | ❌ |
| `/e/虚拟机/cirros/` | Cirros | ⚫ Off | ? | ? | — | ❌ |
| `/e/VMware/123/` | CentOS 7 | ⚫ Off | ? | ? | — | ❌ |
| `/e/VMware/OpenStack/` | unknown | ⚫ Off | ? | ? | — | ❌ |
| `C:/.../CentOS 7 64 位/` | CentOS 7 | ⚫ Off | ? | ? | — | ❌ |
| `C:/.../CentOS 7 64位/` | CentOS 7 | ⚫ Off | ? | ? | — | ❌ |
| `C:/.../其他 Linux 5.x/` | Linux 5.x | ⚫ Off | ? | ? | — | ❌ |

### Access Blocker

All running VMs respond on port 22 (SSH) but require password
authentication. The ED25519 key in `~/.ssh/id_ed25519` is not
trusted by any of these VMs. Root passwords are unknown.

Resolution options:
1. Reset root password via single-user mode (requires VMware console)
2. Mount VM disk images and inject SSH public key
3. Rebuild VMs from ISO with known credentials
4. Use kickstart to automate VM provisioning with SSH key injection

---

## 8. TBase Offline RPM Mirror (Reference)

The `Centos7.tar.gz` (515 MB, 275 RPMs) is a real-world offline RPM
repository built for TBase (TDSQL PostgreSQL) on CentOS 7.

### 8.1 Repository Structure

```
Centos7/
├── tbase_mirror/           # RPM packages organized by category
│   ├── deploy/
│   │   ├── bison/          # 3 RPMs (bison, flex, m4)
│   │   ├── createrepo/     # 5 RPMs (createrepo + deps)
│   │   ├── docker/         # 62 RPMs (docker + selinux deps)
│   │   ├── gcc/            # 20 RPMs (gcc, glibc-devel, etc.)
│   │   ├── httpd/          # 5 RPMs (httpd)
│   │   ├── nss/            # 11 RPMs (nss crypto libs)
│   │   ├── ntp/            # 4 RPMs (ntp + deps)
│   │   ├── php/            # 14 RPMs (php + modules)
│   │   ├── postgres/       # 15 RPMs (pg-specific libs)
│   │   ├── python/         # 1 RPM
│   │   ├── stolon/         # 5 RPMs (PostgreSQL HA)
│   │   ├── tomcat/         # 52 RPMs (tomcat + java deps)
│   │   ├── utils/          # 67 RPMs (general utilities)
│   │   └── xz/             # 5 RPMs
│   └── repodata/           # createrepo-generated metadata
├── tbase_make_rpm/         # RPM build tools
├── tbase_mgr/              # Management tools (with config templates)
├── tbase_mgr_util/         # Management utilities
└── upgrade_cos/            # Upgrade scripts
```

### 8.2 repomd.xml Structure (createrepo format)

```xml
<repomd>
  <data type="primary">       → primary.xml.gz (package metadata)
  <data type="filelists">    → filelists.xml.gz (file paths)
  <data type="other">        → other.xml.gz (changelogs)
  <data type="primary_db">   → primary.sqlite.bz2 (fast query)
  <data type="filelists_db"> → filelists.sqlite.bz2
  <data type="other_db">     → other.sqlite.bz2
</repomd>
```

All checksums are SHA-256. No GPG signatures on the repo metadata
(consistent with our DEC-002). 275 packages, all CentOS 7 x86_64 RPMs.

### 8.3 Lessons for TXSQL

1. **Category-based organization** — TBase groups RPMs by function
   (build tools, runtime deps, database libs). Our repo can use a
   flat structure since `createrepo` handles indexing.

2. **createrepo on CentOS 7** — Uses `createrepo` (Python 2), NOT
   `createrepo_c` (C implementation). The command is:
   ```bash
   createrepo --database /path/to/repo/
   ```
   The `--database` flag generates SQLite metadata for faster yum queries.

3. **No GPG** — TBase mirror does NOT sign RPMs or repo metadata.
   This matches our DEC-002 to use SHA-256 only.

4. **275 RPMs for a complete offline repo** — TXSQL will likely need
   50-100 RPMs (fewer, since we don't include Docker, PHP, Tomcat, etc.)

5. **Dependency categories** — Build tools (gcc, bison, createrepo)
   are included alongside runtime deps. For TXSQL, we separate:
   - Build environment: devtoolset, cmake3, bison (build host only)
   - Runtime repo: only what install.sh needs (target host)

---

## 9. Fingerprint Collection Script

The script at `build/collect-fingerprints.sh` is ready for deployment.
It collects 10 categories of data and is safe (read-only).

When target systems become accessible, run:
```bash
scp build/collect-fingerprints.sh root@<target>:/tmp/
ssh root@<target> sudo bash /tmp/collect-fingerprints.sh --output /tmp/txsql-fp
scp -r root@<target>:/tmp/txsql-fp platforms/<platform-id>/fingerprints/
```

---

## 10. Summary of Gaps

| Platform | ISO Available | VM Available | Live Access | Fingerprint |
|----------|--------------|-------------|-------------|-------------|
| centos-7.9-x86_64 | ✅ Yes | ✅ Running | ❌ No creds | ⚠️ ISO-only |
| centos-7.8-x86_64 | ❌ No | ❌ None found | ❌ | ❌ None |
| tencentos-2.4-x86_64 | ❌ No | ❌ None found | ❌ | ❌ None |
| tencentos-3.1-x86_64 | ❌ No | ❌ None found | ❌ | ❌ None |
| kylin-v10-aarch64 | ❌ No | ❌ No aarch64 | ❌ | ❌ None |

All platforms remain **UNVERIFIED** per the project's strict test-gating
policy. The CentOS 7.9 ISO data provides an authoritative baseline for
package versions but does not substitute for live system fingerprinting.
