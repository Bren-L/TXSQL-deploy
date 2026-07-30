# Dependency Model — 5-Layer Closure Computation

> **Status**: SPECIFICATION — implementation pending.
> **Date**: 2026-07-22

---

## Overview

The dependency model computes the COMPLETE runtime dependency closure for
TXSQL on each target platform.  It uses a 5-layer approach to ensure no
dependency is missed.

```
Layer 1: ELF Static Analysis     →  libfoo.so.N needed by mysqld
Layer 2: RPM Requires            →  libfoo >= 1.2.3 provided by libfoo-1.2.3-1.el7
Layer 3: Recursive RPM Resolution → libfoo → libbar → libbaz (full tree)
Layer 4: Script Command Analysis  →  awk provided by gawk-4.0.2-4.el7
Layer 5: Runtime Dynamic Tracing  →  libplugin.so loaded at runtime via dlopen
```

## Why 5 Layers

- **ldd alone is insufficient**: doesn't catch dlopen'd plugins, RPM deps,
  or script dependencies.
- **rpm -qpR alone is insufficient**: doesn't catch transitive deps or
  non-RPM-encoded dependencies like RPATH resolution.
- **Static ELF analysis alone**: misses runtime-loaded modules.
- **Documentation alone**: often outdated or incomplete.

## Layer 1: ELF Static Analysis

### Process

For every ELF file in the TXSQL installation tree:

```bash
# Identify ELF files
find /usr/lib/txsql -type f -exec file {} \; | grep ELF

# For each ELF:
readelf -d <elf> | grep NEEDED
objdump -p <elf> | grep NEEDED
ldd <elf> 2>&1
```

### Output

```
dist/reports/<platform-id>/elf/
├── manifest.txt              # All ELF files discovered
├── mysqld.needed.txt         # NEEDED entries for mysqld
├── mysqld.ldd.txt            # ldd output for mysqld
├── mysql.needed.txt
├── mysql.ldd.txt
├── ...                       # One pair per ELF
├── plugin-*.needed.txt       # Each plugin
├── *.so.needed.txt           # Each shared library
└── summary.txt               # Aggregate: all NEEDED, resolution status
```

### Pass Criteria

- ZERO "not found" entries in any ldd output.
- All NEEDED entries map to either system libraries or bundled private libraries.

## Layer 2: RPM Requires

### Process

```bash
for rpm in txsql-common-*.rpm txsql-client-*.rpm txsql-server-*.rpm; do
    rpm -qpR "$rpm"
done
```

### Output

```
dist/reports/<platform-id>/rpm-requires/
├── txsql-common.requires.txt
├── txsql-client.requires.txt
├── txsql-server.requires.txt
└── combined-requires.txt     # Deduplicated union
```

## Layer 3: Recursive RPM Resolution

### Process

#### CentOS 7 / yum platforms:

```bash
# Requires yum-utils (repoquery)
repoquery --requires --resolve --recursive \
    txsql-common txsql-client txsql-server \
    > dependency-closure.txt
```

#### DNF platforms:

```bash
dnf repoquery --requires --resolve --recursive \
    txsql-common txsql-client txsql-server \
    > dependency-closure.txt
```

### Output

```
dist/reports/<platform-id>/dependency-closure/
├── direct-deps.txt           # Level 1 (direct RPM Requires)
├── recursive-deps.txt        # Level 1 + transitive closure
├── dependency-tree.txt       # Tree visualization
├── resolution-summary.txt    # Counts, any unresolvable
└── rpm-list.csv              # NEVRA for every RPM in closure
```

CSV format:
```csv
Name,Epoch,Version,Release,Arch,Size,SHA256,Source
glibc,0,2.17,317.el7,x86_64,3.8M,abc123...,centos-7.8-base
libaio,0,0.3.109,13.el7,x86_64,22K,def456...,centos-7.8-base
txsql-server,0,8.0.30,1.el7.centos78,x86_64,45M,ghi789...,built
```

### Pass Criteria

- Every RPM Requires is resolved by an RPM in the closure.
- No "not found" or "not available" entries.
- System-critical packages (glibc, systemd, bash, kernel, rpm, PAM, NSS)
  are identified and flagged as "system — must not bundle".

## Layer 4: Script Command Analysis

### Process

```bash
# Extract all external commands from installer scripts
grep -rhoP '\b([a-zA-Z][a-zA-Z0-9_-]+)\b' installer/ | \
    sort -u | \
    while read cmd; do
        if command -v "$cmd" >/dev/null 2>&1; then
            path=$(which "$cmd")
            owner=$(rpm -qf "$path" 2>/dev/null || echo "NOT_FROM_RPM")
            echo "$cmd -> $path -> $owner"
        fi
    done
```

### Expected Commands

