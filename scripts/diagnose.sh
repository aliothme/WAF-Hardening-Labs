#!/usr/bin/env bash
set -u
printf '\nOS\n'; cat /etc/os-release
printf '\nListening TCP sockets\n'; sudo ss -ltnp
printf '\nApache virtual hosts\n'; sudo apache2ctl -S
printf '\nContainers\n'; sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
printf '\nDocker user chain\n'; sudo iptables -S DOCKER-USER
printf '\nFail2ban jail\n'; sudo docker exec waflab-fail2ban fail2ban-client status modsecurity-dvwa
printf '\nRecent WAF errors (may contain sensitive request data)\n'; sudo tail -n 15 /opt/waf-hardening-lab/logs/error.log
printf '\nRecent Apache errors\n'; sudo tail -n 15 /var/log/apache2/waflab-error.log
