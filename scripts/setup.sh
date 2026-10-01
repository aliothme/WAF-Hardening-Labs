#!/usr/bin/env bash
# Fresh dedicated Ubuntu 24.04 LTS amd64 VM only. Does not adopt existing DVWA.
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
MODE=modsecurity
LAB_IP=
YES=no
while (($#)); do
  case "$1" in
    --server-ip) LAB_IP=${2:?Missing IPv4}; shift 2 ;;
    --mode) MODE=${2:?Missing mode}; shift 2 ;;
    --yes) YES=yes; shift ;;
    -h|--help)
      printf 'Usage: sudo bash scripts/setup.sh --server-ip PRIVATE_IP [--mode modsecurity|safeline] [--yes]\n'; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
need_root
[[ "$MODE" == modsecurity || "$MODE" == safeline ]] || die 'Invalid mode.'
command -v python3 >/dev/null || die 'Install python3 first: sudo apt-get install -y python3'
private_ipv4 "$LAB_IP"
source /etc/os-release
[[ "$ID" == ubuntu && "$VERSION_ID" == 24.04 ]] || die 'This installer targets Ubuntu 24.04 LTS.'
[[ $(dpkg --print-architecture) == amd64 ]] || die 'This installer targets amd64.'
ip -o -4 addr show | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$LAB_IP" || die 'Server IP is not assigned to this VM.'
if [[ -f "$LAB_ROOT/.managed" ]]; then
  load_lab
  note 'Managed lab already exists. Use scripts/labctl.sh start or switch; no database reset performed.'
  exit 0
fi
[[ ! -e /var/www/html/DVWA && ! -e "$LAB_ROOT" ]] || die 'Existing lab data found. Use the migration guide or a fresh VM.'
if command -v docker >/dev/null; then
  [[ -z $(docker ps -aq) ]] || die 'Existing containers found. Use a fresh VM; existing stacks will not be modified.'
fi
if [[ -d /etc/apache2/sites-enabled ]]; then
  for v in /etc/apache2/sites-enabled/*; do
    [[ ! -e "$v" || ${v##*/} == 000-default.conf ]] || die "Existing Apache site found: $v"
  done
fi
if [[ "$YES" != yes ]]; then
  read -r -p 'This installs a deliberately vulnerable lab on this dedicated VM. Type LAB to continue: ' answer
  [[ "$answer" == LAB ]] || die 'Cancelled.'
fi
install -d -m 755 "$LAB_ROOT"
install -d -m 700 "$LAB_ROOT/backups"
trap 'printf "Setup stopped at line %s. Inspect the error; see docs/15-troubleshooting.md. Partial files remain at %s.\n" "$LINENO" "$LAB_ROOT" >&2' ERR
note 'Installing host dependencies'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg git openssl python3 python3-yaml \
  apache2 php libapache2-mod-php php-mysql php-gd php-xml php-mbstring php-curl php-sqlite3 \
  mysql-server iptables logrotate unzip jq
# Do not install host fail2ban: this project uses its container.
if ! command -v docker >/dev/null; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  cat >/etc/apt/sources.list.d/docker.sources <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker mysql
docker compose version
# Fail early on an existing database; never reset someone else's data.
[[ $(mysql -Nse "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='dvwa'") == 0 ]] || die 'Existing dvwa database found.'
[[ $(mysql -Nse "SELECT COUNT(*) FROM mysql.user WHERE User='dvwa_user'") == 0 ]] || die 'Existing dvwa_user found.'
note 'Creating the backend network'
python3 - <<'PY'
import ipaddress,json,subprocess
new=ipaddress.ip_network('172.30.50.0/24')
routes=json.loads(subprocess.check_output(['ip','-j','-4','route']))
for r in routes:
 d=r.get('dst','default')
 if d!='default' and new.overlaps(ipaddress.ip_network(d,strict=False)):
  raise SystemExit('172.30.50.0/24 overlaps an existing route. Choose a fresh VM/network plan.')
