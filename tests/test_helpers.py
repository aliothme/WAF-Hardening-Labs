import importlib.util
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('hosts_entry',ROOT/'scripts/hosts-entry.py')
hosts=importlib.util.module_from_spec(spec)
spec.loader.exec_module(hosts)

class HostsTests(unittest.TestCase):
    def test_preserves_aliases_and_is_idempotent(self):
        old='127.0.0.1 localhost\n10.0.0.5 dvwa.local oldalias # existing\n# note\n'
        new=hosts.update(old,'192.168.99.195','dvwa.local')
        self.assertIn('10.0.0.5\toldalias # existing',new)
        self.assertIn('127.0.0.1 localhost',new)
        self.assertEqual(new,hosts.update(new,'192.168.99.195','dvwa.local'))
        self.assertEqual(new.count('dvwa.local'),1)

class PrivateTargetTests(unittest.TestCase):
    def test_rejects_public_and_malformed_targets(self):
        for target in ['8.8.8.8','127.0.0.1','::1','192.168.1.1;touch /tmp/oops','']:
            r=subprocess.run(['bash','-c','source "$1"; private_ipv4 "$2"','test',str(ROOT/'scripts/common.sh'),target],capture_output=True)
            self.assertNotEqual(r.returncode,0,target)
    def test_accepts_lab_address(self):
        r=subprocess.run(['bash','-c','source "$1"; private_ipv4 "$2"','test',str(ROOT/'scripts/common.sh'),'192.168.99.195'],capture_output=True)
        self.assertEqual(r.returncode,0)

class PolicyRollbackTests(unittest.TestCase):
    """Run control logic in a temporary fake deployment; Docker is a stub."""
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory()
        self.root=Path(self.tmp.name)
        self.repo=self.root/'repo'
        shutil.copytree(ROOT/'scripts',self.repo/'scripts')
        shutil.copytree(ROOT/'config',self.repo/'config')
        self.lab=self.root/'lab'
        for d in ['rules','backups','nginx']:(self.lab/d).mkdir(parents=True,exist_ok=True)
        (self.lab/'.managed').touch()
        (self.lab/'.env').write_text('LAB_IP=192.168.99.195\n')
        (self.lab/'rules/custom.conf').write_text('# original\n')
        shutil.copy(ROOT/'config/nginx/rate-limit.conf',self.lab/'nginx/rate-limit.conf')
        common=self.repo/'scripts/common.sh'
        txt=common.read_text().replace('LAB_ROOT=/opt/waf-hardening-lab',f'LAB_ROOT={self.lab}')
        # Root guard is disabled only in this temporary test copy. All external effects are mocked.
        txt=txt.replace("need_root() { [[ $EUID -eq 0 ]] || die 'Run this command with sudo.'; }",'need_root() { :; }')
        common.write_text(txt)
        bindir=self.root/'bin';bindir.mkdir()
        fake=bindir/'docker'
        fake.write_text('#!/usr/bin/env bash\nif [[ "$*" == *"nginx -t"* && ${FAKE_NGINX_FAIL:-0} == 1 ]]; then exit 1; fi\nexit 0\n')
        fake.chmod(0o755)
        self.env=dict(os.environ,PATH=str(bindir)+os.pathsep+os.environ['PATH'])
    def tearDown(self):self.tmp.cleanup()
    def runctl(self,*args,fail=False):
        env=dict(self.env)
        if fail:env['FAKE_NGINX_FAIL']='1'
        return subprocess.run(['bash',str(self.repo/'scripts/labctl.sh'),*args],env=env,capture_output=True,text=True)
    def test_blacklist_then_whitelist_then_reset(self):
        self.assertEqual(self.runctl('blacklist','192.168.99.141').returncode,0)
        content=(self.lab/'rules/custom.conf').read_text()
        self.assertIn('deny,status:403',content)
        self.assertIn('\\\n',content)
        self.assertEqual(self.runctl('whitelist','192.168.99.141').returncode,0)
        content=(self.lab/'rules/custom.conf').read_text()
        self.assertIn('ctl:ruleEngine=Off',content)
        self.assertNotIn('id:10001',content)
        self.assertEqual(self.runctl('reset-rules').returncode,0)
        self.assertNotIn('SecRule ',(self.lab/'rules/custom.conf').read_text())
    def test_invalid_nginx_config_restores_previous_file(self):
        result=self.runctl('blacklist','192.168.99.141',fail=True)
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((self.lab/'rules/custom.conf').read_text(),'# original\n')
    def test_bad_ip_does_not_change_policy(self):
        result=self.runctl('blacklist','8.8.8.8')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual((self.lab/'rules/custom.conf').read_text(),'# original\n')
    def test_rate_enable_disable(self):
        self.assertEqual(self.runctl('rate-limit','off').returncode,0)
        self.assertIn('limit_req_dry_run on;',(self.lab/'nginx/rate-limit.conf').read_text())
        self.assertEqual(self.runctl('rate-limit','on').returncode,0)
        self.assertIn('limit_req_dry_run off;',(self.lab/'nginx/rate-limit.conf').read_text())

if __name__=='__main__':unittest.main()
