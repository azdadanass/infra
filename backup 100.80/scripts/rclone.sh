#!/bin/bash

# ===== Config =====
log_folder="/home/azdad/log"
log="$log_folder/rclone.txt"
source_dir="/home/azdad/backup"
remote_dir="drive:backup_80"

# Colors (for terminal only)
BLUE='\033[0;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# ===== Functions =====
# For terminal messages (with color)
echo_color() {
  echo -e "$1"
}

# For log messages (no color)
log_message() {
  echo "$2" >> "$log"
  echo_color "$1"
}

run_rclone() {
  local description="$1"
  local source="$2"
  local options="$3"
  
  log_message "${BLUE}$description${NC}" "$description"
  /snap/bin/rclone -v $options "$source" "$remote_dir/$(basename "$source")" 2>&1 | tee -a "$log"
}

# ===== Main Script =====
mkdir -p "$log_folder"
echo "start rclone $(date +%Y-%m-%d__%H:%M:%S)" > "$log"
echo_color "${GREEN}start rclone $(date +%Y-%m-%d__%H:%M:%S)${NC}"
killall rclone 2>/dev/null  # Suppress "no process found" errors

# Sync db_gcom (always sync, not copy)
log_message "${BLUE}sync db_gcom${NC}" "sync db_gcom"
/snap/bin/rclone -v sync "$source_dir/db_gcom" "$remote_dir/db_gcom" 2>&1 | tee -a "$log"

# Determine flags based on argument
if [[ "$1" = "-size-only" ]]; then
  log_message "${GREEN}Option size-only${NC}" "Option size-only"
  rclone_flags="copy --ignore-existing --size-only"
else
  log_message "${GREEN}Option checksum${NC}" "Option checksum"
  rclone_flags="copy --ignore-existing --checksum"
fi

# Run backups for all directories (except db_gcom, which was synced)
directories=("db_mise" "gcom" "mise" "orange")
for dir in "${directories[@]}"; do
  run_rclone "copy $dir" "$source_dir/$dir" "$rclone_flags"
done

# Send email
log_message "${ORANGE}send email${NC}" "send email"
curl -F "file=@$log" "http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/rclone"