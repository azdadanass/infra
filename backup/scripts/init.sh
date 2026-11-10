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


#crontab file
(crontab -l 2>/dev/null; echo "30 * * * * /home/azdad/scripts/backup.sh '/home/azdad/backup'") | crontab -
(crontab -l 2>/dev/null; echo "40 20 * * * /home/azdad/scripts/backup.sh '/home/azdad/backup' -sendNotification") | crontab -
(crontab -l 2>/dev/null; echo "30 * * * * /home/azdad/scripts/backup.sh '/home/azdad/drive/drive3/backup'") | crontab -
(crontab -l 2>/dev/null; echo "40 22 * * * /home/azdad/scripts/backup.sh '/home/azdad/drive/drive3/backup' -sendNotification") | crontab -
(crontab -l 2>/dev/null; echo "00 00 * * * /home/azdad/scripts/delete-old-db-gcom.sh") | crontab -
(crontab -l 2>/dev/null; echo "00 01 * * * /home/azdad/scripts/rclone.sh -size-only") | crontab -
(crontab -l 2>/dev/null; echo "00 05 * * * /home/azdad/scripts/rclone.sh") | crontab -


