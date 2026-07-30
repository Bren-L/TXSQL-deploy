# CLAUDE.md — TXSQL Offline Deployment Project

## Project Identity

This project produces fully-offline, unattended-install TXSQL (Tencent's MySQL
fork) packages for multiple Chinese Linux operating systems.

**Target support matrix (Phase 1):**
- CentOS 7.9 x86_64 — ✅ RELEASE (8.0.30-4.el7)
- openEuler 22.03 LTS-SP3 x86_64 — ✅ RELEASE (8.0.30-1.0.0)
- CentOS 7.8 x86_64 — ⏳ 待开发
- TencentOS Server 2.4 x86_64 — ⏳ 待开发
- TencentOS Server 3.1 x86_64 — ⏳ 待开发
- Kylin Linux Advanced Server V10 aarch64 — ⏳ 待开发

## Core Principles

1. **Complete offline**: No internet access during install — ever.
2. **Unattended**: `sudo bash install.sh </dev/null` — zero prompts.
3. **Per-platform**: Each OS gets its own build, dependency closure, and test gate.
4. **System RPM management**: Use native yum/dnf, local repos, no `--nodeps`.
5. **Safe-by-default**: Never delete existing data; conflict → safe exit.
6. **Test-gated**: A platform is SUPPORTED only after real bare-metal/virt acceptance.
7. **Idempotent**: Detects existing data (auto.cnf), skips re-init.

## Never Use

- `rpm --nodeps`, `rpm --force`, `rpm --replacefiles`
- `yum --skip-broken`, `dnf --skip-broken`
- `kill -9` (except documented last-resort in uninstall)
- Unprotected `rm -rf`
- Automatic SELinux disabling
- Automatic firewall disabling
- `read` / interactive prompts during install

## Environment Status (2026-07-24)

### Available
- Windows 11 development workstation (Git Bash)
- Build VM: 192.168.44.151 (CentOS 7.9.2009 x86_64) — SSH alias `txsql-centos79-build`
- Acceptance VM: 192.168.44.153 (CentOS 7.9.2009 x86_64) — SSH alias `txsql-acceptance2`
- OpenEuler VM: 192.168.44.154 (openEuler 22.03 LTS-SP3 x86_64) — SSH key `C:/Users/20976/Desktop/TXSQL一键部署/.txsql_oe_key`
- TXSQL 8.0.30 source code (tarball extract, no .git, 117,155 files)
- SSH key for build host: `~/.ssh/txsql_centos79`
- SSH key for acceptance host: `~/.ssh/txsql_centos79_acceptance`
- GitHub repo: https://github.com/Bren-L/TXSQL-deploy

### NOT Available (must be resolved for future platforms)
- CentOS 7.8 test machine or image
- TencentOS Server 2.4 / 3.1 test machines or images
- Kylin V10 aarch64 test machine or image

## Phase Tracking

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Audit TXSQL source + OTB reference | ✅ DONE |
| 2 | Collect platform fingerprints | ✅ DONE (CentOS 7.9) |
| 3 | Determine source commit & toolchain | ✅ DONE (GCC 10.2.1, cmake3) |
| 4 | Build: x86_64 common binary | ✅ DONE (278MB mysqld, 63 min) |
| 5 | Kylin aarch64 build | ⏳ NOT STARTED |
| 6 | Generate RPMs | ✅ DONE (4 RPMs, 8.0.30-4.el7) |
| 7 | Compute dependency closures | ✅ DONE (CentOS 7.9) |
| 8 | Generate platform local repos | ✅ DONE (repodata + RPMs) |
| 9 | Generate platform offline bundles | ✅ DONE (102 MB tar.gz) |
| 10 | Implement installer | ✅ DONE (install.sh + lib/) |
| 11 | Per-platform offline acceptance | ✅ DONE (26/26 passed, incl. REBOOT) |
| 12 | GitHub Release | ✅ DONE (v8.0.30-1.0.0) |
| 13 | Expand to more platforms | 🔄 IN PROGRESS (openEuler ✅) |

## Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Install path | /usr/lib/txsql/current/ → 8.0.30 | Multi-version support via symlink |
| Runtime user | txsql:txsql | Dedicated non-root user |
| Private libs | lib/private/, RUNPATH $ORIGIN/../lib/private | Bundled lib isolation |
| OpenSSL | 3.4.1 bundled | CentOS 7 ships EOL 1.0.2k |
| Config protection | %config(noreplace) /etc/txsql/my.cnf | RPM upgrades won't clobber user config |
| Uninstall policy | Keep data/logs/config/credentials by default | Safe-by-default |
| Idempotency | Detect auto.cnf, skip re-init | Safe reinstall |
| SELinux | Never disable; stay Enforcing | Security compliance |

See docs/DECISIONS.md for full decision records with rationale.

## Build Commands

```bash
# On build host (192.168.44.151):
ssh txsql-centos79-build

# Build from TXSQL source
cd /opt/txsql-build
mkdir build && cd build
cmake3 /opt/TXSQL-8.0.30 -DWITH_BOOST=/opt/TXSQL-8.0.30/boost ...

# Generate RPMs
make -j$(nproc)
cmake --install . --prefix /opt/txsql-staging
# Use packaging/rpm/txsql.spec with rpmbuild

# Build offline bundle on Windows workstation:
make bundle PLATFORM=centos-7.9-x86_64
```

## Release Process

1. Build on CentOS 7.9 → produce RPMs
2. cmake --install → staging directory
3. ELF audit (check RPATH/RUNPATH, no build-dir references)
4. rpmbuild from spec → 4 RPMs
5. createrepo → local yum repository
6. Bundle installer scripts + RPMs + repodata → tar.gz
7. Acceptance: 22-item checklist on fresh VM
8. GitHub Release: upload tar.gz + SHA-256

## Current Release

- **Version**: v8.0.30-1.0.0
- **GitHub**: https://github.com/Bren-L/TXSQL-deploy/releases/tag/v8.0.30-1.0.0
- **Package**: txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz (102 MB)
- **SHA-256**: dbc2d23c6fedfc947f866144ff760ae4e8a646fcfece765ba88f947d7791cb4e
