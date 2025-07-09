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
sudo systemctl start mysql

sudo usermod -aG mysql $USER
sudo chmod 750 /var/lib/mysql



echo_color "${BLUE}Install percona-xtrabackup for directory backups${NC}"
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo apt update
sudo percona-release enable tools release
sudo apt -y install percona-xtrabackup-80  

