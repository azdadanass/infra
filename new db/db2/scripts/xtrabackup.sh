#!/bin/bash

# ===== Config =====
script_dir=$(dirname $0)
base_dir=/home/azdad/backup/xtrabackup/
state_file=/tmp/xtrabackup_rotation.state
db1_ip=192.168.1.50

# Colors (for terminal only)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ===== Functions =====
echo_color() {
  echo -e "$1"
}

log_error() {
  echo "$1" >> "$error_log"
  echo_color "${RED}$1${NC}"
}

# Read the last used directory number or default to 1
if [ -f "$state_file" ]; then
    last_used=$(cat "$state_file")
else
    last_used=1
fi

# Calculate the next directory to use
next_used=$((last_used % 3 + 1))

# Set the backup directory
backup_dir="${base_dir}${next_used}"

# Store the next_used for next run
echo "$next_used" > "$state_file"

# Create the directory if it doesn't exist
mkdir -p "$backup_dir"


echo_color "${BLUE}Using backup directory: $backup_dir${NC}"

echo "$backup_dir"/*
rm -rf "$backup_dir"/*

# remote backup
echo_color "${BLUE}Start Remote Backup ($db1_ip)${NC}"
ssh azdad@$db1_ip "xtrabackup --backup --user=root --password=root --stream=xbstream" | xbstream -x -C $backup_dir

#restore backup locally
sudo "$script_dir"/restore-backup.sh $backup_dir