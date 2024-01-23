script_dir=$(dirname $0)

read -p "Enter files_server ip [192.168.100.200] : " files_server_ip
db_name=${db_name:-192.168.100.200}


$script_dir/../commons/install-docker.sh
$script_dir/../commons/install-ncpa.sh


ssh-keygen
ssh-copy-id azdad@$files_server_ip

echo "azdad@:$files_server_ip/home/azdad/gcom/files /home/azdad/files fuse.sshfs noauto,x-systemd.automount,_netdev,allow_other,IdentityFile=/home/azdad/.ssh/id_rsa,reconnect,follow_symlinks 0 0" | sudo tee -a /etc/fstab

echo please to reboot