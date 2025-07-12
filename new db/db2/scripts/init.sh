#!/bin/bash

# ===== Config =====
script_dir=$(dirname $0)


# Colors (for terminal only)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ===== Functions =====
echo_color() {
  echo -e "$1"
}

log_error() {
  echo "$1" >> "$error_log"
  echo_color "${RED}$1${NC}"
}


sudo apt update 


echo_color "${BLUE}Install mysql & p7zip-full${NC}"
sudo apt -y install mysql-server p7zip-full


# Création de l'utilisateur tomcat dans la base de donnée
echo_color "${BLUE}Create user tomcat in database${NC}"
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by 'root';"
mysql -u root -proot -e "CREATE USER 'tomcat'@'%' IDENTIFIED BY 'tacmot';"
mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'tomcat'@'%';"
mysql -u root -proot -e "FLUSH PRIVILEGES;"


echo_color "${BLUE}copy mysqld.conf and restart mysql${NC}"
sudo systemctl stop mysql
sudo cp $script_dir/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo cp $script_dir/client.cnf /etc/mysql/conf.d/client.cnf
sudo systemctl start mysql

sudo usermod -aG mysql $USER
sudo chmod 750 /var/lib/mysql



echo_color "${BLUE}Install percona-xtrabackup for directory backups${NC}"
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo apt update
sudo percona-release enable tools release
sudo apt -y install percona-xtrabackup-80  



echo_color "${BLUE}make restore-backup.sh executable without password${NC}"
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
echo_color "${BLUE}Create crontab file${NC}"
(crontab -l 2>/dev/null; echo "30 8,12,18 * * * /home/azdad/scripts/xtrabackup.sh") | crontab -
