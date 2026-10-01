# Network isolation, DNS, and HTTPS

## Confirm the request path

On Ubuntu:

```bash
sudo ss -ltnp
curl --noproxy '*' -I http://127.0.0.1:8080/DVWA/login.php
```

Apache should listen on loopback and the Docker bridge gateway only. A wildcard `*:8080` or `0.0.0.0:8080` is different: clients may reach the application without WAF inspection. Configure the listeners from [DVWA setup](04-dvwa.md) before testing defenses.

From Kali:

```bash
curl --noproxy '*' --connect-timeout 2 --max-time 3 http://192.168.99.195:8080/DVWA/login.php
```

Expected: connection failure, not the DVWA login page. Restricting the listener is reinforced by Apache's `Require ip` rule, which allows loopback and the specific WAF container. Do not expose MySQL to the lab LAN.

## Configure the application name

On both Ubuntu and Kali, back up and edit `/etc/hosts`:

```bash
sudo cp -a /etc/hosts /etc/hosts.before-waflab
sudo nano /etc/hosts
getent ahostsv4 dvwa.local
```

Use one entry:

```text
192.168.99.195 dvwa.local
```

The repository helper preserves unrelated aliases and replaces only this name:

```bash
sudo python3 scripts/hosts-entry.py 192.168.99.195 dvwa.local
```

A hosts file is sufficient. BIND9 appeared as an optional idea in the reference PDF, but is not required or installed by this lab.

## Generate a lab certificate

On Ubuntu:

```bash
sudo install -d -m 755 /opt/waf-hardening-lab/tls
sudo openssl req -x509 -nodes -newkey rsa:2048 -days 90 \
  -keyout /opt/waf-hardening-lab/tls/server.key \
  -out /opt/waf-hardening-lab/tls/server.crt \
  -subj '/CN=dvwa.local' \
  -addext 'subjectAltName=DNS:dvwa.local,IP:192.168.99.195'
sudo chmod 600 /opt/waf-hardening-lab/tls/server.key
openssl x509 -in /opt/waf-hardening-lab/tls/server.crt -noout -subject -dates -ext subjectAltName
```

Replace the certificate IP when using another subnet. Subject Alternative Name identifies the hostname/IP clients connect to. This self-signed certificate encrypts traffic but is not automatically trusted by browsers. The ModSecurity setup gives its runtime UID ownership of the key without making it world-readable.

For a single lab request, `curl -k` ignores certificate verification. It is used only against your local lab in this guide. For trusted validation, transfer **only the public certificate** to Kali and use:

```bash
curl --noproxy '*' --cacert ./server.crt \
  --resolve dvwa.local:443:192.168.99.195 \
  https://dvwa.local/DVWA/login.php
```

Do not use `-k` to fetch installers. Do not commit private keys. Production requires certificate issuance/renewal for a real domain and appropriate origin TLS verification.

## HTTP versus HTTPS

Both are enabled initially to support controlled comparisons. Once ready, configure HTTP-to-HTTPS redirection, but keep the transport identical between compared WAF runs. In the CRS image, change `NGINX_ALWAYS_TLS_REDIRECT` to `on` and recreate the WAF container. A redirect changes the expected HTTP smoke-test result from 200 to a redirect; HTTPS should continue serving DVWA.

## Client IP trust

The WAF must log Kali's actual source IP for blacklist and Fail2ban exercises. Our direct-client topology trusts no external proxy headers. If a CDN/load balancer is added later, authenticate/trust only its proxy addresses. Setting a broad `set_real_ip_from 0.0.0.0/0` can let a client spoof the IP being banned. Firewall bans against restored HTTP client addresses do not automatically work when the network peer is a CDN.
