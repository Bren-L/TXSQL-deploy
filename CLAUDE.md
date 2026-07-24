# CLAUDE.md — TXSQL Offline Deployment Project

## Project Identity

This project produces fully-offline, unattended-install TXSQL (Tencent's MySQL
fork) packages for multiple Chinese Linux operating systems.

**Target support matrix (Phase 1):**
- CentOS 7.8 x86_64
- CentOS 7.9 x86_64
- TencentOS Server 2.4 x86_64
- TencentOS Server 3.1 x86_64
- Kylin Linux Advanced Server V10 aarch64 (specific SP TBD)

## Core Principles

1. **Complete offline**: No internet access during install — ever.
2. **Unattended**: `sudo ./install.sh </dev/null` — zero prompts.
3. **Per-platform**: Each OS gets its own build, dependency closure, and test gate.
4. **System RPM management**: Use native yum/dnf, local repos, no `--nodeps`.
5. **Safe-by-default**: Never delete existing data; conflict → safe exit.
6. **Test-gated**: A platform is SUPPORTED only after real bare-metal/virt acceptance.

## Never Use

- `rpm --nodeps`, `rpm --force`, `rpm --replacefiles`
- `yum --skip-broken`, `dnf --skip-broken`
- `kill -9` (except documented last-resort in uninstall)
- Unprotected `rm -rf`
- Automatic SELinux disabling
- Automatic firewall disabling
- `read` / interactive prompts during install

## Environment Status (2026-07-22)

### Available
- OpenTenBase-Packages reference project (analyzed — see docs/OTB_REFERENCE_ANALYSIS.md)
- Windows 11 development workstation (Git Bash)

### NOT Available (must be resolved)
- TXSQL source code (path not provided, not found locally)
- CentOS 7.8 / 7.9 test machines or images
- TencentOS Server 2.4 / 3.1 test machines or images
- Kylin V10 aarch64 test machine or image

### Implications
- All code can be written and reviewed, but NO platform can be marked SUPPORTED.
- Platform fingerprints cannot be collected from real systems.
- Build scripts cannot be tested against actual TXSQL source.
- See docs/PLATFORM_MATRIX.md for per-platform status.

## Phase Tracking

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Audit TXSQL source + OTB reference | IN PROGRESS |
| 2 | Collect platform fingerprints | BLOCKED (no target systems) |
| 3 | Determine source commit & toolchain | BLOCKED (no TXSQL source) |
| 4 | Verify x86 common build feasibility | NOT STARTED |
| 5 | Kylin aarch64 build | NOT STARTED |
| 6 | Generate RPMs | NOT STARTED |
| 7 | Compute dependency closures | NOT STARTED |
| 8 | Generate platform local repos | NOT STARTED |
| 9 | Generate platform offline bundles | NOT STARTED |
| 10 | Implement installer | NOT STARTED |
| 11 | Per-platform offline acceptance | NOT STARTED |
| 12 | Multi-platform bundle | NOT STARTED |
| 13 | Final security audit & release | NOT STARTED |

## Key Decisions Log

See docs/DECISIONS.md — every non-obvious choice is recorded there with rationale.

## Build Commands (to be validated)

```bash
# Validate project structure
make validate

# Build for a specific platform (requires build host)
make build PLATFORM=centos-7.8-x86_64

# Build all supported platforms
make build-all

# Run acceptance tests (requires target VM)
make test PLATFORM=centos-7.8-x86_64

# Generate offline bundle
make bundle PLATFORM=centos-7.8-x86_64
```