PY
docker network create --driver bridge --subnet 172.30.50.0/24 --gateway 172.30.50.1 \
  --opt com.docker.network.bridge.name=br-waflab waflab-backend
cp -a /etc/apache2 "$LAB_ROOT/backups/apache2-original"
cp -a /etc/hosts "$LAB_ROOT/backups/hosts-original"
note 'Downloading the pinned DVWA training application'
git clone https://github.com/digininja/DVWA.git /var/www/html/DVWA
# DVWA 2.3 is deliberately selected as the reproducible MySQL lab baseline.
git -C /var/www/html/DVWA checkout --detach 34a10d4166dcdc31f9641cf36ba5bd0fc1d4c59c
git -C /var/www/html/DVWA rev-parse HEAD >"$LAB_ROOT/dvwa-commit.txt"
DB_PASSWORD=$(openssl rand -hex 24)
install -m 640 -o root -g www-data /var/www/html/DVWA/config/config.inc.php.dist /var/www/html/DVWA/config/config.inc.php
WAF_LAB_DB_PASSWORD="$DB_PASSWORD" python3 - <<'PY'
from pathlib import Path
import os
p=Path('/var/www/html/DVWA/config/config.inc.php')
s=p.read_text()
# Appended assignments override the upstream sample without depending on its formatting.
suffix="\n$_DVWA['db_server']='127.0.0.1';\n$_DVWA['db_database']='dvwa';\n$_DVWA['db_user']='dvwa_user';\n$_DVWA['db_password']='"+os.environ['WAF_LAB_DB_PASSWORD']+"';\n$_DVWA['db_port']='3306';\n$_DVWA['default_security_level']='impossible';\n$_DVWA['disable_authentication']=false;\n"
if '?>' in s:s=s.rsplit('?>',1)[0]
p.write_text(s+suffix)
PY
# Password travels on stdin to mysql, not in its command-line arguments.
mysql <<EOF
CREATE DATABASE dvwa;
CREATE USER 'dvwa_user'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa_user'@'localhost';
FLUSH PRIVILEGES;
EOF
unset DB_PASSWORD
chown -R root:root /var/www/html/DVWA
chown root:www-data /var/www/html/DVWA/config/config.inc.php
chmod 640 /var/www/html/DVWA/config/config.inc.php
chown -R www-data:www-data /var/www/html/DVWA/hackable/uploads
[[ ! -f /var/www/html/DVWA/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt ]] || chown www-data:www-data /var/www/html/DVWA/external/phpids/0.6/lib/IDS/tmp/phpids_log.txt
printf 'Listen 127.0.0.1:8080\nListen 172.30.50.1:8080\n' >/etc/apache2/ports.conf
cat >/etc/apache2/sites-available/waflab-dvwa.conf <<'EOF'
<VirtualHost 127.0.0.1:8080 172.30.50.1:8080>
    ServerName dvwa.local
    DocumentRoot /var/www/html
    <Directory /var/www/html/DVWA>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require ip 127.0.0.1 172.30.50.2
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/waflab-error.log
    CustomLog ${APACHE_LOG_DIR}/waflab-access.log combined
