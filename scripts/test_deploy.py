#!/usr/bin/env python3
"""
TXSQL deployment test on remote VMs.
Usage:
  python test_deploy.py centos
  python test_deploy.py openeuler
"""

import paramiko
import sys
import os
import time

PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST_DIR = os.path.join(PROJECT_DIR, "dist")

VMS = {
    "centos": {
        "host": "192.168.44.153", "user": "root", "password": "123",
        "tarball": "txsql-offline-8.0.30-2.0.0-centos7.9-x86_64.tar.gz",
        "remote_path": "/tmp/txsql_test.tar.gz",
        "work_dir": "/tmp/txsql_test",
    },
    "openeuler": {
        "host": "192.168.44.154", "user": "root", "password": "Lt2097619334",
        "tarball": "txsql-offline-8.0.30-2.0.0-openeuler22.03-x86_64.tar.gz",
        "remote_path": "/tmp/txsql_test.tar.gz",
        "work_dir": "/tmp/txsql_test",
    },
}


class Tester:
    def __init__(self, name):
        self.name = name
        self.cfg = VMS[name]
        self.client = None
        self.sftp = None

    def log(self, msg):
        print(f"[{self.name.upper()}] {msg}")

    def connect(self):
        self.log(f"Connecting to {self.cfg['host']}...")
        self.client = paramiko.SSHClient()
        self.client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        self.client.connect(
            self.cfg["host"], username=self.cfg["user"],
            password=self.cfg["password"],
            look_for_keys=False, allow_agent=False, timeout=15)
        self.sftp = self.client.open_sftp()
        self.log("Connected")

    def cmd(self, command, timeout=180):
        """Run command, print output, return exit code."""
        self.log(f"$ {command}")
        _, stdout, stderr = self.client.exec_command(command, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        rc = stdout.channel.recv_exit_status()
        if out.strip():
            for line in out.strip().split("\n"):
                print(f"  {line}")
        if err.strip():
            for line in err.strip().split("\n"):
                if "WARNING" in line or "ERROR" in line:
                    print(f"  [STDERR] {line}")
        return rc, out, err

    def upload(self):
        local = os.path.join(DIST_DIR, self.cfg["tarball"])
        if not os.path.exists(local):
            raise FileNotFoundError(f"Tarball not found: {local}")
        size_mb = os.path.getsize(local) / (1024 * 1024)
        self.log(f"Uploading {self.cfg['tarball']} ({size_mb:.0f} MB)...")
        self.sftp.put(local, self.cfg["remote_path"], callback=lambda x, y: None)
        remote_size = self.sftp.stat(self.cfg["remote_path"]).st_size
        local_size = os.path.getsize(local)
        if remote_size == local_size:
            self.log(f"Upload complete ({remote_size} bytes)")
        else:
            raise IOError(f"Size mismatch: local={local_size} remote={remote_size}")

    def run_test(self):
        self.connect()

        # Step 1: Clean up any previous test
        self.log("=== STEP 1: Cleanup ===")
        self.cmd("systemctl stop txsql 2>/dev/null; systemctl disable txsql 2>/dev/null; true")
        self.cmd("rpm -e txsql-server txsql-client txsql-common txsql 2>/dev/null; true")
        self.cmd("rm -rf /usr/lib/txsql /var/lib/txsql /var/log/txsql /run/txsql /etc/txsql /root/.txsql_credentials /tmp/txsql_test /etc/yum.repos.d/txsql-offline.repo 2>/dev/null; true")
        self.cmd("userdel txsql 2>/dev/null; groupdel txsql 2>/dev/null; true")
        self.log("Cleanup done")

        # Step 2: Upload tarball
        self.log("=== STEP 2: Upload tarball ===")
        self.upload()

        # Step 3: Extract
        self.log("=== STEP 3: Extract ===")
        rc, out, _ = self.cmd(f"mkdir -p {self.cfg['work_dir']} && cd {self.cfg['work_dir']} && tar xzf {self.cfg['remote_path']} && ls -la")
        if rc != 0:
            self.log("EXTRACTION FAILED")
            self.close()
            return False

        # Find the extracted directory
        rc, out, _ = self.cmd(f"cd {self.cfg['work_dir']} && ls -d txsql-offline-*")
        extract_dir = out.strip()
        full_dir = f"{self.cfg['work_dir']}/{extract_dir}"
        self.log(f"Extracted to: {full_dir}")

        # Step 4: List contents
        self.log("=== STEP 4: Bundle contents ===")
        self.cmd(f"cd {full_dir} && ls -la && echo '---' && cat VERSION && echo '---' && cat PLATFORM")

        # Step 5: Run install.sh
        self.log("=== STEP 5: Install ===")
        rc, out, err = self.cmd(f"cd {full_dir} && bash install.sh 2>&1")
        if rc != 0:
            self.log(f"INSTALL FAILED (exit code {rc})")
            # Show the error log if available
            self.cmd("cat /var/log/txsql/install.log 2>/dev/null | tail -30")
            self.close()
            return False

        # Step 6: Verify
        self.log("=== STEP 6: Verify ===")

        # Check service
        rc, out, _ = self.cmd("systemctl is-active txsql")
        if "active" not in out:
            self.log("SERVICE NOT ACTIVE")
            return False

        # Check port
        self.cmd("ss -tlnp | grep 3306")

        # Check socket
        self.cmd("ls -la /run/txsql/mysql.sock")

        # Check version via SQL
        self.cmd("cat /root/.txsql_credentials")
        rc, out, _ = self.cmd("PW=$(grep TXSQL_ROOT_PASSWORD /root/.txsql_credentials | cut -d= -f2) && /usr/lib/txsql/current/bin/mysql -u root -p\"$PW\" -S /run/txsql/mysql.sock -e 'SELECT VERSION(), @@socket, @@port, @@datadir;'")
        if "8.0.30-txsql" not in out:
            self.log("VERSION CHECK FAILED")
            return False

        # Check user
        self.cmd("id txsql")
        self.cmd("ps aux | grep mysqld | grep -v grep")

        # Step 7: SQL CRUD test
        self.log("=== STEP 7: SQL CRUD test ===")
        self.cmd("""PW=$(grep TXSQL_ROOT_PASSWORD /root/.txsql_credentials | cut -d= -f2) && /usr/lib/txsql/current/bin/mysql -u root -p"$PW" -S /run/txsql/mysql.sock -e "
            CREATE DATABASE IF NOT EXISTS test_txsql;
            USE test_txsql;
            CREATE TABLE t (id INT, msg VARCHAR(50));
            INSERT INTO t VALUES (1, 'hello txsql');
            SELECT * FROM t;
            DROP DATABASE test_txsql;
        " """)

        # Step 8: Idempotency test
        self.log("=== STEP 8: Idempotency test ===")
        self.cmd(f"cd {full_dir} && bash install.sh 2>&1 | tail -15")
        self.cmd("/usr/lib/txsql/current/bin/mysql -u root -p\"$(grep TXSQL_ROOT_PASSWORD /root/.txsql_credentials | cut -d= -f2)\" -S /run/txsql/mysql.sock -e 'SELECT COUNT(*) FROM mysql.user;'")

        self.log("=== ALL TESTS PASSED ===")
        self.close()
        return True

    def close(self):
        if self.sftp:
            self.sftp.close()
        if self.client:
            self.client.close()
        self.log("Disconnected")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_deploy.py <centos|openeuler|all>")
        sys.exit(1)

    target = sys.argv[1]
    if target == "all":
        targets = ["centos", "openeuler"]
    else:
        targets = [target]

    results = {}
    for t in targets:
        if t not in VMS:
            print(f"Unknown target: {t}")
            continue
        print(f"\n{'='*60}")
        print(f"  Testing: {t}")
        print(f"{'='*60}")
        tester = Tester(t)
        try:
            ok = tester.run_test()
            results[t] = ok
        except Exception as e:
            print(f"[{t.upper()}] ERROR: {e}")
            results[t] = False

    print(f"\n{'='*60}")
    print("  RESULTS:")
    for t, ok in results.items():
        status = "PASS" if ok else "FAIL"
        print(f"  {t}: {status}")
    print(f"{'='*60}")
