#!/bin/bash

# Configuration
BACKUP_DIR="/home/azdad/backup/full"
LOG_FILE="/home/azdad/backup/backup.log"
BACKUP_NAME="test1"

# Create directories if they don't exist
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

rm -r $BACKUP_DIR/$BACKUP_NAME

# Function to log to both console and file
log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Start time recording
START_TIME=$(date +%s)
log "Starting backup to $BACKUP_DIR/$BACKUP_NAME"

# Run the backup and capture all output
{
  xtrabackup --backup \
    --user=root \
    --password=root \
    --target-dir="$BACKUP_DIR/$BACKUP_NAME"
} 2>&1 | tee -a "$LOG_FILE"

# Capture exit status from xtrabackup (PIPESTATUS[0] captures the first command in the pipe)
EXIT_STATUS=${PIPESTATUS[0]}

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Log results
if [ $EXIT_STATUS -eq 0 ]; then
  log "Backup SUCCESS - Duration: ${DURATION} seconds"
else
  log "Backup FAILED (Code: $EXIT_STATUS) - Duration: ${DURATION} seconds"
  log "Last 5 error lines:"
  tail -n 5 "$LOG_FILE" | tee -a "$LOG_FILE"
fi

exit $EXIT_STATUS