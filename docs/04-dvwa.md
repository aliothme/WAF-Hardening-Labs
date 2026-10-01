# Manual path: Apache, PHP, MySQL, and DVWA

This reproduces the host-installed application architecture used in our lab. The upstream repository is **https://github.com/digininja/DVWA.git**.

## 1. Clone the application

```bash
sudo git clone https://github.com/digininja/DVWA.git /var/www/html/DVWA
sudo git -C /var/www/html/DVWA checkout --detach 34a10d4166dcdc31f9641cf36ba5bd0fc1d4c59c
sudo git -C /var/www/html/DVWA rev-parse HEAD
sudo cp /var/www/html/DVWA/config/config.inc.php.dist /var/www/html/DVWA/config/config.inc.php
```

The pin is DVWA 2.3, chosen for a repeatable MySQL exercise. It is intentionally old vulnerable training software. Do not upgrade it during a WAF comparison. If you choose a newer release, read its dependency/setup requirements and record its exact commit separately.

## 2. Create a dedicated database account

Generate a database password locally, record it privately, then open the MySQL administrative shell:

```bash
openssl rand -hex 24
sudo mysql
```

At the **MySQL prompt**, replace the placeholder with your generated password:

```sql
CREATE DATABASE dvwa;
CREATE USER 'dvwa_user'@'localhost' IDENTIFIED BY 'REPLACE_WITH_RANDOM_PASSWORD';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa_user'@'localhost';
FLUSH PRIVILEGES;
SHOW GRANTS FOR 'dvwa_user'@'localhost';
EXIT;
```

The account can manage only the `dvwa` schema. DVWA's setup operation intentionally drops/recreates that schema. Never point it at a database containing real data.

## 3. Edit the PHP configuration

```bash
sudo nano /var/www/html/DVWA/config/config.inc.php
```

Set these existing fields, leaving other upstream definitions intact:

```php
$_DVWA['db_server'] = '127.0.0.1';
$_DVWA['db_database'] = 'dvwa';
$_DVWA['db_user'] = 'dvwa_user';
$_DVWA['db_password'] = 'REPLACE_WITH_RANDOM_PASSWORD';
$_DVWA['db_port'] = '3306';
$_DVWA['default_security_level'] = 'impossible';
$_DVWA['disable_authentication'] = false;
```

These statements are **PHP configuration**, not Bash commands. The historical setup error came from confusing the database and user names or leaving the wrong credentials configured.

```bash
sudo chown -R root:root /var/www/html/DVWA
sudo chown root:www-data /var/www/html/DVWA/config/config.inc.php
sudo chmod 640 /var/www/html/DVWA/config/config.inc.php
sudo chown -R www-data:www-data /var/www/html/DVWA/hackable/uploads
sudo php -l /var/www/html/DVWA/config/config.inc.php
mysql -u dvwa_user -h 127.0.0.1 -p -e 'USE dvwa; SELECT DATABASE();'
```

Use `-p` without an inline password so MySQL prompts privately. Avoid making the entire application world-writable. If a specific training module requires another writable path, change only that path and document it.

## 4. Configure Apache's private backend

Create the Docker network in the previous chapter first:

```bash
sudo tee /etc/apache2/ports.conf >/dev/null <<'EOF'
Listen 127.0.0.1:8080
Listen 172.30.50.1:8080
EOF

sudo tee /etc/apache2/sites-available/waflab-dvwa.conf >/dev/null <<'EOF'
<VirtualHost 127.0.0.1:8080 172.30.50.1:8080>
    ServerName dvwa.local
    DocumentRoot /var/www/html
    <Directory /var/www/html/DVWA>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require ip 127.0.0.1 172.30.50.2
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/waflab-error.log
    CustomLog ${APACHE_LOG_DIR}/waflab-access.log combined
</VirtualHost>
EOF

echo 'ServerName dvwa.local' | sudo tee /etc/apache2/conf-available/waflab-name.conf
sudo a2dissite 000-default
sudo a2enmod rewrite
sudo a2enconf waflab-name
sudo a2ensite waflab-dvwa
sudo apache2ctl configtest
sudo systemctl restart apache2
sudo apache2ctl -S
sudo ss -ltnp
```

`Options -Indexes` intentionally removes directory browsing from this new baseline. That is an application-server change, so do not attribute its benefit to either WAF.

Ensure Docker restores the bridge before Apache binds its gateway address after reboot:

```bash
sudo mkdir -p /etc/systemd/system/apache2.service.d
sudo tee /etc/systemd/system/apache2.service.d/waflab.conf >/dev/null <<'EOF'
[Unit]
Requires=docker.service
After=docker.service
[Service]
ExecStartPre=/usr/bin/docker network inspect waflab-backend
EOF
sudo systemctl daemon-reload
sudo systemctl enable apache2
```

## 5. Initialize DVWA

From the repository root, initialize a **fresh** schema using DVWA's own CSRF-protected setup form:

```bash
sudo python3 scripts/dvwa-init.py
curl --noproxy '*' -I http://127.0.0.1:8080/DVWA/login.php
sudo mysql -e 'SELECT user_id,user FROM dvwa.users;'
```

Alternatively, from Kali forward a local port over SSH:

```bash
ssh -L 18080:127.0.0.1:8080 YOUR_UBUNTU_USER@192.168.99.195
```

Open `http://127.0.0.1:18080/DVWA/setup.php` in Kali's browser and click **Create / Reset Database** once. Close the tunnel after initializing. That tunnel is an administrative bypass, not the WAF test path.

Training login: `admin` / `password`. Select `low` only for a controlled vulnerability exercise; record the setting for every scan. The automated initializer does not reset an existing `users` table.

Advanced DVWA modules may require extra packages, writable paths, reCAPTCHA credentials, or API dependencies. This baseline targets the classic web/WAF exercises and does not claim every optional DVWA module is preconfigured.
