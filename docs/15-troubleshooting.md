# Troubleshooting by layer

Start with read-only diagnostics:

```bash
bash scripts/diagnose.sh
```

Review output privately; logs may contain sensitive request data.

| Symptom | Likely cause / next check |
|---|---|
| `SecRule: command not found` | A configuration directive was pasted into Bash. Put it in the mounted `.conf` file. |
| DVWA setup HTTP 500 | Inspect PHP/Apache errors and database settings; do not assume WAF failure. |
| Access denied to database `dvwa_user` | Database name was confused with account name. Use database `dvwa`, user `dvwa_user`. |
| `Could not reliably determine ... ServerName` | Set the global Apache ServerName; this warning alone does not explain every outage. |
| Port 80/443 already allocated | Another WAF or Apache is still listening. Stop the correct stack, preserving its data. |
| Nginx 502 | Wrong backend, unavailable Apache, container loopback confusion, or Apache/network ACL. |
| WAF starts but no custom rule effect | Wrong mount, wrong client IP, engine DetectionOnly/Off, duplicate/invalid IDs, missing reload, or stale bind-mounted inode. |
| Key/log permission denied | Compare the image runtime UID/GID with ownership; avoid world-readable private keys. |
| Regex matches zero lines | Check timestamp pattern, log prefix, timezone, file path, permissions, and phases. |
| `pong` but no bans | A live daemon does not prove a jail is active. Check `status`, thresholds, log arrival, and ignored IPs. |
| IP listed banned but web still works | Wrong firewall backend/chain, no hook, wrong destination ports, proxy/NAT address, or another path. |
| Ban succeeds but whitelist still blocked | Firewall ban precedes HTTP inspection. Unban independently. |
| HTTP 429 | Nginx request-rate policy, not this ModSecurity 403 filter. |
| Missing DOCKER-USER | Check Docker firewall backend; do not create a disconnected empty chain as a workaround. |
| Backend reachable from Kali | Apache is listening on LAN/wildcard, another listener exists, or a port is published elsewhere. |
| Different ZAP alert counts | Check transport, authentication, coverage, application state, scanner policy, bans, and challenge settings. |
| Config lost on LinuxServer restart | Customization was saved in `.conf`; use `.local`. |
| Site fails after reboot | Docker bridge not ready for Apache, inactive container restart policies, or server IP changed. |

## Database inspection

```bash
sudo tail -n 40 /var/log/apache2/waflab-error.log
sudo php -l /var/www/html/DVWA/config/config.inc.php
mysql -u dvwa_user -h 127.0.0.1 -p -e 'USE dvwa; SELECT DATABASE();'
sudo mysql -e "SHOW GRANTS FOR 'dvwa_user'@'localhost';"
```

Do not paste the database password or full config file into a public issue. If a newer DVWA revision requires schema syntax unavailable on your database, use the documented baseline pin or follow that revision's supported database requirements; do not silently alter the vulnerable application's code mid-comparison.

## WAF inspection

```bash
sudo docker logs --tail 100 waflab-modsecurity
sudo docker exec waflab-modsecurity nginx -t
sudo docker exec waflab-modsecurity nginx -T
sudo docker inspect waflab-modsecurity --format '{{json .NetworkSettings.Networks}}'
sudo tail -n 30 /opt/waf-hardening-lab/logs/error.log
```

Remember that `127.0.0.1` inside a bridge-networked container is that container, not Ubuntu. The managed ModSecurity upstream is `172.30.50.1:8080`; SafeLine's host-network Tengine uses host loopback.

## Fail2ban inspection

```bash
sudo docker exec waflab-fail2ban fail2ban-client -t
sudo docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa
sudo docker exec waflab-fail2ban fail2ban-client get modsecurity-dvwa ignoreip
sudo docker exec waflab-fail2ban fail2ban-regex /remotelogs/modsecurity/error.log /config/fail2ban/filter.d/modsecurity-dvwa.local
sudo iptables -nvL DOCKER-USER
sudo iptables -nvL f2b-waflab
```

Historical log lines can match `fail2ban-regex` without falling inside the jail's current time window. Generate fresh events, verify UTC timestamps, and make sure the test IP is not ignored. The sample jail intentionally does not whitelist the entire private LAN.

## Readiness is not complete verification

`docker ps` proves a process/container state. `nginx -t` proves configuration syntax. `fail2ban-regex` proves matching against a sample. A successful end-to-end test needs the correct request, response, log event, firewall behavior, and recovery observation.
