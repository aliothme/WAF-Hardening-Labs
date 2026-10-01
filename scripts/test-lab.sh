#!/usr/bin/env bash
# Bounded lab probes. No public targets, scanning, or unbounded load generation.
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ ${1:-} != --help ]] || { echo 'Usage: bash scripts/test-lab.sh PRIVATE_IP smoke|ban|rate|backend'; exit 0; }
target=${1:?Provide the Ubuntu private IPv4 address}
mode=${2:-smoke}
private_ipv4 "$target"
base=(curl --noproxy '*' -4 -k -sS --connect-timeout 2 --max-time 4 --resolve "dvwa.local:443:$target")
url=https://dvwa.local/DVWA/login.php
case "$mode" in
  smoke)
    "${base[@]}" "$url" -o /dev/null -w 'Normal HTTP: %{http_code}\n'
    "${base[@]}" -G "$url" --data-urlencode 'waf_test=<script>alert(1)</script>' -o /dev/null -w 'XSS HTTP: %{http_code}\n'
    ;;
  ban)
    note 'Run from Kali. Expected: initial 403 responses, then connection failure after the ban.'
    note 'Disable IP whitelist/blacklist first. Keep rate limiting at the baseline 20r/s.'
    start=$SECONDS
    for i in {1..12}; do
      "${base[@]}" --max-time 1 -G "$url" --data-urlencode 'waf_test=<script>alert(1)</script>' \
        -o /dev/null -w "Probe $i: %{http_code}\n" || true
      sleep 0.15
    done
    printf 'Probe window: %s seconds. Verify ten matching events fell inside ten seconds.\n' "$((SECONDS-start))"
    sleep 2
    "${base[@]}" "$url" -o /dev/null -w 'Normal request after probes: %{http_code}\n' || true
    echo 'On Ubuntu, verify fail2ban-client status and iptables counters; a timeout alone is not proof.'
    ;;
  rate)
    note 'This sends 80 normal requests in short batches. Stop Fail2ban for this exercise.'
    for i in {1..10}; do
      for _ in {1..8}; do "${base[@]}" "$url" -o /dev/null -w '%{http_code}\n' & done
      wait
    done
    ;;
  backend)
    note 'From Kali, port 8080 on the Ubuntu LAN IP should be unreachable.'
    if curl --noproxy '*' -4 -sS --connect-timeout 2 --max-time 3 "http://$target:8080/DVWA/login.php" -o /dev/null; then
      die 'Backend is reachable; investigate a WAF bypass path.'
    fi
    echo 'No HTTP response from the backend LAN port. Confirm listeners on Ubuntu.'
    ;;
  *) die 'Choose smoke, ban, rate, or backend.' ;;
esac
