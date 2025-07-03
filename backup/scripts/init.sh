ssh-keygen
ssh-copy-id azdad@192.168.100.70
ssh-copy-id azdad@192.168.100.130
ssh-copy-id azdad@192.168.100.140
ssh-copy-id root@192.168.100.99



sudo apt-get install cifs-utils
echo //192.168.100.51/drive3  /home/azdad/drive/drive3 cifs user=3gcom,pass=rootroot,uid=1000,gid=1000 0 0 | sudo tee -a /etc/fstab
sudo mount -a


sudo snap install rclone
rclone config


