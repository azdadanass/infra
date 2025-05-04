#!/bin/bash
echo "start rclone backup  `date +%Y-%m-%d__%H:%M:%S` "

log_folder=/home/azdad/log
log=$log_folder/rclone.txt

mkdir -p $log_folder

/snap/bin/rclone -v sync  /home/azdad/backup/db_gcom drive:backup_80/db_gcom &> $log
/snap/bin/rclone -v copy --max-age 24h --no-traverse /home/azdad/backup/db_mise drive:backup_80/db_mise &>> $log
/snap/bin/rclone -v copy --max-age 24h --no-traverse /home/azdad/backup/gcom drive:backup_80/gcom &>> $log
/snap/bin/rclone -v copy --max-age 24h --no-traverse /home/azdad/backup/mise drive:backup_80/mise &>> $log
/snap/bin/rclone -v copy --max-age 24h --no-traverse /home/azdad/backup/orange drive:backup_80/orange &>> $log


curl -F file=@$log http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/rclone
