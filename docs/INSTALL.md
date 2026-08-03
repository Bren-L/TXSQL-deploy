# TXSQL 安装指南

> **最新版本**: v8.0.30-2.0.1 | **支持平台**: CentOS 7.9 x86_64、openEuler 22.03 LTS-SP3 x86_64
> **GitHub**: https://github.com/Bren-L/TXSQL-deploy

---

## 前置依赖

**CentOS 7.9** minimal 已内置 `curl`、`tar`、`sudo`，无需额外安装。

**openEuler 22.03** minimal 可能缺少 `tar`，先安装：

```bash
dnf install -y tar curl sudo
```

---

## 部署流程（两台平台通用）

```
Step 1: 下载并解压（从 GitHub Release 获取离线包）
Step 2: bash install.sh </dev/null（一条命令，完全离线、无人值守）
Step 3: 安装完后 PATH 已自动配置，直接用
```

---

## 方式一：直接下载安装

以 **root** 用户，在联网的目标机器上执行对应平台的命令：

### CentOS 7.9 x86_64

```bash
# Step 1: 下载并解压
curl -fSL --retry 3 -# -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz \
  && cd txsql-offline-8.0.30-2.0.0-centos7.9-x86_64

# Step 2: 安装
bash install.sh </dev/null
```

### openEuler 22.03 LTS-SP3 x86_64

```bash
# Step 1: 下载并解压
curl -fSL --retry 3 -# -o txsql.tar.gz \
  https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz \
  && tar xzf txsql.tar.gz \
  && rm -f txsql.tar.gz \
  && cd txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64

# Step 2: 安装
bash install.sh </dev/null

```

---

## 方式二：本地下载后上传

如果目标机器无法访问 GitHub，先在本地浏览器下载对应平台的离线包，再上传到目标机器。

### CentOS 7.9 x86_64

**Step 1 — 本地下载**

浏览器打开：
```
https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz
```

**Step 2 — 上传到目标机器**

使用 Xshell、MobaXterm 等工具将 `txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz` 上传到目标机器的 `/root/` 目录。

**Step 3 — 解压并安装**

```bash
# 以 root 执行
tar xzf /root/txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz
cd txsql-offline-8.0.30-2.0.0-centos7.9-x86_64
bash install.sh </dev/null
```

### openEuler 22.03 LTS-SP3 x86_64

**Step 1 — 本地下载**

浏览器打开：
```
https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-2.0.0/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz
```

**Step 2 — 上传到目标机器**

使用 Xshell、MobaXterm 等工具将 `txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz` 上传到目标机器的 `/root/` 目录。

**Step 3 — 解压并安装**

```bash
# 以 root 执行
tar xzf /root/txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz
cd txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64
bash install.sh </dev/null
```

---

## 验证安装

部署完成后，验证以下 5 项：

```bash
# 1. 服务正在运行
systemctl status txsql | head -3

# 2. 端口已监听
ss -tlnp | grep 3306

# 3. 查看版本和 socket
mysql -u root -S /run/txsql/mysql.sock -e "SELECT VERSION(), @@socket;"
# → 8.0.30-txsql | /run/txsql/mysql.sock

# 4. 读写测试
mysql -u root -S /run/txsql/mysql.sock -e "
  CREATE DATABASE IF NOT EXISTS test_txsql;
  USE test_txsql;
  CREATE TABLE t (id INT, msg VARCHAR(50));
  INSERT INTO t VALUES (1, 'hello txsql');
  SELECT * FROM t;
  DROP DATABASE test_txsql;
"

# 5. 自启动已启用
systemctl is-enabled txsql
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

## 登录方式

TXSQL 安装完成后 **root 用户无密码**（`--initialize-insecure`），可通过以下方式登录：

```bash
# 本地 socket 登录（推荐，无需密码）
mysql -u root -S /run/txsql/mysql.sock

# TCP 登录（本机 localhost）
mysql -u root -h 127.0.0.1 -P 3306

# 远程 TCP 登录（需先修改 my.cnf 中的 bind-address）
mysql -u root -h <服务器IP> -P 3306
```

> **安全提示**：生产环境请在首次登录后立即设置 root 密码：
> ```sql
> ALTER USER 'root'@'localhost' IDENTIFIED BY '你的强密码';
> FLUSH PRIVILEGES;
> ```

---

## 自定义选项

```bash
bash install.sh \
  --port 3307 \
  --data-dir /data/txsql \
  --log-dir /var/log/txsql
```

所有选项通过命令行参数传入，安装过程零交互。

---

## 安装内容

| 组件 | 路径 |
|------|------|
| 服务端 | `/usr/lib/txsql/current/bin/mysqld` |
| 客户端 | `/usr/lib/txsql/current/bin/mysql*` |
| 配置文件 | `/etc/txsql/my.cnf` |
| 数据目录 | `/var/lib/txsql/data` |
| 日志 | `/var/log/txsql/` |
| 运行文件 | `/run/txsql/` |
| systemd 服务 | `/usr/lib/systemd/system/txsql.service` |
| 环境变量 | `/etc/profile.d/txsql.sh`（PATH 自动配置） |

## 卸载

```bash
bash uninstall.sh           # 保留数据、日志、配置
bash uninstall.sh --purge   # 完全清除（含数据）
```

卸载后重新安装会自动检测已有数据，不会重复初始化。

---

## 故障排除

| 问题 | 检查 |
|------|------|
| 端口被占用 | `ss -tlnp \| grep 3306` |
| 服务启动失败 | `journalctl -u txsql -f` |
| 连接被拒 | `ls -la /run/txsql/mysql.sock` |
| SELinux 拦截 | `ausearch -m avc -ts recent` |
| RPM 冲突 | `rpm -qa \| grep -i mysql`（先卸载旧版） |

详见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。
