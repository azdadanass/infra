#!/bin/bash

# ===== Config =====
backup_dir=$1

# Colors (for terminal only)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ===== Functions =====


log_error() {
  echo "$1" >> "$error_log"
  echo_color red "$1"
}

echo_color blue "try restore $backup_dir"

echo_color "${GREEN}stop mysql"
systemctl stop mysql


echo_color "${GREEN}Prepare (xtrabackup --prepare)"
xtrabackup --prepare --target-dir=$backup_dir

echo_color "${GREEN}clear /var/lib/mysql/*"
rm -rf /var/lib/mysql/*

echo_color "${GREEN}Restore(xtrabackup --copy-back)"
xtrabackup --copy-back --target-dir=$backup_dir --datadir=/var/lib/mysql

echo_color "${GREEN}chown -R mysql:mysql /var/lib/mysql"
chown -R mysql:mysql /var/lib/mysql

echo_color "${GREEN}start mysql"
systemctl start mysql