# TXSQL 8.0.30 一键安装部署工具

> 一条命令 · 多平台支持

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

1. **一键安装部署** — `sudo bash install.sh </dev/null` 零交互
2. **每平台独立** — 独立构建、独立依赖闭包、独立验收
3. **系统原生包管理** — CentOS 使用 RPM/yum，openEuler 使用二进制部署
4. **安全优先** — 不删数据、不强制覆盖、冲突即退出
5. **测试门禁** — 未经原生系统验收的平台不声明支持
6. **幂等安装** — 重复安装检测已有数据，不重复初始化

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

### 环境准备

首先以 root 身份创建一个具有 sudo 权限的 `txsql` 用户，后续所有操作均在该用户下进行：

```bash
# 创建 txsql 用户
sudo useradd -m txsql

# 设置密码
sudo passwd txsql

# 授予 sudo 权限
sudo usermod -aG wheel txsql

# 切换到 txsql 用户
su - txsql
```

> **注意**：CentOS 7 的 wheel 组默认已配置 sudo 权限。如果未生效，可执行 `visudo` 确认 `%wheel ALL=(ALL) ALL` 未被注释。

### 方式一：直接下载安装

在 `txsql` 用户下执行：

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

### 方式二：本地下载后上传

如果虚拟机无法直接访问 GitHub，先在本地下载再上传。

**Step 1：本地下载**

在浏览器中访问以下地址，下载对应平台的压缩包：

```
https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz
```

**Step 2：上传到虚拟机**

使用 Xshell、MobaXterm 等工具将下载的压缩包上传到虚拟机，例如上传到 `/home/txsql/` 目录。

**Step 3：解压并安装**

切换到 `txsql` 用户，在 `/home/txsql/` 下操作：

```bash
# 切换到 txsql 用户（如尚未切换）
su - txsql

# 解压
tar xzf /home/txsql/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz

# 进入解压目录
cd txsql-offline-8.0.30-2.0.0-centos7.9-x86_64

# 一键安装
sudo bash install.sh </dev/null
```

---

## 🚀 快速开始 — openEuler 22.03 LTS-SP3

> 最新版本: [v8.0.30-2.0.0](https://github.com/Bren-L/TXSQL-deploy/releases)

### 前置依赖

openEuler 22.03 minimal 已内置 `curl`、`tar`、`sudo`，**无需安装任何额外依赖**。

### 环境准备

首先以 root 身份创建一个具有 sudo 权限的 `txsql` 用户，后续所有操作均在该用户下进行：

```bash
# 创建 txsql 用户
sudo useradd -m txsql

# 设置密码
sudo passwd txsql

# 授予 sudo 权限
sudo usermod -aG wheel txsql

# 切换到 txsql 用户
su - txsql
```

> **注意**：openEuler 的 wheel 组默认已配置 sudo 权限。如果未生效，可执行 `visudo` 确认 `%wheel ALL=(ALL) ALL` 未被注释。

### 方式一：直接下载安装

在 `txsql` 用户下执行：

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

### 方式二：本地下载后上传

如果虚拟机无法直接访问 GitHub，先在本地下载再上传。

**Step 1：本地下载**

在浏览器中访问以下地址，下载对应平台的压缩包：

```
https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz
```

**Step 2：上传到虚拟机**

使用 Xshell、MobaXterm 等工具将下载的压缩包上传到虚拟机，例如上传到 `/home/txsql/` 目录。

**Step 3：解压并安装**

切换到 `txsql` 用户，在 `/home/txsql/` 下操作：

```bash
# 切换到 txsql 用户（如尚未切换）
su - txsql

# 解压
tar xzf /home/txsql/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz

# 进入解压目录
cd txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64

# 一键安装
sudo bash install.sh </dev/null
```

### 配置环境变量

安装完成后，将 MySQL 客户端加入 PATH：

```bash
echo 'export PATH="/usr/lib/txsql/current/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
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
| [v8.0.30-2.0.0](https://github.com/Bren-L/TXSQL-deploy/releases) | 2026-07-31 | CentOS 7.9 + openEuler 22.03 双平台支持 (修订版) |
| [v8.0.30-1.0.0](https://github.com/Bren-L/TXSQL-deploy/releases/tag/v8.0.30-1.0.0) | 2026-07-23 | 首个正式发布，CentOS 7.9 x86_64 支持 |

### v8.0.30-2.0.0 SHA-256

| 包文件 | SHA-256 |
|--------|---------|
| `txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz` | `32806af60e88d5847fe19eb803d3ce47fe98a1b71579a7c9a9d3d1f8936cfbfa` |
| `txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz` | `d76c7f2bb13530fd68861559deca8197690c9255a11fd4b9b4d4fe983e08dc64` |

---

## 许可证

本项目为 TXSQL 部署工具工程，遵循与 TXSQL 兼容的开源许可。
