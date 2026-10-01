# Security and lab scope

This repository intentionally deploys DVWA for local cybersecurity education. Use a dedicated private lab, synthetic data, and targets you control. Do not expose DVWA or management ports to the Internet.

The installer requires root and downloads packages/images from their publishers. Read the scripts first. It targets a fresh Ubuntu 24.04 amd64 VM and refuses existing lab/container data. Automatic SafeLine policy provisioning is not claimed.

Report repository script/configuration defects with a minimal sanitized reproduction. Do not attach passwords, private keys, session cookies, raw scan exports, or real customer data. Follow each third-party project's vulnerability-reporting process for issues in that software.

If a secret is committed, revoke/rotate it; deleting the file in a later commit does not erase Git history. Built-in DVWA credentials are public training credentials, not a production authentication design.
