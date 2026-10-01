#!/usr/bin/env bash
# Shared helpers. No host changes occur when this file is sourced.
set -Eeuo pipefail
LAB_ROOT=/opt/waf-hardening-lab
# Used by scripts that source this file.
# shellcheck disable=SC2034
REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
note() { printf '\n[WAF LAB] %s\n' "$*"; }
need_root() { [[ $EUID -eq 0 ]] || die 'Run this command with sudo.'; }
private_ipv4() {
  python3 - "$1" <<'PY'
import ipaddress,sys
try:
    a=ipaddress.ip_address(sys.argv[1])
    ranges=['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']
    assert a.version==4 and any(a in ipaddress.ip_network(r) for r in ranges)
except (ValueError,AssertionError):
    sys.exit('Use an RFC1918 private IPv4 address for this isolated lab.')
PY
}
load_lab() {
  [[ -f "$LAB_ROOT/.managed" ]] || die 'Managed installation not found. Read README.md.'
  LAB_IP=$(sed -n 's/^LAB_IP=//p' "$LAB_ROOT/.env")
  private_ipv4 "$LAB_IP"
}
dc() { docker compose --project-directory "$LAB_ROOT" -f "$LAB_ROOT/compose.yaml" "$@"; }
wait_http() {
  local url=$1
  for _ in {1..60}; do
    if curl --noproxy '*' -kfsS -H 'Host: dvwa.local' --max-time 3 "$url" -o /dev/null; then return 0; fi
    sleep 2
  done
  return 1
}
stamp() { date -u +%Y%m%dT%H%M%S%NZ; }
