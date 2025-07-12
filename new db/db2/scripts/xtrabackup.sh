#!/bin/bash
source /etc/environment

# ===== Config =====
script_dir=$(dirname $0)
base_dir=/home/azdad/backup/xtrabackup/
state_file=/tmp/xtrabackup_rotation.state
db1_ip=$DATABASE1_IP #from /etc/environment
log_folder="/home/azdad/log"
backup_error_log="$log_folder/xtrabackup_backup_error.txt"
restore_error_log="$log_folder/xtrabackup_restore_error.txt"

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
  echo "$1" >> "$backup_error_log"
  echo_color "${RED}$1${NC}"
}

# ===== Time Tracking =====
start_time=$(date +%s)
echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Starting backup process${NC}"

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
mkdir -p "$log_folder"
mkdir -p "$backup_dir"

echo_color "${BLUE}Using backup directory: $backup_dir${NC}"

echo "$backup_dir"/*
rm -rf "$backup_dir"/*

# remote backup
echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Starting remote backup from $db1_ip${NC}"
ssh azdad@$db1_ip "xtrabackup --backup --user=root --password=root --stream=xbstream" 2> "$backup_error_log" | xbstream -x -C "$backup_dir"
remote_backup_status=$?

if [ $remote_backup_status -eq  ]; then
    echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Remote backup completed successfully${NC}"
    # Clean up error log if exists
    rm -f "$backup_dir/xtrabackup_error.log"
else
    echo_color "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] Remote backup failed!${NC}"
    
    # Capture additional error context
    {
        echo "=== Backup Error Details ==="
        echo "Timestamp: $(date)"
        echo "Backup Directory: $backup_dir"
        echo "Exit Status: $remote_backup_status"
        echo "=== Last 20 Lines of Error Log ==="
        tail -n 20 "$backup_error_log"
    } > "$log_folder/error_report.txt"
    
    # Send error report
    curl -F "file=@$log_folder/error_report.txt" "http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/xtrabackup_ssh_backup_error"
    exit 1
fi

# restore backup locally
echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Starting local restore${NC}"
sudo "$script_dir"/restore-backup.sh $backup_dir
sudo "$script_dir"/restore-backup.sh "$backup_dir" 2> "$restore_error_log"
restore_status=$?


#if [ $restore_status -eq 0 ]; then
#    echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Local restore completed successfully${NC}"
#else
#    echo_color "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] Local restore failed!${NC}"
#fi

if [ $restore_status -eq 0 ]; then
    echo_color "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] Local restore completed successfully${NC}"
    rm -f "$restore_error_log"
else
    echo_color "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] Local restore failed with status $restore_status${NC}"
    
    # Create comprehensive restore error report
    restore_report="$log_folder/restore_failure_$(date +%Y%m%d_%H%M%S).report"
    {
        echo "MySQL Restore Failure Report"
        echo "============================"
        echo "Host: $(hostname)"
        echo "Backup Source: $backup_dir"
        echo "Timestamp: $(date)"
        echo "Exit Status: $restore_status"
        echo ""
        echo "Restore Error Log:"
        cat "$restore_error_log"
        echo ""
        echo "Disk Space Info:"
        df -h
        echo ""
        echo "MySQL Service Status:"
        systemctl status mysql --no-pager
    } > "$restore_report"
    
    # Send report
    curl_response=$(curl -s -w "%{http_code}" -F "file=@$restore_report" \
        "http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/xtrabackup_restore_error")
    
    if [[ "${curl_response: -3}" == "200" ]]; then
        echo_color "${ORANGE}Restore error report sent successfully${NC}"
    else
        echo_color "${RED}Failed to send restore error report (HTTP ${curl_response: -3})${NC}"
    fi
    exit 1
fi

# Calculate and display total duration
end_time=$(date +%s)
duration=$((end_time - start_time))
echo_color "${ORANGE}[$(date +'%Y-%m-%d %H:%M:%S')] Total execution time: ${duration} seconds${NC}"