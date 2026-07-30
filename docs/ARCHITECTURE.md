# TXSQL Offline Deployment — Architecture

> **Version**: 1.0.0-draft
> **Date**: 2026-07-22
> **Status**: Architecture defined; implementation pending.

---

## 1. System Context

```
┌──────────────────────────────────────────────────────────────────────┐
│                        TXSQL-Packages Project                         │
│                                                                       │
│  ┌─────────────┐   ┌──────────────┐   ┌────────────────────────────┐ │
│  │ Source       │   │ Build        │   │ Distribution               │ │
│  │ Inspection   │──▶│ Pipeline     │──▶│ Pipeline                    │ │
│  │              │   │              │   │                             │ │
│  │ - TXSQL src  │   │ - per-plat   │   │ - per-platform .tar.gz     │ │
│  │ - cmake      │   │ - GCC/cmake  │   │ - all-platforms .tar.gz    │ │
│  │ - deps       │   │ - RPM build  │   │ - SHA256SUMS               │ │
│  └─────────────┘   │ - dep closure│   └────────────────────────────┘ │
│                     │ - local repo │                                   │
│                     └──────────────┘                                   │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ Installer                                                        │ │
│  │                                                                   │ │
│  │  install.sh                                                       │ │
│  │  ├── detect-platform.sh    (exact OS fingerprint match)          │ │
│  │  ├── select-payload.sh     (choose platform bundle)              │ │
│  │  ├── verify-media.sh       (SHA-256 check)                       │ │
│  │  ├── precheck.sh           (env validation, hard-fail on issues) │ │
│  │  ├── local-repository.sh   (configure file:// repo)              │ │
│  │  ├── packages.sh           (rpm/dnf install, no --nodeps)        │ │
│  │  ├── directories.sh        (create dirs, set perms)              │ │
│  │  ├── configuration.sh      (generate my.cnf)                     │ │
│  │  ├── initialization.sh     (mysqld --initialize-insecure)        │ │
│  │  ├── credentials.sh        (auto-gen password, secure storage)   │ │
│  │  ├── service.sh            (systemctl enable/start)              │ │
│  │  ├── healthcheck.sh        (verify running, check ELFs)          │ │
│  │  ├── sql-test.sh           (CRUD verification)                   │ │
│  │  └── rollback.sh           (cleanup on failure)                  │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layer Architecture

### Layer 0: Source Intelligence

```
build/inspect-source.sh
───────────────────────
Reads TXSQL source tree and extracts:
- TXSQL_BRANCH, TXSQL_COMMIT, TXSQL_VERSION
- GCC_VERSION minimum, CMAKE_VERSION minimum
- BOOST_VERSION, BOOST_DOWNLOAD_URL
- Build options (WITH_SSL, WITH_ZLIB, etc.)
- Plugin list (static vs dynamic)
- Bundled third-party versions

Output: build/source-profile.env
```

This layer runs ONCE per source commit.

### Layer 1: Platform Fingerprints

```
platforms/<id>/fingerprints/
─────────────────────────────
Static reference data collected from REAL target systems.
Used by both build system (to configure toolchain) and
installer (to detect platform at install time).

Each platform directory is immutable after collection.
```

### Layer 2: Build

```
build/build-txsql.sh
────────────────────
Compiles TXSQL from source on a build host matching the
target platform (or the lowest common denominator).

Input:  TXSQL source + source-profile.env
Output: build/output/<platform-id>/  (compiled tree)

build/build-rpm.sh
─────────────────
Packages compiled TXSQL into RPMs.

