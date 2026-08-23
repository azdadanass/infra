#!/usr/bin/env bash

# ============================================================
# MySQL 8.0.42 Installation Script
# Ubuntu 20.04 - amd64
#
# Package:
# mysql-server_8.0.42-1ubuntu20.04_amd64.deb-bundle.tar
# ============================================================

set -Eeuo pipefail

MYSQL_VERSION="8.0.42"
MYSQL_PACKAGE="mysql-server_8.0.42-1ubuntu20.04_amd64.deb-bundle.tar"

DOWNLOAD_URL="https://dev.mysql.com/get/Downloads/MySQL-8.0/${MYSQL_PACKAGE}"

INSTALL_DIR="/tmp/mysql-${MYSQL_VERSION}"
DOWNLOAD_DIR="/tmp/mysql-download"

# ------------------------------------------------------------
# Colors / logging
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------
# Error handler
# ------------------------------------------------------------

trap 'error "Installation failed at line $LINENO. Command: $BASH_COMMAND"' ERR

# ------------------------------------------------------------
# Must run as root
# ------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    error "Please run this script with sudo:"
    echo
    echo "  sudo bash $0"
    exit 1
fi

# ------------------------------------------------------------
# Check operating system
# ------------------------------------------------------------

log "Checking operating system..."

if [[ ! -f /etc/os-release ]]; then
    error "Cannot determine operating system."
    exit 1
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    error "This script is intended for Ubuntu."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if [[ "${VERSION_ID}" != "20.04" ]]; then
    error "This script is intended for Ubuntu 20.04."
    error "Detected: Ubuntu ${VERSION_ID}"
    exit 1
fi

ARCH="$(dpkg --print-architecture)"

if [[ "${ARCH}" != "amd64" ]]; then
    error "This MySQL bundle is for amd64."
    error "Detected architecture: ${ARCH}"
    exit 1
fi

success "Ubuntu 20.04 amd64 detected."

# ------------------------------------------------------------
# Check if MySQL is already installed
# ------------------------------------------------------------

if command -v mysql >/dev/null 2>&1; then
    CURRENT_VERSION="$(mysql --version || true)"

    warning "MySQL is already installed:"
    echo
    echo "  ${CURRENT_VERSION}"
    echo

    read -r -p "Continue and install MySQL ${MYSQL_VERSION}? [y/N]: " ANSWER

    if [[ ! "${ANSWER}" =~ ^[Yy]$ ]]; then
        log "Installation cancelled."
        exit 0
    fi
fi

# ------------------------------------------------------------
# Create working directories
# ------------------------------------------------------------

log "Creating working directories..."

mkdir -p "${DOWNLOAD_DIR}"
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

cd "${DOWNLOAD_DIR}"

# ------------------------------------------------------------
# Install prerequisites
# ------------------------------------------------------------

log "Updating APT package information..."

apt-get update

log "Installing required tools and dependencies..."

apt-get install -y \
    wget \
    ca-certificates \
    tar \
    debconf-utils \
    libaio1

success "Prerequisites installed."

# ------------------------------------------------------------
# Download MySQL bundle
# ------------------------------------------------------------

if [[ -f "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" ]]; then
    log "MySQL bundle already exists. Checking it..."

    if tar -tf "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" >/dev/null 2>&1; then
        success "Existing MySQL bundle is valid."
    else
        warning "Existing file is not a valid tar archive."
        rm -f "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}"
    fi
fi

if [[ ! -f "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" ]]; then

    log "Downloading MySQL ${MYSQL_VERSION}..."
    echo
    echo "URL:"
    echo "${DOWNLOAD_URL}"
    echo

    wget \
        --show-progress \
        --progress=bar:force:noscroll \
        -O "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" \
        "${DOWNLOAD_URL}"

    success "Download completed."
fi

# ------------------------------------------------------------
# Verify downloaded file
# ------------------------------------------------------------

log "Verifying downloaded MySQL bundle..."

if ! tar -tf "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" >/dev/null 2>&1; then
    error "The downloaded file is not a valid tar archive."
    echo
    echo "File information:"
    file "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}"
    echo
    echo "First 500 bytes:"
    head -c 500 "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" || true
    echo
    exit 1
fi

FILE_SIZE="$(du -h "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" | cut -f1)"

success "MySQL bundle verified."
log "Downloaded file size: ${FILE_SIZE}"

# ------------------------------------------------------------
# Extract bundle
# ------------------------------------------------------------

log "Extracting MySQL ${MYSQL_VERSION} packages..."

tar -xf \
    "${DOWNLOAD_DIR}/${MYSQL_PACKAGE}" \
    -C "${INSTALL_DIR}"

