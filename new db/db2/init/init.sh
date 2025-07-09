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





# Make executable
sudo chmod 755 /home/azdad/restore-backup.sh

# Create sudoers entry
sudo bash -c 'echo "azdad ALL=(ALL) NOPASSWD: /home/azdad/restore-backup.sh" > /etc/sudoers.d/azdad-mysql'
sudo chmod 440 /etc/sudoers.d/azdad-mysql



# Create a new sudoers file fragment
sudo bash -c 'cat > /etc/sudoers.d/azdad-mysql <<EOF
azdad ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop mysql,
                          /usr/bin/systemctl start mysql,
                          /usr/bin/systemctl restart mysql,
                          /usr/bin/rm -rf /var/lib/mysql/*,
                          /usr/bin/chown -R mysql:mysql /var/lib/mysql
EOF'

# Set secure permissions
sudo chmod 440 /etc/sudoers.d/azdad-mysql

# Validate syntax
if sudo visudo -cf /etc/sudoers.d/azdad-mysql; then
    echo "✅ Sudoers updated successfully"
else
    echo "❌ Error in sudoers syntax" >&2
    sudo rm -f /etc/sudoers.d/azdad-mysql  # Clean up invalid file
fi





##use this o you can run systemctl mysql without sudo
#POLKIT_RULES_FILE="/etc/polkit-1/rules.d/10-mysql-control.rules"
#
## Define the content (adjust username 'azdad' if needed)
#POLKIT_RULES_CONTENT='
#polkit.addRule(function(action, subject) {
#    if (action.id == "org.freedesktop.systemd1.manage-units" && 
#        action.lookup("unit") == "mysql.service" && 
#        subject.user == "azdad") {
#        return polkit.Result.YES;
#    }
#});
#'
#
## Create the directory if it doesn't exist
#sudo mkdir -p "$(dirname "$POLKIT_RULES_FILE")"
#
## Write the rules file
#echo "$POLKIT_RULES_CONTENT" | sudo tee "$POLKIT_RULES_FILE"
#
## Set correct permissions (readable by root and polkitd)
#sudo chmod 644 "$POLKIT_RULES_FILE"
#sudo chown root:root "$POLKIT_RULES_FILE"

