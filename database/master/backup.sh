#!/bin/bash

error_log=~/log/backup_db_error.log
backup_folder=~/backup/db
sql_file=~/tmp/gcom-full.sql
backup_file=~/backup/gcom-full_`date +%Y-%m-%d_%H-%M`.7z

echo "" 2> $error_log

find $backup_folder -type f -mtime +7 -delete  

mysqldump \
 --defaults-extra-file=~/scripts/config.cnf \
 --max_allowed_packet=1G \
 --default-character-set=utf8 \
 --single-transaction=TRUE "gcom"  \
 --ignore-table=gcom.presence \
 --ignore-table=gcom.event \
 --ignore-table=gcom.entry \
 --ignore-table=gcom.detailed_entry \
 --ignore-table=gcom.video \
 --ignore-table=gcom.message  \
 --databases  > $sql_file  2>> $error_log

7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $backup_file $sql_file  2>> $error_log

rm $sql_file 2>> $error_log


#mutt -s "backup database gcom" -a $error_log -- a.azdad@3gcom-int.com < $error_log
#mutt -s    "backup database gcom" -a $error_log -- a.abourhnim@3gcom-int.com < $error_log
