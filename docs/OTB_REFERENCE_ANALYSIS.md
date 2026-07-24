# OpenTenBase Packages — Reference Analysis

> **Source**: OpenTenBase-Packages-main.zip (unzipped 2026-07-22)
> **Repository**: https://github.com/CDUESTC-OpenAtom-Open-Source-Club/OpenTenBase-Packages
> **Analyzed version**: v5.0-p32 (latest in zip)

---

## 1. Executive Summary

OpenTenBase-Packages is a **packaging recipe repository** — it contains build
recipes, CI workflows, configs, and scripts, but NOT the compiled .deb/.rpm
files.  Build artifacts are published to GitHub Releases (150-200+ files per
release) and distributed via Cloudflare CDN (`repo.blackevil217.com`).

The project is an excellent reference for TXSQL packaging because it solves the
exact same problem class: **multi-distro, multi-arch, offline-capable database
packaging with system-native package management**.

---

## 2. Architecture Patterns Worth Adopting

### 2.1 Packaging Recipe Repository

```
Git Repo (recipes) ──CI──→ GitHub Releases (artifacts) ──CDN──→ Users
```

**Our adaptation**: Same pattern.  Git repo holds build scripts, configs,
installer source.  CI (or manual build) produces platform bundles.  Bundles
are distributed as .tar.gz for offline installation.

### 2.2 OS Detection Pattern

`scripts/setup-rpm.sh` uses a tiered detection:

```bash
. /etc/os-release

case "$ID" in
    rocky|almalinux|centos|rhel|opencloudos|anolis|tencentos)
        case "$VERSION_ID" in
            8*|9*) REPO_SUBDIR="el${VERSION_ID%%.*}" ;;
            *)     REPO_SUBDIR="el9" ;;  # fallback with warning
        esac
        ;;
    fedora)      REPO_SUBDIR="fedora" ;;
    openeuler|hce) REPO_SUBDIR="openeuler" ;;
    *)
        # ID_LIKE fallback for unknown RHEL-compatible distros
        if echo "$ID_LIKE" | grep -qiE "rhel|fedora|centos"; then
            ...
        else
            log_error "Unsupported distribution: $ID"
            exit 1
        fi
        ;;
esac
```

**Our adaptation**: We need STRICTER detection.  OpenTenBase uses a soft
fallback ("untested, using el9 repo"); we must HARD FAIL on unknown platforms
because TXSQL binaries are compiled against a specific glibc/libstdc++ and
a wrong match will segfault or fail to load plugins.

### 2.3 Script-Driven Architecture

OpenTenBase's one-liner install (`curl | bash`) is designed for online use.
Our project must adapt this for OFFLINE:

| OpenTenBase | Our TXSQL |
|-------------|-----------|
| Online-only `curl | bash` | Offline `.tar.gz` with `./install.sh` |
| Auto-detect fastest CDN mirror | SHA-256 verify bundled media |
| Download packages from repo | Install from local file:// repository |
| GPG signature verification | SHA-256 checksum verification |
| Interactive prompts in some scripts | Zero interaction `/dev/null` |

### 2.4 RPM Packaging Strategy

OpenTenBase RPM spec (`rpm/opentenbase.spec`) is a SINGLE spec producing
6 sub-packages (metapackage, server, client, contrib, dev, doc) via
`%package` directives.  This is the standard RPM way for multi-binary projects.

**Our adaptation**: We need 3 packages (common, client, server) similar to
MySQL's official RPM layout.  Using `%package` in a single spec is cleaner
than 3 separate specs, but 3 specs allow independent versioning.

### 2.5 Dependency Management

OpenTenBase handles dependencies with:

1. **`%global __requires_exclude`** — filters false-positive RPM auto-detected deps
2. **Bundle critical libs** — libssh2, libpqxx bundled in `%{otb_prefix}/lib/`
3. **RPATH** — binaries link to private libs via RPATH, not LD_LIBRARY_PATH
4. **Source build fallback** — if system libpqxx is too old, build from source during RPM build

**Our adaptation**: Same approach but more rigorous:
- Must compute full dependency closure (5-layer model)
- Must verify every ELF has all libraries resolved
- Must not use `%global __requires_exclude` to hide real missing deps

### 2.6 CI/CD Pipeline

