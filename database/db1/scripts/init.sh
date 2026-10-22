
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# MySQL 8.0.42 + configuration + Percona XtraBackup
# Ubuntu 22.04 / AMD64
# ============================================================

MYSQL_VERSION="8.0.42"
MYSQL_PACKAGE="mysql-server_8.0.42-1ubuntu22.04_amd64.deb-bundle.tar"
DOWNLOAD_URL="https://dev.mysql.com/get/Downloads/MySQL-8.0/${MYSQL_PACKAGE}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="/tmp/mysql-download"
INSTALL_DIR="/tmp/mysql-${MYSQL_VERSION}"

# Existing application credentials (kept for compatibility).
# WARNING: These passwords are weak. Change them for production.
MYSQL_ROOT_PASSWORD="root"
TOMCAT_PASSWORD="tacmot"
BACKUP_PASSWORD="backup"
NAGIOS_PASSWORD="nagios"

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

trap 'error "Failed at line $LINENO: $BASH_COMMAND"' ERR

# ------------------------------------------------------------
# Root and OS checks
# ------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
    echo "Run with: sudo bash $0"
    exit 1
fi

source /etc/os-release

if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "22.04" ]]; then
    error "This script requires Ubuntu 22.04."
    exit 1
fi

if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    error "This script requires AMD64 architecture."
    exit 1
fi

# Do not overwrite an existing MySQL installation.
if dpkg-query -W -f='${Status}' mysql-server 2>/dev/null |
        grep -q "install ok installed" ||
   dpkg-query -W -f='${Status}' mysql-community-server 2>/dev/null |
        grep -q "install ok installed"; then
    error "A MySQL server package is already installed."
    error "Back up your databases and plan an upgrade separately."
    exit 1
fi

# Check required configuration files before making changes.
for file in mysqld.cnf client.cnf; do
    if [[ ! -f "${SCRIPT_DIR}/${file}" ]]; then
        error "Missing ${SCRIPT_DIR}/${file}"
        exit 1
    fi
done

# ------------------------------------------------------------
# Install prerequisites
# ------------------------------------------------------------

log "Updating APT and installing prerequisites..."

apt-get update
apt-get install -y wget ca-certificates tar debconf-utils libaio1

mkdir -p "$DOWNLOAD_DIR"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# ------------------------------------------------------------
# Download and extract the exact MySQL version
# ------------------------------------------------------------

cd "$DOWNLOAD_DIR"

if [[ ! -f "$MYSQL_PACKAGE" ]] ||
   ! tar -tf "$MYSQL_PACKAGE" >/dev/null 2>&1; then
    rm -f "$MYSQL_PACKAGE"
    log "Downloading MySQL ${MYSQL_VERSION}..."
    wget --show-progress -O "$MYSQL_PACKAGE" "$DOWNLOAD_URL"
fi

tar -tf "$MYSQL_PACKAGE" >/dev/null
tar -xf "$MYSQL_PACKAGE" -C "$INSTALL_DIR"

cd "$INSTALL_DIR"

# Verify that the bundle contains the expected server package.
SERVER_DEB="$(find . -maxdepth 1 -type f \
    -name "mysql-community-server_${MYSQL_VERSION}-*.deb" \
    -print -quit)"

if [[ -z "$SERVER_DEB" ]]; then
    error "MySQL ${MYSQL_VERSION} server package not found."
    exit 1
fi

success "MySQL ${MYSQL_VERSION} bundle extracted."

# ------------------------------------------------------------
# Install MySQL 8.0.42
# ------------------------------------------------------------

log "Installing MySQL ${MYSQL_VERSION} packages..."

# Install only the server/client packages, not debug or test suites.
shopt -s nullglob
MYSQL_DEBS=(
    ./mysql-common_*.deb
    ./mysql-community-client-plugins_${MYSQL_VERSION}-*.deb
    ./mysql-community-client-core_${MYSQL_VERSION}-*.deb
    ./mysql-community-client_${MYSQL_VERSION}-*.deb
    ./mysql-client_${MYSQL_VERSION}-*.deb
    ./mysql-community-server-core_${MYSQL_VERSION}-*.deb
    ./mysql-community-server_${MYSQL_VERSION}-*.deb
    ./mysql-server_${MYSQL_VERSION}-*.deb
)
shopt -u nullglob

