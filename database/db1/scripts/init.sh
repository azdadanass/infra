#!/usr/bin/env bash
set -Eeuo pipefail



SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------------------------------------
# Install mysql8 and Percona XtraBackup
# ------------------------------------------------------------

 "${SCRIPT_DIR}/install-mysql-8.0.42.sh"

# ------------------------------------------------------------
# Configure backup cron jobs (for the current sudo caller)
# ------------------------------------------------------------

BACKUP_SCRIPT="/home/azdad/scripts/mysqldump.sh"

if [[ -x "$BACKUP_SCRIPT" ]]; then
    log "Configuring backup cron jobs for azdad..."

    CRON_TMP="$(mktemp)"
    crontab -u azdad -l 2>/dev/null > "$CRON_TMP" || true

    grep -Fqx "00 19 * * * ${BACKUP_SCRIPT}" "$CRON_TMP" ||
        echo "00 19 * * * ${BACKUP_SCRIPT}" >> "$CRON_TMP"

    grep -Fqx "00 00 * * SUN ${BACKUP_SCRIPT} --type=full" "$CRON_TMP" ||
        echo "00 00 * * SUN ${BACKUP_SCRIPT} --type=full" >> "$CRON_TMP"

    crontab -u azdad "$CRON_TMP"
    rm -f "$CRON_TMP"
    success "Backup cron jobs configured."
else
    warning "Backup script not found or not executable: ${BACKUP_SCRIPT}"
    warning "Cron jobs were not installed."
fi


