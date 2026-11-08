#!/usr/bin/env bash
set -Eeuo pipefail



SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Install mysql8 and Percona XtraBackup
# ------------------------------------------------------------

 "${SCRIPT_DIR}/install-mysql-8.0.42.sh"

# ------------------------------------------------------------
# Configure Percona XtraBackup
# ------------------------------------------------------------

echo_color blue "make restore-backup.sh executable without password"
# Make executable
sudo chmod 755 /home/azdad/scripts/restore-backup.sh

# Create sudoers entry
sudo bash -c 'echo "azdad ALL=(ALL) NOPASSWD: /home/azdad/scripts/restore-backup.sh" > /etc/sudoers.d/azdad-mysql'
sudo chmod 440 /etc/sudoers.d/azdad-mysql


#read var DATABASE1_IP
read -p "Enter database1 address [192.168.1.50] : " database1_ip
database1_ip=${database1_ip:-192.168.1.50}
echo "DATABASE1_IP=$database1_ip" | sudo tee -a /etc/environment

source /etc/environment


#automate ssh with db1
ssh-keygen
ssh-copy-id azdad@$database1_ip

#crontab file
echo_color blue "Create crontab file"
(crontab -l 2>/dev/null; echo "30 8,12,18 * * * /home/azdad/scripts/xtrabackup.sh") | crontab -


