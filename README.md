# TXSQL Offline Deployment — TXSQL 8.0.30 离线一键部署

> **腾讯 TXSQL (Tencent MySQL) 多操作系统离线无人值守部署工程**

---

## 项目状态

| 阶段 | 状态 | 说明 |
|------|------|------|
| 阶段 1: 源码审计 | ✅ 完成 | TXSQL 8.0.30 源码分析，117,155 文件，boost 1.77.0 bundled |
| 阶段 2: 平台指纹 | ✅ 完成 | CentOS 7.9 + openEuler 22.03 指纹采集 |
| 阶段 3: 编译构建 | ✅ 完成 | CentOS 7.9: GCC 10.2.1 | openEuler: GCC 10.3.1 |
| 阶段 4: RPM 打包 | ✅ 完成 | CentOS 7.9: 4 个 RPM | openEuler: 二进制包 |
| 阶段 5: 离线部署包 | ✅ 完成 | 完全离线安装脚本 + 依赖闭包 |
| 阶段 6: 验收测试 | ✅ 完成 | CentOS 7.9: 26/26 通过（含 REBOOT） |
| 阶段 7: 正式发布 | ✅ 完成 | CentOS 7.9 + openEuler 22.03 均已发布 |

---

## 目标支持矩阵

| 平台 | 架构 | 状态 | 部署方式 |
|------|------|------|----------|
| CentOS 7.9 | x86_64 | ✅ **RELEASE** | RPM (yum local repo) |
| openEuler 22.03 LTS-SP3 | x86_64 | ✅ **RELEASE** | 二进制 |
| CentOS 7.8 | x86_64 | ⏳ 待开发 | — |
| TencentOS Server 2.4 | x86_64 | ⏳ 待开发 | — |
| TencentOS Server 3.1 | x86_64 | ⏳ 待开发 | — |
| 银河麒麟 V10 (SP TBD) | aarch64 | ⏳ 待开发 | — |

详见 [docs/PLATFORM_MATRIX.md](docs/PLATFORM_MATRIX.md)

---

## 版本信息

| 项目 | CentOS 7.9 | openEuler 22.03 |
|------|------------|-----------------|
| TXSQL 版本 | 8.0.30-txsql | 8.0.30-txsql |
| 编译器 | GCC 10.2.1 | GCC 10.3.1 |
| glibc | 2.17 | 2.34 |
| OpenSSL | 3.4.1 (bundled) | 1.1.1wa (system) |
| 部署方式 | RPM (yum) | 二进制 copy |

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
| Socket | /run/txsql/mysql.sock |
| 配置文件 | /etc/txsql/my.cnf |
| 配置目录 | /etc/txsql/conf.d |
| 凭据文件 | /root/.txsql_credentials |

---

## 核心原则

1. **完全离线** — 安装过程不访问互联网
2. **完全无人值守** — `sudo bash install.sh </dev/null` 零交互
3. **每平台独立** — 独立构建、独立依赖闭包、独立验收
4. **系统原生包管理** — CentOS 使用 RPM/yum，openEuler 使用二进制部署
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

## 🚀 快速开始 — CentOS 7.9

> 最新版本: [v8.0.30-2.0.0](https://github.com/Bren-L/TXSQL-deploy/releases)

### 前置依赖

CentOS 7 minimal 已内置 `curl`、`tar`、`sudo`，**无需安装任何额外依赖**。

### 方式一：下载并安装

```bash
# Step 1: 下载并解压
curl -fSL --retry 3 -# -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz \
  && cd txsql-offline-8.0.30-2.0.0-centos7.9-x86_64

# Step 2: 安装
sudo bash install.sh </dev/null
```

### 方式二：离线传输

在有网络的机器上下载解压，通过 U 盘 / SCP 传到目标机：

```bash
# === 可联网机器 ===
curl -fSL --retry 3 -# -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz \
  && tar xzf txsql.tar.gz
scp -r txsql-offline-*/ root@<目标机器IP>:/tmp/

# === 目标机器 ===
cd /tmp/txsql-offline-*/
sudo bash install.sh </dev/null
```

---

## 🚀 快速开始 — openEuler 22.03 LTS-SP3

> 最新版本: [v8.0.30-2.0.0](https://github.com/Bren-L/TXSQL-deploy/releases)

### 前置依赖

openEuler 22.03 minimal 已内置 `curl`、`tar`、`sudo`，**无需安装任何额外依赖**。

### 下载并安装

```bash
# Step 1: 下载并解压
curl -fSL --retry 3 -# -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz \
  && cd txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64

# Step 2: 安装
sudo bash install.sh </dev/null
```

### 验证部署

```bash
# 1. 服务正在运行
sudo systemctl status txsql | head -3

# 2. 端口已监听
sudo ss -tlnp | grep 3306

# 3. 查看版本和 socket
sudo cat /root/.txsql_credentials
mysql -u root -p -S /run/txsql/mysql.sock -e "SELECT VERSION(), @@socket;"
# → 8.0.30-txsql | /run/txsql/mysql.sock

# 4. 读写测试
mysql -u root -p -S /run/txsql/mysql.sock -e "
  CREATE DATABASE IF NOT EXISTS test_txsql;
  USE test_txsql;
  CREATE TABLE t (id INT, msg VARCHAR(50));
  INSERT INTO t VALUES (1, 'hello txsql');
  SELECT * FROM t;
  DROP DATABASE test_txsql;
"
```

> 6 项全通过即为部署成功：服务 running ✅、端口 3306 ✅、版本 8.0.30-txsql ✅、读写正常 ✅、密码可查 ✅、socket 路径正确 ✅。

### 卸载

```bash
sudo bash uninstall.sh           # 保留数据、日志、配置
sudo bash uninstall.sh --purge   # 完全清除（含数据）
```

---

## 项目结构

```
TXSQL-Packages/
├── README.md
├── CLAUDE.md
├── Makefile
├── VERSION / SOURCE_COMMIT
├── installer/              # 安装器脚本
│   ├── install.sh          # 主安装入口（自包含）
│   ├── uninstall.sh        # 卸载脚本
│   ├── install-remote.sh   # 远程一键安装
│   └── lib/                # 模块化安装器库
├── build/                  # 构建脚本
├── config/                 # MySQL 配置模板
├── systemd/                # txsql.service
├── platforms/              # 平台配置
├── dist/                   # 离线包输出
└── docs/                   # 文档
```

---

## 构建（开发用）

```bash
# 构建特定平台（在对应构建机上）
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
| [INSTALL.md](docs/INSTALL.md) | 安装指南 |
| [UNINSTALL.md](docs/UNINSTALL.md) | 卸载指南 |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | 故障排除 |
| [DECISIONS.md](docs/DECISIONS.md) | 关键设计决策记录 |

---

## 发布

| 版本 | 日期 | 说明 |
|------|------|------|
| [v8.0.30-2.0.0](https://github.com/Bren-L/TXSQL-deploy/releases) | 2026-07-30 | CentOS 7.9 + openEuler 22.03 双平台支持 |
| [v8.0.30-1.0.0](https://github.com/Bren-L/TXSQL-deploy/releases/tag/v8.0.30-1.0.0) | 2026-07-23 | 首个正式发布，CentOS 7.9 x86_64 支持 |

---

## 许可证

本项目为 TXSQL 部署工具工程，遵循与 TXSQL 兼容的开源许可。
