sudo apt-get install -y nagios-nrpe-server nagios-plugins



echo "allowed_hosts=127.0.0.1,192.168.1.131,172.17.0.3" | sudo tee -a /etc/nagios/nrpe.cfg
echo "command[check_disk]=/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /" | sudo tee -a /etc/nagios/nrpe.cfg
sudo systemctl restart nagios-nrpe-server