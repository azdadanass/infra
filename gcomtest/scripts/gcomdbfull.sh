#!/bin/bash

# Database Configuration
LOCAL_DB_USER="root"
LOCAL_DB_PASS="root"
LOCAL_DB_NAME="gcom"
POST_IMPORT_SQL="/home/azdad/scripts/initDB.sql"

# Tables to always ignore
BASE_IGNORED_TABLES=(
  "presence"
  "access_log"
  "event"
  "entry"
  "detailed_entry"
  "video"
  "message"
)

# Get list of tables ending with _comment from remote server
echo "Fetching list of _comment tables to ignore..."
IGNORED_COMMENT_TABLES=$(ssh root@192.168.100.99 "mysql --defaults-extra-file=/root/scripts/config.cnf -Nse 'SHOW TABLES FROM gcom LIKE \"%_comment\"'")

# Combine all ignored tables
ALL_IGNORED_TABLES=("${BASE_IGNORED_TABLES[@]}")
for table in $IGNORED_COMMENT_TABLES; do
  ALL_IGNORED_TABLES+=("$table")
done

# Generate MySQL 5.1 compatible ignore flags
IGNORE_FLAGS=""
for table in "${ALL_IGNORED_TABLES[@]}"; do
  IGNORE_FLAGS+="--ignore-table=gcom.$table "
done

# Debug output
echo "-------------------------------------"
echo "TABLES TO IGNORE:"
printf " - %s\n" "${ALL_IGNORED_TABLES[@]}"
echo "-------------------------------------"

# Main Database Import
echo "Starting database transfer..."
start_time=$(date +%s)

# drop existing local database
mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" -e "DROP DATABASE IF EXISTS $LOCAL_DB_NAME; CREATE DATABASE $LOCAL_DB_NAME;"

ssh -C root@192.168.100.99 "mysqldump --defaults-extra-file=/root/scripts/config.cnf \
  --max_allowed_packet=1G \
  --default-character-set=utf8 \
  --single-transaction \
  --extended-insert \
  --quick \
  $IGNORE_FLAGS \
  gcom" | mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" \
  "$LOCAL_DB_NAME" \
  --max_allowed_packet=1G \
  --init-command="SET FOREIGN_KEY_CHECKS=0; SET unique_checks=0; SET autocommit=0;"

import_status=$?
end_time=$(date +%s)
duration=$((end_time - start_time))

if [ $import_status -ne 0 ]; then
  echo "❌ Database import failed after $duration seconds"
  exit 1
fi

echo "✅ Database imported successfully in $duration seconds"

# Verify no ignored tables were imported
echo "Verifying no ignored tables were imported..."
IMPORTED_IGNORED_TABLES=$(mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" -Nse "
  SELECT GROUP_CONCAT(TABLE_NAME SEPARATOR ', ') 
  FROM information_schema.TABLES 
  WHERE TABLE_SCHEMA = '$LOCAL_DB_NAME' 
  AND (TABLE_NAME IN ('$(IFS="','"; echo "${ALL_IGNORED_TABLES[*]}")'))
" 2>/dev/null)

if [ -n "$IMPORTED_IGNORED_TABLES" ]; then
  echo "❌ CRITICAL ERROR: These tables were imported but should be ignored:"
  echo "$IMPORTED_IGNORED_TABLES" | tr ',' '\n' | sed 's/^/ - /'
  exit 1
else
  echo "✅ Verification passed: No ignored tables were imported"
fi

# Run post-import script if exists
if [ -f "$POST_IMPORT_SQL" ]; then
  echo "Executing post-import script..."
  start_post_time=$(date +%s)
  
  mysql -u "$LOCAL_DB_USER" -p"$LOCAL_DB_PASS" "$LOCAL_DB_NAME" < "$POST_IMPORT_SQL"
  post_status=$?
  
  end_post_time=$(date +%s)
  post_duration=$((end_post_time - start_post_time))

  if [ $post_status -ne 0 ]; then
    echo "❌ Post-import script failed after $post_duration seconds"
    exit 1
  fi
  
  echo "✅ Post-import script completed in $post_duration seconds"
else
  echo "⚠️  Post-import script not found at $POST_IMPORT_SQL"
fi

# Final Summary
total_time=$(( $(date +%s) - start_time ))
echo "-------------------------------------"
echo "IMPORT SUMMARY"
echo "-------------------------------------"
echo " - Import duration:    $duration seconds"
echo " - Post-import duration: ${post_duration:-0} seconds"
echo " - Total time:        $total_time seconds"
echo " - Ignored tables:    ${#ALL_IGNORED_TABLES[@]}"
echo "-------------------------------------"