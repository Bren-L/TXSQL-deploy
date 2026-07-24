# Build Guide

> **Status**: SPECIFICATION — build not yet executed.
> **Date**: 2026-07-22

---

## Prerequisites

### Build Host Requirements

The build host must match the TARGET platform (or be the lowest common
denominator for the strategy A common build).

| Platform | Build Host | GCC | CMake | Notes |
|----------|-----------|-----|-------|-------|
| centos-7.8-x86_64 | CentOS 7.8 | devtoolset-8 (TBD) | cmake3 (TBD) | GCC 4.8.5 likely too old |
| centos-7.9-x86_64 | CentOS 7.9 | devtoolset-8 (TBD) | cmake3 (TBD) | Same as 7.8 |
| tencentos-2.4-x86_64 | TencentOS 2.4 | TBD | TBD | |
| tencentos-3.1-x86_64 | TencentOS 3.1 | TBD | TBD | |
| kylin-v10-aarch64 | Kylin V10 aarch64 | TBD | TBD | Must be native aarch64 |

### Required Build Tools

```bash
# CentOS 7
yum install -y devtoolset-8 cmake3 bison flex perl git
yum install -y ncurses-devel libaio-devel openssl-devel
yum install -y cyrus-sasl-devel openldap-devel libtirpc-devel
yum install -y rpm-build createrepo

# TencentOS 3 / Kylin V10
dnf install -y gcc gcc-c++ cmake bison flex perl git
dnf install -y ncurses-devel libaio-devel openssl-devel
dnf install -y cyrus-sasl-devel openldap-devel libtirpc-devel
dnf install -y rpm-build createrepo_c
```

---

## Build Flow

```bash
# Step 1: Inspect TXSQL source
make inspect-source TXSQL_SOURCE=/path/to/txsql

# Step 2: Build TXSQL from source
make build PLATFORM=centos-7.8-x86_64 TXSQL_SOURCE=/path/to/txsql

# Step 3: Build RPM packages
make build-rpm PLATFORM=centos-7.8-x86_64

# Step 4: Compute dependency closure
bash build/inspect-elf.sh --platform centos-7.8-x86_64
bash build/resolve-dependencies.sh --platform centos-7.8-x86_64
bash build/collect-dependencies.sh --platform centos-7.8-x86_64

# Step 5: Create local RPM repository
bash build/create-local-repo.sh --platform centos-7.8-x86_64

# Step 6: Generate offline bundle
make bundle PLATFORM=centos-7.8-x86_64
```

---

## Build Output

```
dist/txsql-offline-<version>-<platform-id>.tar.gz
```

---

## Build Verification

Before releasing a bundle, verify:

1. `SHA256SUMS` covers all files
2. All ELF files have zero "not found" in `ldd`
3. Dependency closure is complete (no missing RPMs)
4. Local repo `repodata/` is valid
5. Unpacked bundle installs on a clean target system
