#!/usr/bin/env python3
"""Replace only the requested hostname; preserve unrelated aliases and comments."""
import ipaddress
import sys
from pathlib import Path

def update(text, ip, name):
    output = []
    for line in text.splitlines():
        body, sep, comment = line.partition('#')
        fields = body.split()
        if len(fields) > 1 and name in fields[1:]:
            aliases = [v for v in fields[1:] if v != name]
            if aliases:
                output.append(fields[0] + '\t' + ' '.join(aliases) + (' #' + comment if sep else ''))
            elif sep and comment.strip() != 'waf-hardening-lab':
                output.append('#' + comment)
        else:
            output.append(line)
    output.append(f'{ip}\t{name} # waf-hardening-lab')
    return '\n'.join(output) + '\n'

if __name__ == '__main__':
    ip, name = sys.argv[1:]
    ipaddress.IPv4Address(ip)
    if name != 'dvwa.local':
        raise SystemExit('This helper only manages dvwa.local.')
    p = Path('/etc/hosts')
    p.write_text(update(p.read_text(), ip, name))
