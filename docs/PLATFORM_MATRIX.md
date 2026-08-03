# Platform Support Matrix

> **Last Updated**: 2026-08-03
> **Principle**: SUPPORTED only after full offline acceptance on native hardware.

---

## 1. Platform Status

| Platform | Arch | 部署方式 | 状态 |
|----------|------|----------|------|
| CentOS 7.9 x86_64 | x86_64 | RPM (yum local repo) | ✅ **RELEASE** |
| openEuler 22.03 LTS-SP3 x86_64 | x86_64 | Binary | ✅ **RELEASE** |
| Kylin V11 (Swan25) x86_64 | x86_64 | Binary | ✅ **RELEASE** |

---

## 2. 已发布平台

### CentOS 7.9 x86_64

| 项目 | 详情 |
|------|------|
| TXSQL 版本 | 8.0.30-txsql |
| GCC | 8.3.1 (devtoolset-8) |
| glibc | 2.17 |
| OpenSSL | 1.1.1w (自编译, SM4 支持) |
| 部署方式 | RPM (yum local repo) |
| 构建时间 | ~63 min |
| 验收测试 | 22/22 PASSED |

### openEuler 22.03 LTS-SP3 x86_64

| 项目 | 详情 |
|------|------|
| TXSQL 版本 | 8.0.30-txsql |
| GCC | 10.3.1 (system) |
| glibc | 2.34 |
| OpenSSL | 1.1.1wa (system, SM3/SM4 built-in) |
| 部署方式 | Binary copy |
| 构建时间 | ~20 min |
| 验收测试 | 全部 PASSED |

### 银河麒麟 V11 (Swan25) x86_64

| 项目 | 详情 |
|------|------|
| TXSQL 版本 | 8.0.30-txsql |
| GCC | 12.3.1 (system) |
| glibc | 2.38 |
| OpenSSL | 3.0.12 (system, SM3/SM4 built-in) |
| 部署方式 | Binary copy |
| 构建时间 | ~33 min (make -j4, with swap) |
| 验收测试 | 全部 PASSED |

---

## 3. 验收检查项

每个平台发布前必须全部通过：

| # | 检查项 |
|---|--------|
| 1 | 服务启动 (`systemctl status txsql` → active) |
| 2 | 端口监听 (3306) |
| 3 | 版本验证 (`SELECT VERSION()` → 8.0.30-txsql) |
| 4 | Socket 路径正确 (/run/txsql/mysql.sock) |
| 5 | 读写 CRUD 正常 |
| 6 | 幂等安装 (重复安装不破坏数据) |
| 7 | 自启动启用 (`systemctl is-enabled txsql`) |
