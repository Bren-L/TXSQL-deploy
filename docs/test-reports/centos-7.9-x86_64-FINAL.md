# TXSQL 8.0.30 CentOS 7.9 x86_64 — Final Acceptance Report

**Date**: 2026-07-23
**Acceptance VM**: 192.168.44.153

## Test Results: 22/22 PASSED

| # | Test | Result |
|---|------|--------|
| 1 | Air-gap offline install | PASS |
| 2 | RPM install | PASS |
| 3 | Database init | PASS |
| 4 | systemd start | PASS |
| 5 | /run/txsql auto-create | PASS |
| 6 | systemd enable | PASS |
| 7 | SQL VERSION() | PASS |
| 8 | SQL @@version_comment | PASS |
| 9 | SQL transactions | PASS |
| 10 | mysqldump | PASS |
| 11 | mysqladmin ping | PASS |
| 12 | LDD (0 not found) | PASS |
| 13 | SELinux Enforcing | PASS |
| 14 | Restart test | PASS |
| 15 | Idempotent reinstall | PASS |
| 16 | %config(noreplace) | PASS |
| 17 | Uninstall (preserve) | PASS |
| 18 | Reinstall (old data) | PASS |
| 19 | **REBOOT TEST** | **PASS** |
| 20 | Post-reboot auto-start | PASS |
| 21 | Post-reboot data | PASS |
| 22 | Post-reboot SELinux | PASS |

## Platform Status

```
PLATFORM_STATUS=SUPPORTED
OFFLINE_INSTALL_PASSED=1
REBOOT_PASSED=1
IDEMPOTENCY_PASSED=1
UNINSTALL_PASSED=1
```

## Final Package

- **File**: txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz
- **SHA-256**: cd691c86fa7c99becf88ed7d6de171cfcb777fc077b02032fd73ad6e9a31fb44
- **Size**: 102 MB

## RPMs

- txsql-8.0.30-3.el7.CANDIDATE.x86_64.rpm (3.8 KB)
- txsql-common-8.0.30-3.el7.CANDIDATE.x86_64.rpm (6.9 KB)
- txsql-client-8.0.30-3.el7.CANDIDATE.x86_64.rpm (27 MB)
- txsql-server-8.0.30-3.el7.CANDIDATE.x86_64.rpm (75 MB)

## Install Paths

- Binary: /usr/lib/txsql/current/bin/
- Data: /var/lib/txsql/data
- Config: /etc/txsql/my.cnf (%config noreplace)
- Logs: /var/log/txsql
- Credentials: /root/.txsql_credentials (0600)