Input:  build/output/<platform-id>/ + packaging/rpm/*.spec
Output: RPMS/<platform-id>/txsql-{common,client,server}-*.rpm
```

### Layer 3: Dependency Resolution

```
build/inspect-elf.sh → build/resolve-dependencies.sh → build/collect-dependencies.sh
─────────────────────────────────────────────────────────────────────────────────────
5-layer dependency closure computation:

Layer 1: ELF scanning
  - file (identify ELF)
  - readelf -d (NEEDED entries)
  - objdump -p (shared lib deps)
  - ldd (dynamic linker resolution)
  Output: build/reports/<platform-id>/elf/*.txt

Layer 2: RPM Requires
  - rpm -qpR for each TXSQL RPM
  Output: build/reports/<platform-id>/rpm-requires.txt

Layer 3: Recursive resolution
  - repoquery --requires --resolve --recursive (yum)
  - dnf repoquery --requires --resolve --recursive (dnf)
  Output: build/reports/<platform-id>/dependency-closure.txt

Layer 4: Script command deps
  - Scan all installer/*.sh for external commands
  - rpm -qf $(which <cmd>) for each
  Output: build/reports/<platform-id>/script-commands.txt

Layer 5: Runtime dynamic deps
  - strace -f /proc/<pid>/maps LD_DEBUG=libs
  - Actual mysqld execution trace
  Output: build/reports/<platform-id>/runtime-deps.txt
```

### Layer 4: Local Repository

```
build/create-local-repo.sh
───────────────────────────
Assembles the platform-local RPM repository.

Input:  TXSQL RPMs + dependency RPM closure
Output: payloads/<platform-id>/repository/
        ├── txsql-common-*.rpm
        ├── txsql-client-*.rpm
        ├── txsql-server-*.rpm
        ├── <all transitive dependency RPMs>
        └── repodata/   (createrepo / createrepo_c)
```

### Layer 5: Bundling

```
build/build-platform-bundle.sh
───────────────────────────────
Creates the distributable offline tarball.

Input:  payloads/<platform-id>/ + installer/ + config/ + systemd/
Output: dist/txsql-offline-<version>-<platform-id>.tar.gz

build/build-universal-bundle.sh
────────────────────────────────
Aggregates verified platform payloads.

Input:  dist/*.tar.gz (all SUPPORTED platforms)
Output: dist/txsql-offline-<version>-all-supported-platforms.tar.gz
```

### Layer 6: Installation

```
installer/install.sh
────────────────────
The user-facing entry point.  Orchestrates all lib/ modules.

Must work with: sudo ./install.sh </dev/null
Must NOT: access internet, prompt user, use --nodeps
```

---

## 3. Data Flow

```
TXSQL Source ──┬──▶ inspect-source.sh ──▶ source-profile.env
               │
               └──▶ build-txsql.sh ──▶ compiled binaries
                           │
                           ▼
                    build-rpm.sh ──▶ TXSQL RPMs
                           │
                           ▼
                    inspect-elf.sh ──▶ ELF reports
                           │
                           ▼
                    resolve-dependencies.sh ──▶ dep list
                           │
                           ▼
                    collect-dependencies.sh ──▶ RPM closure
                           │
                           ▼
                    create-local-repo.sh ──▶ payloads/<id>/repository/
                           │
                           ▼
                    build-platform-bundle.sh ──▶ dist/*.tar.gz
                           │
                           ▼
                    [Transfer to target system]
                           │
                           ▼
                    installer/install.sh ──▶ Running TXSQL instance
```

---

## 4. Component Interfaces

### 4.1 Build Scripts (`build/*.sh`)

All build scripts source `build/common.sh` for:
- Logging functions (`log_info`, `log_warn`, `log_error`)
- Path constants (`TXSQL_BASEDIR`, etc.)
- Platform detection (for build host)
- Error handling (`set -euo pipefail`)

Each script accepts `--platform <id>` and `--output-dir <path>`.

### 4.2 Installer Modules (`installer/lib/*.sh`)

All installer modules source `installer/lib/common.sh` for:
- Logging (with timestamps, to both stdout and log file)
- State tracking (PLATFORM_MATCHED, MEDIA_VERIFIED, etc.)
- Error handling (trap-based cleanup)
- Path resolution

Modules are called sequentially by `install.sh`.  Each module:
1. Checks if its state marker is already set (idempotency)
2. Performs its function
3. Sets its state marker on success
4. On failure, calls `rollback.sh` to undo partial changes

### 4.3 State Markers

```
PLATFORM_MATCHED   → detect-platform.sh
MEDIA_VERIFIED     → verify-media.sh
PRECHECK_PASSED    → precheck.sh
PACKAGES_READY     → packages.sh
CONFIG_READY       → configuration.sh
DATADIR_READY      → initialization.sh
CREDENTIALS_READY  → credentials.sh
SERVICE_READY      → service.sh
SQL_READY          → sql-test.sh
```

Stored in `/var/lib/txsql/.install_state` (machine-readable).

---

## 5. Key Design Patterns

### 5.1 Phase-Based Sequential Execution

install.sh runs modules in strict sequence.  Each phase depends on the
previous.  No parallel execution within a single install.  This is
deliberate: database installation is inherently sequential, and parallel
operations would create race conditions.

### 5.2 Hard-Fail on Prechecks

Precheck failures are NOT warnings.  They immediately exit with a clear
error code and message.  The operator must resolve the issue and re-run.
This prevents partial installations that are hard to diagnose.

### 5.3 Idempotency Through State Markers

Each module checks its state marker before doing work.  If already set,
skip.  This enables safe re-execution of `install.sh`.

### 5.4 Clean Rollback on Failure

If any phase fails, `rollback.sh` is invoked to undo:
- Installed RPMs (rpm -e, preserving data)
- Created directories (if empty)
- Repository configuration
- Systemd unit enablement
State markers are cleared so re-install can proceed.

### 5.5 Platform Isolation

Platform-specific code is ONLY in:
- `platforms/<id>/platform.env` — platform metadata
- `platforms/<id>/fingerprints/` — reference fingerprints
- `installer/lib/detect-platform.sh` — the fingerprint database

All other code is platform-agnostic or parameterized by platform ID.

---

## 6. Directory Ownership & Permissions

```
/usr/lib/txsql/<version>/     root:root    0755   (RPM-owned)
/usr/lib/txsql/current/       root:root    0755   (symlink)
/etc/txsql/                   root:txsql   0750
/etc/txsql/my.cnf             root:txsql   0640
/etc/txsql/conf.d/            root:txsql   0750
/var/lib/txsql/               root:root    0755
/var/lib/txsql/data/          txsql:txsql  0750
/var/log/txsql/               txsql:txsql  0750
/run/txsql/                   txsql:txsql  0750   (tmpfs, created by systemd)
/root/.txsql_credentials      root:root    0600
```

---

## 7. Network Architecture (Install Time)

```
┌─────────────────────────────────────────┐
│  Target Host (air-gapped)                │
│                                          │
│  ┌──────────┐    ┌────────────────────┐  │
│  │ install.sh│───▶│ Local file:// repo │  │
│  └──────────┘    │ (from .tar.gz)     │  │
│       │          └────────────────────┘  │
│       │          ┌────────────────────┐  │
│       ├─────────▶│ yum/dnf (offline)  │  │
│       │          └────────────────────┘  │
│       │          ┌────────────────────┐  │
│       └─────────▶│ mysqld (Unix sock) │  │
│                  └────────────────────┘  │
│                                          │
│  ═══════════════════════════════════════ │
│  FIREWALL: NO outbound connections        │
│  All online repos disabled                │
│  Only file:// repo enabled                │
└─────────────────────────────────────────┘
```

---

## 8. Error Handling Strategy

| Error Class | Behavior | Exit Code |
|-------------|----------|-----------|
| Not root | Immediate exit, message to use sudo | 1 |
| Platform mismatch | Exit with fingerprint comparison | 10 |
| Architecture mismatch | Exit with arch error | 11 |
| SHA-256 failure | Exit, list failed files | 20 |
| Precheck failure | Exit with specific check name | 30-39 |
| RPM transaction failure | Rollback, exit with yum/dnf output | 40 |
| ELF not-found | Exit with missing libs list | 50 |
| Disk space | Exit with required/available | 60 |
| Port conflict | Exit with process info | 70 |
| MySQL/MariaDB running | Exit with process info | 71 |
| Initialize failure | Exit with mysqld error log | 80 |
| Service start failure | Exit with journalctl tail | 90 |
| SQL test failure | Exit with SQL error | 100 |

---

## 9. Future Extension Points

- **New platform**: Add `platforms/<new-id>/`, collect fingerprints, run tests.
- **Multi-version**: Version directories become `/usr/lib/txsql/<version>/`.
- **Multi-instance**: systemd template unit `txsql@.service`.
- **Online repo**: Add GPG signing, CDN distribution (like OpenTenBase).
- **DEB support**: Add `packaging/deb/` directory, adapt installer for APT.
- **Docker images**: Add `docker/` with build and runtime Dockerfiles.
