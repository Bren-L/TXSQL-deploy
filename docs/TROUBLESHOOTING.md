# Troubleshooting

---

## 常见问题

### "mysql: command not found" / "mysql: 未找到命令"

**原因**: PATH 未生效。

**解决**:
```bash
source /etc/profile.d/txsql.sh
# 或直接用完整路径
/usr/lib/txsql/current/bin/mysql -u root -S /run/txsql/mysql.sock
```

### "ERROR 2002: Can't connect through socket"

**原因**: mysqld 未运行或 socket 路径不对。

**解决**:
```bash
systemctl status txsql
ls -la /run/txsql/mysql.sock
```

### "mysqld fails to start" / 服务启动失败

**解决**:
```bash
# 查看日志
journalctl -u txsql -n 100
tail -100 /var/log/txsql/error.log

# 端口占用
ss -tlnp | grep 3306

# SELinux 拦截
ausearch -m avc -ts recent

# 文件权限
ls -la /var/lib/txsql/data/
ls -la /etc/txsql/
```

### "Library not found" errors

**原因**: 运行时依赖缺失。

**检查**:
```bash
ldd /usr/lib/txsql/current/bin/mysqld | grep "not found"
```

### "Dependency resolution failed"（CentOS RPM 模式）

**原因**: 本地 yum 仓库缺少依赖包。

**解决**:
```bash
yum --disablerepo='*' --enablerepo='txsql-offline' deplist txsql-server
```

### 端口被占用

```bash
ss -tlnp | grep 3306
# 如被占用，可指定其他端口安装：
bash install.sh --port 3307
```

### RPM 冲突

```bash
# 检查是否已有 MySQL/MariaDB
rpm -qa | grep -iE 'mysql|mariadb'
# 先卸载旧版再安装 TXSQL
```

---

## 日志位置

| 组件 | 路径 |
|------|------|
| 安装日志 | `/var/log/txsql/install.log` |
| MySQL 错误 | `/var/log/txsql/error.log` |
| MySQL 通用 | `/var/log/txsql/general.log`（需开启） |
| 慢查询 | `/var/log/txsql/slow.log`（需开启） |
| systemd | `journalctl -u txsql` |
| SELinux | `ausearch -m avc -ts recent` |
| RPM/yum | `/var/log/yum.log` 或 `dnf.log` |
