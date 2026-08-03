#!/usr/bin/env python3
"""SSH to Kylin V11 VM with extended timeouts for heavily-loaded system."""
import paramiko
import sys
import time

HOST = "192.168.44.157"
USER = "root"
PASSWORD = "Lt314147"

def ssh_cmd(command, timeout=300):
    """Run command on Kylin VM with long timeouts."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

    for attempt in range(5):
        try:
            client.connect(
                HOST, username=USER, password=PASSWORD,
                look_for_keys=False, allow_agent=False,
                timeout=120, banner_timeout=120, auth_timeout=60
            )
            break
        except Exception as e:
            print(f"  Connect attempt {attempt+1}/5: {e}")
            time.sleep(10)
    else:
        print("ERROR: Could not connect after 5 attempts")
        return "", "", -1

    try:
        _, stdout, stderr = client.exec_command(command, timeout=timeout)
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        rc = stdout.channel.recv_exit_status()
        return out, err, rc
    finally:
        client.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python ssh_kylin.py <command>")
        sys.exit(1)

    cmd = " ".join(sys.argv[1:])
    print(f"$ {cmd[:80]}...")
    out, err, rc = ssh_cmd(cmd)
    if out.strip():
        print(out.strip())
    if err.strip():
        print(f"[STDERR] {err.strip()[:500]}")
    print(f"EXIT: {rc}")
