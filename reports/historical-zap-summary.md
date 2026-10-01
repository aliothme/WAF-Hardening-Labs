# Historical ZAP summary

Extracted from user-supplied HTML summary tables. These are historical observations, not acceptance results for the new installer.

| Metric | SafeLine baseline, Sep 28 | SafeLine Strict, Sep 29 | ModSecurity + CRS, Sep 30 |
|---|---|---|---|
| High categories | 5 | 3 | 2 |
| Medium categories | 11 | 10 | 10 |
| Low categories | 11 | 11 | 7 |
| Informational categories | 10 | 10 | 9 |
| Total categories | 37 | 34 | 28 |
| Target | https://dvwa.local | https://dvwa.local | http://dvwa.local |
| Count of total endpoints | 76 | 54 | 68 |
| Percentage of responses with status code 4xx | 50 % | 25 % | 50 % |
| Percentage of responses with status code 5xx | 2 % | 7 % | 1 % |
| Percentage of slow responses | 56 % | 18 % | 29 % |

The mode labels come from the supplied filenames/user context; the summary tables do not independently prove enabled WAF policies. HTTP versus HTTPS and unequal coverage prevent a fair direct ranking. Alert categories are not a count of confirmed exploitable vulnerabilities. Statistics above are scoped to each listed primary target; the ModSecurity report also contains a secondary HTTPS statistic that must not overwrite the primary HTTP measurement.

## Source provenance

- SafeLine baseline (user-identified Balanced): `2026-09-28-ZAP-Report-.html`; SHA-256 `2dc6094176e6b2fbc88b20bceecb77d6b3c3c396177eadeb5e2b12206e75cd7c`.
- SafeLine Strict: `2026-09-29-ZAP-Report-Safeline WAF + Semantic Analysis Strict Mode.html`; SHA-256 `737852db0fbbec757fc8ff5dfdc0a3cf67013e1952ceb1661beea7ddeabec9dd`.
- ModSecurity + CRS: `2026-09-30-ZAP-Report-Mod Security WAF + Owasp CRS.html`; SHA-256 `c216c56a03047a7d6eb1a6f2c5b236a06dade678f4844af6363fbc61cd120b77`.

Raw reports are intentionally not included because they can contain session cookies, request bodies, and other sensitive material.