</VirtualHost>
EOF
printf 'ServerName dvwa.local\n' >/etc/apache2/conf-available/waflab-name.conf
a2dissite 000-default || true
a2enmod rewrite
a2enconf waflab-name
a2ensite waflab-dvwa
install -d /etc/systemd/system/apache2.service.d
cat >/etc/systemd/system/apache2.service.d/waflab.conf <<'EOF'
[Unit]
Requires=docker.service
After=docker.service
[Service]
ExecStartPre=/usr/bin/docker network inspect waflab-backend
EOF
systemctl daemon-reload
apache2ctl configtest
systemctl enable apache2
systemctl restart apache2
python3 "$REPO_ROOT/scripts/dvwa-init.py"
python3 "$REPO_ROOT/scripts/hosts-entry.py" "$LAB_IP" dvwa.local
note 'Preparing container configuration and HTTPS certificate'
install -d -m 755 "$LAB_ROOT"/{rules,nginx,tls,logs,fail2ban/fail2ban/filter.d,fail2ban/fail2ban/action.d}
cp "$REPO_ROOT/config/modsecurity/compose.yaml" "$LAB_ROOT/compose.yaml"
cp "$REPO_ROOT/config/modsecurity/custom.conf" "$LAB_ROOT/rules/custom.conf"
cp "$REPO_ROOT/config/nginx/rate-limit.conf" "$LAB_ROOT/nginx/rate-limit.conf"
cp "$REPO_ROOT/config/fail2ban/modsecurity-dvwa.local" "$LAB_ROOT/fail2ban/fail2ban/filter.d/"
cp "$REPO_ROOT/config/fail2ban/waflab-web.local" "$LAB_ROOT/fail2ban/fail2ban/action.d/"
cp "$REPO_ROOT/config/fail2ban/jail.local" "$LAB_ROOT/fail2ban/fail2ban/"
openssl req -x509 -nodes -newkey rsa:2048 -days 90 \
  -keyout "$LAB_ROOT/tls/server.key" -out "$LAB_ROOT/tls/server.crt" \
  -subj '/CN=dvwa.local' -addext "subjectAltName=DNS:dvwa.local,IP:$LAB_IP"
WAF_TAG=${WAF_IMAGE:-owasp/modsecurity-crs:nginx}
F2B_TAG=${F2B_IMAGE:-lscr.io/linuxserver/fail2ban:latest}
docker pull "$WAF_TAG"
docker pull "$F2B_TAG"
WAF_PIN=$(docker image inspect "$WAF_TAG" --format '{{index .RepoDigests 0}}')
F2B_PIN=$(docker image inspect "$F2B_TAG" --format '{{index .RepoDigests 0}}')
[[ "$WAF_PIN" == *@sha256:* && "$F2B_PIN" == *@sha256:* ]] || die 'Could not resolve image digests.'
printf 'LAB_IP=%s\nLAB_DOMAIN=dvwa.local\nWAF_IMAGE=%s\nF2B_IMAGE=%s\n' "$LAB_IP" "$WAF_PIN" "$F2B_PIN" >"$LAB_ROOT/.env"
chmod 600 "$LAB_ROOT/.env"
WAF_UID=$(docker run --rm --entrypoint id "$WAF_PIN" -u)
WAF_GID=$(docker run --rm --entrypoint id "$WAF_PIN" -g)
chown "$WAF_UID:$WAF_GID" "$LAB_ROOT/logs" "$LAB_ROOT/tls/server.key"
chmod 750 "$LAB_ROOT/logs"
chmod 600 "$LAB_ROOT/tls/server.key"
touch "$LAB_ROOT/logs/error.log"
chown "$WAF_UID:$WAF_GID" "$LAB_ROOT/logs/error.log"
chmod 640 "$LAB_ROOT/logs/error.log"
cat >/etc/logrotate.d/waflab <<EOF
$LAB_ROOT/logs/error.log {
    daily
    rotate 7
    size 20M
    missingok
    notifempty
    compress
    delaycompress
    create 0640 $WAF_UID $WAF_GID
    postrotate
        /usr/bin/docker exec waflab-modsecurity nginx -s reopen >/dev/null 2>&1 || true
    endscript
}
EOF
touch "$LAB_ROOT/.managed"
dc config --quiet
if [[ "$MODE" == modsecurity ]]; then
  bash "$REPO_ROOT/scripts/labctl.sh" start
  bash "$REPO_ROOT/scripts/verify-host.sh"
else
  bash "$REPO_ROOT/scripts/safeline-setup.sh"
fi
note 'Installation finished. Read the output above and complete the Kali hosts entry.'
printf 'App: https://dvwa.local/DVWA/login.php\nDVWA training login: admin / password\nRuntime: %s\n' "$LAB_ROOT"
