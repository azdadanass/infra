script_dir=$(dirname $0)

#install registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2
echo '{"insecure-registries" : ["192.168.100.160:5000"]}' | sudo tee /etc/docker/daemon.json

mkdir -p ~/scripts
mkdir -p ~/log
mkdir -p ~/git

cp $script_dir/* ~/scripts

cd ~/git
git clone git@bitbucket.org:anassjuventus/docker.git


