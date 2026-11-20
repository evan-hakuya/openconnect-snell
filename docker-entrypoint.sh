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

socks5_args() {
  SOCKS5_ARGS=(-i "${SOCKS5_HOST:-0.0.0.0}" -p "${SOCKS5_PORT:-8388}")

  if [[ -n "${SOCKS5_USER:-}" || -n "${SOCKS5_PASSWORD:-}" ]]; then
    if [[ -z "${SOCKS5_USER:-}" || -z "${SOCKS5_PASSWORD:-}" ]]; then
      echo 'SOCKS5_USER and SOCKS5_PASSWORD must be provided together' >&2
      return 1
    fi
    SOCKS5_ARGS+=(-u "$SOCKS5_USER" -P "$SOCKS5_PASSWORD")
  fi
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
  vpn_args
  socks5_args

  stopping=0
  cleanup() {
    stopping=1
    trap - EXIT INT TERM
    kill "${vpn_pid:-}" "${socks5_pid:-}" 2>/dev/null || true
    wait "${vpn_pid:-}" "${socks5_pid:-}" 2>/dev/null || true
  }
  trap cleanup EXIT INT TERM

  microsocks "${SOCKS5_ARGS[@]}" &
  socks5_pid=$!
  run_openconnect &
  vpn_pid=$!
  wait "$socks5_pid"
}

if [[ $# -eq 0 ]]; then
  launch
else
  exec "$@"
fi
