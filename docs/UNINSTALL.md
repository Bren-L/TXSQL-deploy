# 卸载指南

---

## 默认卸载（保留数据）

```bash
bash uninstall.sh
```

移除内容：
- TXSQL RPM 包（CentOS）或二进制文件（openEuler）
- systemd 服务
- 本地 yum/dnf 仓库配置
- 运行目录 `/run/txsql`

保留内容：
- `/var/lib/txsql/data` — 所有数据库
- `/etc/txsql/` — 配置文件
- `/var/log/txsql/` — 日志

---

## 完全清除

```bash
bash uninstall.sh --purge
```

额外移除：
- `/var/lib/txsql/data` — 所有数据库（**不可恢复**）
- `/var/log/txsql/` — 所有日志
- `/etc/txsql/` — 配置文件
- `/root/.txsql_credentials` — 凭据文件

`--purge` 不会弹出确认提示，删除前会校验路径防止误删 `/`、`/var` 等系统目录。

---

## 卸载后重新安装

默认卸载保留了数据，重新运行 `install.sh` 会：
1. 检测已有数据目录（auto.cnf 存在）
2. 跳过数据库初始化
3. 重新安装包和服务
4. 沿用已有配置

---

## 手动清理

如果无卸载脚本：

```bash
# 停止并禁用服务
systemctl stop txsql
systemctl disable txsql
rm -f /usr/lib/systemd/system/txsql.service
systemctl daemon-reload

# CentOS: 卸载 RPM 包
rpm -e txsql-server txsql-client txsql-common

# openEuler: 删除二进制
rm -rf /usr/lib/txsql/8.0.30 /usr/lib/txsql/current

# 删除仓库配置
rm -f /etc/yum.repos.d/txsql-offline.repo

# 可选：删除数据（注意备份！）
# rm -rf /var/lib/txsql/data
```
