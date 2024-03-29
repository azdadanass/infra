#############################################################
# Installation Docker
#############################################################

# Installation
sudo apt-get update
sudo apt-get -y install apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io

# Création de l'utilisateur unix docker
sudo usermod -aG docker $USER

# Autorisation du registry
echo '{"insecure-registries" : ["192.168.100.160:5000"]}' | sudo tee /etc/docker/daemon.json

# Redemarrage docker
sudo service docker restart

echo You should reboot system !!!




