sudo -i
apt-get install apt-transport-https
echo "deb https://repo.nagios.com/deb/$(lsb_release -cs) /" > /etc/apt/sources.list.d/nagios.list
wget -qO - https://repo.nagios.com/GPG-KEY-NAGIOS-V3 | apt-key add -
apt-get update
apt-get install ncpa