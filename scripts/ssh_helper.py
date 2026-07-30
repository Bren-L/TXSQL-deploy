#!/usr/bin/env python3
"""
SSH helper for TXSQL VM testing.
Usage:
  python ssh_helper.py centos cmd "cat /etc/centos-release"
  python ssh_helper.py centos upload <local> <remote>
  python ssh_helper.py openeuler cmd "dnf list installed | head"
  python ssh_helper.py openeuler upload <local> <remote>
"""

import paramiko
import sys
import os

VMS = {
    "centos":    {"host": "192.168.44.153", "user": "root", "password": "123"},
    "openeuler": {"host": "192.168.44.154", "user": "root", "password": "Lt2097619334"},
}

def ssh_cmd(vm, command, timeout=120):
    """Run a command on the VM via SSH, return (stdout, stderr, exit_code)."""
    cfg = VMS[vm]
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(cfg["host"], username=cfg["user"], password=cfg["password"],
                       look_for_keys=False, allow_agent=False, timeout=10)
        _, stdout, stderr = client.exec_command(command, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        rc = stdout.channel.recv_exit_status()
        return out, err, rc
    finally:
        client.close()

def upload_file(vm, local_path, remote_path):
    """Upload a file to the VM via SFTP."""
    cfg = VMS[vm]
    transport = paramiko.Transport((cfg["host"], 22))
    try:
        transport.connect(username=cfg["user"], password=cfg["password"])
        sftp = paramiko.SFTPClient.from_transport(transport)
        sftp.put(local_path, remote_path)
        print(f"Uploaded: {local_path} → {vm}:{remote_path}")
        # Get remote file size to verify
        remote_stat = sftp.stat(remote_path)
        local_size = os.path.getsize(local_path)
        if remote_stat.st_size == local_size:
            print(f"Size verified: {local_size} bytes")
        else:
            print(f"WARNING: Size mismatch! Local={local_size} Remote={remote_stat.st_size}")
        sftp.close()
    finally:
        transport.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    vm = sys.argv[1].lower()
    if vm not in VMS:
        print(f"Unknown VM: {vm}. Options: {list(VMS.keys())}")
        sys.exit(1)

    action = sys.argv[2] if len(sys.argv) > 2 else "cmd"

    if action == "cmd":
        cmd = " ".join(sys.argv[3:]) if len(sys.argv) > 3 else "echo OK"
        out, err, rc = ssh_cmd(vm, cmd)
        if out:
            print(out.rstrip())
        if err:
            print(f"[STDERR] {err.rstrip()}")
        sys.exit(rc)

    elif action == "upload":
        if len(sys.argv) < 5:
            print("Usage: python ssh_helper.py <vm> upload <local_path> <remote_path>")
            sys.exit(1)
        local_path = sys.argv[3]
        remote_path = sys.argv[4]
        # Convert Windows path if needed
        upload_file(vm, local_path, remote_path)

    else:
        print(f"Unknown action: {action}")
        sys.exit(1)
