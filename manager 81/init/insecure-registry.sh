echo '{"insecure-registries" : ["192.168.100.81:5000"]}' | sudo tee /etc/docker/daemon.json
sudo service docker restart
