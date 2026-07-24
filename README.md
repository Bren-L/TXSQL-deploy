# TXSQL Offline Deployment — TXSQL 8.0.30 离线一键部署

> **腾讯 TXSQL (Tencent MySQL) 多操作系统离线无人值守部署工程**

---

## 项目状态

| 阶段 | 状态 | 说明 |
|------|------|------|
| 阶段 1: 源码审计 | ✅ 完成 | TXSQL 8.0.30 源码分析，117,155 文件，boost 1.77.0 bundled |
| 阶段 2: 平台指纹 | ✅ 完成 | CentOS 7.9 构建机指纹采集 |
| 阶段 3: 编译构建 | ✅ 完成 | GCC 10.2.1，耗时 63 分钟，278MB mysqld |
| 阶段 4: RPM 打包 | ✅ 完成 | 4 个 RPM (txsql, txsql-common, txsql-client, txsql-server) |
| 阶段 5: 离线部署包 | ✅ 完成 | 完全离线安装脚本 + 依赖闭包 |
| 阶段 6: 验收测试 | ✅ 完成 | 26 项测试全部通过（含 REBOOT 持久化） |
| 阶段 7: 正式发布 | ✅ 完成 | v8.0.30-1.0.0 已发布至 GitHub |

---

## 目标支持矩阵

| 平台 | 架构 | 状态 | RPM 版本 |
|------|------|------|----------|
| CentOS 7.9 | x86_64 | ✅ **RELEASE** | 8.0.30-4.el7 |
| CentOS 7.8 | x86_64 | ⏳ 待开发 | — |
| TencentOS Server 2.4 | x86_64 | ⏳ 待开发 | — |
| TencentOS Server 3.1 | x86_64 | ⏳ 待开发 | — |
| 银河麒麟 V10 (SP TBD) | aarch64 | ⏳ 待开发 | — |

详见 [docs/PLATFORM_MATRIX.md](docs/PLATFORM_MATRIX.md)

---

## 版本信息

| 项目 | 值 |
|------|-----|
| TXSQL 版本 | 8.0.30-txsql |
| MySQL 上游 | 8.0.30 |
| 编译器 | GCC 10.2.1 (devtoolset-10) |
| glibc | 2.17 |
| OpenSSL | 3.4.1 (bundled) |
| Boost | 1.77.0 (bundled) |
| 构建类型 | RelWithDebInfo |
| 发布包版本 | 8.0.30-1.0.0 |

---

## 项目结构

```
TXSQL-Packages/
├── README.md                   # 本文件
├── CLAUDE.md                   # AI 助手指令
├── Makefile                    # 构建入口
├── VERSION                     # 版本定义
├── SOURCE_COMMIT               # TXSQL 源码引用
│
├── platforms/                  # 各平台独立目录
│   ├── centos-7.9-x86_64/      # ✅ RELEASE
│   ├── centos-7.8-x86_64/      # ⏳ 待开发
│   ├── tencentos-2.4-x86_64/   # ⏳ 待开发
│   ├── tencentos-3.1-x86_64/   # ⏳ 待开发
│   └── kylin-v10-aarch64/      # ⏳ 待开发
│
├── build/                      # 构建脚本（平台无关）
│   ├── build-platform-bundle.sh
│   ├── collect-dependencies.sh
│   ├── create-local-repo.sh
│   └── inspect-elf.sh
│
├── packaging/rpm/              # RPM SPEC 文件
├── installer/                  # 安装器
│   ├── install.sh              # 主安装入口
│   └── lib/                    # 安装器模块
├── config/                     # MySQL 配置模板
├── systemd/                    # txsql.service
├── tests/                      # 测试套件
├── dist/                       # 离线包 + repodata + 依赖分析报告
└── docs/                       # 文档
```

---

## 核心原则

1. **完全离线** — 安装过程不访问互联网
2. **完全无人值守** — `sudo bash install.sh </dev/null` 零交互
3. **每平台独立** — 独立构建、独立依赖闭包、独立验收
4. **系统原生 RPM** — 使用 yum/dnf，本地仓库，不依赖外部源
5. **安全优先** — 不删数据、不强制覆盖、冲突即退出
6. **测试门禁** — 未经原生系统验收的平台不声明支持
7. **幂等安装** — 重复安装检测已有数据，不重复初始化

---

## 禁止事项

- `rpm --nodeps / --force / --replacefiles`
- `yum --skip-broken / dnf --skip-broken`
- `kill -9`（卸载中作为最后手段除外）
- 无保护 `rm -rf`
- 自动关闭 SELinux
- 自动关闭防火墙
- 安装过程中 `read` 交互
- root 用户运行 mysqld

