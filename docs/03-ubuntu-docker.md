# Manual path: prepare Ubuntu and Docker

Run these instructions on a fresh dedicated Ubuntu 24.04 amd64 VM. For an existing lab, use the migration section in [operations](14-operations.md). Commands beginning with `sudo` modify the VM; others inspect it.

```bash
cat /etc/os-release
dpkg --print-architecture
ip -br -4 address
sudo ss -ltnp
```

Install host dependencies. `iptables` is required by the Fail2ban container's host-network action; it is not the Fail2ban daemon.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git openssl python3 python3-yaml \
  apache2 php libapache2-mod-php php-mysql php-gd php-xml php-mbstring php-curl php-sqlite3 \
  mysql-server iptables logrotate unzip jq
```

Configure Docker's signed package repository:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker mysql
sudo docker version
sudo docker compose version
```

Keep using `sudo docker` for this guide. Membership of the `docker` group grants powerful host access. Do not blindly remove existing container packages from a shared server to satisfy this lab.

From the repository root, initialize the runtime and backups:

```bash
sudo install -d -m 755 /opt/waf-hardening-lab
sudo install -d -m 700 /opt/waf-hardening-lab/backups
sudo cp -a /etc/apache2 /opt/waf-hardening-lab/backups/apache2-original
sudo cp -a /etc/hosts /opt/waf-hardening-lab/backups/hosts-original
```

Reserve the network **only if it does not overlap an existing LAN/VPN/Docker network**:

```bash
ip route
sudo docker network ls
sudo docker network create --driver bridge \
  --subnet 172.30.50.0/24 --gateway 172.30.50.1 \
  --opt com.docker.network.bridge.name=br-waflab waflab-backend
sudo docker network inspect waflab-backend
```

The fixed addresses are shared by Compose, Apache, and the Fail2ban action. If you choose a different subnet, update all three; do not change only one file.

Continue with [DVWA](04-dvwa.md), then [network/TLS](05-network-tls.md), and your selected WAF.

Reference: [Docker's Ubuntu installation guide](https://docs.docker.com/engine/install/ubuntu/).
