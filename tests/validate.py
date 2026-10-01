#!/usr/bin/env python3
"""Static release checks. Never invokes Docker or changes host configuration."""
from pathlib import Path
import ast
import configparser
import re
import subprocess
import sys
import yaml

ROOT=Path(__file__).resolve().parents[1]
errors=[]
for p in ROOT.rglob('*.sh'):
    r=subprocess.run(['bash','-n',str(p)],capture_output=True,text=True)
    if r.returncode:errors.append(f'{p}: {r.stderr}')
for p in ROOT.rglob('*.py'):
    try:ast.parse(p.read_text(),filename=str(p))
    except SyntaxError as e:errors.append(str(e))
for p in [*ROOT.rglob('*.yaml'), *ROOT.rglob('*.yml')]:
    try:yaml.safe_load(p.read_text())
    except yaml.YAMLError as e:errors.append(f'{p}: {e}')
for p in (ROOT/'config/fail2ban').glob('*.local'):
    try:
        parser=configparser.ConfigParser(interpolation=None)
        parser.read_string(p.read_text())
    except configparser.Error as e:errors.append(f'{p}: {e}')
for p in ROOT.rglob('*.md'):
    for target in re.findall(r'\]\(([^\s)]+)(?:\s+[^)]*)?\)',p.read_text()):
        if '://' in target or target.startswith(('#','mailto:')):continue
        target=target.split('#')[0]
        if target and not (p.parent/target).exists():errors.append(f'Broken local link: {p.relative_to(ROOT)} -> {target}')
for p in ROOT.rglob('*'):
    if p.is_file() and (p.suffix in ('.key','.pem','.pcap','.har') or p.name=='.env'):
        errors.append(f'Generated/private artifact found: {p.relative_to(ROOT)}')
compose=yaml.safe_load((ROOT/'config/modsecurity/compose.yaml').read_text())
waf=compose['services']['waf']
assert waf['networks']['backend']['ipv4_address']=='172.30.50.2'
assert all('${LAB_IP' in v for v in waf['ports'])
assert compose['services']['fail2ban']['network_mode']=='host'
assert waf['environment']['MODSEC_RULE_ENGINE']=='On'
assert not any('docker.sock' in v for s in compose['services'].values() for v in s.get('volumes',[]))
action=(ROOT/'config/fail2ban/waflab-web.local').read_text()
assert '-d 172.30.50.2' in action and '--dports 8080,8443' in action
assert '-F DOCKER-USER' not in action and '-F INPUT' not in action
if errors:
    print('\n'.join(errors));sys.exit(1)
print('PASS: shell/Python syntax, YAML/INI parsing, local document links, private-file scan, and topology invariants.')