---

## 安装默认值

| 参数 | 默认值 |
|------|--------|
| 端口 | 3306 |
| 系统用户 | txsql:txsql |
| 基路径 | /usr/lib/txsql/current → 8.0.30 |
| 数据目录 | /var/lib/txsql/data |
| 日志目录 | /var/log/txsql |
| 运行目录 | /run/txsql |
| 私有库目录 | /usr/lib/txsql/current/lib/private |
| Socket | /var/lib/txsql/mysql.sock |
| 配置文件 | /etc/txsql/my.cnf (%config(noreplace)) |
| 配置目录 | /etc/txsql/conf.d |
| 凭据文件 | /root/.txsql_credentials |

---

## 🚀 快速开始（联网下载）

> 适用于 CentOS 7.9 x86_64，一条命令完成下载安装。

### 方式一：curl 一键安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash
```

### 方式二：手动下载安装

```bash
# 1. 从 GitHub Release 下载
wget https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz

# 2. 验证 SHA-256
echo "dbc2d23c6fedfc947f866144ff760ae4e8a646fcfece765ba88f947d7791cb4e  txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz" | sha256sum -c

# 3. 解压安装
tar xzf txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz
cd txsql-offline-8.0.30-1.0.0-centos7.9-x86_64
sudo bash install.sh
```

> 📦 **最新版本及更多平台**：前往 [GitHub Releases](https://github.com/Bren-L/TXSQL-deploy/releases) 查看所有可用版本。

### 管理服务

```bash
# 首次安装后查看临时密码
sudo cat /root/.txsql_credentials

# 连接数据库
mysql -u root -p -S /var/lib/txsql/mysql.sock

# 服务管理
sudo systemctl status txsql      # 查看状态
sudo systemctl stop txsql        # 停止
sudo systemctl restart txsql     # 重启
```

### 卸载

```bash
# 进入之前的解压目录，或重新下载解压
sudo bash uninstall.sh           # 保留数据、日志、配置、凭据
sudo bash uninstall.sh --purge   # 完全清除（含数据）
```

### 离线安装（无网络环境）

如果目标机器**没有网络**，请在一台可联网的机器上下载离线包，然后通过 U 盘/SCP 传输到目标机器，再按上面的「手动下载安装」步骤执行。

```bash
# 可联网机器（下载离线包）
wget https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz

# 传输到目标机器
scp txsql-offline-*.tar.gz root@<目标机器IP>:/tmp/
```

---

## 构建（开发用）

```bash
# 构建特定平台（在对应构建机上）
make build PLATFORM=centos-7.9-x86_64

# 生成离线包
make bundle PLATFORM=centos-7.9-x86_64

# 构建所有已支持平台
make build-all
```

---

## 文档索引

| 文档 | 内容 |
|------|------|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | 系统架构设计 |
| [PLATFORM_MATRIX.md](docs/PLATFORM_MATRIX.md) | 平台支持矩阵 |
| [PLATFORM_FINGERPRINTS.md](docs/PLATFORM_FINGERPRINTS.md) | 平台指纹采集协议 |
| [TXSQL_SOURCE_ANALYSIS.md](docs/TXSQL_SOURCE_ANALYSIS.md) | TXSQL 源码分析 |
| [OTB_REFERENCE_ANALYSIS.md](docs/OTB_REFERENCE_ANALYSIS.md) | OpenTenBase 参考分析 |
| [DEPENDENCY_MODEL.md](docs/DEPENDENCY_MODEL.md) | 5层依赖闭包模型 |
| [DECISIONS.md](docs/DECISIONS.md) | 关键设计决策记录 |
| [BUILD.md](docs/BUILD.md) | 构建指南 |
| [INSTALL.md](docs/INSTALL.md) | 安装指南 |
| [UNINSTALL.md](docs/UNINSTALL.md) | 卸载指南 |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 故障排除 |
| [TEST_REPORT.md](docs/TEST_REPORT.md) | 测试报告 |
| [test-reports/centos-7.9-x86_64-RELEASE-FINAL.md](docs/test-reports/centos-7.9-x86_64-RELEASE-FINAL.md) | 正式版验收报告 (26/26 通过) |

---

## 发布

| 版本 | 日期 | 说明 |
|------|------|------|
| [v8.0.30-1.0.0](https://github.com/Bren-L/TXSQL-deploy/releases/tag/v8.0.30-1.0.0) | 2026-07-23 | 首个正式发布，CentOS 7.9 x86_64 支持 |

---

## 许可证

本项目为 TXSQL 部署工具工程，遵循与 TXSQL 兼容的开源许可。
