# Fail2ban: built-in rules, a custom WAF jail, and scoped bans

## What is included by default?

The LinuxServer image includes upstream filters/actions and additional service configurations. Its default jails are disabled until you enable the ones you need and mount their log directories.

Examples include `sshd` for SSH authentication failures, `nginx-http-auth` for HTTP Basic authentication failures, and `nginx-limit-req` for Nginx limiter events. `apache-modsecurity` expects Apache-format ModSecurity messages; our WAF emits Nginx-format messages, so we use a custom filter.

The runtime configuration consists of:

| File | Role |
|---|---|
| `filter.d/modsecurity-dvwa.local` | Identify request-phase ModSecurity 403 denial messages |
| `jail.local` | Enable the jail; choose log, threshold, time window, and duration |
| `action.d/waflab-web.local` | Add/remove a firewall ban scoped to the WAF container |

LinuxServer refreshes its supplied `.conf` files on container restart. Use `.local` for overrides and customizations.

## Migrate away from host Fail2ban if installed

On an existing lab, first back up the host configuration privately:

```bash
sudo tar -czf /root/fail2ban-host-backup.tar.gz /etc/fail2ban
sudo systemctl disable --now fail2ban
sudo apt-get purge -y fail2ban
```

Do **not** remove `iptables`; Docker and your chosen container action still need it. Do not flush the firewall. Check `sudo iptables-save` for stale `f2b-*` chains and remove only the old jail's jump/chain after identifying it. The fresh-VM automatic installer never installs host Fail2ban.

## Install the lab configuration

From the repository root, after the ModSecurity manual chapter:

```bash
sudo mkdir -p /opt/waf-hardening-lab/fail2ban/fail2ban/{filter.d,action.d}
sudo cp config/fail2ban/modsecurity-dvwa.local /opt/waf-hardening-lab/fail2ban/fail2ban/filter.d/
sudo cp config/fail2ban/waflab-web.local /opt/waf-hardening-lab/fail2ban/fail2ban/action.d/
sudo cp config/fail2ban/jail.local /opt/waf-hardening-lab/fail2ban/fail2ban/
sudo docker compose --project-directory /opt/waf-hardening-lab -f /opt/waf-hardening-lab/compose.yaml up -d fail2ban
sudo docker logs --tail 80 waflab-fail2ban
sudo docker exec waflab-fail2ban fail2ban-client ping
```

Expected health response: `Server replied: pong`. Compose supplies host networking, `NET_ADMIN` and `NET_RAW`; the ModSecurity log directory is mounted read-only. No Docker socket is mounted into Fail2ban.

## Understand the filter and threshold

The trusted beginning of a matching message resembles:

```text
2026/09/30 16:07:20 [error] 579#579: *19 [client 192.168.99.141] ModSecurity: Access denied with code 403 (phase 2).
```

The date parser removes the timestamp; the regex then anchors on the Nginx error prefix and the ModSecurity client address. It does not trust an arbitrary IP written later in a user-controlled header/request string.

```ini
findtime = 10
maxretry = 10
bantime = 1800
```

These mean **ten matched events for the same IP during the preceding ten seconds**, then a **thirty-minute ban**. They do not mean ten arbitrary requests or every 403 generated anywhere. Application 403s, Nginx 429s, and ModSecurity warnings are excluded. Response-phase denials are not counted by this request-phase filter. Inspect the real logs to confirm one qualifying event per blocked transaction in your deployment.

## Why DOCKER-USER and container ports?

Docker DNAT translates external `80/443` to container `8080/8443` before the packets reach this chain. The supplied action additionally matches destination `172.30.50.2`. It blocks the banned source only for those web ports on this WAF container; host SSH and unrelated containers are outside that action.

```bash
sudo iptables --version
sudo docker exec waflab-fail2ban iptables --version
sudo iptables -S DOCKER-USER
sudo iptables -S FORWARD
sudo docker exec waflab-fail2ban iptables -S DOCKER-USER
```

Both iptables commands must control the same backend. `iptables ... (nf_tables)` is the compatibility frontend and can still use Docker's iptables chains. Docker's native nftables backend has no equivalent `DOCKER-USER` path for these commands. An empty manually created chain is not proof packets traverse it; verify the Docker hook and counters.

This lab publishes only on a private IPv4 address. IPv6 enforcement needs a separate design and verification; do not publish an unfiltered IPv6 listener and assume this IPv4 action covers it.

## Inspect available and active rules

```bash
sudo docker exec waflab-fail2ban ls -1 /config/fail2ban/filter.d
sudo docker exec waflab-fail2ban ls -1 /config/fail2ban/jail.d
sudo docker exec waflab-fail2ban ls -1 /config/fail2ban/action.d
sudo docker exec waflab-fail2ban fail2ban-client status
sudo docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa
sudo docker exec waflab-fail2ban fail2ban-client get modsecurity-dvwa findtime
sudo docker exec waflab-fail2ban fail2ban-client get modsecurity-dvwa maxretry
sudo docker exec waflab-fail2ban fail2ban-client get modsecurity-dvwa bantime
```

File existence is not activation. `Jail list` shows active jails. Do not enable `sshd` just because it exists: its logs and action chain are separate from this WAF exercise.

## Validate and test

Generate one XSS-signature probe from Kali, then on Ubuntu:

```bash
sudo docker exec waflab-fail2ban fail2ban-regex \
  /remotelogs/modsecurity/error.log \
  /config/fail2ban/filter.d/modsecurity-dvwa.local
sudo docker exec waflab-fail2ban fail2ban-client -t
sudo docker exec waflab-fail2ban fail2ban-client reload
```

Regex success proves parsing, not successful firewall enforcement. Validate both separately:

```bash
sudo docker exec waflab-fail2ban fail2ban-client set modsecurity-dvwa banip 192.168.99.141
sudo iptables -nvL f2b-waflab
sudo iptables -nvL DOCKER-USER
```

From Kali, a fresh web connection should fail while SSH remains accessible. Manual ban validates the action, not the event threshold. Then unban before the automatic test:

```bash
sudo docker exec waflab-fail2ban fail2ban-client set modsecurity-dvwa unbanip 192.168.99.141
```

Run the automatic test in [testing](11-testing.md), inspect the jail's banned list and logs, then either wait 1800 seconds and retest or unban manually. Record which recovery you actually verified.

## Rollback

For one IP use `unbanip`. To disable this control temporarily:

```bash
sudo docker stop waflab-fail2ban
```

A graceful stop runs action cleanup. Confirm the jump is gone; if a crash left stale rules, remove only the exact lab rules as documented in [operations](14-operations.md). Never flush `INPUT`, `FORWARD`, or `DOCKER-USER` globally.

References: [LinuxServer image](https://docs.linuxserver.io/images/docker-fail2ban/), [configuration behavior](https://github.com/linuxserver/fail2ban-confs), [Docker firewall path](https://docs.docker.com/engine/network/firewall-iptables/).
