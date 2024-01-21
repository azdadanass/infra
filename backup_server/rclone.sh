#!/bin/bash

output=~/log/rclone-out.log
errors=~/log/rclone-err.log 

mkdir -p ~/log

echo > $output
echo > $errors

rclone -v copy /home/azdad/backup drive:backup >> $output 2>> $errors

mutt -s "rclone (from $HOSTNAME)" -a $output $errors -- a.azdad@3gcom-int.com  < $errors
mutt -s "rclone (from $HOSTNAME)" -a $output $errors -- a.abourhnim@3gcom-int.com  < $errors