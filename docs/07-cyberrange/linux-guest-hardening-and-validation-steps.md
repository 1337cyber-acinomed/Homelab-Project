<!-- Converted from Word document: linux hardening steps.docx -->

\# Outbound checks

ping -c 3 8.8.8.8

nslookup google.com

curl -I https://example.com

\# Protected-destination checks — all four should fail/timeout

curl -m 5 -k https://10.10.30.1

curl -m 5 http://192.168.10.2:8006

curl -m 5 https://100.100.100.100

curl -m 5 <http://169.254.169.254>

\# 1. SSH hardening

sudo sed -i 's/^#\\PermitRootLogin.\*/PermitRootLogin no/' /etc/ssh/sshd_config

sudo systemctl restart ssh

\# 2. UFW

sudo ufw default deny incoming

sudo ufw default allow outgoing

sudo ufw allow 22/tcp

sudo ufw --force enable

sudo ufw status verbose

\# 3. Unattended-upgrades

sudo dpkg-reconfigure -plow unattended-upgrades

systemctl is-enabled unattended-upgrades

\# 4. fail2ban

sudo apt install -y fail2ban

sudo systemctl enable --now fail2ban

sudo systemctl status fail2ban --no-pager

\# 5. Service audit

ss -tulpn
