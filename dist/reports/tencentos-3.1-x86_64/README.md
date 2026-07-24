# tencentos-3.1-x86_64 — Dependency Closure Report

**Status**: UNVERIFIED (no environment, no fingerprints)
**Date**: 2026-07-22
**Expected Base**: RHEL 8 / CentOS 8.x
**Expected glibc**: 2.28
**Expected PKG MGR**: dnf (not yum)
**Key Risk**: DNF modularity, systemd 239+ vs 219, Tencentsm

## Blocking Issues
- ❌ No TencentOS 3.1 environment
- ❌ glibc version not confirmed
- ❌ DNF module stream behavior unknown
- ❌ createrepo_c vs createrepo unknown

## Critical Unknowns

1. **glibc 2.28 Forward Compatibility**: A TXSQL binary compiled on
   CentOS 7.9 (glibc 2.17) SHOULD run on glibc 2.28. This is a
   verified property of glibc (backward-compatible).
   → Must test to confirm.

2. **DNF Modularity**: TencentOS 3.1 may have package modularity enabled.
   Some libraries might be in module streams that need explicit enabling.
   → Must disable modules or pin to specific stream.

3. **Systemd 239+**: Service file directives available in systemd 239+
   but NOT in CentOS 7's systemd 219:
   - ProtectSystem=strict
   - ProtectHome=yes
   - PrivateTmp=yes (available in 219)
   → Use directives compatible with BOTH systemd 219 and 239+.

4. **RPM Format**: RHEL 8 RPMs use different compression. CentOS 7 RPMs
   use gzip; RHEL 8 uses xz. RPM 4.14 on RHEL 8 can read old-format RPMs.
   → Build RPMs on CentOS 7 (gzip format) for maximum compatibility.

5. **createrepo_c**: DNF platforms use createrepo_c by default.
   createrepo_c output IS compatible with yum on CentOS 7.
   → Use createrepo_c on the BUILD host if available; fallback to createrepo.

## Projected Dependency Closure

Dependency closure will DIFFER from centos-7.9:
- glibc 2.28 vs 2.17 → different NEVRA
- libstdc++ from GCC 8.x vs 4.8.5 → different NEVRA, different ABI version
- OpenSSL 1.1.1 standard (vs 1.0.2k on CentOS 7)
- All RPM release numbers will differ (el8 vs el7)

This closure MUST be computed independently on a real TencentOS 3.1 system.
Do NOT copy centos-7.9 RPMs — they have el7 releases and won't parse
correctly in dnf dependency resolution for el8.

## Verification Gate
Same 6 steps as centos-7.9, PLUS:
7. Verify glibc forward compatibility with centos-7.9 binary
8. Verify DNF local repo configuration works correctly
9. Verify systemd 239+ service directives are compatible
10. Compute independent dependency closure (do NOT copy centos-7.9)
