#!/usr/bin/env python3
"""Initialize a fresh local DVWA via its own setup form and CSRF token."""
import http.cookiejar
import re
import subprocess
import urllib.parse
import urllib.request

def main():
    count = subprocess.check_output(['mysql', '-Nse',
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='dvwa' AND table_name='users'"])
    if count.strip() != b'0':
        print('DVWA is already initialized; no reset performed.')
        return
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    url = 'http://127.0.0.1:8080/DVWA/setup.php'
    text = opener.open(url, timeout=15).read().decode()
    match = re.search(r"name=['\"]user_token['\"][^>]*value=['\"]([^'\"]+)", text)
    if not match:
        raise SystemExit('DVWA setup CSRF token not found. Inspect the Apache error log.')
    data = urllib.parse.urlencode({'create_db': 'Create / Reset Database', 'user_token': match[1]}).encode()
    opener.open(url, data=data, timeout=30).read()
    count = subprocess.check_output(['mysql', '-Nse', "SELECT COUNT(*) FROM dvwa.users WHERE user='admin'"])
    if count.strip() != b'1':
        raise SystemExit('DVWA database initialization failed.')
    print('DVWA initialized: admin account exists.')

if __name__ == '__main__':
    main()
