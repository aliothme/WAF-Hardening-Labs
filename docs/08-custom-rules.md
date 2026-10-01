# Blacklist, whitelist, narrow exclusions, and rollback

Use one exercise at a time. In the repository's deployment the active custom rule file is:

```text
/opt/waf-hardening-lab/rules/custom.conf
```

It is mounted as `REQUEST-900-EXCLUSION-RULES-BEFORE-CRS.conf` so phase-1 runtime exceptions can apply before the CRS detection rules. The original lab's file lived under `~/modsecurity-dvwa/rules/`; do not mix the two deployments' paths.

## Blacklist one source IP

On Ubuntu, back up the file and open it:

```bash
sudo cp /opt/waf-hardening-lab/rules/custom.conf /opt/waf-hardening-lab/backups/custom-before-ip-test.conf
sudo nano /opt/waf-hardening-lab/rules/custom.conf
```

Place this **ModSecurity configuration**, replacing Kali's address:

```apache
SecRule REMOTE_ADDR "@ipMatch 192.168.99.141" \
    "id:10001,phase:1,t:none,deny,status:403,log,msg:'LAB: IP blacklist'"
```

`REMOTE_ADDR` is the client address seen by the WAF. `@ipMatch` accepts addresses/CIDRs. The unique `id` identifies this custom rule. `phase:1` runs at request headers. `t:none` clears inherited transformations; `deny` blocks; `status:403` selects the response; `log` records it.

```bash
sudo docker exec waflab-modsecurity nginx -t
sudo docker exec waflab-modsecurity nginx -s reload
```

From Kali, a normal login-page request should now return 403. SSH remains governed by the host's SSH/firewall policy; this SecRule does not process SSH packets.

## Full inspection whitelist

Replace the blacklist exercise with:

```apache
SecRule REMOTE_ADDR "@ipMatch 192.168.99.141" \
    "id:10005,phase:1,t:none,pass,log,msg:'LAB: Full WAF bypass',ctl:ruleEngine=Off"
```

Test and reload again. This disables ModSecurity inspection for the matching transaction. It is intentionally broad for demonstration. It does not remove a Fail2ban ban, disable Nginx rate limiting, or grant application authentication.

If Kali is already banned, unban it before testing the whitelist:

```bash
sudo docker exec waflab-fail2ban fail2ban-client set modsecurity-dvwa unbanip 192.168.99.141
```

An XSS-signature probe may then reach the application normally. Check the bypass log event and the application response. A whitelist does not mean the source is permanently trustworthy.

## Access allowlist versus inspection bypass

`examples/modsecurity/ip-allowlist-only.conf` denies clients outside an IP list while still inspecting allowed clients. That is different from `ctl:ruleEngine=Off`. Avoid placing a broad allow/bypass before a deny and assuming both will be enforced. Test rule ordering with the exact engine mode and actual client IP.

## Narrow false-positive exclusion

First identify the real rule ID, parameter, and endpoint from a legitimate failing workflow. Prefer an exception limited to that context. The demonstration in `examples/modsecurity/narrow-exclusion.conf` excludes only `ARGS:comment` from rule `941100` for an example URL; it is not an instruction to exempt DVWA attack exercises.

Never edit vendor CRS files directly: upgrades replace them, and broad edits obscure the reason for an exception. Record a justification, owner, and review date for each custom rule.

## Roll back

Restore into the existing bind-mounted file (preserving its inode):

```bash
sudo sh -c 'cat /opt/waf-hardening-lab/backups/custom-before-ip-test.conf > /opt/waf-hardening-lab/rules/custom.conf'
sudo docker exec waflab-modsecurity nginx -t
sudo docker exec waflab-modsecurity nginx -s reload
sudo docker exec waflab-fail2ban fail2ban-client set modsecurity-dvwa unbanip 192.168.99.141
```

Then retest a normal request and a malicious signature. If you rename a host file atomically over a file bind mount, the running container may still see the old inode; recreating the container refreshes the mount.

Equivalent exercise helpers:

```bash
sudo bash scripts/labctl.sh blacklist 192.168.99.141
sudo bash scripts/labctl.sh reset-rules
sudo bash scripts/labctl.sh whitelist 192.168.99.141
sudo bash scripts/labctl.sh reset-rules
```

References: [ModSecurity reference](https://github.com/owasp-modsecurity/ModSecurity/wiki/Reference-Manual-(v3.x)), [CRS tuning](https://coreruleset.org/docs/2-how-crs-works/2-3-false-positives-and-tuning/).
