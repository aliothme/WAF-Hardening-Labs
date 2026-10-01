# Manual path: Nginx + ModSecurity + OWASP CRS

Complete [DVWA](04-dvwa.md) and [TLS](05-network-tls.md). Stop SafeLine first if it is running; [operations](14-operations.md) explains how to preserve restart policies and restore it later.

## 1. Prepare configuration files

Run from the repository root:

```bash
sudo mkdir -p /opt/waf-hardening-lab/{rules,nginx,logs,tls,backups}
sudo cp config/modsecurity/compose.yaml /opt/waf-hardening-lab/compose.yaml
sudo cp config/modsecurity/custom.conf /opt/waf-hardening-lab/rules/custom.conf
sudo cp config/nginx/rate-limit.conf /opt/waf-hardening-lab/nginx/rate-limit.conf
sudo docker pull owasp/modsecurity-crs:nginx
sudo docker pull lscr.io/linuxserver/fail2ban:latest
```

Resolve the selected images to digests and write Compose's private environment file:

```bash
WAF_PIN=$(sudo docker image inspect owasp/modsecurity-crs:nginx --format '{{index .RepoDigests 0}}')
F2B_PIN=$(sudo docker image inspect lscr.io/linuxserver/fail2ban:latest --format '{{index .RepoDigests 0}}')
printf 'LAB_IP=192.168.99.195\nLAB_DOMAIN=dvwa.local\nWAF_IMAGE=%s\nF2B_IMAGE=%s\n' "$WAF_PIN" "$F2B_PIN" \
  | sudo tee /opt/waf-hardening-lab/.env >/dev/null
sudo chmod 600 /opt/waf-hardening-lab/.env
```

Replace the example server IP. Pinning preserves the image you selected; updates should later be deliberate and tested. The original lab used digest `sha256:88c42590d8242eb48f53af309013642793152d4a5e4a16f8a74c2bcc9c840a1b`; it is historical evidence, not a current production recommendation.

## 2. Give the unprivileged WAF access to its key and log directory

```bash
WAF_UID=$(sudo docker run --rm --entrypoint id "$WAF_PIN" -u)
WAF_GID=$(sudo docker run --rm --entrypoint id "$WAF_PIN" -g)
sudo chown "$WAF_UID:$WAF_GID" /opt/waf-hardening-lab/logs /opt/waf-hardening-lab/tls/server.key
sudo chmod 750 /opt/waf-hardening-lab/logs
sudo chmod 600 /opt/waf-hardening-lab/tls/server.key
sudo touch /opt/waf-hardening-lab/logs/error.log
sudo chown "$WAF_UID:$WAF_GID" /opt/waf-hardening-lab/logs/error.log
sudo chmod 640 /opt/waf-hardening-lab/logs/error.log
```

Read the actual image UID instead of assuming it is always 101. Do not solve permission errors with `chmod 777`.

## 3. Start only the WAF

```bash
sudo docker compose --project-directory /opt/waf-hardening-lab -f /opt/waf-hardening-lab/compose.yaml config --quiet
sudo docker compose --project-directory /opt/waf-hardening-lab -f /opt/waf-hardening-lab/compose.yaml up -d waf
sudo docker logs --tail 80 waflab-modsecurity
sudo docker exec waflab-modsecurity nginx -t
sudo touch /opt/waf-hardening-lab/.managed
```

The marker makes the repository's control helpers available after manual installation. Do not create it on an unrelated installation. Fail2ban is configured in its own chapter before starting that service.

## 4. Understand the configuration

| Setting | Lab value | Meaning |
|---|---|---|
| `BACKEND` | `http://172.30.50.1:8080` | Host Apache reached from the Docker bridge |
| `PROXY_HOST_HEADER` | `dvwa.local` | Hostname delivered to Apache |
| `MODSEC_RULE_ENGINE` | `On` | Enforce disruptive rule actions |
| Request/response body access | `On` | Enable configured body inspection |
| Blocking paranoia | `1` | Baseline rules contributing to blocking |
| Detection paranoia | `1` | Baseline executed rules |
| Inbound / outbound anomaly thresholds | `5` / `4` | Scores used for blocking evaluation |
| Audit engine | `RelevantOnly` | Audit relevant transactions |
| Audit log | JSON to stdout | Structured investigation evidence |
| Error log | Shared host directory | Input for the Fail2ban filter |

Paranoia level adds rule coverage; anomaly thresholds determine when scored matches become a block. They are different controls. Increasing a threshold to hide false positives can also let attacks pass.

## 5. Inspect the installed rules

```bash
sudo docker exec waflab-modsecurity sh -c 'ls -1 /etc/modsecurity.d/owasp-crs/rules'
sudo docker exec waflab-modsecurity sh -c 'cat /etc/modsecurity.d/setup.conf'
sudo docker exec waflab-modsecurity sh -c 'grep -n "949110" /etc/modsecurity.d/owasp-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf'
sudo docker exec waflab-modsecurity nginx -T
sudo tail -n 20 /opt/waf-hardening-lab/logs/error.log
```

Use rule IDs, message, phase, URI, source IP, and score to explain a block. Rule `949110` is the **inbound blocking evaluation**, not a specific SQLi or XSS signature. Look for the preceding detection events/audit messages that contributed to its score.

Typical CRS families include protocol enforcement, file/path inclusion, remote execution, XSS, SQL injection, and response leakage checks. Discover the exact files shipped in your pinned image rather than assuming every release has identical IDs.

## 6. Change paranoia safely

Edit the runtime Compose file. For a tuning exercise, keep `BLOCKING_PARANOIA: "1"` and set `DETECTION_PARANOIA: "2"`, then recreate the WAF:

```bash
sudo nano /opt/waf-hardening-lab/compose.yaml
sudo docker compose --project-directory /opt/waf-hardening-lab -f /opt/waf-hardening-lab/compose.yaml up -d --force-recreate waf
```

Review legitimate transactions matched by the extra rules. Only raise blocking to 2 after tuning. Roll back by restoring both levels to 1 and recreating. `DetectionOnly` is an engine-wide observe mode; it differs from running extra paranoia rules for detection while retaining PL1 blocking.

References: [CRS Docker](https://github.com/coreruleset/modsecurity-crs-docker), [paranoia levels](https://coreruleset.org/docs/2-how-crs-works/2-2-paranoia_levels/).