```
awk         → /usr/bin/awk        → gawk
sed         → /usr/bin/sed        → sed
grep        → /usr/bin/grep       → grep
find        → /usr/bin/find       → findutils
sha256sum   → /usr/bin/sha256sum  → coreutils
systemctl   → /usr/bin/systemctl  → systemd
useradd     → /usr/sbin/useradd   → shadow-utils
groupadd    → /usr/sbin/groupadd  → shadow-utils
getent      → /usr/bin/getent     → glibc-common
ss          → /usr/sbin/ss        → iproute
flock       → /usr/bin/flock      → util-linux
install     → /usr/bin/install    → coreutils
readlink    → /usr/bin/readlink   → coreutils
realpath    → /usr/bin/realpath   → coreutils
tar         → /usr/bin/tar        → tar
gzip        → /usr/bin/gzip       → gzip
rpm         → /usr/bin/rpm        → rpm
yum         → /usr/bin/yum        → yum
dnf         → /usr/bin/dnf        → dnf
```

### Output

```
dist/reports/<platform-id>/script-commands/
├── all-commands.txt          # All commands found
├── rpm-owned.txt             # Commands with RPM owners
├── builtins.txt              # Shell builtins (no dep needed)
└── not-from-rpm.txt          # Commands not in RPM (investigate)
```

### Pass Criteria

- No required command is missing from the target system.
- Any command not in the minimal OS package set has its RPM included in the local repo.
- Shell builtins (echo, cd, test, [) are correctly identified as no-dep.

## Layer 5: Runtime Dynamic Tracing

### Process

```bash
# Start mysqld with tracing
strace -f -e openat,open,mmap,mmap2 \
    mysqld --initialize-insecure --user=txsql \
    2>&1 | grep '\.so' | sort -u > runtime-opened-libs.txt

# Check /proc/<pid>/maps during running state
cat /proc/$(pgrep mysqld)/maps | \
    awk '{print $NF}' | grep '\.so' | sort -u > runtime-mapped-libs.txt

# LD_DEBUG for detailed library resolution
LD_DEBUG=libs mysqld --version 2>&1 | \
    grep 'calling init' | sort -u > runtime-ld-debug.txt
```

### Output

```
dist/reports/<platform-id>/runtime-deps/
├── strace-open.txt           # Files opened during initialize
├── proc-maps.txt             # Libraries mapped at runtime
├── ld-debug.txt              # LD_DEBUG resolution trace
├── dlopen-plugins.txt        # Plugins loaded via dlopen
└── runtime-summary.txt       # New deps not found in layers 1-4
```

### Pass Criteria

- Zero unexpected library loads (plugins, dlopen'd libs) that aren't in the closure.
- Any new dependency found here is added to the closure and the RPM repo.
- No library loaded from unexpected paths (e.g., `/usr/local/lib`).

---

## Dependency Closure Manifest

Each platform's final dependency closure is recorded as:

```
dist/reports/<platform-id>/DEPENDENCY_MANIFEST
```

Format:
```
# TXSQL Dependency Manifest
# Platform: centos-7.8-x86_64
# Generated: 2026-07-22T12:00:00+08:00
# TXSQL Version: 8.0.30-1.0.0

# ============================================================
# System RPMs (provided by OS, NOT included in bundle)
# ============================================================
glibc-2.17-317.el7.x86_64
systemd-219-78.el7.x86_64
bash-4.2.46-34.el7.x86_64
rpm-4.11.3-45.el7.x86_64
yum-3.4.3-168.el7.centos.noarch
pam-1.1.8-23.el7.x86_64
nss-3.44.0-7.el7_7.x86_64
kernel-3.10.0-1127.el7.x86_64

# ============================================================
# Bundled RPMs (included in local repository)
# ============================================================
libaio-0.3.109-13.el7.x86_64
ncurses-libs-5.9-14.20130511.el7_4.x86_64
openssl-libs-1.0.2k-19.el7.x86_64
cyrus-sasl-lib-2.1.26-23.el7.x86_64
openldap-2.4.44-21.el7_6.x86_64
libcurl-7.29.0-57.el7.x86_64
numactl-libs-2.0.12-5.el7.x86_64
# ... (full transitive closure)

# ============================================================
# TXSQL RPMs (built)
# ============================================================
txsql-common-8.0.30-1.el7.centos78.x86_64
txsql-client-8.0.30-1.el7.centos78.x86_64
txsql-server-8.0.30-1.el7.centos78.x86_64

# ============================================================
# Private Libraries (in /usr/lib/txsql/<ver>/lib/private/)
# ============================================================
# libjemalloc.so.2 (bundled, not from system RPM)
# libssl.so.1.1 (if system provides only 1.0.x)
```

---

## Third-Party Licenses

Generate `THIRD_PARTY_LICENSES` and `SBOM`:

```bash
# For each RPM in the closure:
rpm -q --queryformat '%{NAME} %{LICENSE}\n' -p <rpm>
```

Aggregate by license type.  Flag any license that restricts redistribution.
