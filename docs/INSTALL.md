# TXSQL 安装指南

> **最新版本**: v8.0.30-1.0.0 | **支持平台**: CentOS 7.9 x86_64
> **GitHub**: https://github.com/Bren-L/TXSQL-deploy

---

## 方式一：curl 一键安装（推荐，需联网）

在目标 CentOS 7.9 机器上以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/Bren-L/TXSQL-deploy/main/installer/install-remote.sh | sudo bash
```

脚本会自动完成：平台检测 → 下载离线包 → 解压 → RPM 安装 → 初始化数据库 → 启动服务。

> ⚠️ 如果你不信任 `curl | bash` 模式，请使用下方的方式二或方式三。

---

## 方式二：手动下载安装（需联网）

```bash
# 1. 从 GitHub Release 下载（替换 URL 为最新版本）
wget https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz

# 2. 验证文件完整性（可选但推荐）
sha256sum txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz
# 预期: dbc2d23c6fedfc947f866144ff760ae4e8a646fcfece765ba88f947d7791cb4e

# 3. 解压
tar xzf txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz
cd txsql-offline-8.0.30-1.0.0-centos7.9-x86_64

# 4. 安装（完全离线、零交互）
sudo bash install.sh
```

---

## 方式三：离线安装（目标机器无网络）

### 步骤 1：在可联网机器上下载

```bash
# 从 GitHub Release 下载离线包
wget https://github.com/Bren-L/TXSQL-deploy/releases/download/v8.0.30-1.0.0/txsql-offline-8.0.30-1.0.0-centos7.9-x86_64.tar.gz
```

### 步骤 2：传输到目标机器

```bash
# 通过 U 盘、SCP 等方式传输
scp txsql-offline-*.tar.gz root@<目标机器IP>:/tmp/
```

### 步骤 3：在目标机器上安装

```bash
tar xzf /tmp/txsql-offline-*.tar.gz -C /tmp/
cd /tmp/txsql-offline-*/
sudo bash install.sh
```

---

## 验证安装

```bash
# 查看服务状态
sudo systemctl status txsql

# 获取 root 密码
sudo cat /root/.txsql_credentials

# 连接数据库
mysql -u root -p -S /var/lib/txsql/mysql.sock

# 查看版本
mysql> SELECT VERSION();
-- 8.0.30-txsql
```

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
# 保留数据、日志、配置（默认）
sudo bash uninstall.sh

# 完全清除（含数据）
sudo bash uninstall.sh --purge
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
