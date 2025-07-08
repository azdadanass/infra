#!/bin/bash

# Config
BACKUP_DIR="/backups"
FULL_BACKUP_PREFIX="full"
INC_BACKUP_PREFIX="inc"
MYSQL_USER="backup_user"
MYSQL_PASSWORD="XXX"
LOG_FILE="/var/log/mysql_backup.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to find latest backup
get_latest_backup() {
    find "$BACKUP_DIR" -type d -name "${FULL_BACKUP_PREFIX}-*" -o -name "${INC_BACKUP_PREFIX}-*" | sort | tail -n 1
}

# Determine backup type (full on Sundays, incremental otherwise)
if [ "$(date +%u)" -eq 7 ]; then
    # Full backup on Sunday
    BACKUP_TYPE="full"
    TARGET_DIR="${BACKUP_DIR}/${FULL_BACKUP_PREFIX}-$(date +\%Y\%m\%d)"
else
    # Incremental backup other days
    BACKUP_TYPE="inc"
    LATEST_BACKUP=$(get_latest_backup)
    if [ -z "$LATEST_BACKUP" ]; then
        echo "$(date) - ERROR: No base backup found for incremental" >> "$LOG_FILE"
        exit 1
    fi
    TARGET_DIR="${BACKUP_DIR}/${INC_BACKUP_PREFIX}-$(date +\%Y\%m\%d_\%H\%M)"
fi

# Run backup
echo "$(date) - Starting $BACKUP_TYPE backup to $TARGET_DIR" >> "$LOG_FILE"

if [ "$BACKUP_TYPE" = "full" ]; then
    xtrabackup --backup \
        --target-dir="$TARGET_DIR" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        >> "$LOG_FILE" 2>&1
else
    xtrabackup --backup \
        --target-dir="$TARGET_DIR" \
        --incremental-basedir="$LATEST_BACKUP" \
        --user="$MYSQL_USER" \
        --password="$MYSQL_PASSWORD" \
        >> "$LOG_FILE" 2>&1
fi

# Check result and log
if [ $? -eq 0 ]; then
    echo "$(date) - $BACKUP_TYPE backup succeeded" >> "$LOG_FILE"
else
    echo "$(date) - $BACKUP_TYPE backup FAILED" >> "$LOG_FILE"
fi