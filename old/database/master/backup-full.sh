#!/bin/bash

database=$1
error_log=~/log/backup_db_error.log
backup_folder=~/backup/db
sql_file=~/tmp/$database-full.sql
backup_file=$backup_folder/$database-full`date +%Y-%m-%d_%H-%M`.7z

rm $error_log && touch $error_log

find $backup_folder -type f -name "$database*" -mtime +7 -delete

mysqldump \
 --defaults-extra-file=~/scripts/config.cnf \
 --max_allowed_packet=1G \
 --default-character-set=utf8 \
 --single-transaction=TRUE "$database"  \
 --databases  > $sql_file  2>> $error_log

7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $backup_file $sql_file  2>> $error_log

rm $sql_file 2>> $error_log

if [ -s $error_log ]; then
    curl -F file=@$error_log http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/dbmasterBackupFullError
fi




#mutt -s "backup database $database" -a $error_log -- a.azdad@3$database-int.com < $error_log
#mutt -s	"backup database $database" -a $error_log --	a.abourhnim@3$database-int.com <	$error_log
