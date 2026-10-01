#!/usr/bin/env bash
# One-command guided deployment. SafeLine application onboarding remains in its UI.
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
need_root
load_lab
bash "$REPO_ROOT/scripts/labctl.sh" stop
install -d -m 700 "$LAB_ROOT/vendor"
note 'Downloading the official SafeLine Python installer over verified HTTPS'
curl --fail --location --show-error --proto '=https' --tlsv1.2 \
  https://waf.chaitin.com/release/latest/manager.py -o "$LAB_ROOT/vendor/safeline-manager.py"
sha256sum "$LAB_ROOT/vendor/safeline-manager.py" >"$LAB_ROOT/vendor/safeline-manager.sha256"
if [[ -n ${SAFELINE_INSTALLER_SHA256:-} ]]; then
  printf '%s  %s\n' "$SAFELINE_INSTALLER_SHA256" "$LAB_ROOT/vendor/safeline-manager.py" | sha256sum -c -
fi
note 'The vendor installer is interactive. Choose INSTALL and international edition.'
# Use the official Python entry point directly; do not use curl -k for downloads.
python3 "$LAB_ROOT/vendor/safeline-manager.py" --en
docker inspect safeline-tengine >/dev/null
[[ $(docker inspect -f '{{.HostConfig.NetworkMode}}' safeline-tengine) == host ]] || die 'Expected the vendor Tengine host-network topology. See SafeLine guide before choosing an upstream.'
cat <<EOF

Complete these steps in the SafeLine dashboard:
  URL: https://$LAB_IP:9443
  Domain: dvwa.local
  HTTP listener: 80 (keep this during the first smoke test)
  HTTPS listener: 443
  Upstream: http://127.0.0.1:8080
  Certificate: $LAB_ROOT/tls/server.crt
  Private key: $LAB_ROOT/tls/server.key
  Initial detection policy: Balanced; blocking enabled

The backend loopback address works because safeline-tengine uses host networking.
Do not select the public WAF address as its own upstream.
For UI labels and optional Strict/rate-limit/challenge exercises, read docs/06-safeline.md.
EOF
read -r -p 'After saving the application in the dashboard, press Enter to verify: ' _
wait_http "http://$LAB_IP/DVWA/login.php" || die 'SafeLine route is not ready. Check the domain, upstream and listener.'
code=$(curl --noproxy '*' -ksS --resolve "dvwa.local:443:$LAB_IP" \
  -G https://dvwa.local/DVWA/login.php --data-urlencode 'waf_test=<script>alert(1)</script>' \
  -o /dev/null -w '%{http_code}')
[[ "$code" == 403 ]] || die "Expected a blocking response for XSS; received $code. Inspect the SafeLine event log."
printf 'safeline\n' >"$LAB_ROOT/active-mode"
note 'SafeLine route and one XSS block verified. This is not a full security assessment.'
