#!/bin/bash
set -Eeuo pipefail

log() {
  printf '[openconnect-socks5] %s\n' "$*"
}

require_env() {
  local name
  for name in VPN_USER VPN_PASSWORD VPN_HOST; do
    if [[ -z "${!name:-}" ]]; then
      printf '%s is required\n' "$name" >&2
      return 1
    fi
  done
}

vpn_args() {
  VPN_ARGS=(
    "--user=$VPN_USER"
    --passwd-on-stdin
    --os=linux-64
    "$VPN_HOST"
  )

  [[ -n "${VPN_SERVERCERT:-}" ]] && VPN_ARGS+=("--servercert=$VPN_SERVERCERT")
  [[ -n "${VPN_AUTH_GROUP:-}" ]] && VPN_ARGS+=("--authgroup=$VPN_AUTH_GROUP")

  case "${VPN_NO_DTLS:-}" in
    1|true|TRUE|yes|YES) VPN_ARGS+=(--no-dtls) ;;
  esac
}

dante_config() {
  local config_file=$1
  cat > "$config_file" <<EOF
logoutput: stderr
internal: ${SOCKS5_HOST:-0.0.0.0} port = ${SOCKS5_PORT:-8388}
external: tun0
user.privileged: root
user.unprivileged: nobody
clientmethod: none
socksmethod: none
client pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
}
socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  command: connect
  log: error connect disconnect iooperation
}
socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  command: udpassociate
  log: error connect disconnect iooperation
}
socks pass {
  from: 0.0.0.0/0 to: 0.0.0.0/0
  command: bindreply udpreply
  log: error connect disconnect iooperation
}
EOF
}

wait_for_tun() {
  local i
  for i in {1..30}; do
    [[ -e /sys/class/net/tun0 ]] && return 0
    sleep 1
  done
  return 1
}

run_openconnect() {
  local delay=5
  local status
  local dante_config_file

  dante_config_file=$(mktemp)
  dante_config "$dante_config_file"

  while :; do
    log "connecting to $VPN_HOST"
    printf '%s\n%s\n' "$VPN_PASSWORD" "${VPN_AUTH_CODE:-}" | openconnect "${VPN_ARGS[@]}" &
    openconnect_pid=$!

    if wait_for_tun; then
      danted -f "$dante_config_file" &
      socks5_pid=$!
      log "SOCKS5 TCP/UDP proxy started on ${SOCKS5_PORT:-8388}"
    else
      log 'tun0 was not created after VPN login'
    fi

    if wait "$openconnect_pid"; then
      status=0
    else
      status=$?
    fi

    kill "${socks5_pid:-}" 2>/dev/null || true
    wait "${socks5_pid:-}" 2>/dev/null || true
    socks5_pid=''
    ((stopping)) && return 0
    log "OpenConnect exited with status $status; retrying in ${delay}s"
    sleep "$delay"
    ((delay < 10)) && delay=$((delay * 2))
  done

  rm -f "$dante_config_file"
}

launch() {
  VPN_PASSWORD="${VPN_PASSWORD:-${VPN_PASSWD:-}}"
  export VPN_PASSWORD
  require_env
  vpn_args

  stopping=0
  cleanup() {
    stopping=1
    trap - EXIT INT TERM
    kill "${supervisor_pid:-}" "${openconnect_pid:-}" "${socks5_pid:-}" 2>/dev/null || true
    wait "${supervisor_pid:-}" "${openconnect_pid:-}" "${socks5_pid:-}" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  run_openconnect &
  supervisor_pid=$!
  wait "$supervisor_pid"
}

if [[ $# -eq 0 ]]; then
  launch
else
  exec "$@"
fi
