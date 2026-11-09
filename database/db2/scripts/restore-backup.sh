#!/bin/bash

# ===== Config =====
backup_dir=$1

# ===== Functions =====


log_error() {
  echo "$1" >> "$error_log"
  echo_color red "$1"
}

echo_color blue "try restore $backup_dir"

echo_color green "stop mysql"
systemctl stop mysql


echo_color green "Prepare (xtrabackup --prepare)"
xtrabackup --prepare --target-dir=$backup_dir

echo_color green "clear /var/lib/mysql/*"
rm -rf /var/lib/mysql/*

echo_color green "Restore(xtrabackup --copy-back)"
xtrabackup --copy-back --target-dir=$backup_dir --datadir=/var/lib/mysql

echo_color green "chown -R mysql:mysql /var/lib/mysql"
chown -R mysql:mysql /var/lib/mysql

echo_color green "start mysql"
systemctl start mysql