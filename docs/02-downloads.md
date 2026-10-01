# Software and container inventory

## Core downloads

| Component | Official source | Installation in this project |
|---|---|---|
| Ubuntu Server | https://ubuntu.com/download/server | Ubuntu 24.04 LTS amd64 VM |
| Kali Linux | https://www.kali.org/get-kali/ | Test-client VM |
| VirtualBox | https://www.virtualbox.org/wiki/Downloads | Hypervisor on the workstation |
| Docker Engine / Compose | https://docs.docker.com/engine/install/ubuntu/ | Official Ubuntu apt repository |
| DVWA | https://github.com/digininja/DVWA.git | Git checkout on Ubuntu, not a DVWA container |
| ModSecurity engine | https://github.com/owasp-modsecurity/ModSecurity | Included in the CRS image |
| OWASP CRS | https://github.com/coreruleset/coreruleset | Included in the CRS image |
| Nginx | https://nginx.org/ | Included in the CRS image |
| Fail2ban | https://github.com/fail2ban/fail2ban | LinuxServer container |
| ZAP | https://www.zaproxy.org/download/ | Kali `zaproxy` package |
| wafw00f | https://github.com/EnableSecurity/wafw00f | Kali `wafw00f` package |
| Apache / PHP / MySQL | Ubuntu repositories | Host packages |

## Containers used in the original lab

| Image | Container registry / download page | Purpose |
|---|---|---|
| `owasp/modsecurity-crs:nginx` | https://hub.docker.com/r/owasp/modsecurity-crs | Nginx + ModSecurity + CRS |
| `lscr.io/linuxserver/fail2ban:latest` | https://hub.docker.com/r/linuxserver/fail2ban | Log-driven temporary bans |
| `chaitin/safeline-mgt-g` | https://hub.docker.com/r/chaitin/safeline-mgt-g | SafeLine management |
| `chaitin/safeline-tengine-g` | https://hub.docker.com/r/chaitin/safeline-tengine-g | SafeLine reverse proxy |
| `chaitin/safeline-detector-g` | https://hub.docker.com/r/chaitin/safeline-detector-g | Detection component |
| `chaitin/safeline-luigi-g` | https://hub.docker.com/r/chaitin/safeline-luigi-g | Vendor-managed internal component |
| `chaitin/safeline-fvm-g` | https://hub.docker.com/r/chaitin/safeline-fvm-g | Vendor-managed internal component |
| `chaitin/safeline-chaos-g` | https://hub.docker.com/r/chaitin/safeline-chaos-g | Vendor-managed protection component |
| `chaitin/safeline-postgres` | https://hub.docker.com/r/chaitin/safeline-postgres | SafeLine PostgreSQL data store |

The original SafeLine components used `9.4.1`, with PostgreSQL image `15.18`. These are historical observations, not a direction to combine those images with a different release's Compose file. Install the complete matching vendor bundle through its official installer. Region and architecture can change the exact image names.

```bash
sudo docker pull owasp/modsecurity-crs:nginx
sudo docker pull lscr.io/linuxserver/fail2ban:latest
sudo docker image inspect owasp/modsecurity-crs:nginx --format '{{json .RepoDigests}}'
sudo docker image inspect lscr.io/linuxserver/fail2ban:latest --format '{{json .RepoDigests}}'
```

To record every installed image without displaying its environment/secrets:

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}'
sudo docker inspect safeline-mgt --format '{{.Config.Image}}'
```

`owasp/modsecurity` was discussed as an alternative engine image. This repository uses `owasp/modsecurity-crs` because it includes the CRS rules. Do not assume an engine-only image provides the same detection coverage without configuring a ruleset.