success "MySQL packages extracted."

# ------------------------------------------------------------
# Show extracted packages
# ------------------------------------------------------------

log "Packages included in the bundle:"
echo

find "${INSTALL_DIR}" -maxdepth 1 -type f -name "*.deb" \
    -printf "  %f\n" | sort

echo

# ------------------------------------------------------------
# Preconfigure MySQL
# ------------------------------------------------------------

SERVER_DEB="$(find "${INSTALL_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "mysql-community-server_${MYSQL_VERSION}-*.deb" \
    | head -n 1)"

if [[ -z "${SERVER_DEB}" ]]; then
    error "Could not find the MySQL community server package."
    exit 1
fi

log "MySQL server package:"
echo "  ${SERVER_DEB}"
echo

log "Preconfiguring MySQL..."

echo
echo "============================================================"
echo " MySQL configuration"
echo "============================================================"
echo

echo "The MySQL package may ask you to configure a root password."
echo "Please complete the package configuration when prompted."
echo

dpkg-preconfigure "${SERVER_DEB}" || true

# ------------------------------------------------------------
# Install MySQL packages
# ------------------------------------------------------------

log "Installing MySQL ${MYSQL_VERSION}..."

cd "${INSTALL_DIR}"

DEB_COUNT="$(find . -maxdepth 1 -type f -name "*.deb" | wc -l)"

if [[ "${DEB_COUNT}" -eq 0 ]]; then
    error "No .deb packages were found."
    exit 1
fi

log "Installing ${DEB_COUNT} Debian packages..."

apt-get install -y ./*.deb

success "MySQL packages installed."

# ------------------------------------------------------------
# Fix any remaining dependencies
# ------------------------------------------------------------

log "Checking package dependencies..."

apt-get install -f -y

success "Package dependencies are satisfied."

# ------------------------------------------------------------
# Enable MySQL service
# ------------------------------------------------------------

log "Enabling MySQL service..."

systemctl enable mysql

# ------------------------------------------------------------
# Start MySQL
# ------------------------------------------------------------

log "Starting MySQL..."

systemctl restart mysql

sleep 3

# ------------------------------------------------------------
# Check service
# ------------------------------------------------------------

if systemctl is-active --quiet mysql; then
    success "MySQL service is running."
else
    error "MySQL service failed to start."
    echo
    systemctl status mysql --no-pager || true
    echo
    echo "Recent MySQL logs:"
    journalctl -u mysql --no-pager -n 100 || true
    exit 1
fi

# ------------------------------------------------------------
# Verify MySQL version
# ------------------------------------------------------------

echo
echo "============================================================"
echo " MySQL Installation Result"
echo "============================================================"
echo

if command -v mysql >/dev/null 2>&1; then
    mysql --version
else
    error "mysql command was not found."
    exit 1
fi

echo

INSTALLED_VERSION="$(mysql --version)"

if echo "${INSTALLED_VERSION}" | grep -q "${MYSQL_VERSION}"; then
    success "MySQL ${MYSQL_VERSION} is installed."
else
    warning "MySQL is installed, but the detected version is:"
    echo "${INSTALLED_VERSION}"
fi

# ------------------------------------------------------------
# Edit my.cnf
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Edit my.cnf"
echo "============================================================"
echo

echo '[mysqld]' | tee -a /etc/mysql/my.cnf
echo 'sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"' | tee -a /etc/mysql/my.cnf

systemctl restart mysql

# ------------------------------------------------------------
# Service status
# ------------------------------------------------------------

echo
echo "============================================================"
echo " MySQL Service Status"
echo "============================================================"
echo

systemctl status mysql --no-pager --lines=10

# ------------------------------------------------------------
# Final information
# ------------------------------------------------------------

echo
echo "============================================================"
echo " Installation Complete"
echo "============================================================"
echo

success "MySQL ${MYSQL_VERSION} installation completed."

echo
echo "Useful commands:"
echo
echo "  Check status:"
echo "    sudo systemctl status mysql"
echo
echo "  Start MySQL:"
echo "    sudo systemctl start mysql"
echo
echo "  Stop MySQL:"
echo "    sudo systemctl stop mysql"
echo
echo "  Restart MySQL:"
echo "    sudo systemctl restart mysql"
echo
echo "  Check version:"
echo "    mysql --version"
echo
echo "  Login as root:"
echo "    sudo mysql -u root -p"
echo
echo "  MySQL configuration:"
echo "    /etc/mysql/"
echo
echo "  MySQL data directory:"
echo "    /var/lib/mysql/"
echo

success "Done."