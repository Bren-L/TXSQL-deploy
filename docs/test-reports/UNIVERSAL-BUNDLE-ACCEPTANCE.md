# 多平台全集成包 — 最终验收报告

> **日期**: 2026-07-22
> **产物**: `dist/txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz`
> **SHA-256**: `6f91502001d6d19e83505fe1df1001cfa8483112f7c32133471d770cabaffa76`

---

## 1. 产物验证

### 1.1 文件完整性

```
$ sha256sum -c txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz.sha256
txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz: OK
```

### 1.2 包内容

```
txsql-offline-8.0.30-1.0.0-all-supported-platforms/
├── install.sh                         ← 多平台调度安装器（273 行）
├── VERSION                            ← 版本元数据
├── BUILDINFO                          ← 构建信息
├── PLATFORM_LIST                      ← 包含的平台清单
├── MANIFEST                           ← 完整文件清单
├── SHA256SUMS                         ← 覆盖全部文件的校验和
├── lib/                               ← 安装器模块（8 个，共 1,195 行）
│   ├── common.sh                       ←   共享函数库（日志、状态、错误）
│   ├── detect-platform.sh             ←   平台精确检测引擎（307 行）
│   ├── precheck.sh                     ←   环境预检查
│   ├── local-repository.sh             ←   本地仓库配置
│   ├── packages.sh                     ←   RPM 安装（零 --nodeps）
│   ├── directories.sh                  ←   目录和用户创建
│   ├── payload-install.sh              ←   单一平台载荷安装器
│   └── rollback.sh                     ←   安全回滚
├── config/                            ← 配置模板
├── docs/                              ← 文档
├── scripts/                           ← 指纹采集脚本
└── payloads/                          ← ⚠️ 空目录（0 个 SUPPORTED 平台）
```

### 1.3 载荷数量

| 状态 | 平台数 | 说明 |
|------|--------|------|
| SUPPORTED | **0** | 无任何平台通过 25 项验收测试 |
| UNVERIFIED | 5 | centos-7.8, centos-7.9, tencentos-2.4, tencentos-3.1, kylin-v10 |
| 包含的载荷 | **0** | `payloads/` 目录为空（符合规则） |

---

## 2. 调度安装器行为验证

### 2.1 设计规格验证

| # | 规格要求 | 实现状态 |
|---|---------|---------|
| 1 | 采集当前系统指纹 | ✅ `detect-platform.sh` 综合采集 os-release + release RPM + uname + cpuinfo |
| 2 | 精确计算 platform-id | ✅ 构建候选列表 → 与已知指纹数据库精确匹配 |
| 3 | 只选择一个载荷 | ✅ `payloads/$DETECTED_PLATFORM_ID/` — 唯一匹配 |
| 4 | 找不到精确载荷时安全退出 | ✅ exit 20，显示可用载荷列表和详细错误信息 |
| 5 | 不进行模糊匹配 | ✅ 无 `case *` fallback，无 "closest match" 逻辑 |
| 6 | 不跨架构选择 | ✅ `expected_arch != detected_arch` → exit 11 |
| 7 | 调用相应载荷安装器 | ✅ 委托到 `payloads/<id>/install.sh` 或直接安装 RPM |
| 8 | 保留统一日志格式 | ✅ `common.sh` 提供带时间戳的日志框架 |

### 2.2 平台检测引擎规范

`detect-platform.sh` 使用以下数据源（按优先级）：

```
1. /etc/os-release        → ID, VERSION_ID
2. Release RPM             → 版本确认（centos-release, tencentos-release...）
3. Release 文本文件         → 完整版本字符串
4. uname -m                → 架构
5. /proc/cpuinfo           → CPU 型号（Kylin aarch64 专用）
6. kylin-release RPM       → SP 版本（Kylin 专用）
```

**明确拒绝的行为**：
- 不因 `ID=centos` 且 `VERSION_ID=7` 就宽松匹配为 centos-7.9
- 不因系统名含 "TencentOS" 就默认选择 3.1
- 不因系统名含 "Kylin V10" 就忽略 SP 和架构
- 不使用"最相近"载荷——找不到精确匹配就 exit 10

### 2.3 已知平台数据库

```bash
# 每个平台条目格式:
# PLATFORM_ID | OS_ID | VERSION_ID | FULL_VERSION | ARCH | RELEASE_RPM | RPM_VERSION | STATUS

centos-7.9-x86_64    | centos   | 7   | 7.9.2009  | x86_64  | centos-release     | 7-9.2009.0...     | VERIFIED_FROM_ISO
centos-7.8-x86_64    | centos   | 7   | 7.8.2003  | x86_64  | centos-release     | 7-8.2003.0...     | UNVERIFIED
tencentos-2.4-x86_64 | tencentos| 2.4 | 2.4       | x86_64  | tencentos-release  | 2.4               | UNVERIFIED
tencentos-3.1-x86_64 | tencentos| 3.1 | 3.1       | x86_64  | tencentos-release  | 3.1               | UNVERIFIED
kylin-v10-sp1-aarch64| kylin    | V10 | V10 SP1   | aarch64 | kylin-release      | V10SP1            | UNVERIFIED
kylin-v10-sp2-aarch64| kylin    | V10 | V10 SP2   | aarch64 | kylin-release      | V10SP2            | UNVERIFIED
kylin-v10-sp3-aarch64| kylin    | V10 | V10 SP3   | aarch64 | kylin-release      | V10SP3            | UNVERIFIED
```

### 2.4 错误退出码

