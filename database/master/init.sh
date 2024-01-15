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
script_dir=$(dirname $0)
sudo cp $script_dir/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
sudo systemctl start mysql


read -p "Enter slave address [192.168.1.101] : " slave_ip
slave_ip=${slave_ip:-192.168.1.101}

mysql -u root -proot -e "CREATE USER slaveuser@$slave_ip IDENTIFIED WITH mysql_native_password BY 'pass';"
mysql -u root -proot -e "grant replication slave on *.* to slaveuser@$slave_ip;"
mysql -u root -proot -e "flush privileges;"
mysql -u root -proot -e "show grants for slaveuser@$slave_ip;"
mysql -u root -proot -e "show master status\G"