OpenTenBase uses GitHub Actions with 12 workflows:
- `build-deb.yml` (17KB) — 21 amd64 + 21 arm64 jobs
- `build-rpm.yml` (18KB) — 27 x86_64 + 27 aarch64 jobs
- `release.yml` — aggregates artifacts → GPG sign → GitHub Release
- `deploy-repo.yml` — GitHub Pages + CDN sync
- `test.yml` / `test-all.yml` / `stress-test.yml` — 3-tier testing

**Our adaptation**: We need CI for build verification, but the OFFLINE
acceptance tests MUST run on real VMs, not just Docker containers (for
systemd and OS integration testing).

---

## 3. Detailed Component Analysis

### 3.1 RPM Spec Deep Dive

File: `rpm/opentenbase.spec`

Key patterns:
```spec
Name:           opentenbase
Version:        %{!?otb_version:5.0}%{?otb_version}
Release:        1

# Disable problematic Fedora build macros
%undefine _annotated_build
%undefine _hardened_build
%undefine _lto_cflags

# Filter false-positive deps from RPM auto-detection
%global __requires_exclude ^libc\\.so\\.6\\(GLIBC_PRIVATE\\)|libssh2|libpq\\.so\\.5\\(RHPG|libpq\\.so\\.5$

BuildRequires: gcc gcc-c++ make bison flex perl cmake
BuildRequires: readline-devel zlib-devel openssl-devel pam-devel
BuildRequires: libxml2-devel openldap-devel libuuid-devel
BuildRequires: libcurl-devel lz4-devel
```

**Lessons for TXSQL**:
- `%undefine` directives may be needed on newer Fedora/RHEL derivatives
- BuildRequires must be platform-tested (some packages have different names on CentOS 7 vs TencentOS 3)
- `__requires_exclude` should be used sparingly and documented

### 3.2 Installer Script Pattern

File: `scripts/setup-rpm.sh`

The script follows a clean phase pattern:
1. `check_root` — early guard
2. `detect_os` — platform identification
3. `detect_mirror` — online only (we skip this for offline)
4. `add_gpg_key` — online only (we use SHA-256)
5. `configure_repo` — we adapt for local file:// repo
6. `update_cache` — `dnf makecache` or `yum makecache`
7. `install_libpqxx_dependency` — handle special deps
8. `show_install_info` — summary

**Our adaptation**: This clean phase structure is EXACTLY what we need for
`installer/install.sh`.  Each phase maps to a `lib/` module:
- `lib/detect-platform.sh`
- `lib/precheck.sh`
- `lib/select-payload.sh`
- `lib/verify-media.sh`
- `lib/local-repository.sh`
- `lib/packages.sh`
- `lib/directories.sh`
- `lib/configuration.sh`
- `lib/initialization.sh`
- `lib/credentials.sh`
- `lib/service.sh`
- `lib/healthcheck.sh`
- `lib/sql-test.sh`

### 3.3 Uninstall Pattern

File: `scripts/uninstall.sh`

Phases:
1. Stop processes (graceful → force)
2. Remove packages (rpm -e / apt-get remove)
3. Remove repo configuration
4. Remove config directory
5. Optional: remove data and logs (`--purge`)
6. Optional: remove legacy directories

**Key design choice**: Default preserves data.  `--purge` deletes data.
This is exactly our requirement.

Our `uninstall.sh` should mirror this but be simpler (no online repos, no sshpass).

### 3.4 Docker Testing Strategy

OpenTenBase uses Docker for CI testing but acknowledges its limitations:
- Docker tests for package installation verification
- Real hardware/VMs for systemd integration, OS compatibility
- ARM64 native build on real hardware (Huawei Cloud HCE 2.0), not QEMU

**Our adaptation**: Same hybrid approach.  Docker for fast build/test cycles.
Real VMs for final systemd + OS integration acceptance.

### 3.5 Platform Matrix (from CHANGELOG & TEST-PLAN)

OpenTenBase currently supports:

| DEB (x86_64) | RPM (x86_64) | RPM (aarch64) |
|--------------|-------------|---------------|
| Ubuntu 20.04/22.04/24.04/25.04 | Rocky 8/9 | EulerOS 2.0 |
| Debian 11/12/13 | AlmaLinux 8/9 | Rocky 9 (Docker) |
| | CentOS Stream 8/9 | openEuler 24.03 (Docker) |
| | Fedora 40 | HCE 2.0 |
| | openEuler 22.03 | |

Note: **CentOS 7 is NOT in their matrix** — they target EL8/9 only.

