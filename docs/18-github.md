# Publish and maintain the learning project

The ZIP is a repository-ready source tree. It does not contain a preconfigured Git remote or publish anything automatically.

## Review before publishing

Keep these private: `.env`, database passwords, TLS private keys, API tokens, cookies, full ZAP sessions, raw HTTP captures, backups, and logs. The included `.gitignore` excludes common generated paths, but review staged files because ignore rules do not remove already-tracked secrets.

```bash
git init
git branch -M main
git add README.md docs config examples scripts tests reports .github .gitignore LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md VALIDATION.md
git status --short
git diff --cached --stat
git diff --cached
git commit -m "Add reproducible WAF hardening lab and learning guides"
```

Create an empty GitHub repository through your account, then substitute your real URL:

```bash
git remote add origin https://github.com/YOUR_USERNAME/waf-hardening-lab.git
git push -u origin main
```

Do not push until you have reviewed the staged content. GitHub Actions performs static checks; it does not provision the VMs or prove enforcement.

## Suggested learning milestones

1. VM and application baseline.
2. SafeLine Balanced/Strict evidence.
3. ModSecurity CRS PL1 and custom rules.
4. Request-rate limiting and rollback.
5. Fail2ban match, action, automatic ban, and expiry evidence.
6. Controlled ZAP comparison and false-positive tuning.
7. Reboot, log rotation, and update recovery.

For each completed milestone, add a sanitized test record and exact version references. Mark untested items as NOT RUN. Use issues for reproducible failures and pull requests for changes to rules/configuration. Require benign-path regression checks before accepting a stricter policy.
