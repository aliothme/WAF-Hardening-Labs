# Download Ubuntu and Kali, then create the VMs

## 1. Plan resources

Practical starting allocations, not vendor minimum guarantees: Ubuntu 4 vCPU, 6-8 GB RAM, 40 GB disk; Kali 2-4 vCPU, 4 GB RAM, 30 GB disk. Allocate more for concurrent scanning. Run only one WAF stack at a time. Use an x86-64 host with virtualization enabled for this installer.

## 2. Download official installation media

Official pages: [Ubuntu Server](https://ubuntu.com/download/server), [Kali Linux](https://www.kali.org/get-kali/), [VirtualBox](https://www.virtualbox.org/wiki/Downloads).

On a Linux workstation, the included helper discovers the available Ubuntu 24.04 and Kali installer ISO names, downloads the ISO and checksum/signature files, and checks hashes:

```bash
bash scripts/download-isos.sh "$HOME/waf-lab-isos"
```

Manual example filenames observed while preparing this guide (October 2026); check the official directories if a release moves:

```bash
mkdir -p ~/waf-lab-isos/ubuntu ~/waf-lab-isos/kali
cd ~/waf-lab-isos/ubuntu
curl -fLO https://releases.ubuntu.com/noble/ubuntu-24.04.5-live-server-amd64.iso
curl -fLO https://releases.ubuntu.com/noble/SHA256SUMS
curl -fLO https://releases.ubuntu.com/noble/SHA256SUMS.gpg
sha256sum --check --ignore-missing SHA256SUMS

cd ~/waf-lab-isos/kali
curl -fLO https://cdimage.kali.org/current/kali-linux-2026.2-installer-amd64.iso
curl -fLO https://cdimage.kali.org/current/SHA256SUMS
curl -fLO https://cdimage.kali.org/current/SHA256SUMS.gpg
sha256sum --check --ignore-missing SHA256SUMS
```

Checksums verify agreement with the downloaded checksum file. Signed checksums additionally authenticate its publisher when the signing key is independently verified. Follow [Kali's signature instructions](https://www.kali.org/docs/introduction/download-official-kali-linux-images/) and [Ubuntu's verification instructions](https://ubuntu.com/tutorials/how-to-verify-ubuntu). For example, after obtaining and verifying the appropriate key fingerprint:

```bash
gpg --verify SHA256SUMS.gpg SHA256SUMS
```

Do not download an ISO from an arbitrary mirror linked in a forum. Keep the signed checksums with your lab notes.

## 3. Create two VirtualBox VMs

Create `WAF-Lab-Ubuntu` (Linux / Ubuntu 64-bit) and `WAF-Lab-Kali` (Linux / Debian 64-bit). Attach the matching installer ISO, allocate RAM/disk, and boot. On Ubuntu choose 24.04 LTS, a normal sudo user, and OpenSSH Server. On Kali install a desktop environment and create a normal user.

Use **NAT for outbound downloads plus a shared host-only network for lab traffic**. Both VMs must share that host-only network. VirtualBox commonly uses `192.168.56.0/24`; replace this guide's historical `192.168.99.x` examples with your assigned addresses. Do not change a physical/work network merely to match the examples. The original lab used LAN/bridged connectivity; a dedicated host-only network is easier to contain for beginners.

Do not forward the WAF, database, or DVWA ports from your Internet router. Disable the NAT adapter after downloads if you want a disconnected exercise. Keep the host-only link active.

## 4. Verify the network

On each VM:

```bash
ip -br -4 address
ip route
```

From Kali, replacing the example address:

```bash
ping -c 3 192.168.99.195
ssh YOUR_UBUNTU_USER@192.168.99.195
```

On Ubuntu if SSH was not installed:

```bash
sudo apt-get update
sudo apt-get install -y openssh-server
sudo systemctl enable --now ssh
sudo ss -ltnp
```

Record the host-only addresses and use DHCP reservations or stable guest configuration so the certificate and port bindings remain valid. Take a **clean OS snapshot** before installing the application. Guest Additions are optional; match VirtualBox components to the installed host version rather than mixing Extension Pack versions.

## 5. Prepare Kali tools

```bash
sudo apt-get update
sudo apt-get install -y curl openssl git jq wafw00f zaproxy
sudo cp -a /etc/hosts /etc/hosts.before-waflab
sudo nano /etc/hosts
```

Add one mapping, replacing an older `dvwa.local` mapping rather than duplicating it:

```text
192.168.99.195 dvwa.local
```

```bash
getent ahostsv4 dvwa.local
```

The automated equivalent is `sudo bash scripts/kali-setup.sh SERVER_IP`. OS installation and desktop setup remain manual; application/WAF setup begins after these prerequisites.
