# SafeLine installation and hardening exercises

## Install the complete vendor bundle

Complete Ubuntu/Docker, DVWA, and TLS setup first. Apache must not own ports 80/443. Stop another WAF before starting SafeLine.

Use the [official SafeLine repository](https://github.com/chaitin/SafeLine) and [documentation](https://docs.waf.chaitin.com/en/home). The official shell launcher delegates to this Python installer; download it using certificate verification, record its hash, inspect it, and run it:

```bash
mkdir -p ~/safeline-installer
cd ~/safeline-installer
curl --fail --location --show-error --proto '=https' --tlsv1.2 \
  https://waf.chaitin.com/release/latest/manager.py -o manager.py
sha256sum manager.py
less manager.py
sudo python3 manager.py --en
```

Choose installation and note the actual installation directory, generated credentials, management port, and release. The installer is interactive and downloads a version-matched Compose bundle. Keep its exact images/configuration together; do not construct a new release by mixing historical container tags.

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
sudo docker logs --tail 80 safeline-mgt
sudo docker inspect safeline-tengine --format '{{.HostConfig.NetworkMode}}'
```

The original deployment's proxy used `host` networking. That allows the backend `http://127.0.0.1:8080`. If your vendor deployment uses bridge networking instead, loopback refers to the container; stop and adjust the backend/network policy rather than opening Apache to the whole LAN.

Management normally uses `https://SERVER_IP:9443`. Keep this interface accessible only to lab administrators. The observed CLI for recovering the local administrator is:

```bash
sudo docker exec safeline-mgt /app/mgt-cli reset-admin --once
```

Run that only when recovery is needed. It changes administrator access; check the installed release's help if its CLI differs.

## Onboard DVWA in the dashboard

UI labels can differ by release/edition. Create a protected website/application with:

| Field | Lab value |
|---|---|
| Domain | `dvwa.local` |
| HTTP listener | `80` |
| HTTPS listener | `443` |
| Upstream / backend | `http://127.0.0.1:8080` with host-network Tengine |
| Certificate | Contents of `server.crt` |
| Private key | Contents of `server.key`, handled privately |
| Inspection | Blocking enabled; start with Balanced |

Keep HTTP enabled for the first routing test. Removing the HTTP listener does **not** itself create an HTTP-to-HTTPS redirect. Use the product's explicit redirect option if desired.

From Kali:

```bash
curl --noproxy '*' -k --resolve dvwa.local:443:192.168.99.195 \
  https://dvwa.local/DVWA/login.php -o /dev/null -w 'Normal: %{http_code}\n'
curl --noproxy '*' -k --resolve dvwa.local:443:192.168.99.195 \
  -G https://dvwa.local/DVWA/login.php \
  --data-urlencode 'waf_test=<script>alert(1)</script>' \
  -o /dev/null -w 'XSS probe: %{http_code}\n'
```

Inspect the matching attack event, source IP, URL, action, and time in the dashboard. A challenge may produce a different response from a plain block; record that policy rather than assuming every rejection is 403.

## What the built-in protections mean

| Protection family | Purpose | Lab verification |
|---|---|---|
| Web attack / semantic detection | Identify suspicious SQL, script, command, traversal, and related attack patterns | Send one known probe, find its event |
| Balanced / Strict policy | Change inspection aggressiveness | Repeat identical malicious and benign requests |
| Access-control rules | Match conditions such as source IP and take an allow/deny action | Compare Kali with another client |
| HTTP flood defense | Apply configured traffic thresholds and handling | Use a bounded normal-request test |
| Anti-bot challenge | Ask visitors to satisfy a browser/human verification flow | Test an ordinary browser and curl separately |
| Authentication challenge | Require an additional access credential where available | Confirm prompt precedes the application |
| Dynamic protection | Transform delivered HTML/JavaScript where supported | Check application compatibility separately |

These describe product capabilities, not a promise that every feature is active or free in your installed edition. Record the actual enabled settings and licensing labels. SafeLine's vendor-managed detection policies are not the CRS `.conf` files, and this guide does not invent a complete list of internal signature IDs.

## Balanced to Strict

Export or capture the current policy, record a baseline, select Strict, save/apply, and replay the same test set. Exercise login, upload, forms, and normal navigation. Record both blocks and legitimate requests rejected. Roll back by returning to the saved Balanced policy and replaying the normal workflow. Strict is not guaranteed to fix application vulnerabilities or improve every metric.

## Blacklist, whitelist, and rollback

Create a site-scoped source-IP rule for Kali's actual IPv4 address, with action **deny/block**. Test from Kali, confirm the event, then disable/delete that exact rule to roll back. A WAF access rule affects protected web traffic, not host SSH.

For an allow/whitelist exercise, inspect the action's documented semantics in your installed release. **Allow through an ACL** and **skip all inspection** are different policies. Record the chosen inspection exemptions and test with a harmless XSS signature. Do not assume an allow rule overrides flood/challenge policies or another deny rule. Roll back by removing that exact exception and confirming the probe is inspected again.

## Flood and challenge exercise

Select the application, open the HTTP flood/rate policy, set a modest request threshold, and choose the available handling action and penalty duration. Test separately from attack-detection benchmarking. If the requested action is a Pro feature, document the limitation rather than substituting a hidden API.

The scenario "threshold exceeded in 10 seconds, challenge for the next 60 minutes" needs a product policy supporting **both the trigger and the challenge duration**. It is not achieved by setting Fail2ban `bantime=3600`. Disable the temporary policy and clear the corresponding penalty state to roll back.

## Guided script boundary

`scripts/safeline-setup.sh` automates host preparation integration and launches the vendor installer; it then waits for dashboard onboarding. It verifies a normal route and a blocking test afterward. Automatic rule provisioning via an undocumented management API is intentionally not claimed.

References: [SafeLine repository](https://github.com/chaitin/SafeLine), [release notes](https://github.com/chaitin/SafeLine/releases).
