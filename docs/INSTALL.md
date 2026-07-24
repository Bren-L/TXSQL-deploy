# TXSQL 安装指南

> **最新版本**: v8.0.30-1.0.0 | **支持平台**: CentOS 7.9 x86_64
> **GitHub**: https://github.com/Bren-L/TXSQL-deploy

---

## 部署流程

```
Step 1: 下载并解压（从 GitHub Release 获取离线包）
Step 2: 安装部署（一条命令，完全离线、无人值守）
```

---

## 前置依赖

CentOS 7 minimal 已内置 `curl`、`tar`、`sudo`，**无需安装任何额外依赖**。

```bash
# 确认依赖就绪（三个命令都应该存在）
which curl tar sudo
```

---

## 方式一：一键自动部署

在目标 CentOS 7.9 机器上以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash
```

脚本自动完成下载解压和安装部署，无需手动操作。

---

## 方式二：手动两步部署（推荐，清晰可控）

### Step 1 — 下载并解压

从 [GitHub Release](https://github.com/Bren-L/TXSQL-deploy/releases) 下载离线包并解压：

```bash
# 下载（自动重试 3 次）→ 校验成功 → 解压 → 删除安装包 → 进入目录
curl -fsSL --retry 3 -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz \
  && cd txsql-offline-8.0.30-1.0.0-centos7.9-x86_64
```

> `--retry 3` 自动重试应对网络波动；`&&` 保证下载失败不会解压残缺文件。
>
> ⚠️ 国内访问 GitHub 可能不稳定，如遇 `TCP connection reset` 可设置代理后重试：
> ```bash
> export https_proxy=http://<代理IP>:<端口>
> ```
> 或使用[方式三](#方式三离线环境目标机器无网络)离线传输。

### Step 2 — 安装部署

```bash
sudo bash install.sh
```

安装过程完全离线、零交互。完成后 TXSQL 已通过 systemd 启动运行。

---

## 方式三：离线环境（目标机器无网络）

在可联网机器上做 Step 1，然后把解压后的目录传到目标机器，再执行 Step 2。

```bash
# === 可联网机器 ===

# Step 1: 下载并解压
curl -fsSL --retry 3 -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz

# 传输解压后的目录到目标机器
scp -r txsql-offline-*/ root@<目标机器IP>:/tmp/


# === 目标机器（离线） ===

# Step 2: 安装部署（tar 和 bash 已内置，无需额外依赖）
cd /tmp/txsql-offline-*/
sudo bash install.sh
```

---

## 验证安装

部署完成后，依次检查以下 5 项即可确认成功：

```bash
# 1. 服务正在运行
sudo systemctl status txsql | head -3

# 2. 端口已监听
sudo ss -tlnp | grep 3306

# 3. 查看 TXSQL 版本
sudo cat /root/.txsql_credentials   # 先取密码
mysql -u root -p -S /var/lib/txsql/mysql.sock -e "SELECT VERSION();"
# → 8.0.30-txsql

# 4. 读写测试
mysql -u root -p -S /var/lib/txsql/mysql.sock -e "
  CREATE DATABASE IF NOT EXISTS test_txsql;
  USE test_txsql;
  CREATE TABLE t (id INT, msg VARCHAR(50));
  INSERT INTO t VALUES (1, 'hello txsql');
  SELECT * FROM t;
  DROP DATABASE test_txsql;
"

# 5. systemd 自启动已启用
sudo systemctl is-enabled txsql
# → enabled
```

| # | 检查项 | 通过标志 |
|---|--------|----------|
| 1 | 服务状态 | `active (running)` |
| 2 | 端口监听 | `LISTEN 3306` |
| 3 | 版本号 | `8.0.30-txsql` |
| 4 | 读写 | INSERT + SELECT 正常 |
| 5 | 自启动 | `enabled` |

全部通过即部署成功 ✅

---

## 自定义选项

```bash
sudo bash install.sh \
  --port 3307 \
  --data-dir /data/txsql \
  --log-dir /var/log/txsql
```

所有选项通过命令行参数传入，安装过程不会弹出任何交互提示。

---

## 安装内容

| 组件 | 路径 |
|------|------|
| 服务端 | `/usr/lib/txsql/current/bin/mysqld` |
| 客户端 | `/usr/lib/txsql/current/bin/mysql*` |
| 私有库 | `/usr/lib/txsql/current/lib/private/` |
| 配置文件 | `/etc/txsql/my.cnf` |
| 数据目录 | `/var/lib/txsql/data` |
| 日志 | `/var/log/txsql/` |
| 运行文件 | `/run/txsql/` |
| systemd 服务 | `/usr/lib/systemd/system/txsql.service` |
| root 凭据 | `/root/.txsql_credentials` |

---

## 卸载

```bash
sudo bash uninstall.sh           # 保留数据、日志、配置（默认）
sudo bash uninstall.sh --purge   # 完全清除（含数据）
```

卸载后重新安装会自动检测已有数据，不会重复初始化。

---

## 故障排除

| 问题 | 检查 |
|------|------|
| 端口被占用 | `sudo ss -tlnp \| grep 3306` |
| 服务启动失败 | `sudo journalctl -u txsql -f` |
| 连接被拒 | `ls -la /var/lib/txsql/mysql.sock` |
| SELinux 拦截 | `sudo ausearch -m avc -ts recent` |
| RPM 冲突 | `rpm -qa \| grep -i mysql`（先卸载旧版） |

详细内容见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。
