#!/usr/bin/env bash
set -euo pipefail

test -e /sys/class/net/tun0
test -e /proc/1
grep -qs '[[:space:]]tun0:' /proc/net/dev
grep -qs danted /proc/*/comm
grep -qs openconnect /proc/*/comm
