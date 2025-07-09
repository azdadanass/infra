#!/bin/bash

# ===== Config =====
script_dir=$(dirname $0)
base_dir=/home/azdad/backup/xtrabackup/
state_file=/tmp/xtrabackup_rotation.state

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

echo "Using backup directory: $backup_dir"

echo "$backup_dir"/*
rm -rf "$backup_dir"/*

ssh azdad@192.168.1.50 \
"xtrabackup --backup --user=root --password=root --stream=xbstream" | xbstream -x -C $backup_dir


"$script_dir"/restore-backup.sh