---

## 4. Architecture Diagram (OTB → TXSQL Mapping)

```
OpenTenBase-Packages                    TXSQL-Packages (our project)
══════════════════════                  ════════════════════════════

debian/                                 packaging/rpm/  (RPM-only for Phase 1)
├─ control                             ├─ txsql-common.spec
├─ rules                               ├─ txsql-client.spec
├─ *.install                           └─ txsql-server.spec
└─ *.postinst/prerm                     
                                        
rpm/                                    build/
├─ opentenbase.spec                    ├─ common.sh
└─ build-rpm.sh                        ├─ inspect-source.sh
                                        ├─ build-txsql.sh
scripts/                               ├─ build-rpm.sh
├─ setup-apt.sh    ──online──→         ├─ inspect-elf.sh
├─ setup-rpm.sh    ──online──→         ├─ resolve-dependencies.sh
├─ opentenbase.sh  ──online──→         ├─ collect-dependencies.sh
├─ uninstall.sh    ──keep──→           ├─ create-local-repo.sh
└─ switch-version.sh                   ├─ build-platform-bundle.sh
                                        └─ build-universal-bundle.sh
config/
├─ *.conf.template                     config/
└─ v5.0/ v2.6.0/ v2.5.0/              ├─ my.cnf.tpl
                                        ├─ bootstrap.cnf.tpl
                                        └─ conf.d/user.cnf.example
systemd/
└─ opentenbase@.service                systemd/
                                        └─ txsql.service
test/                                   tests/
├─ smoke-test.sh                       ├─ common/
├─ multi-node-test.sh                  ├─ platform/
├─ version-switch-test.sh              ├─ acceptance/
├─ docker-e2e-test.sh                  └─ destructive/
└─ advanced/ (5 suites)
                                       
.github/workflows/                     (future CI)
├─ build-deb.yml                       (GitHub Actions or internal CI)
├─ build-rpm.yml
├─ release.yml
└─ test*.yml

docker/                                (future Docker support)
├─ Dockerfile                          (for build container)
├─ build/ (7 distro Dockerfiles)      (for build isolation)
└─ runtime/ (14 runtime Dockerfiles)  (for smoke tests)

                                       
──ONLINE FEATURES (we skip)──→         ──OFFLINE ONLY──
GPG signing                            SHA-256 verification
CDN distribution                       .tar.gz distribution
curl|bash install                      ./install.sh from media
Auto-detect mirror                     Local file:// repo only
```

---

## 5. Key Design Decisions We Inherit

| Decision | OTB Approach | Our Adaptation |
|----------|-------------|----------------|
| Multi-version coexistence | `/usr/lib/opentenbase/{version}/` | `/usr/lib/txsql/{version}/` with `current` symlink |
| User isolation | `opentenbase` system user | `txsql` system user |
| Config layout | `/etc/opentenbase/{version}/` | `/etc/txsql/my.cnf` + `conf.d/` |
| Data layout | `/var/lib/opentenbase/{version}/` | `/var/lib/txsql/data/` |
| Log layout | `/var/log/opentenbase/` | `/var/log/txsql/` |
| Bundle deps | libpqxx, libssh2 in private lib | Determined per dependency closure |
| RPATH | `$ORIGIN/../lib` | `$ORIGIN/../lib/private` for private libs |
| Systemd | `opentenbase@.service` (templated) | `txsql.service` (single instance) |
| Init strategy | `opentenbase_ctl` (C++, cluster-aware) | `mysqld --initialize-insecure` (standard MySQL) |
| Password mgmt | Admin configured manually | Auto-generated, stored to `/root/.txsql_credentials` |

---

## 6. What We Do Differently

### 6.1 Offline-First (vs OTB's Online-First)

OTB assumes online access for GPG key fetch, package download, and CDN
mirror selection.  We must pre-bundle EVERYTHING.

### 6.2 Strict Platform Matching (vs OTB's Soft Fallback)

OTB uses "EL9" as a catch-all for any RHEL 9 derivative.  We must match
exact platform IDs because:
- glibc versions differ between CentOS 7.8 and 7.9
- libstdc++ ABI differs between TencentOS 2.4 and 3.1
- Kylin V10 has different SP levels with different library sets

### 6.3 Full Dependency Closure (vs OTB's Selective Bundling)

OTB bundles libssh2 and libpqxx but relies on system packages for most
other deps.  We must compute and verify the FULL closure, including
transitive dependencies of all bundled RPMs.

