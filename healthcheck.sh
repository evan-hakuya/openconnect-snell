#!/usr/bin/env bash
set -euo pipefail

test -e /sys/class/net/tun0
test -e /proc/1
grep -qs '^tun0:' /proc/net/dev
grep -qs 'openconnect' /proc/*/comm
