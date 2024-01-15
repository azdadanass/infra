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


read -p "Enter master address [192.168.1.100] : " master_ip
master_ip=${master_ip:-192.168.1.100}

read -p "Enter master_log_file address [mysql-bin.000001] : " master_log_file
master_log_file=${master_log_file:-mysql-bin.000001}

read -p "Enter master_log_pos  [861] : " master_log_pos
master_log_pos=${master_log_pos:-861}


mysql -u root -proot -e "CHANGE MASTER TO MASTER_HOST='$master_ip', MASTER_USER='slaveuser', MASTER_PASSWORD='pass', MASTER_LOG_FILE='$master_log_file', MASTER_LOG_POS=$master_log_pos;"
mysql -u root -proot -e "start slave;"
mysql -u root -proot -e "show slave status\G"




