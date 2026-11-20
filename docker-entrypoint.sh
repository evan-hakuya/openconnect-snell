#!/bin/bash
set -Eeuo pipefail

log() {
  printf '[openconnect-snell] %s\n' "$*"
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

run_openconnect() {
  local delay=5
  local status

  while :; do
    log "connecting to $VPN_HOST"
    if printf '%s\n%s\n' "$VPN_PASSWORD" "${VPN_AUTH_CODE:-}" | openconnect "${VPN_ARGS[@]}"; then
      status=0
    else
      status=$?
    fi

    ((stopping)) && return 0
    log "OpenConnect exited with status $status; retrying in ${delay}s"
    sleep "$delay"
    ((delay < 10)) && delay=$((delay * 2))
  done
}

launch() {
  VPN_PASSWORD="${VPN_PASSWORD:-${VPN_PASSWD:-}}"
  export VPN_PASSWORD
  require_env

  if [[ -z "${SNELL_PSK:-}" ]]; then
    SNELL_PSK=$(hexdump -n 16 -e '4/4 "%08x" 1 "\n"' /dev/urandom)
  fi

  vpn_args
  umask 077
  local config_file
  config_file=$(mktemp)
  printf '[snell-server]\nlisten = %s:%s\npsk = %s\nobfs = %s\n' \
    "${SNELL_HOST:-0.0.0.0}" "${SNELL_PORT:-8388}" "$SNELL_PSK" "${SNELL_OBFS:-off}" > "$config_file"

  stopping=0
  cleanup() {
    stopping=1
    trap - EXIT INT TERM
    kill "${vpn_pid:-}" "${snell_pid:-}" 2>/dev/null || true
    wait "${vpn_pid:-}" "${snell_pid:-}" 2>/dev/null || true
    rm -f "$config_file"
  }
  trap cleanup EXIT INT TERM

  snell-server -c "$config_file" &
  snell_pid=$!
  run_openconnect &
  vpn_pid=$!
  wait "$snell_pid"
}

if [[ $# -eq 0 ]]; then
  launch
else
  exec "$@"
fi
