#############################################################
# Installation mysql
#############################################################

# Installation
sudo apt update
sudo apt -y install mysql-server

# Création de l'utilisateur tomcat dans la base de donnée
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by 'root';"
mysql -u root -proot -e "CREATE USER 'tomcat'@'%' IDENTIFIED BY 'tacmot';"
mysql -u root -proot -e "GRANT ALL PRIVILEGES ON *.* TO 'tomcat'@'%';"
mysql -u root -proot -e "FLUSH PRIVILEGES;"


sudo systemctl stop mysql


sudo rm /var/lib/mysql/ib_logfile*
mkdir -p /home/azdad/dbdata
sudo rsync -av /var/lib/mysql /home/azdad/dbdata
sudo mv /var/lib/mysql /var/lib/mysql.bak
script_dir=$(dirname $0)
sudo cp $script_dir/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i "/alias \/var\/lib\/mysql/c\alias \/var\/lib\/mysql\/ -> \/home\/azdad\/dbdata\/mysql\/," /etc/apparmor.d/tunables/alias

sudo systemctl restart apparmor
sudo mkdir /var/lib/mysql/mysql -p

sudo systemctl start mysql

