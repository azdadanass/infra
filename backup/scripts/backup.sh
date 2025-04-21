#!/bin/bash

message=~/git/scripts/commons/message.sh 
export output=~/log/backup-out.log
export errors=~/log/backup-err.log 
backup_folder=~/backup

mkdir -p ~/log ~/backup

echo > $output
rm $errors && touch $errors

$message "start local backup  `date +%Y-%m-%d__%H:%M:%S` "



#dh01
ssh-copy-id azdad@192.168.100.70

$message "rsync dh01"
mkdir -p $backup_folder/dh01
rsync -azv azdad@192.168.100.70:/home/azdad/files $backup_folder/dh01/  >> $output 2>> $errors

#dh03
ssh-copy-id azdad@192.168.100.140

$message "rsync dh03"
mkdir -p $backup_folder/dh03
rsync -azv azdad@192.168.100.140:/home/azdad/files $backup_folder/dh03/  >> $output 2>> $errors


#dh04
ssh-copy-id azdad@192.168.100.130

$message "rsync dh04"
mkdir -p $backup_folder/dh04
rsync -azv azdad@192.168.100.130:/home/azdad/files $backup_folder/dh04/  >> $output 2>> $errors


#db_gcom
ssh-copy-id root@192.168.100.99

$message "rsync db_gcom"
mkdir -p $backup_folder/db_gcom
rsync -azv root@192.168.100.99:/root/backup/db/* $backup_folder/db_gcom/ >> $output 2>> $errors

#orange_gcom
ssh-copy-id azdad@192.168.100.140

#$message "rsync db_orange"
#mkdir -p $backup_folder/db_orange
#rsync -azv azdad@192.168.100.140:/home/azdad/backup/db/* $backup_folder/db_orange/ >> $output 2>> $errors

#mise_gcom
ssh-copy-id azdad@192.168.100.130

$message "rsync db_mise"
mkdir -p $backup_folder/db_mise
rsync -azv azdad@192.168.100.130:/home/azdad/backup/db/* $backup_folder/db_mise/ >> $output 2>> $errors


#send notifications
mutt -s "backup local (from $HOSTNAME)" -a $output $errors -- a.azdad@3gcom-int.com < $errors
mutt -s "backup local (from $HOSTNAME)" -a $output $errors -- a.abourhnim@3gcom-int.com < $errors


curl -F file=@$errors http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/warning_email


if [ -s $errors ]; then
        # The file is not-empty.
        echo "$errors not empty"
fi
