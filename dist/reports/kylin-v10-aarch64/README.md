# kylin-v10-aarch64 — Dependency Closure Report

**Status**: UNVERIFIED (no aarch64 environment, no fingerprints)
**Date**: 2026-07-22
**Expected Base**: openEuler / RHEL 8
**Architecture**: aarch64 (ARM64)
**SP Version**: UNDETERMINED (SP1/SP2/SP3)

## Blocking Issues
- ❌ No aarch64 hardware available (this workstation is x86_64)
- ❌ No Kylin V10 ISO or VM image
- ❌ SP version unknown (each SP may have different dependency trees)
- ❌ Kylin-customized packages may differ from openEuler upstream
- ❌ CPU model unknown (Kunpeng 920 vs Phytium FT-2000+)

## Critical Unknowns

1. **Native Build Required**: TXSQL MUST be compiled natively on aarch64.
   No cross-compilation from x86_64. This means:
   - The entire build toolchain must be set up on aarch64
   - All build dependencies must be resolved from Kylin repos
   - The dependency closure is COMPLETELY DIFFERENT from x86_64
     (different arch, different packages, different library paths)

2. **SP Version**: Kylin V10 comes in SP1, SP2, SP3 (and possibly more).
   Each SP has different base OS versions:
   - SP1: openEuler 20.03 LTS based? (glibc 2.28?)
   - SP2: openEuler 22.03 LTS based? (glibc 2.34?)
   - SP3: openEuler 24.03 based? (glibc 2.38?)
   Until the SP is determined, no dependency versions can be projected.

3. **CPU Architecture Details**: Kunpeng 920 vs Phytium FT-2000+:
   - Both are ARMv8.2-A
   - Kunpeng 920: TaiShan v110 cores, 64KB L1, 512KB L2, 64MB L3
   - Phytium FT-2000+: FTC662 cores
   - NUMA topology differs → numactl behavior may differ
   - Build optimization flags may differ (-march=armv8.2-a+crypto+crc)

4. **Library Paths**: aarch64 systems typically use /usr/lib64/ for
   64-bit libraries. But some aarch64 distros use /usr/lib/ (Debian-style).
   Kylin, being RPM-based, likely uses /usr/lib64/.
   → Must verify via fingerprint collection.

5. **Package Names**: Kylin may use different package names from both
   CentOS and openEuler:
   - kylin-release (not centos-release or openEuler-release)
   - libgcc → gcc-libs? libatomic?
   - openssl → kylin-openssl? (possible Kylin-customized crypto)
   → Must fingerprint to determine.

## Dependency Closure Strategy

This platform requires a FULL INDEPENDENT dependency resolution:
1. Set up native aarch64 build environment on Kylin V10
2. Install build deps from Kylin repos
3. Build TXSQL natively
4. Run ALL 6 dependency resolution layers independently
5. Generate independent local RPM repository with aarch64 RPMs
6. Package names and versions will be COMPLETELY DIFFERENT from x86_64

## Verification Gate
Same 6 steps as centos-7.9, PLUS:
7. Native aarch64 build verified
8. Each SP tested independently (SP1, SP2, SP3 are separate platforms)
9. CPU-specific optimizations verified (Kunpeng 920 vs Phytium)
10. NUMA configuration verified for aarch64 topology
11. Independent dependency closure (zero x86_64 crossover)

## Per-SP Platform IDs (to be finalized after fingerprinting)
  kylin-v10-sp1-aarch64  (openEuler 20.03 LTS based?)
  kylin-v10-sp2-aarch64  (openEuler 22.03 LTS based?)
  kylin-v10-sp3-aarch64  (openEuler 24.03 based?)
