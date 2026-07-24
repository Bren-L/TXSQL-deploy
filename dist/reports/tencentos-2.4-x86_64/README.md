# tencentos-2.4-x86_64 — Dependency Closure Report

**Status**: UNVERIFIED (no environment, no fingerprints)
**Date**: 2026-07-22
**Expected Base**: RHEL 7 / CentOS 7.x
**Expected glibc**: 2.17
**Key Risk**: Tencentsm (Tencent国密) may replace standard OpenSSL

## Blocking Issues
- ❌ No TencentOS 2.4 environment
- ❌ OS ID unknown ('tencentos' vs 'tlinux')
- ❌ OpenSSL vs Tencentsm unknown
- ❌ Package names may differ from CentOS 7

## Critical Unknowns

1. **OS Identity**: /etc/os-release ID may be 'tencentos' or 'tlinux'.
   tencentos-release or tlinux-release RPM version must be captured.

2. **Crypto Provider**: If Tencentsm replaces OpenSSL, TXSQL linking strategy
   must change:
   - libssl.so may be libtencentsm.so
   - SM2/SM3/SM4 algorithms instead of RSA/AES
   - May need to bundle standard OpenSSL in private lib/

3. **Package Names**: TencentOS may use different package names for:
   - cyrus-sasl → may be libsasl
   - openldap → may be libldap
   - numactl-libs → may be libnuma
   These must be resolved by fingerprint collection.

4. **Kernel**: TLinux kernel may have different /proc and /sys interfaces.
   Typically not a problem for userspace, but NUMA and AIO behavior may differ.

## Projected Dependency Closure

If TencentOS 2.4 is RHEL 7 based (glibc 2.17):
  → centos-7.9 projected closure is the BEST starting point
  → With the Tencentsm caveat — crypto libraries may differ

See `dist/reports/centos-7.9-x86_64/bundled-rpms.txt` as baseline projection.
ALL entries must be verified against actual TencentOS 2.4 package names.

## Verification Gate
Same 6 steps as centos-7.9, PLUS:
7. Verify OS identity (os-release + release RPM)
8. Identify crypto provider (OpenSSL vs Tencentsm)
9. Map all CentOS package names to TencentOS equivalents
10. Test TXSQL binary from centos-7.9 build on TencentOS 2.4
