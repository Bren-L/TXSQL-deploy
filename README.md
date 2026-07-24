# TXSQL Offline Deployment — 一键离线部署项目

> **腾讯 TXSQL (Tencent MySQL) 多操作系统离线无人值守部署工程**

---

## 项目状态

| 阶段 | 状态 | 说明 |
|------|------|------|
| 阶段 1: 源码审计 | ✅ 完成 | TXSQL源码分析 + OpenTenBase参考项目分析 |
| 阶段 2: 平台指纹 | ⚠️ 阻塞 | 缺少目标操作系统环境 |
| 阶段 3-13 | ⏳ 未开始 | 等待前置条件满足 |

**当前可交付物**: 项目骨架、架构设计、决策记录、参考分析、平台指纹采集协议。

**阻塞项**:
- TXSQL 源码路径 (`<TXSQL_SOURCE_PATH>`) 未解析为实际路径
- 无可用目标操作系统镜像或测试机

---

## 目标支持矩阵

| 平台 | 架构 | 状态 |
|------|------|------|
| CentOS 7.8 | x86_64 | UNVERIFIED |
| CentOS 7.9 | x86_64 | UNVERIFIED |
| TencentOS Server 2.4 | x86_64 | UNVERIFIED |
| TencentOS Server 3.1 | x86_64 | UNVERIFIED |
| 银河麒麟 V10 (SP TBD) | aarch64 | UNVERIFIED |

详见 [docs/PLATFORM_MATRIX.md](docs/PLATFORM_MATRIX.md)

---

## 项目结构

```
TXSQL-Packages/
├── README.md                   # 本文件
├── CLAUDE.md                   # AI 助手指令
├── Makefile                    # 构建入口
├── VERSION                     # 版本定义
├── SOURCE_COMMIT               # TXSQL 源码引用
├── .gitignore
│
├── platforms/                  # 各平台独立目录
│   ├── centos-7.8-x86_64/
│   ├── centos-7.9-x86_64/
│   ├── tencentos-2.4-x86_64/
│   ├── tencentos-3.1-x86_64/
│   └── kylin-v10-aarch64/
│
├── build/                      # 构建脚本（平台无关）
├── packaging/rpm/              # RPM SPEC 文件
├── installer/                  # 安装器
│   ├── install.sh              # 主安装入口
│   ├── uninstall.sh            # 卸载
│   ├── upgrade.sh              # 升级
│   └── lib/                    # 安装器模块
├── config/                     # 配置模板
├── systemd/                    # systemd 单元
├── tests/                      # 测试套件
└── docs/                       # 文档
```

---

## 核心原则

1. **完全离线** — 安装过程不访问互联网
2. **完全无人值守** — `sudo ./install.sh </dev/null` 零交互
3. **每平台独立** — 独立构建、独立依赖闭包、独立验收
4. **系统原生 RPM** — 使用 yum/dnf，本地仓库
5. **安全优先** — 不删数据、不强制覆盖、冲突即退出
6. **测试门禁** — 未经原生系统验收的平台不声明支持

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
| 系统用户 | txsql |
| 基路径 | /usr/lib/txsql/current |
| 数据目录 | /var/lib/txsql/data |
| 日志目录 | /var/log/txsql |
| 运行目录 | /run/txsql |
| Socket | /run/txsql/mysql.sock |
| 配置文件 | /etc/txsql/my.cnf |
| 配置目录 | /etc/txsql/conf.d |
| 凭据文件 | /root/.txsql_credentials |

---

## 快速开始（当环境就绪后）

```bash
# 1. 采集目标平台指纹
sudo bash collect-fingerprints.sh

# 2. 审计 TXSQL 源码
make inspect-source TXSQL_SOURCE=/path/to/txsql

# 3. 构建特定平台
make build PLATFORM=centos-7.8-x86_64

# 4. 生成离线包
make bundle PLATFORM=centos-7.8-x86_64

# 5. 在目标系统安装
sudo ./install.sh </dev/null
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

---

## 许可证

本项目为 TXSQL 部署工具工程，遵循与 TXSQL 兼容的开源许可。
