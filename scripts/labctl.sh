#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
usage() {
  cat <<'EOF'
Usage: sudo bash scripts/labctl.sh COMMAND [ARGUMENT]
  status | start | stop | benchmark | protection
  switch modsecurity|safeline
  blacklist PRIVATE_IP | whitelist PRIVATE_IP | reset-rules
  rate-limit on|off
  ban PRIVATE_IP | unban PRIVATE_IP
  backup
Examples apply only to the managed lab at /opt/waf-hardening-lab.
EOF
}
[[ ${1:-} != --help && ${1:-} != -h ]] || { usage; exit 0; }
need_root
load_lab
CMD=${1:-status}
ARG=${2:-}
apply_rules() {
  local backup
  backup="$LAB_ROOT/backups/custom-$(stamp).conf"
  cp "$LAB_ROOT/rules/custom.conf" "$backup"
  # Keep the bind-mounted inode; an atomic rename can leave the old file mounted.
  cat "$1" >"$LAB_ROOT/rules/custom.conf"
  if ! docker exec waflab-modsecurity nginx -t; then
    cat "$backup" >"$LAB_ROOT/rules/custom.conf"
    die "Invalid rules; restored $backup"
  fi
  docker exec waflab-modsecurity nginx -s reload
  note "Rules applied. Previous file: $backup"
}
check_safeline_stopped() {
  if docker ps --format '{{.Names}}' | grep -Eq '^safeline([_-]|$)'; then
    die 'SafeLine is running. Use labctl.sh switch modsecurity.'
  fi
}
start_modsec() {
  check_safeline_stopped
  # No empty DOCKER-USER chain is created here: Docker must supply the real hook.
  dc up -d waf
  iptables -w -S DOCKER-USER >/dev/null || die 'Docker DOCKER-USER hook missing. See troubleshooting; native nftables backend is not supported by this action.'
  wait_http "http://$LAB_IP/DVWA/login.php" || die 'WAF is not serving DVWA.'
  dc up -d fail2ban
  for _ in {1..45}; do
    if docker exec waflab-fail2ban fail2ban-client ping >/dev/null 2>&1; then
      printf 'modsecurity\n' >"$LAB_ROOT/active-mode"
      return 0
    fi
    sleep 2
  done
  die 'Fail2ban did not become ready.'
}
stop_modsec() { dc stop fail2ban; dc stop waf; }
case "$CMD" in
  status)
    dc ps
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
    docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa || true
    ;;
  start) start_modsec ;;
  stop) stop_modsec ;;
  switch)
    case "$ARG" in
      modsecurity)
        install -d -m 700 "$LAB_ROOT/backups"
        python3 "$REPO_ROOT/scripts/safeline-containers.py" stop
        start_modsec
        ;;
      safeline)
        stop_modsec
        python3 "$REPO_ROOT/scripts/safeline-containers.py" start
        printf 'safeline\n' >"$LAB_ROOT/active-mode"
        note 'SafeLine restored. Check its dashboard and DVWA route before testing.'
        ;;
      *) die 'Use switch modsecurity or switch safeline.' ;;
    esac
    ;;
  blacklist|whitelist|reset-rules)
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    if [[ "$CMD" == reset-rules ]]; then
      cp "$REPO_ROOT/config/modsecurity/custom.conf" "$tmp"
    else
      private_ipv4 "$ARG"
      if [[ "$CMD" == blacklist ]]; then
        printf 'SecRule REMOTE_ADDR "@ipMatch %s" \\\n    "id:10001,phase:1,t:none,deny,status:403,log,msg:\x27LAB: IP blacklist\x27"\n' "$ARG" >"$tmp"
      else
        printf 'SecRule REMOTE_ADDR "@ipMatch %s" \\\n    "id:10005,phase:1,t:none,pass,log,msg:\x27LAB: Full WAF bypass\x27,ctl:ruleEngine=Off"\n' "$ARG" >"$tmp"
      fi
    fi
    apply_rules "$tmp"
    note 'One exercise policy replaces the previous exercise. Fail2ban bans are separate; unban when needed.'
    ;;
  rate-limit)
    [[ "$ARG" == on || "$ARG" == off ]] || die 'Use rate-limit on|off.'
    cp "$LAB_ROOT/nginx/rate-limit.conf" "$LAB_ROOT/backups/rate-$(stamp).conf"
    # on means enforce: dry_run off. off means observe only: dry_run on.
    dry=on; [[ "$ARG" != on ]] || dry=off
    python3 - "$LAB_ROOT/nginx/rate-limit.conf" "$dry" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); p.write_text(re.sub(r'limit_req_dry_run\s+(on|off);','limit_req_dry_run '+sys.argv[2]+';',p.read_text()))
PY
    docker exec waflab-modsecurity nginx -t
    docker exec waflab-modsecurity nginx -s reload
    ;;
  benchmark)
    dc stop fail2ban
    bash "$REPO_ROOT/scripts/labctl.sh" reset-rules
    bash "$REPO_ROOT/scripts/labctl.sh" rate-limit off
    note 'Benchmark mode: CRS remains ON; custom IP policies cleared; rate enforcement and Fail2ban stopped.'
    ;;
  protection)
    bash "$REPO_ROOT/scripts/labctl.sh" rate-limit on
    dc up -d fail2ban
    ;;
  ban|unban)
    private_ipv4 "$ARG"
    action=banip; [[ "$CMD" != unban ]] || action=unbanip
    docker exec waflab-fail2ban fail2ban-client set modsecurity-dvwa "$action" "$ARG"
    ;;
  backup)
    file="$LAB_ROOT/backups/config-$(stamp).tar.gz"
    tar -C "$LAB_ROOT" -czf "$file" .env compose.yaml rules nginx tls fail2ban/fail2ban
    chmod 600 "$file"
    note "Backup includes secrets and private keys. Keep private: $file"
    ;;
  *) usage; exit 1 ;;
esac
