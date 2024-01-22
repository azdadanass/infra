script_dir=$(dirname $0)

#install docker
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
echo "try to reconnect with ssh -A to forward personal ssh keys"

#install registry
sudo docker run -d -p 5000:5000 --restart=always --name registry registry:2
echo '{"insecure-registries" : ["192.168.100.160:5000"]}' | sudo tee /etc/docker/daemon.json

mkdir -p ~/scripts
mkdir -p ~/log

cp $script_dir/* ~/scripts

echo Please to restart