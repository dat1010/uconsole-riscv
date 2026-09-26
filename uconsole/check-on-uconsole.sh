#!/bin/sh
set -eu

if [ "$(uname -m)" != riscv64 ]; then
    echo 'Run this check on the RISC-V uConsole.' >&2
    exit 1
fi
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v python3 >/dev/null
"$package_dir/codex" --version
"$package_dir/codex-resources/bwrap" --version

check_dir=$(mktemp -d "$HOME/codex-sandbox-check.XXXXXX")
trap 'rm -f -- "$check_dir/blocked.txt"; rmdir -- "$check_dir"' EXIT HUP INT TERM
"$package_dir/codex" sandbox -c 'sandbox_mode="read-only"' -- python3 - "$check_dir/blocked.txt" <<'PY'
import errno
import socket
import sys

try:
    with open(sys.argv[1], "w") as handle:
        handle.write("sandbox write probe\n")
except OSError as error:
    if error.errno not in (errno.EACCES, errno.EPERM, errno.EROFS):
        raise
else:
    raise SystemExit("FAIL: read-only sandbox allowed a write")

try:
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
except OSError as error:
    if error.errno != errno.EPERM:
        raise
else:
    probe.close()
    raise SystemExit("FAIL: network sandbox allowed an IPv4 socket")

print("PASS: filesystem writes and IPv4 sockets are blocked")
PY
