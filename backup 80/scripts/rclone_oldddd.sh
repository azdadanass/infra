#!/bin/bash


log_folder=/home/azdad/log
log=$log_folder/rclone.txt
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

mkdir -p $log_folder

echo -e "${GREEN}start rclone `date +%Y-%m-%d__%H:%M:%S` ${NC}" > $log
killall rclone

echo -e "${BLUE}sync db_gcom${NC}" >> $log
/snap/bin/rclone -v sync  /home/azdad/backup/db_gcom drive:backup_80/db_gcom &>> $log

if  [[ $1 = "-size-only" ]]; then
	echo -e "${GREEN}Option size-only${NC}" >> $log
	echo -e "${BLUE}copy db_mise${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --size-only /home/azdad/backup/db_mise drive:backup_80/db_mise &>> $log
	echo -e "${BLUE}copy gcom${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --size-only /home/azdad/backup/gcom drive:backup_80/gcom &>> $log
	echo -e "${BLUE}copy mise${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --size-only /home/azdad/backup/mise drive:backup_80/mise &>> $log
	echo -e "${BLUE}copy orange${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --size-only /home/azdad/backup/orange drive:backup_80/orange &>> $log
else
	echo -e "${GREEN}Option checksum${NC}" >> $log
	echo -e "${BLUE}copy db_mise${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --checksum /home/azdad/backup/db_mise drive:backup_80/db_mise &>> $log
	echo -e "${BLUE}copy gcom${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --checksum /home/azdad/backup/gcom drive:backup_80/gcom &>> $log
	echo -e "${BLUE}copy mise${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --checksum /home/azdad/backup/mise drive:backup_80/mise &>> $log
	echo -e "${BLUE}copy orange${NC}" >> $log
	/snap/bin/rclone -v copy --ignore-existing --checksum /home/azdad/backup/orange drive:backup_80/orange &>> $log
fi
echo -e "${ORANGE}send email${NC}" >> $log
curl -F file=@$log http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/rclone
