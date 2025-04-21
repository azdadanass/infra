#!/bin/bash

message=~/git/scripts/commons/message.sh 
export output=~/log/ehd-backup-out.log
export errors=~/log/ehd-backup-err.log 
backup_folder=~/backup

echo > $output
echo > $errors

$message "start ehd backup  `date +%Y-%m-%d__%H:%M:%S` "

rsync -azv /home/azdad/backup /media/externalHardDrive/  >> $output 2>> $errors

#send notifications
mutt -s "ehd backup (from $HOSTNAME)" -a $output $errors -- a.azdad@3gcom-int.com < $errors
mutt -s "ehd backup (from $HOSTNAME)" -a $output $errors -- a.abourhnim@3gcom-int.com < $errors


