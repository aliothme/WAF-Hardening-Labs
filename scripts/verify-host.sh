#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
need_root
load_lab
dc config --quiet
apache2ctl configtest
docker exec waflab-modsecurity nginx -t
docker exec waflab-fail2ban fail2ban-client ping
docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa
iptables -w -S DOCKER-USER
docker exec waflab-fail2ban iptables -w -S DOCKER-USER
note 'Check that host and container iptables refer to the same backend'
iptables --version
docker exec waflab-fail2ban iptables --version
host_backend=$(iptables --version | sed -n 's/.*(\([^)]*\)).*/\1/p')
container_backend=$(docker exec waflab-fail2ban iptables --version | sed -n 's/.*(\([^)]*\)).*/\1/p')
[[ -n "$host_backend" && "$host_backend" == "$container_backend" ]] || die 'Host/container iptables backends do not match.'
note 'Backend login page'
curl --noproxy '*' -fsS http://127.0.0.1:8080/DVWA/login.php -o /dev/null
note 'Protected HTTPS login page and one XSS probe'
normal=$(curl --noproxy '*' -ksS --resolve "dvwa.local:443:$LAB_IP" https://dvwa.local/DVWA/login.php -o /dev/null -w '%{http_code}')
attack=$(curl --noproxy '*' -ksS --resolve "dvwa.local:443:$LAB_IP" -G https://dvwa.local/DVWA/login.php --data-urlencode 'waf_test=<script>alert(1)</script>' -o /dev/null -w '%{http_code}')
printf 'Normal: %s; XSS: %s\n' "$normal" "$attack"
[[ "$normal" == 200 && "$attack" == 403 ]] || die 'Unexpected HTTP response. Inspect the WAF and application logs.'
docker exec waflab-fail2ban fail2ban-regex /remotelogs/modsecurity/error.log /config/fail2ban/filter.d/modsecurity-dvwa.local
note 'Host smoke checks finished. Auto-ban must be tested from Kali; see docs/11-testing.md.'
