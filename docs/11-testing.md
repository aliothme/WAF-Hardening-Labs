# Bounded hands-on exercises

Run all client probes from **Kali**, against your own private lab. Run administrative commands on **Ubuntu**. Replace example IPs. Use a clean browser session and record whether DVWA security is `low` or `impossible`.

## Exercise 1: normal routing and one WAF detection

```bash
bash scripts/test-lab.sh 192.168.99.195 smoke
wafw00f http://dvwa.local/DVWA/login.php
```

Expected baseline: normal 200, XSS signature 403. A generic wafw00f identification is acceptable; absence of a product name does not prove absence of a WAF. Check its event/log before concluding that the intended layer blocked the request.

The individual request is:

```bash
curl --noproxy '*' -4 -k --resolve dvwa.local:443:192.168.99.195 \
  -G https://dvwa.local/DVWA/login.php \
  --data-urlencode 'waf_test=<script>alert(1)</script>' \
  -sS -o /dev/null -w 'HTTP: %{http_code}\n'
```

This tests detection of an XSS-like string; it does not demonstrate executable XSS in the login page.

## Exercise 2: backend isolation

```bash
bash scripts/test-lab.sh 192.168.99.195 backend
```

On Ubuntu verify private listener addresses with `sudo ss -ltnp`. A successful backend response from Kali is a bypass path that must be fixed before scoring WAF defenses.

## Exercise 3: blacklist / whitelist / rollback

On Ubuntu:

```bash
sudo docker stop waflab-fail2ban
sudo bash scripts/labctl.sh blacklist 192.168.99.141
```

On Kali, a normal request should get 403. Then on Ubuntu:

```bash
sudo bash scripts/labctl.sh whitelist 192.168.99.141
```

On Kali, repeat the same normal and XSS-signature requests. Correlate the bypass log and application response. Finally:

```bash
sudo bash scripts/labctl.sh reset-rules
sudo bash scripts/labctl.sh protection
```

Normal traffic should work, and the signature should be blocked again. Disabling Fail2ban here prevents a previous blacklist test from creating an unrelated firewall ban.

## Exercise 4: automatic ten-event ban

On Ubuntu:

```bash
sudo bash scripts/labctl.sh reset-rules
sudo bash scripts/labctl.sh protection
sudo bash scripts/labctl.sh unban 192.168.99.141
```

On Kali:

```bash
bash scripts/test-lab.sh 192.168.99.195 ban
```

On Ubuntu:

```bash
sudo docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa
sudo docker logs --tail 100 waflab-fail2ban
sudo iptables -nvL f2b-waflab
sudo iptables -nvL DOCKER-USER
sudo tail -n 20 /opt/waf-hardening-lab/logs/error.log
```

Pass criteria: ten qualifying log events for the same IP fall inside ten seconds, the jail lists that IP, firewall counters rise when it reconnects, and a normal web request fails. Fail2ban polls logs, so enforcement may follow the tenth event with a small processing delay.

Recover:

```bash
sudo bash scripts/labctl.sh unban 192.168.99.141
```

Confirm a normal request succeeds. To validate natural expiry, repeat and wait the configured 1800 seconds; record start, expected expiry, actual unban event, and successful request. Do not claim expiry verified after only manual unban.

## Exercise 5: rate limit

Follow [rate limiting](09-rate-limiting.md). Test only normal requests and keep this separate from the ten-event ban. Expected limiter response is 429, while ModSecurity commonly returns 403 and a DROP firewall ban causes connection failure.

## Exercise 6: application behavior

Log in to DVWA, select the intended security level, and test normal inputs before a controlled SQLi/XSS/command-injection training exercise. For example, compare a normal SQL Injection module lookup with an input containing a quote or a deliberately true condition. The WAF event plus actual application behavior matters more than the scanner label. Use only synthetic DVWA data.

## Evidence template

Copy `reports/templates/test-record.md` for each exercise. Keep raw headers, cookies, private keys, and full scanner sessions out of the public repository. Record actual results as PASS/FAIL/NOT RUN; this guide's expected results are not measured evidence.
