#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ ${1:-} != --help ]] || { echo 'Usage: sudo bash scripts/kali-setup.sh SERVER_PRIVATE_IP'; exit 0; }
need_root
private_ipv4 "${1:?Provide the Ubuntu private IPv4 address}"
source /etc/os-release
[[ "$ID" == kali ]] || die 'Run this on Kali Linux.'
apt-get update
apt-get install -y curl openssl git jq wafw00f zaproxy
cp -a /etc/hosts "/etc/hosts.waflab-$(stamp).bak"
python3 "$REPO_ROOT/scripts/hosts-entry.py" "$1" dvwa.local
getent ahostsv4 dvwa.local
note 'Kali is ready. Launch zaproxy as your normal desktop user, without sudo.'
