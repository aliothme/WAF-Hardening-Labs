# Switching WAFs, backups, rollback, and existing-lab migration

## Names used by this repository

The original lab used `modsecurity-dvwa`, `fail2ban`, `~/modsecurity-dvwa`, and `~/fail2ban-dvwa`. This package uses `waflab-modsecurity`, `waflab-fail2ban`, and `/opt/waf-hardening-lab` so generated training assets are identifiable. Commands for these deployments are not interchangeable.

**Do not run the fresh-VM installer against the original server.** It refuses existing DVWA/container data instead of guessing how to adopt it. You can follow the manual guides to compare configurations or create a clean snapshot/clone for this repository.

## Normal operation

From the repository root:

```bash
sudo bash scripts/labctl.sh status
sudo bash scripts/labctl.sh stop
sudo bash scripts/labctl.sh start
sudo bash scripts/labctl.sh backup
```

`stop` shuts down Fail2ban before the WAF so ban cleanup can run. It preserves containers, certificates, rules, and database data. `start` checks that SafeLine is not running. Backups contain private keys and configuration: do not commit them.

## Switch after both WAFs have been installed

```bash
sudo bash scripts/labctl.sh switch modsecurity
sudo bash scripts/labctl.sh switch safeline
```

Switching to ModSecurity saves the running SafeLine container names and restart policies, sets their restart policy to `no`, and stops them. This prevents an `always` policy from unexpectedly restarting the alternate WAF after a Docker/host restart. Switching back restores those policies and starts exactly those containers. SafeLine data is not deleted.

The helpers do not recreate or reconfigure the vendor's Compose project. After a vendor upgrade, capture a fresh snapshot of its running deployment. Always verify `docker ps`, listeners, and the normal application route after switching.

## Original-server migration checks

The following read-only commands use the **original** container names:

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
sudo docker inspect modsecurity-dvwa --format '{{json .Mounts}}'
sudo docker exec fail2ban fail2ban-client status
sudo apache2ctl -S
sudo ss -ltnp
```

Privately back up Compose files, `.env`, custom rules, Apache configuration, and DVWA configuration. Record network subnets and image digests. Do not print/publish an unrestricted `docker inspect` or Compose environment dump because they may contain secrets.

The original mount line ended in `:ro\` in one pasted configuration. YAML volume mode should be `:ro`, without that trailing backslash. Validate with `docker compose config --quiet` before recreating a container.

For a temporary stop of the original SafeLine containers:

```bash
mkdir -p ~/waf-migration-backup
sudo docker ps --format '{{.Names}}' | grep -E '^safeline([_-]|$)' > ~/waf-migration-backup/safeline-running.txt
xargs -r sudo docker stop < ~/waf-migration-backup/safeline-running.txt
```

This simple stop does not change an `always` restart policy; after a daemon restart the vendor stack may return. For a durable switch, use the saved-policy helper on a managed lab, or explicitly record/change/restore the original policies. Never delete SafeLine volumes merely to free ports.

## Roll back rules or limiter settings

```bash
sudo bash scripts/labctl.sh reset-rules
sudo bash scripts/labctl.sh unban 192.168.99.141
sudo bash scripts/labctl.sh rate-limit on
```

To restore a specific saved rules file, copy its contents into the active file, test with `nginx -t`, and reload. Recreate the WAF after changes to environment variables or template mounts. File permissions must still permit the unprivileged WAF to read them.

## Recover a stale Fail2ban chain after a crash

First stop **only** this lab's Fail2ban container and inspect its jump:

```bash
sudo docker stop waflab-fail2ban
sudo iptables -S DOCKER-USER
sudo iptables -S f2b-waflab
```

Only if the exact stale lab rules remain, remove them:

```bash
sudo iptables -w -D DOCKER-USER -d 172.30.50.2 -p tcp -m multiport --dports 8080,8443 -j f2b-waflab
sudo iptables -w -F f2b-waflab
sudo iptables -w -X f2b-waflab
```

"No chain/target/match" means cleanup may already have happened. Do not flush a shared chain. Restart Fail2ban after fixing the cause and repeat the action test.

## Restore Apache on the fresh lab VM

A clean pre-install VM snapshot is the simplest full rollback. To restore just the original Apache configuration on a VM managed by this repository:

```bash
sudo bash scripts/labctl.sh stop
# Also stop SafeLine first if it currently owns 80/443.
sudo a2dissite waflab-dvwa
sudo a2disconf waflab-name
sudo rm -f /etc/systemd/system/apache2.service.d/waflab.conf
sudo cp -a /opt/waf-hardening-lab/backups/apache2-original/. /etc/apache2/
sudo systemctl daemon-reload
sudo apache2ctl configtest
sudo systemctl restart apache2
```

Restoring the old Apache listener may make DVWA directly accessible again if its files remain under the document root. Stop Apache when retiring the lab or restore the clean VM snapshot. This operation is not a production-safe uninstall routine for a shared web server.

## Recover a partial setup

The installer stops at the failing command and leaves files for diagnosis; it does not silently undo packages or reset the database. If failure happened before `.managed` was written, restore the pre-install snapshot and retry after correcting the issue, or finish the manual steps after inspecting what succeeded. An existing directory makes a fresh install refuse to proceed. If `.managed` exists, use `labctl.sh start` and `verify-host.sh` after resolving the cause. Re-running setup never resets an initialized database.
