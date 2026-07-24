# Installation Guide

> **Status**: SPECIFICATION — installer not yet built.
> **Date**: 2026-07-22

---

## Quick Install

```bash
# Unpack the offline bundle
tar xzf txsql-offline-<version>-<platform-id>.tar.gz
cd txsql-offline-<version>-<platform-id>/

# Run the installer (no internet, no prompts)
sudo ./install.sh </dev/null
```

On success, TXSQL is running with:
- Port 3306 (configurable via `--port`)
- User `txsql`
- Data at `/var/lib/txsql/data`
- Credentials at `/root/.txsql_credentials`

---

## Custom Options

```bash
sudo ./install.sh \
  --port 3307 \
  --data-dir /data/txsql \
  --log-dir /var/log/txsql \
  --socket /run/txsql/mysql.sock
```

Note: All options are passed at invocation time.  The installer does not
prompt for input.

---

## What Gets Installed

| Component | Location |
|-----------|----------|
| Server binary | `/usr/lib/txsql/current/bin/mysqld` |
| Client tools | `/usr/lib/txsql/current/bin/mysql*` |
| Configuration | `/etc/txsql/my.cnf` |
| Data directory | `/var/lib/txsql/data` |
| Logs | `/var/log/txsql/` |
| Runtime files | `/run/txsql/` |
| Systemd service | `/usr/lib/systemd/system/txsql.service` |
| Credentials | `/root/.txsql_credentials` |

---

## Post-Install

```bash
# Check service status
systemctl status txsql

# Connect to MySQL
sudo cat /root/.txsql_credentials
mysql -u root -p -S /run/txsql/mysql.sock

# View logs
journalctl -u txsql -f
tail -f /var/log/txsql/error.log
```

---

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
