#!/usr/bin/env python3
"""Save/restore SafeLine restart policies while switching WAFs."""
import json
import subprocess
import sys
from pathlib import Path

def docker(*args):
    return subprocess.check_output(['docker',*args],text=True)

def main():
    path=Path('/opt/waf-hardening-lab/backups/safeline-containers.json')
    if sys.argv[1]=='stop':
        names=[n for n in docker('ps','--format','{{.Names}}').splitlines()
               if n.startswith(('safeline-','safeline_'))]
        if not names:
            print('No running SafeLine containers; retaining any previous snapshot.')
            return
        data=json.loads(docker('inspect',*names))
        saved=[{'name':x['Name'].lstrip('/'),'restart':x['HostConfig']['RestartPolicy']} for x in data]
        path.write_text(json.dumps(saved,indent=2)+'\n'); path.chmod(0o600)
        for item in saved:
            docker('update','--restart=no',item['name'])
            docker('stop',item['name'])
    elif sys.argv[1]=='start':
        if not path.exists():raise SystemExit('No saved SafeLine deployment. Run safeline-setup.sh first.')
        for item in json.loads(path.read_text()):
            policy=item['restart']['Name'] or 'no'
            maximum=item['restart'].get('MaximumRetryCount',0)
            if policy=='on-failure' and maximum:policy+=f':{maximum}'
            docker('update',f'--restart={policy}',item['name'])
            docker('start',item['name'])
    else:raise SystemExit('Choose stop or start.')

if __name__=='__main__':main()
