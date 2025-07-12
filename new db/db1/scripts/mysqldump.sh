#!/bin/bash

# ===== Config =====
script_dir=$(dirname $0)
current_date=$(date +%Y-%m-%d_%H:%M)
log_folder="/home/azdad/log"
error_log="$log_folder/export_db_error.txt"
config_file="$script_dir/config.cnf"
export_folder="/home/azdad/backup/mysqldump"
sql_path=/tmp/gcom.sql
zip_path="$export_folder/gcom_${current_date}"

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

format_duration() {
  local seconds=$1
  if (( seconds < 60 )); then
    printf "%ds" $seconds
  else
    printf "%dm %ds" $((seconds/60)) $((seconds%60))
  fi
}

show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Database backup script"
  echo
  echo "Options:"
  echo "  --type=TYPE    Export type: light (default) or full"
  echo "  --fast         Use fast compression (default: max compression)"
  echo "  --help         Show this help"
  exit 0
}

# ===== Argument Parsing =====
export_type="light"
compression_mode="max"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type=*)
      export_type="${1#*=}"
      [[ "$export_type" != "light" && "$export_type" != "full" ]] && {
        echo_color "${RED}Error: Invalid type. Use 'light' or 'full'${NC}"
        exit 1
      }
      shift
      ;;
    --fast)
      compression_mode="fast"
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      echo_color "${RED}Error: Unknown option '$1'${NC}"
      show_help
      exit 1
      ;;
  esac
done

# ===== Main Script =====
mkdir -p "$log_folder"
mkdir -p "$export_folder"

# Set filename and display mode
if [[ "$export_type" == "full" ]]; then
  zip_path="${zip_path}_full.7z"
  echo_color "${ORANGE}Running FULL database export${NC}"
else
  zip_path="${zip_path}.7z"
  echo_color "${BLUE}Running LIGHT database export${NC}"
fi

echo_color "${BLUE}Compression mode: ${compression_mode}${NC}"

# Clear export folder
if [ -d "$export_folder" ]; then
    echo_color "${BLUE}Clearing export folder${NC}"
    rm -f "$export_folder"/* 2>/dev/null
fi

#clear log
rm $error_log

# Export database with error handling
echo_color "${BLUE}Exporting database ($export_type version)${NC}"

start_dump=$(date +%s)
if [[ "$export_type" == "full" ]]; then
  mysqldump \
   --defaults-extra-file="$config_file" \
   --max_allowed_packet=2G \
   --default-character-set=utf8 \
   --single-transaction=TRUE "gcom" \
   --databases > "$sql_path" 2>&1
else
  mysqldump \
   --defaults-extra-file="$config_file" \
   --max_allowed_packet=2G \
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
dump_status=$?
dump_duration=$(($(date +%s) - start_dump))

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
echo_color "${GREEN}Database export successful (took $(format_duration $dump_duration))${NC}"

# Compression settings
start_compress=$(date +%s)
if [[ "$compression_mode" == "fast" ]]; then
  echo_color "${BLUE}Using FAST compression${NC}"
  7z a -t7z \
    -m0=lzma2 \
    -mx=1 \
    -md=32m \
    -mmt=on \
    "$zip_path" "$sql_path" 2>&1 | tee -a "$error_log"
else
  echo_color "${BLUE}Using MAXIMUM compression${NC}"
  7z a -t7z \
    -m0=lzma2 \
    -mx=9 \
    -mfb=273 \
    -md=256m \
    -ms=on \
    -mmt=off \
    -myx=9 \
    -mqs=on \
    "$zip_path" "$sql_path" 2>&1 | tee -a "$error_log"
fi
compress_duration=$(($(date +%s) - start_compress))

# Calculate and show compression ratio
original_size=$(stat -c %s "$sql_path")
compressed_size=$(stat -c %s "$zip_path")
ratio=$(echo "scale=2; ($original_size - $compressed_size) * 100 / $original_size" | bc)
echo_color "${GREEN}Compression: ${ratio}% (mode: $compression_mode, took $(format_duration $compress_duration))${NC}" | tee -a "$error_log"

# Delete sql file
echo_color "${BLUE}Deleting temporary sql file${NC}"
rm -f "$sql_path"

# Send success notification
total_duration=$(($dump_duration + $compress_duration))
echo_color "${GREEN}Success ($export_type export, total time: $(format_duration $total_time))${NC}"
curl -u admin:admin "http://utils.3gcominside.com/sendEmail/a.azdad@3gcom-int.com/db_gcom_export_success"