### 6.4 No `--nodeps` Fallback

OTB's RPM install falls back to `rpm --nodeps` when dnf rejects RHPG
symbol dependencies.  We must NEVER use `--nodeps` — the dependency
closure must be complete beforehand.

### 6.5 SHA-256 Instead of GPG

OTB uses GPG signing with pinned key fingerprints for authenticity.
For offline-only distribution where the entire medium is trusted,
SHA-256 integrity verification is sufficient and avoids GPG key
management complexity.

---

## 7. Files Worth Directly Studying

These OTB files provide patterns we can adapt:

| File | What to Learn |
|------|---------------|
| `scripts/setup-rpm.sh` | OS detection, repo config, package install flow |
| `scripts/uninstall.sh` | Graceful shutdown, package removal, data preservation |
| `rpm/opentenbase.spec` | Multi-subpackage RPM, `%files`, `%post`/`%preun` scripts |
| `rpm/build-rpm.sh` | RPM build orchestration, tarball prep |
| `debian/rules` | Build recipe for Debian packages |
| `.github/workflows/build-rpm.yml` | Multi-distro build matrix |
| `docker/build/` | Dockerfiles for each build distro |
| `test/smoke-test.sh` | Package verification |
| `test/advanced/` | SQL acceptance patterns |
| `config/*.conf.template` | Config template patterns |
| `systemd/opentenbase@.service` | systemd unit patterns |

---

## 8. Gaps in OTB Reference (Not Applicable to Us)

OTB includes features we explicitly do NOT need:
- Multi-version coexistence (Phase 1: single version only)
- Cluster management (`opentenbase_ctl` for GTM+CN+DN)
- SSH setup / sshpass (no multi-machine in Phase 1)
- libssh2 bundling (MySQL doesn't use SSH)
- libpqxx bundling (MySQL uses libmysqlclient, not libpqxx)
- Multi-node deployment (Phase 1: single instance only)

---

## 9. Platform Coverage Comparison

| Platform | OTB Status | Our Phase 1 Target |
|----------|-----------|-------------------|
| CentOS 7.8 | ❌ Not supported | ✅ Target |
| CentOS 7.9 | ❌ Not supported | ✅ Target |
| Rocky 8/9 | ✅ Supported | ❌ Not targeted (yet) |
| TencentOS 2.4 | Not listed | ✅ Target |
| TencentOS 3.1 | Not listed | ✅ Target |
| Kylin V10 aarch64 | Not listed | ✅ Target |
| EulerOS/HCE | ✅ Supported | ❌ Not targeted (yet) |
| openEuler 22.03 | ✅ Supported | ❌ Not targeted (yet) |

This is a significant gap — **CentOS 7 and Kylin V10 are not in OTB's matrix**.
We must independently verify:
- Whether MySQL 8.0 / TXSQL can compile on CentOS 7's GCC 4.8.5
- Whether devtoolset is needed for GCC 7+ on CentOS 7
- Kylin V10's RPM ABI compatibility
- Kylin V10's systemd version and service semantics

---

## 10. Risk Register

| # | Risk | Likelihood | Impact | Mitigation |
|---|------|-----------|--------|------------|
| 1 | CentOS 7 GCC too old for TXSQL | High | Build failure | devtoolset-7/8/9 or custom GCC |
| 2 | CentOS 7 glibc 2.17 incompatibility | Medium | Runtime crash | Must compile on CentOS 7, not newer |
| 3 | Kylin V10 non-standard RPM layout | Medium | Install failure | Fingerprints must be collected first |
| 4 | TencentOS custom package names | Medium | Dep resolution failure | Platform-specific package name mapping |
| 5 | TXSQL ColumnStore needs newer libs | Low | Build failure | Feature-gate if needed |

---

## 11. Key Takeaway

The OpenTenBase-Packages project demonstrates a PROVEN multi-platform
database packaging approach.  We inherit its:

- Clean phase-based script architecture
- Platform detection patterns (with stricter matching)
- RPM multi-subpackage design
- Data preservation defaults
- Graceful shutdown → force pattern

We diverge on:
- Offline-first (no CDN, no GPG, no curl|bash)
- Stricter platform matching (exact match, no fallback)
- Full dependency closure computation
- SHA-256 instead of GPG
- MySQL/TXSQL specifics (no cluster management, no sshpass)
