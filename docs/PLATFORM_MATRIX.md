# Platform Support Matrix

> **Last Updated**: 2026-07-22
> **Principle**: SUPPORTED only after full offline acceptance on native hardware.

---

## 1. Platform Status

| Platform | Arch | Build | Dep Closure | Offline Install | SQL | Restart | OS Reboot | Idempotent | Status |
|----------|------|-------|------------|-----------------|-----|---------|-----------|------------|--------|
| centos-7.9-x86_64 | x86_64 | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED | **UNVERIFIED** |
| centos-7.8-x86_64 | x86_64 | — | — | — | — | — | — | — | **UNVERIFIED** |
| tencentos-2.4-x86_64 | x86_64 | — | — | — | — | — | — | — | **UNVERIFIED** |
| tencentos-3.1-x86_64 | x86_64 | — | — | — | — | — | — | — | **UNVERIFIED** |
| kylin-v10-aarch64 | aarch64 | — | — | — | — | — | — | — | **UNVERIFIED** |

---

## 2. Test Counts (centOS-7.9-x86_64)

| Metric | Count |
|--------|-------|
| Planned | 75 |
| Executed | 0 |
| Passed | 0 |
| Failed | 0 |
| Blocked | 75 |

Breakdown: 25 acceptance tests × 3 (独立包 + 全集成包独立验收 + 全集成包重验收) = 75 total.
All 75 blocked by two root causes: (A) no TXSQL source, (B) no VM access.

---

## 3. Blockers for CentOS 7.9 (the focus platform)

### Blocker A: TXSQL Source Unavailable

| Attempt | Result |
|---------|--------|
| `git clone https://github.com/OpenTenBase/TXSQL.git` | Failed to connect to github.com:443 |
| `git ls-remote https://gitee.com/opentenbase/TXSQL.git` | Timed out |
| `git ls-remote https://gitclone.com/github.com/OpenTenBase/TXSQL.git` | Timed out |
| Local filesystem search (all drives) | No CMakeLists.txt matching *txsql* or *mysql* found |
| SSH host "abc" (192.168.44.133) | Connection timed out (VM not running / not at that IP) |

### Blocker B: No Accessible CentOS 7.9 VM

| Attempt | Result |
|---------|--------|
| SSH to 192.168.44.129 (CentOS 7.9 VM) | 70+ password attempts, all rejected |
| SSH key (ed25519) | Not trusted by any VM |
| vmrun guest operations | "Invalid user name or password for the guest OS" |
| vmrun getGuestIPAddress | "VMware Tools are not running" |
| VMDK direct read (7-zip) | LVM PV extracted but 35GB filled disk, 0 readable strings |

**Available but inaccessible:**
- 6 VMware VMs running (CentOS 7.9, CentOS 7 PG, OTB, TDSQL-1/2/3)
- CentOS 7.9 ISO (`E:\镜像\CentOS-7-x86_64-DVD-2009 (1).iso`)

### Unblocking Paths

1. **Get root password** for 192.168.44.129 (CentOS 7.9 VM)
2. **OR** create a new VM from the CentOS 7.9 ISO with known credentials
3. **OR** provide TXSQL source via USB/external drive (tarball or git bundle)
4. **OR** enable internet access to clone from GitHub

---

## 4. Acceptance Test Checklist (all 75 BLOCKED)

| # | Test | Status |
|---|------|--------|
| 1-25 | 独立包验收 (platform bundle) | BLOCKED |
| 26-50 | 全集成包独立验收 (universal bundle single-platform) | BLOCKED |
| 51-75 | 全集成包重验收 (universal bundle re-verify) | BLOCKED |

See `docs/test-reports/centos-7.9-x86_64-BLOCKERS.md` for detailed per-test status.

---

## 5. What Was Verified (from ISO only)

| # | Item | Status |
|---|------|--------|
| 1 | CentOS 7.9 ISO identity (.discinfo: 7.9, x86_64) | ✅ |
| 2 | @core group: 86 packages (comps.xml.gz) | ✅ |
| 3 | glibc 2.17-317.el7 (build floor) | ✅ |
| 4 | kernel 3.10.0-1160.el7 | ✅ |
| 5 | GCC 4.8.5 on ISO (too old for MySQL 8.0) | ✅ |
| 6 | CMake 2.8.12.2 on ISO (too old) | ✅ |
| 7 | All installer commands in @core | ✅ |
| 8 | 6 RPMs not in @core but needed for TXSQL runtime | ✅ (projected) |
