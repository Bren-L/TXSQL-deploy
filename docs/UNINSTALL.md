# Uninstall Guide

> **Status**: SPECIFICATION — uninstaller not yet built.
> **Date**: 2026-07-22

---

## Default Uninstall (Preserves Data)

```bash
sudo ./uninstall.sh
```

This removes:
- TXSQL RPM packages
- Systemd service
- Local repository configuration
- Temporary installation files

This preserves:
- `/var/lib/txsql/data` — all databases
- `/etc/txsql/` — configuration
- `/var/log/txsql/` — logs
- `/root/.txsql_credentials` — credentials

---

## Purge Uninstall (Removes Data)

```bash
sudo ./uninstall.sh --purge-data
```

This additionally removes:
- `/var/lib/txsql/data` — all databases (**IRREVERSIBLE**)
- `/var/log/txsql/` — all logs
- `/root/.txsql_credentials` — credentials

`--purge-data` does not prompt for confirmation if run non-interactively.
It validates all paths before deletion (prevents deleting `/`, `/var`, etc.)

---

## Reinstall After Uninstall

Default uninstall preserves data, so re-running `install.sh` will:
1. Detect existing data directory
2. Skip database initialization
3. Reinstall packages and service
4. Use existing configuration (if compatible)

---

## Manual Cleanup

If the uninstaller is not available:

```bash
# Stop service
systemctl stop txsql
systemctl disable txsql

# Remove packages
rpm -e txsql-server txsql-client txsql-common

# Remove repo config
rm -f /etc/yum.repos.d/txsql-offline.repo

# Optional: remove data (CAREFUL!)
# rm -rf /var/lib/txsql/data
```
