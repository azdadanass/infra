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

# generate ssh key
eval $(ssh-agent)

#create default keygen
ssh-keygen
#create bitbucket keygen
ssh-keygen -t ed25519 -b 4096 -C "azdadanass@gmail.com" -f ~/.ssh/bitbucket_work
ssh-add ~/.ssh/bitbucket_work

echo "Host bitbucket.org" >> ~/.ssh/config
echo  " AddKeysToAgent yes" >> ~/.ssh/config
echo  " IdentityFile ~/.ssh/bitbucket_work" >> ~/.ssh/config

echo -e "\n\n\n"
echo copy this key to bitbucket 
cat ~/.ssh/bitbucket_work.pub
echo -e "\n\n\n"

echo Please to restart ,dont forget to run init2.sh after reboot