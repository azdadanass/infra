sudo apt-get update
sudo apt update && sudo apt install -y docker.io docker-buildx-plugin

sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
