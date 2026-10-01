# Rate limiting and anti-bot controls

## Three different mechanisms

| Requirement | Mechanism in this project |
|---|---|
| Limit request arrival rate per client | Nginx `limit_req` |
| Ten matched WAF-denial events in ten seconds, ban thirty minutes | Fail2ban jail |
| Present a browser challenge for sixty minutes after a trigger | SafeLine policy if supported, or a separately integrated challenge service |

The Nginx image uses ModSecurity v3. This lab uses Nginx for request rates and Fail2ban for persistent timed bans; it does not rely on cross-request ModSecurity collection behavior. Fail2ban's standard firewall action cannot render a CAPTCHA or JavaScript challenge.

## Nginx configuration

The included `config/nginx/rate-limit.conf` is mounted in the Nginx **http context**:

```nginx
limit_req_zone $binary_remote_addr zone=waflab_per_ip:10m rate=20r/s;
limit_req zone=waflab_per_ip burst=40 nodelay;
limit_req_status 429;
limit_req_log_level warn;
limit_req_dry_run off;
```

The key groups requests by source IP. `20r/s` is the sustained rate; `burst=40` tolerates excess requests, and `nodelay` admits an allowed burst immediately. This is a leaky-bucket mechanism, not an exact "200 requests per fixed ten-second window" counter. HTTP and HTTPS share the zone. A rejected excess request gets 429; this does not create a 30-minute IP ban.

The global example is deliberately simple. Real applications may need separate API/login/static-resource policies. Browser page loads make many requests, and several users behind one NAT share a source IP.

Inspect, edit, validate, reload:

```bash
sudo cat /opt/waf-hardening-lab/nginx/rate-limit.conf
sudo nano /opt/waf-hardening-lab/nginx/rate-limit.conf
sudo docker exec waflab-modsecurity nginx -t
sudo docker exec waflab-modsecurity nginx -s reload
```

To test with a more visible small limit, temporarily use `rate=2r/s` and `burst=4`, then validate/reload. Stop Fail2ban during this separate exercise so two controls do not confuse the outcome:

```bash
sudo docker stop waflab-fail2ban
```

From Kali:

```bash
bash scripts/test-lab.sh 192.168.99.195 rate
```

Expect a mixture of successful responses and 429s. Check for Nginx `limiting requests` messages. Our Fail2ban filter counts only ModSecurity 403 denial messages, so it does not count these 429s.

## Rollback / benchmark mode

Restore `rate=20r/s` and `burst=40`. To keep measuring rates without enforcing them:

```bash
sudo bash scripts/labctl.sh rate-limit off
```

That helper sets `limit_req_dry_run on`. To enforce again:

```bash
sudo bash scripts/labctl.sh rate-limit on
sudo bash scripts/labctl.sh protection
```

For all detection-only comparison preparation use `labctl.sh benchmark`: it stops Fail2ban, clears custom IP policies, and disables rate enforcement while leaving CRS blocking enabled.

## Built-in Fail2ban `nginx-limit-req`

This filter recognizes Nginx rate-limit log events. It does not configure the Nginx rate limiter. If you add a jail for it later, select its log severity/matching mode carefully and test delayed-versus-rejected events so one event is not misinterpreted as another. The default lab does not enable this additional jail.

References: [Nginx limit_req](https://nginx.org/en/docs/http/ngx_http_limit_req_module.html), [upstream filter](https://github.com/fail2ban/fail2ban/blob/master/config/filter.d/nginx-limit-req.conf).
