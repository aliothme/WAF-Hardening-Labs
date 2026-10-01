# Orientation: what each layer does

## Learning outcomes

By the end, you should be able to explain the request path, identify the component that blocked a request, write a narrow rule, recognize false positives, recover access, and design a fair WAF comparison.

| Component | Responsibility | Does not establish |
|---|---|---|
| DVWA | Deliberately vulnerable PHP training application | Production application security |
| Apache / PHP / MySQL | Application and database execution | WAF protection |
| Nginx or SafeLine Tengine | Reverse proxy, connections, HTTP routing | That every attack was detected |
| ModSecurity | Rule-processing engine | A complete policy without loaded rules |
| OWASP CRS | Generic attack-detection rules and scoring | Application-specific business authorization |
| SafeLine | WAF policies, traffic inspection, management interface | Identical features in every edition/version |
| Nginx rate limiter | Request-rate enforcement | A 30-minute penalty after WAF detections |
| Fail2ban | Log matching and time-limited ban actions | Payload inspection or a native browser challenge |

A **filter** recognizes a log event. A **jail** combines a filter, log, threshold, time window, and action. An **action** makes/removes the firewall change. A WAF rule evaluates an HTTP transaction instead.

## Lab addresses

| Machine/interface | Example | Purpose |
|---|---|---|
| Ubuntu LAN/host-only IP | `192.168.99.195` | Published WAF entry point |
| Kali IP | `192.168.99.141` | Test source |
| Local hostname | `dvwa.local` | Application name |
| Docker bridge gateway | `172.30.50.1` | Apache backend address for container |
| ModSecurity container | `172.30.50.2` | WAF destination for scoped ban |
| MySQL | `127.0.0.1:3306` | Local database |

Use your actual VM addresses. `dvwa.local` is kept for continuity with the original lab. `.local` is also used by multicast DNS, so verify `/etc/hosts` resolution and use curl `--resolve` when diagnosing ambiguity. For a new naming scheme, `.test` is reserved for testing, but changing this package's hostname requires changing all matching configuration/certificates.

## Learning sequence

1. Create the VMs and verify connectivity.
2. Install the application and confirm a normal login page.
3. Put one WAF in front of it.
4. Compare a normal request with one harmless XSS-signature probe.
5. Correlate the status code with a WAF log event.
6. Exercise blacklist, whitelist, rate limit, and temporary ban separately.
7. Roll back each exercise before the next.
8. Run a controlled authenticated ZAP comparison.

The lab distinguishes **evidence from expectations**. A `403` may come from the application, proxy, or WAF. A timeout may be a firewall ban, service outage, or routing failure. Correlate observations rather than relying on one status code.
