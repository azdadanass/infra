#!/bin/bash

# ===== Config =====
current_date=$(date +%Y-%m-%d_%H:%M)
log_folder="/root/log"
error_log="$log_folder/export_db_error.txt"
config_file="/root/scripts/config.cnf"
export_folder="/root/backup/db"
sql_path=/tmp/gcom.sql
zip_path="/root/backup/db/gcom_${current_date}"

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

# ===== Main Script =====
mkdir -p "$log_folder"
mkdir -p "$export_folder"

# Determine export type
if [[ "$1" == "-full" ]]; then
  export_type="full"
  zip_path="${zip_path}_full.7z"
  echo_color "${ORANGE}Running FULL database export${NC}"
else
  export_type="light"
  zip_path="${zip_path}.7z"
  echo_color "${BLUE}Running LIGHT database export${NC}"
fi

# Clear export folder
if [ -d "$export_folder" ]; then
    echo_color "${BLUE}Clearing export folder${NC}"
    rm -f "$export_folder"/* 2>/dev/null
fi

# Export database with error handling
echo_color "${BLUE}Exporting database ($export_type version)${NC}"

if [[ "$export_type" == "full" ]]; then
  mysqldump \
   --defaults-extra-file="$config_file" \
   --max_allowed_packet=1G \
   --default-character-set=utf8 \
   --single-transaction=TRUE "gcom" \
   --databases > "$sql_path" 2>&1
else
  mysqldump \
   --defaults-extra-file="$config_file" \
   --max_allowed_packet=1G \
   --default-character-set=utf8 \
   --single-transaction=TRUE "gcom" \
   --ignore-table=gcom.presence \
   --ignore-table=gcom.event \
   --ignore-table=gcom.entry \
   --ignore-table=gcom.detailed_entry \
   --ignore-table=gcom.video \
   --ignore-table=gcom.message \
   --databases > "$sql_path" 2>&1
fi

# Store exit status immediately
dump_status=$?

# Check and display errors
if [ $dump_status -ne 0 ]; then
  log_error "MySQLDump Error at $(date):"
  grep -i error "$sql_path" >> "$error_log"
  grep -i error "$sql_path" >&2
  
  # Skip compression on failure
  echo_color "${RED}Database export failed - skipping compression${NC}"
  echo_color "${BLUE}Deleting temporary sql file${NC}"
  rm -f "$sql_path"
  
  # Send error notification and exit
  echo_color "${RED}Errors detected, sending error log${NC}"
  curl -F "file=@$error_log" "http://utils.3gcominside.com/sendEmailAttachement/a.azdad@3gcom-int.com/db_gcom_export_error"
  exit 1
fi

# Only proceed with compression if dump succeeded
echo_color "${GREEN}Database export successful${NC}"

# Compress sql file
echo_color "${BLUE}Compressing sql file${NC}"
7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "$zip_path" "$sql_path" 2>&1 | tee -a "$error_log"

# Delete sql file
echo_color "${BLUE}Deleting temporary sql file${NC}"
rm -f "$sql_path"

# Send success notification
echo_color "${GREEN}Success ($export_type export), sending success notification${NC}"
curl -u admin:admin "http://utils.3gcominside.com/sendEmail/a.azdad@3gcom-int.com/db_gcom_export_success"