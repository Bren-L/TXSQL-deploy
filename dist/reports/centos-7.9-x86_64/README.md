# centos-7.9-x86_64 — Dependency Closure Report

**Status**: PROJECTED (from CentOS 7.9 ISO analysis)
**Source**: `E:\镜像\CentOS-7-x86_64-DVD-2009 (1).iso` — 4,070 packages
**Date**: 2026-07-22
**Method**: Authoritative ISO repodata extraction via 7-Zip

## Blocking Issues

- ❌ **TXSQL RPMs do not exist** (no source code to build from)
- ❌ **Live VM inaccessible** (root password unknown for 192.168.44.129)
- ❌ **No ELF scan** of actual TXSQL binaries
- ❌ **No runtime strace/proc/maps** trace

## What This Report Contains

This report projects the COMPLETE dependency closure for a TXSQL 8.0
installation on CentOS 7.9, based on:
1. Known MySQL 8.0.30 runtime dependencies (industry-standard)
2. Authoritative CentOS 7.9 ISO package versions (verified)
3. TBase offline mirror reference (real-world pattern)

ALL versions listed under "Projected Closure" are CONFIRMED to exist
on the CentOS 7.9 ISO. What is UNCONFIRMED is whether TXSQL actually
needs each specific library — that requires building and scanning
actual TXSQL binaries.

## Verification Gate

Once TXSQL is built and RPMs exist, these 6 steps must pass:
1. `inspect-elf.sh` → 0 "not found"
2. `resolve-dependencies.sh` → 0 unresolved
3. `collect-dependencies.sh` → 0 missing
4. `create-local-repo.sh` → valid repodata
5. `scan-scripts.sh` → 0 critical missing
6. Install test on clean VM with network disabled → SUCCESS

Until all 6 pass, this platform remains UNVERIFIED.
