#sudo -i
sudo apt-get install apt-transport-https
echo "deb https://repo.nagios.com/deb/$(lsb_release -cs) /" | sudo tee /etc/apt/sources.list.d/nagios.list
wget -qO - https://repo.nagios.com/GPG-KEY-NAGIOS-V3 | sudo apt-key add -
sudo apt-get update
sudo apt-get install ncpa