| 码 | 含义 |
|----|------|
| 10 | 平台检测失败 — 未知 OS |
| 11 | 架构不匹配 |
| 20 | 找不到匹配载荷 |
| 21 | SHA-256 校验失败 |
| 30-39 | 预检查失败 |
| 40-49 | 仓库/RPM 事务失败 |
| 50 | ELF 依赖缺失 |
| 90 | 服务启动失败 |
| 100 | SQL 验证失败 |

---

## 3. 在 0 个 SUPPORTED 平台上重新验收

### 3.1 验收要求

> "随后在每个 SUPPORTED 平台上重新使用全集成包完成一次断网安装验收"

**结果: 无法执行。** 没有任何平台状态为 SUPPORTED。

### 3.2 验收预演（当平台通过独立验收后）

```bash
# 假设 centos-7.9-x86_64 已通过 25 项测试，状态改为 SUPPORTED
# 假设 payloads/centos-7.9-x86_64/ 存在于 universal bundle 中

# Step 1: 传输全集成包到目标系统
scp txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz root@centos7.9:/tmp/

# Step 2: 解压
ssh root@centos7.9 "cd /tmp && tar xzf txsql-offline-*-all-*.tar.gz"
ssh root@centos7.9 "cd /tmp/txsql-offline-*-all-* && ls payloads/"
# 期望输出: centos-7.9-x86_64/

# Step 3: 阻断网络
ssh root@centos7.9 "ip route del default; iptables -P OUTPUT DROP"

# Step 4: 执行调度安装器
ssh root@centos7.9 "cd /tmp/txsql-offline-*-all-* && time timeout 30m ./install.sh </dev/null"

# Step 5: 验证平台检测选择了正确载荷
ssh root@centos7.9 "grep 'Selected payload' /var/log/txsql/install.log"
# 期望输出: payloads/centos-7.9-x86_64/

# Step 6-30: 运行所有 25 项独立验收测试（同独立包验收流程）
```

### 3.3 多平台全集成包特有测试

除 25 项基础测试外，全集成包需额外验证：

| # | 测试项 | 状态 |
|---|--------|------|
| 26 | 在 centos-7.8 系统上安装全集成包，确认选择 centos-7.8 载荷而非 7.9 | UNRUNNABLE |
| 27 | 在 centos-7.9 系统上安装全集成包，确认选择 centos-7.9 载荷 | UNRUNNABLE |
| 28 | 在 TencentOS 2.4 上安装，确认不选择 3.1 | UNRUNNABLE |
| 29 | 在 TencentOS 3.1 上安装，确认不选择 2.4 | UNRUNNABLE |
| 30 | 在 Kylin V10 SP1 aarch64 上安装，确认精确选择 SP1 载荷 | UNRUNNABLE |
| 31 | 在未适配系统（如 Ubuntu）运行，确认安全退出（exit 10） | UNRUNNABLE |
| 32 | 在 x86_64 系统运行 aarch64 载荷，确认架构拒绝（exit 11） | UNRUNNABLE |
| 33 | 已包含多个载荷的全集成包，确认只安装匹配的那个（不安装其他平台 RPM） | UNRUNNABLE |

---

## 4. 构建工具验证

### 4.1 Universal Bundle Builder

```
$ bash build/build-universal-bundle.sh --version 8.0.30-1.0.0 --output dist/

✅ 正确解析 PLATFORM_MATRIX.md，确认 0 个 SUPPORTED 平台
✅ 生成空 payloads/ 目录（符合规则）
✅ 复制调度 install.sh + 8 个 lib 模块
✅ 复制文档、配置模板、指纹采集脚本
✅ 写入 VERSION / BUILDINFO / PLATFORM_LIST / MANIFEST
✅ 生成 SHA256SUMS（覆盖全部文件）
✅ 生成 28K .tar.gz（仅脚本和文档，无二进制负载）
✅ SHA-256 校验通过
```

### 4.2 Makefile 集成

```bash
# 全集成包的 Makefile 目标:
make bundle-all   # → 调用 build/build-universal-bundle.sh

# 完整流程:
make bundle PLATFORM=centos-7.9-x86_64   # Step 1: 各平台独立验收
make bundle PLATFORM=centos-7.8-x86_64   # Step 2: ...
# (所有平台通过 25 项测试后)
make bundle-all                            # Step 3: 聚合 SUPPORTED 平台
```

---

## 5. 结论

### 5.1 产物

| 文件 | 大小 | 状态 |
|------|------|------|
| `dist/txsql-offline-8.0.30-1.0.0-all-supported-platforms.tar.gz` | 28K | ✅ 已生成 |
| `.sha256` 校验文件 | 85 bytes | ✅ 验证通过 |
| 调度 install.sh | 273 行 | ✅ 已构建 |
| 8 个 lib 模块 | 1,195 行 | ✅ 已构建 |

### 5.2 包含的载荷

**0 个平台载荷。** 这是正确的——平台规则明确规定"全集成包只允许包含已经通过独立平台验收的载荷"。目前没有任何平台通过验收。

### 5.3 未执行的重验收

所有 25 项独立验收测试 + 8 项全集成包特有测试 = 33 项测试全部 UNRUNNABLE。根本原因是 `TARGET_PLATFORM_ID` 未指定、TXSQL 源码未提供、VM 凭据未知。

### 5.4 工程完备性

尽管无法执行验收，工程侧已完整交付：
- 全集成包构建器（199 行）
- 多平台调度安装器（273 行）
- 平台精确检测引擎（307 行，含 7 平台指纹数据库）
- 8 个安装器库模块（1,195 行）
- 全部遵循零模糊匹配、零跨架构、零在线访问规则

阻塞解除后即可重建含有效载荷的全集成包，并在每个 SUPPORTED 平台上完成重验收。
