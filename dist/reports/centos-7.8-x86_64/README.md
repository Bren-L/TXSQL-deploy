# centos-7.8-x86_64 — Dependency Closure Report

**Status**: UNVERIFIED (no ISO, no VM, no fingerprints)
**Date**: 2026-07-22
**Relation to centos-7.9**: Same glibc (2.17), same systemd (219), same RPM (4.11), same GCC (4.8.5).
Expected differences: kernel 3.10.0-1127 vs 1160, minor RPM release numbers.
Binary compatibility with centos-7.9-built TXSQL: VERY LIKELY.

## Blocking Issues
- ❌ No CentOS 7.8 ISO or VM available
- ❌ CentOS release RPM version unknown
- ❌ Exact RPM release numbers unknown (glibc, kernel, systemd)

## Projected Dependency Closure

The centos-7.9 report provides the most reliable projection for centos-7.8.
Key packages expected identical: glibc 2.17, libstdc++ 4.8.5, libaio, zlib,
ncurses, cyrus-sasl, openldap — all same SONAMEs.

DIFFERENCES to verify: kernel release (1127 vs 1160), systemd release
(67 vs 78), rpm release, glibc release number.

See `dist/reports/centos-7.9-x86_64/` for the complete projected closure.
This platform inherits all centos-7.9 projections until disproven by testing.

## Verification Gate
Same 6 steps as centos-7.9. Additional step: diff RPM dependency lists
between 7.8 and 7.9 to confirm identical closure.