if [[ ${#MYSQL_DEBS[@]} -lt 8 ]]; then
    error "Expected MySQL packages are missing from the bundle."
    exit 1
fi

# Let the package installer ask for the initial MySQL root password.
dpkg-preconfigure "$SERVER_DEB" || true

DEBIAN_FRONTEND=noninteractive apt-get install -y "${MYSQL_DEBS[@]}"

systemctl enable mysql
systemctl restart mysql

for i in {1..30}; do
    if mysqladmin ping --silent >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

if ! systemctl is-active --quiet mysql; then
    systemctl status mysql --no-pager || true
    journalctl -u mysql --no-pager -n 80 || true
    error "MySQL did not start."
    exit 1
fi

# Verify the actual SERVER version, not just the client version.
SERVER_VERSION="$(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -NBe 'SELECT VERSION()' 2>/dev/null || true)"

if [[ "$SERVER_VERSION" != "$MYSQL_VERSION" ]]; then
    error "Expected server ${MYSQL_VERSION}, found: ${SERVER_VERSION:-unavailable}"
    error "Check the root login and installed package versions."
    exit 1
fi

success "MySQL Server ${SERVER_VERSION} installed."

# ------------------------------------------------------------
# Create application and monitoring users
# ------------------------------------------------------------

log "Creating database users and permissions..."

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS 'tomcat'@'%' IDENTIFIED BY '${TOMCAT_PASSWORD}';
ALTER USER 'tomcat'@'%' IDENTIFIED BY '${TOMCAT_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'tomcat'@'%';

CREATE USER IF NOT EXISTS 'backup'@'localhost' IDENTIFIED BY '${BACKUP_PASSWORD}';
ALTER USER 'backup'@'localhost' IDENTIFIED BY '${BACKUP_PASSWORD}';
GRANT SELECT, SHOW VIEW, TRIGGER, LOCK TABLES, PROCESS
ON *.* TO 'backup'@'localhost';

CREATE USER IF NOT EXISTS 'nagios'@'localhost' IDENTIFIED BY '${NAGIOS_PASSWORD}';
ALTER USER 'nagios'@'localhost' IDENTIFIED BY '${NAGIOS_PASSWORD}';
GRANT PROCESS, REPLICATION CLIENT ON *.* TO 'nagios'@'localhost';

FLUSH PRIVILEGES;
SQL

# Note: The legacy SUPER privilege is intentionally not granted to
# nagios. Add any additional privilege only if your monitoring setup
# explicitly requires it.

success "Database users configured."

# ------------------------------------------------------------
# Install MySQL configuration files
# ------------------------------------------------------------

log "Installing MySQL configuration files..."

install -o root -g root -m 644 \
    "${SCRIPT_DIR}/mysqld.cnf" \
    /etc/mysql/mysql.conf.d/mysqld.cnf

install -o root -g root -m 644 \
    "${SCRIPT_DIR}/client.cnf" \
    /etc/mysql/conf.d/client.cnf

# Preserve the SQL mode from your original script without
# appending duplicate sections on every run.
cat > /etc/mysql/conf.d/zz-custom-sql-mode.cnf <<'EOF'
[mysqld]
sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
EOF

chmod 750 /var/lib/mysql

# ------------------------------------------------------------
# Restart and verify MySQL
# ------------------------------------------------------------

log "Restarting MySQL with the new configuration..."

systemctl restart mysql

if ! systemctl is-active --quiet mysql; then
    systemctl status mysql --no-pager || true
    journalctl -u mysql --no-pager -n 80 || true
    error "MySQL failed after applying configuration."
    exit 1
fi

SERVER_VERSION="$(mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" \
    -NBe 'SELECT VERSION()')"

if [[ "$SERVER_VERSION" != "$MYSQL_VERSION" ]]; then
    error "Unexpected MySQL server version: $SERVER_VERSION"
    exit 1
fi

success "MySQL ${SERVER_VERSION} is running."

# ------------------------------------------------------------
# Install Percona XtraBackup 8.0
# ------------------------------------------------------------

log "Installing Percona XtraBackup..."

cd /tmp

wget -O percona-release.deb \
    https://repo.percona.com/apt/percona-release_latest.jammy_all.deb

dpkg -i percona-release.deb
apt-get update
percona-release enable tools release
apt-get update
apt-get install -y percona-xtrabackup-80

success "Percona XtraBackup installed."

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

# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installation complete"
echo "============================================================"

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e \
    "SELECT VERSION() AS mysql_server_version;"

systemctl status mysql --no-pager --lines=10

echo
success "MySQL ${MYSQL_VERSION} setup completed."
