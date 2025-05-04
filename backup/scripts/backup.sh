#!/bin/bash
echo "start local backup  `date +%Y-%m-%d__%H:%M:%S` "

backup_folder=$1
log_folder=/home/azdad/log
errors=$log_folder/backup-error.txt

#create folders
mkdir -p $log_folder $backup_folder

#init logs
rm $errors && touch $errors

#gcom
echo "rsync gcom"
mkdir -p $backup_folder/gcom
rsync -azv azdad@192.168.100.70:/home/azdad/files $backup_folder/gcom/   2>> $errors

#mise
echo "rsync mise"
mkdir -p $backup_folder/mise
rsync -azv azdad@192.168.100.130:/home/azdad/files $backup_folder/mise/   2>> $errors

#orange
echo "rsync orange"
mkdir -p $backup_folder/orange
rsync -azv azdad@192.168.100.140:/home/azdad/files $backup_folder/orange/   2>> $errors

#db_gcom
echo "rsync db_gcom"
mkdir -p $backup_folder/db_gcom
rsync -azv root@192.168.100.99:/root/backup/db/* $backup_folder/db_gcom/  2>> $errors

#db_mise
echo "rsync db_mise"
mkdir -p $backup_folder/db_mise
rsync -azv azdad@192.168.100.130:/home/azdad/backup/db/* $backup_folder/db_mise/  2>> $errors

if  [[ $2 = "-sendNotification" ]]; then
    echo "Option -sendNotification turned on"
    curl -u admin:admin  http://utils.3gcominside.com/sendEmail/a.azdad@3gcom-int.com/backup_script
else
    echo "You did not use option -sendNotification"
fi

if [ -s $errors ]; then
        # The file is not-empty.
        echo "$errors not empty"
        curl -F file=@$errors http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/backup_error
fi
