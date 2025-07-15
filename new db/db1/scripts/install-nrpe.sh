sudo apt-get install -y nagios-nrpe-server nagios-plugins nagios-plugins-contrib



echo "allowed_hosts=127.0.0.1,192.168.1.131" | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_load]=/usr/lib/nagios/plugins/check_load -w 5,4,3 -c 10,8,6"  | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /"  | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_memory]=/usr/lib/nagios/plugins/check_memory -w 85% -c 90%"  | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_mysql]=/usr/lib/nagios/plugins/check_mysql -H 127.0.0.1 -u nagios -p nagios"  | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_mysql_threads]=/usr/lib/nagios/plugins/check_mysql_health --hostname=127.0.0.1 --username=nagios --password=nagios --mode=threads-connected --warning=30 --critical=50"  | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_mysql_slow]=/usr/lib/nagios/plugins/check_mysql_health --hostname=127.0.0.1 --username=nagios --password=nagios --mode=slow-queries --warning=10 --critical=20"  | sudo tee -a /etc/nagios/nrpe.cfg

sudo mkdir -p /var/cache/nagios
sudo chown nagios:nagios /var/cache/nagios
sudo chmod 755 /var/cache/nagios

sudo systemctl restart nagios-nrpe-server