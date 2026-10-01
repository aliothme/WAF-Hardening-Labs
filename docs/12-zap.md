# Fair WAF evaluation with OWASP ZAP

ZAP finds potential application issues under the responses it receives. It is not a standalone WAF benchmark score. An IP ban, browser challenge, expired login, or unreachable endpoint can reduce alert counts by preventing coverage.

## Prepare the scanner

On Kali:

```bash
sudo apt-get update
sudo apt-get install -y zaproxy
zaproxy
```

Launch as the desktop user. Create a separate session for each run. Set a context that includes only `http://dvwa.local/DVWA/` **or** `https://dvwa.local/DVWA/`, consistently across all compared runs. Use ZAP's browser to log into DVWA, set the selected security level, and browse the same modules. Configure session/authentication handling and a logged-in indicator; verify that active-scan requests remain authenticated.

Do not scan unrelated IPs, vendor dashboards, external links, or production systems. Use the same ZAP version, add-ons, policy, request concurrency, timeout, crawl method, URLs, credentials, and DVWA database snapshot.

## Separate two experiments

| Experiment | What stays enabled | What is disabled |
|---|---|---|
| Detection comparison | WAF payload inspection | IP allow/bypass rules, anti-bot challenge, timed bans, rate enforcement |
| Combined defense behavior | WAF + rate limit + bans/challenge | Only unrelated controls |

For the ModSecurity detection experiment:

```bash
sudo bash scripts/labctl.sh benchmark
```

This stops Fail2ban and disables Nginx rate enforcement; it does **not** disable CRS. Apply the equivalent control isolation in SafeLine's dashboard. Capture settings before changing them and restore after the scan.

## Recommended run matrix

1. Local backend baseline through an administrator-only SSH tunnel, with the same DVWA state.
2. SafeLine Balanced.
3. SafeLine Strict.
4. ModSecurity CRS PL1, thresholds 5/4.
5. ModSecurity tuned PL2, if you performed the tuning exercise.
6. Separate full-stack run with rate limiting and temporary bans enabled.

Keep baseline access temporary/private. Reset application data and test cookies consistently. Export the ZAP HTML/JSON reports and record scope, authentication state, date/time, component versions, and configuration hashes.

## Metrics and interpretation

- Number of unique alert categories by severity, plus instances/endpoints separately.
- Malicious test transactions actually blocked, tied to WAF events.
- Benign test transactions incorrectly blocked (false positives).
- Endpoints reached and authenticated coverage.
- 2xx/3xx/4xx/5xx responses, connection failures, and scanner warnings.
- Request latency distribution measured under a controlled workload.

Block rate is meaningful only with a defined, labeled malicious request set. False-positive rate needs a labeled benign set. Total ZAP alert categories are neither of those denominators.

An SQLi alert based on HTTP 500 is a lead, not confirmed data access. An XSS payload reflected in a response does not prove JavaScript execution under the page's CSP. Missing CSP/cookie flags may be application/header configuration issues. HTTP versus HTTPS changes which transport-related checks apply. Read request/response evidence before calling a finding a successful bypass.

## Restore controls

```bash
sudo bash scripts/labctl.sh protection
```

Restore SafeLine's saved policies separately. Keep raw sessions private, and publish sanitized findings using `reports/templates/comparison.md`.

Reference: [ZAP getting started](https://www.zaproxy.org/getting-started/) and [authentication documentation](https://www.zaproxy.org/docs/desktop/start/features/authentication/).
