# Historical lab evidence and limitations

These observations came from the original learning sessions, not from executing this new repository's installer. The repository uses a new baseline (including private backend listeners and disabled Apache directory listing), so do not label old reports as results from the new automation.

## Confirmed observations

| Observation | Evidence available |
|---|---|
| SafeLine 9.4.1 stack running | User-supplied container listing |
| SafeLine containers stopped before migration | User-supplied stop output and empty running-container list |
| Apache backend on wildcard port 8080 | `ss` and `apache2ctl -S` output |
| ModSecurity/CRS frontend available | Normal request 200 and XSS probe 403 |
| CRS anomaly block | Error log rule `949110`, inbound anomaly score 20 for an XSS probe |
| LinuxServer Fail2ban running | `fail2ban-client ping` returned pong |
| Host/container iptables compatibility | Both reported `nf_tables` |
| Custom filter recognized the log | Three lines, three matched, zero missed |

**Not yet proven by those original outputs:** automatic ten-event ban, natural 30-minute expiry, complete blacklist/whitelist rollback evidence, full backend isolation, and a 60-minute conditional anti-bot challenge.

## Original scan comparison

The sanitized table in [historical-zap-summary.md](../reports/historical-zap-summary.md) was extracted from the supplied report summary tables. The September 28 scan was identified by the user as the pre-Strict baseline; the HTML summary alone does not independently prove the SafeLine mode. September 29 was supplied as SafeLine Strict, and September 30 as ModSecurity + CRS.

The reports used different transports and reached different endpoint counts. Their totals represent reported alert categories/severity groups, not confirmed exploitable vulnerabilities or a WAF block-rate percentage. The disappearance of a finding can reflect a control, reduced coverage, a changed session, or a scan difference.

The original SafeLine guide was written by Royden Rebello (The Social Dork). It helped frame the home lab, but some example configuration in it differs from DVWA's actual `$_DVWA` keys and from this repository's hardened listener layout. The original PDF is credited, not copied into the public package.

## What to collect next

Use the test-record template to establish a new baseline with this repository. Record component digests, DVWA commit, transport, rule settings, authentication state, and all controls enabled. Validate benign workflows, manual ban action, automatic ban, expiry/unban, reboot behavior, and log rotation before describing the full setup as verified.
