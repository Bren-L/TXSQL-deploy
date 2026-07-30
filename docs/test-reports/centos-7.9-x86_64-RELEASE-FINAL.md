# TXSQL 8.0.30 CentOS 7.9 x86_64 — RELEASE FINAL Acceptance Report

**Date**: 2026-07-23
**Acceptance VM**: 192.168.44.153 (fresh from snapshot `00-clean-centos79-minimal`)

---

## Release Package

| Item | Value |
|------|-------|
| **File** | `txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz` |
| **SHA-256** | `dbc2d23c6fedfc947f866144ff760ae4e8a646fcfece765ba88f947d7791cb4e` |
| **Size** | 102 MB |
| **Status** | **RELEASE** |

## Formal RPMs (8.0.30-4.el7, no CANDIDATE)

| RPM | Size | NEVRA |
|-----|------|-------|
| txsql | 3.7 KB | txsql-8.0.30-4.el7.x86_64 |
| txsql-common | 6.8 KB | txsql-common-8.0.30-4.el7.x86_64 |
| txsql-client | 27 MB | txsql-client-8.0.30-4.el7.x86_64 |
| txsql-server | 75 MB | txsql-server-8.0.30-4.el7.x86_64 |

---

## Acceptance Test Results: 22/22 PASSED

| # | Test | Result | Details |
|---|------|--------|---------|
| 1 | Baseline (clean) | PASS | No TXSQL/MySQL, CentOS 7.9.2009, x86_64 |
| 2 | Tarball SHA-256 | PASS | Build=Acceptance: `dbc2d23c...` |
| 3 | Air-gap confirmed | PASS | yum repolist=0 |
| 4 | Unattended install | PASS | Exit 0, < 3 min |
| 5 | RPM transaction | PASS | 4 RPMs, 8.0.30-4.el7 |
| 6 | DB initialization | PASS | mysqld --initialize |
| 7 | systemd start | PASS | active, txsql:txsql user |
| 8 | /run/txsql auto-created | PASS | RuntimeDirectory=txsql |
| 9 | Socket | PASS | /var/lib/txsql/mysql.sock |
| 10 | Credentials 0600 | PASS | /root/.txsql_credentials |
| 11 | SELinux Enforcing | PASS | No AVCs |
| 12 | SELECT VERSION() | PASS | 8.0.30-txsql |
| 13 | SELECT @@version_comment | PASS | 20221230 |
| 14 | Transaction (INSERT/UPDATE/COMMIT) | PASS | InnoDB, 3 rows |
| 15 | mysqldump | PASS | Non-empty output |
| 16 | mysqladmin ping | PASS | "mysqld is alive" |
| 17 | LDD all ELFs (0 not found) | PASS | Router symlinks working |
| 18 | systemctl restart | PASS | Data persisted |
| 19 | Idempotent reinstall | PASS | Data/Creds/UUID unchanged |
| 20 | %config(noreplace) | PASS | Custom comment preserved |
| 21 | Uninstall (data preserved) | PASS | 4 dirs preserved, RPMs removed |
| 22 | Reinstall (old data) | PASS | Old data recognized, no re-init |
| **23** | **REBOOT** | **PASS** | boot_id changed: `4cb36ad8` → `642663a7` |
| **24** | Auto-start after reboot | **PASS** | enabled + active |
| **25** | Post-reboot data | **PASS** | 3 rows, UUID unchanged |
| **26** | Post-reboot SELinux | **PASS** | Enforcing, no AVCs |

## Final Status

```
PACKAGE_STATUS=RELEASE
PLATFORM_STATUS=SUPPORTED
OFFLINE_INSTALL_PASSED=1
REBOOT_PASSED=1
IDEMPOTENCY_PASSED=1
UNINSTALL_PASSED=1
```

## Acceptance Machine

| Item | Value |
|------|-------|
| OS | CentOS Linux release 7.9.2009 (Core) |
| Kernel | 3.10.0-1160.el7.x86_64 |
| Arch | x86_64 |
| SELinux | Enforcing |
| Memory | 7.8 GB |
| Disk | 44 GB |

## Build Information

| Item | Value |
|------|-------|
| Source | Tarball, no .git |
| GIT_COMMIT | unknown |
| SOURCE_VERSION | 8.0.30 |
| Compiler | GCC 10.2.1 (devtoolset-10) |
| Build type | RelWithDebInfo |
| GLIBC | 2.17 |
| OpenSSL | 3.4.1 (bundled) |
| Target | centos-7.9-x86_64 |

Planned=22 | Executed=22 | Passed=22 | Failed=0 | NotRun=0
