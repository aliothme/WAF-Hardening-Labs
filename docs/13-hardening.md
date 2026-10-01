# Hardening the WAF and its operation

Hardening should preserve legitimate application workflows while reducing bypasses, administrative exposure, and operational failures. The DVWA application itself remains intentionally vulnerable for exercises.

## Network and administrative access

- Bind the backend privately and verify it from Kali; do not leave wildcard port 8080 exposed.
- Limit published listeners to the intended private IP. Audit IPv6 separately.
- Keep MySQL local. SafeLine's internal PostgreSQL is not the DVWA database.
- Restrict SafeLine management access to administrators or an SSH tunnel. A published Docker management port may bypass a simple UFW expectation; inspect actual packet paths.
- Use strong unique management credentials. Keep a separate SSH recovery session when testing access controls.
- Trust client-IP headers only from known upstream proxies. In this direct lab, rely on the real peer address.

## WAF policy

Start with CRS PL1 or SafeLine Balanced, collect normal workflows, then increase inspection deliberately. Keep the blocking threshold distinct from paranoia level. Prefer a single-rule/single-parameter/single-endpoint exclusion to whole-IP bypass. Remove exercise whitelists before measuring defense.

Do not treat WAF protection as a replacement for parameterized queries, output encoding, authorization, CSRF defenses, safe file handling, and application patching. A missing security header and a malicious request block are different issues.

## HTTPS and response behavior

Use valid certificates for production and test renewal. Enable HTTP-to-HTTPS redirect after confirming the HTTPS route. Use TLS 1.2/1.3. Apply security headers based on the application's behavior; a blindly copied restrictive CSP can break a training module or application workflow. HSTS should be enabled only after the domain is consistently HTTPS-ready. Do not use a long HSTS policy on an experimental self-signed domain casually.

`server_tokens off` reduces version disclosure, but hiding a server name is not access control. Do not count a changed fingerprint as proof of stronger protection.

## Logging and resource use

Our Docker log driver rotates JSON logs at 20 MB x 5 for WAF and 10 MB x 3 for Fail2ban. The shared WAF error log needs its own rotation. The automatic installer creates `/etc/logrotate.d/waflab`; manual users can add an equivalent file:

```bash
sudo nano /etc/logrotate.d/waflab
```

Example, replacing UID/GID with the WAF image's actual values:

```text
/opt/waf-hardening-lab/logs/error.log {
    daily
    rotate 7
    size 20M
    missingok
    notifempty
    compress
    delaycompress
    create 0640 WAF_UID WAF_GID
    postrotate
        /usr/bin/docker exec waflab-modsecurity nginx -s reopen >/dev/null 2>&1 || true
    endscript
}
```

Mount the log directory into Fail2ban, not a single rotating file. Verify log continuity and regex matching after rotation. Audit logs can contain cookies, tokens, and request bodies; restrict access and retention.

```bash
sudo logrotate --debug /etc/logrotate.d/waflab
sudo docker stats --no-stream
df -h
sudo du -sh /opt/waf-hardening-lab/logs
```

## Updates and recovery

Record image digests and DVWA commit before experiments. Test a new image in a snapshot/clone, confirm rule loading, replay benign and malicious tests, and then update the pinned environment file. Keep backups private. A container restart policy is not high availability; a single VM remains a single point of failure.

## Production budget decision

Our recommendation favored ModSecurity + CRS for granular custom rules and willingness to maintain configuration. SafeLine can save administration time when its dashboard and integrated capabilities fit the requirement. Compare total server, maintenance, monitoring, support, and licensing costs for the edition you actually need. Do not infer a universal performance winner from the historical ZAP reports.

Neither a local reverse proxy nor a local Fail2ban rule can recover a saturated Internet link during a volumetric DDoS attack. That problem requires upstream capacity/protection.
