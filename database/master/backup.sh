#!/bin/bash

error_log=~/log/backup_db_error.log
backup_folder=~/backup/db
sql_file=~/tmp/$database.sql
backup_file=$backup_folder/$database_`date +%Y-%m-%d_%H-%M`.7z

echo "" 2> $error_log

find $backup_folder -type f -mtime +7 -delete  

mysqldump \
 --defaults-extra-file=~/scripts/config.cnf \
 --max_allowed_packet=1G \
 --default-character-set=utf8 \
 --single-transaction=TRUE "$database"  \
 --ignore-table=$database.presence \
 --ignore-table=$database.event \
 --ignore-table=$database.entry \
 --ignore-table=$database.detailed_entry \
 --ignore-table=$database.video \
 --ignore-table=$database.message  \
 --databases  > $sql_file  2>> $error_log

7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $backup_file $sql_file  2>> $error_log

rm $sql_file 2>> $error_log


#mutt -s "backup database $database" -a $error_log -- a.azdad@3$database-int.com < $error_log
#mutt -s    "backup database $database" -a $error_log -- a.abourhnim@3$database-int.com < $error_log
