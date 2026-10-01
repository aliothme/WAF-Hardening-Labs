# Package validation

## Checks performed while preparing this release

| Check | Result |
|---|---|
| Bash syntax for all included shell scripts | PASS |
| ShellCheck 0.11.0, including sourced shared helpers | PASS |
| Python syntax for helpers/tests | PASS |
| YAML and INI parsing | PASS |
| Docker Compose 5.5.1 `config --quiet` with sample environment values | PASS; no daemon or containers started |
| Internal Markdown links | PASS |
| No generated keys, credentials, or raw captures in release tree | PASS |
| Hosts-file alias preservation and repeat-run behavior | PASS |
| Private-target acceptance / public and malformed target rejection | PASS |
| Blacklist, whitelist, reset, and failed-rule rollback using mocked Docker | PASS |
| Rate-limit on/off helper using mocked Docker | PASS |
| Upstream Fail2ban 1.1.0 regex against synthetic positive/negative fixtures | PASS: 2 intended matches; 5 intentional nonmatches |
| Upstream Fail2ban 1.1.0 jail/filter/action configuration parsing | PASS; threshold 10 / window 10 seconds / duration 1800 seconds |

The negative filter cases include a limiter warning, application/proxy denial, ModSecurity warning, response-phase denial, and a forged client marker inside request text. This does not prove every possible log format is supported.

## Checks that still require an actual lab

- Fresh Ubuntu 24.04 VM end-to-end package installation and database initialization.
- Current pinned image startup, image entrypoint behavior, permissions, and `nginx -t`.
- SafeLine vendor installer, dashboard onboarding, and edition-specific policies.
- Client-to-WAF connectivity, backend isolation, and real source-IP preservation.
- Real firewall action, ten-event ban, natural expiry, and unban recovery.
- VM reboot ordering, log rotation continuity, update/rollback, and benign workflow checks.

The build environment did not provide a Docker daemon or the two VMs. The release therefore does not claim these runtime checks passed. The installer contains runtime checks to fail visibly, and the documentation provides acceptance exercises to complete after deployment.

## Reproduce static checks

```bash
sudo apt-get install -y python3-yaml shellcheck
python3 tests/validate.py
python3 -m unittest discover -s tests -v
shellcheck -x -P SCRIPTDIR scripts/*.sh
```

To test the filter using your installed container, without sending attacks:

```bash
sudo docker cp tests/fixtures/modsecurity.log waflab-fail2ban:/tmp/waflab-fixture.log
sudo docker exec waflab-fail2ban fail2ban-regex \
  /tmp/waflab-fixture.log /config/fail2ban/filter.d/modsecurity-dvwa.local
```

Expected: seven fixture lines, two matches, five intentional nonmatches. Old fixture timestamps are suitable for regex testing, not for testing a live jail's current time window.
