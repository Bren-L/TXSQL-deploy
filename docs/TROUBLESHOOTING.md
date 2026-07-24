# Troubleshooting

> **Status**: PRELIMINARY — based on expected issues, not field data.
> **Date**: 2026-07-22

---

## Common Issues

### "Platform not supported" error

**Symptom**: `detect-platform.sh` exits with platform mismatch.

**Cause**: The target OS does not match any known fingerprint.

**Fix**:
1. Check `/etc/os-release` and compare with expected values in `docs/PLATFORM_FINGERPRINTS.md`
2. If this is a supported platform variant, collect fingerprints and add to the database
3. Do NOT use `--force-platform` (not implemented in Phase 1)

### "SHA-256 verification failed"

**Symptom**: `verify-media.sh` reports checksum mismatch.

**Cause**: File corruption during transfer or tampering.

**Fix**:
1. Re-transfer the bundle (use `rsync -c` or verify checksums after transfer)
2. If the issue persists, re-download or re-build the bundle
3. Check storage media for errors

### "Dependency resolution failed"

**Symptom**: `yum install` reports missing dependencies.

**Cause**: Incomplete dependency closure in the local repository.

**Fix**: This should not happen in a properly built bundle.  Report the
missing dependencies and rebuild with an updated closure.

### "mysqld fails to start"

**Symptom**: `systemctl start txsql` fails or times out.

**Fix**:
```bash
# Check error log
journalctl -u txsql -n 100
tail -100 /var/log/txsql/error.log

# Check if port is in use
ss -tlnp | grep 3306

# Check SELinux denials
ausearch -m avc -ts recent

# Check file permissions
ls -la /var/lib/txsql/data/
ls -la /etc/txsql/
```

### "Library not found" errors

**Symptom**: `ldd /usr/lib/txsql/current/bin/mysqld` shows "not found".

**Cause**: Missing runtime dependency.

**Fix**: This indicates a build problem.  The dependency closure computation
should have caught this.  Report the missing library and investigate the
build pipeline.

---

## Log Locations

| Component | Log Location |
|-----------|-------------|
| Installer | `/var/log/txsql/install.log` |
| MySQL error | `/var/log/txsql/error.log` |
| MySQL general | `/var/log/txsql/general.log` (if enabled) |
| Slow query | `/var/log/txsql/slow.log` (if enabled) |
| systemd | `journalctl -u txsql` |
| SELinux AVC | `ausearch -m avc -ts recent` |
| RPM transactions | `/var/log/yum.log` or `dnf.log` |

---

## Getting Help

1. Check this document first
2. Check `docs/PLATFORM_MATRIX.md` for platform-specific known issues
3. Review `DECISIONS.md` for design rationale
4. Check the installer log at `/var/log/txsql/install.log`
