#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
entrypoint="$project_root/docker-entrypoint.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/openconnect" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-V" ]]; then
  exit 0
fi
exit 1
EOF

cat > "$tmpdir/danted" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-v" ]]; then
  exit 0
fi
exit 0
EOF

chmod +x "$tmpdir/openconnect" "$tmpdir/danted"

if PATH="$tmpdir:$PATH" timeout 3 "$entrypoint" >"$tmpdir/missing.log" 2>&1; then
  echo "expected missing credentials to fail" >&2
  exit 1
fi

grep -q "VPN_USER is required" "$tmpdir/missing.log"
grep -q 'delay < 10' "$entrypoint"

cat > "$tmpdir/openconnect" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-V" ]]; then
  exit 0
fi
cat > "$MOCK_INPUT"
exit 1
EOF

cat > "$tmpdir/danted" <<'EOF'
#!/usr/bin/env bash
while :; do /bin/sleep 30; done
EOF

cat > "$tmpdir/sleep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$MOCK_SLEEP"
/bin/sleep 0.01
EOF

chmod +x "$tmpdir/openconnect" "$tmpdir/danted" "$tmpdir/sleep"

set +e
PATH="$tmpdir:$PATH" \
  MOCK_INPUT="$tmpdir/openconnect.input" \
  MOCK_SLEEP="$tmpdir/sleep.log" \
  VPN_USER=test-user \
  VPN_PASSWD=test-password \
  VPN_HOST=vpn.example.com \
  SNELL_PSK=test-psk \
  timeout -s TERM 2 "$entrypoint" >"$tmpdir/runtime.log" 2>&1
runtime_status=$?
set -e

[[ "$runtime_status" -eq 124 || "$runtime_status" -eq 143 ]]
grep -q '^test-password$' "$tmpdir/openconnect.input"
! grep -q 'test-password\|test-psk' "$tmpdir/runtime.log"
! awk '$1 > 10 { found = 1 } END { exit found }' "$tmpdir/sleep.log"

echo "entrypoint validation test passed"
