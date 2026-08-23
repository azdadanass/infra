#!/usr/bin/env bash
set -euo pipefail

# Install Docker Engine on Ubuntu 22.04
# Intended for running containers (not building images).

if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run as root, e.g.:"
    echo "  sudo bash $0"
    exit 1
fi

echo "==> Removing conflicting Docker packages..."
apt-get remove -y \
    docker.io \
    docker-doc \
    docker-compose \
    podman-docker \
    containerd \
    runc \
    2>/dev/null || true

echo "==> Installing prerequisites..."
apt-get update
apt-get install -y \
    ca-certificates \
    curl

echo "==> Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

echo "==> Adding Docker APT repository..."
. /etc/os-release

echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list

echo "==> Installing Docker Engine..."
apt-get update
apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io

echo "==> Enabling Docker..."
systemctl enable --now docker

echo "==> Verifying Docker..."
docker --version
docker run --rm hello-world


echo "==> add user to docker group..."
sudo usermod -aG docker azdad
echo "log out and log back in "



echo
echo "=========================================="
echo "Docker installation completed successfully"
echo "=========================================="
echo
echo "Docker service:"
systemctl --no-pager --full status docker | head -n 12


