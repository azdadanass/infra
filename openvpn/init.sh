#!/usr/bin/env bash

# ============================================================
# OpenVPN NAT Server Installer
# Ubuntu 24.04
#
# OpenVPN 2.6
# Easy-RSA 3.1.x
#
# Features:
#   - OpenVPN server
#   - NAT for VPN clients
#   - No route required on the router
#   - Persistent iptables rules
#   - Password-protected CA
#   - First client certificate
#   - Self-contained .ovpn client file
#
# Client file:
#   /home/<user>/openvpn-clients/<client>.ovpn
# ============================================================

set -Eeuo pipefail

# ------------------------------------------------------------
# Require root
# ------------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script with sudo."
    echo
    echo "Example:"
    echo "  sudo bash $0"
    exit 1
fi

# ------------------------------------------------------------
# Determine the real user
# ------------------------------------------------------------
#
# If executed as:
#
#   sudo bash install-openvpn.sh
#
# SUDO_USER will be the normal logged-in user.
#
# If executed directly as root, USER will be used.
# ------------------------------------------------------------

INSTALL_USER="${SUDO_USER:-$USER}"

INSTALL_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"

if [[ -z "$INSTALL_HOME" || ! -d "$INSTALL_HOME" ]]; then
    echo "ERROR: Could not determine home directory for user:"
    echo "       $INSTALL_USER"
    exit 1
fi

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

EASYRSA_DIR="/etc/openvpn/easy-rsa"
SERVER_DIR="/etc/openvpn/server"

CLIENT_DIR="$INSTALL_HOME/openvpn-clients"

VPN_NETWORK="10.8.0.0"
VPN_NETMASK="255.255.255.0"
VPN_CIDR="10.8.0.0/24"

# ------------------------------------------------------------
# Functions
# ------------------------------------------------------------

ask_default() {
    local prompt="$1"
    local default="$2"
    local answer

    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default]: " answer
        echo "${answer:-$default}"
    else
        read -r -p "$prompt: " answer
        echo "$answer"
    fi
}

valid_port() {
    [[ "$1" =~ ^[0-9]+$ ]] &&
    (( "$1" >= 1 && "$1" <= 65535 ))
}

valid_ipv4() {
    local ip="$1"
    local IFS=.
    local -a octets

    read -ra octets <<< "$ip"

    [[ "${#octets[@]}" -eq 4 ]] || return 1

    for octet in "${octets[@]}"; do
        [[ "$octet" =~ ^[0-9]+$ ]] || return 1
        (( octet >= 0 && octet <= 255 )) || return 1
    done

    return 0
}

valid_cidr() {
    local cidr="$1"
    local ip
    local prefix

    [[ "$cidr" == */* ]] || return 1

    ip="${cidr%/*}"
    prefix="${cidr#*/}"

    valid_ipv4 "$ip" || return 1

    [[ "$prefix" =~ ^[0-9]+$ ]] || return 1
    (( prefix >= 0 && prefix <= 32 )) || return 1

    return 0
}

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo
echo "============================================================"
echo "       OpenVPN NAT Server Installer - Ubuntu 24.04"
echo "============================================================"
echo
echo "Running as root."
echo "Client files will belong to:"
echo
echo "  $INSTALL_USER"
echo
echo "and will be stored in:"
echo
echo "  $CLIENT_DIR"
echo

# ------------------------------------------------------------
# Collect configuration
# ------------------------------------------------------------

PUBLIC_ENDPOINT="$(ask_default \
    "Public IP address or DNS hostname" \
    "")"

while [[ -z "$PUBLIC_ENDPOINT" ]]; do
    echo "ERROR: Public IP / hostname cannot be empty."
    PUBLIC_ENDPOINT="$(ask_default \
        "Public IP address or DNS hostname" \
        "")"
done

OPENVPN_PORT="$(ask_default \
    "OpenVPN UDP port" \
    "1194")"

while ! valid_port "$OPENVPN_PORT"; do
    echo "ERROR: Invalid UDP port."
    OPENVPN_PORT="$(ask_default \
        "OpenVPN UDP port" \
        "1194")"
done

LAN_GATEWAY="$(ask_default \
    "LAN default gateway" \
    "192.168.1.1")"

while ! valid_ipv4 "$LAN_GATEWAY"; do
    echo "ERROR: Invalid IPv4 address."
    LAN_GATEWAY="$(ask_default \
        "LAN default gateway" \
        "192.168.1.1")"
done

LAN_SUBNET="$(ask_default \
    "LAN subnet" \
    "192.168.1.0/24")"

while ! valid_cidr "$LAN_SUBNET"; do
    echo "ERROR: Invalid CIDR subnet."
    LAN_SUBNET="$(ask_default \
        "LAN subnet" \
        "192.168.1.0/24")"
done

CLIENT_NAME="$(ask_default \
    "First VPN client name" \
    "laptop")"

while [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    echo "ERROR: Client name may contain only:"
    echo "       letters, numbers, '-' and '_'."

    CLIENT_NAME="$(ask_default \
        "First VPN client name" \
        "laptop")"
done

# ------------------------------------------------------------
# Detect LAN interface
# ------------------------------------------------------------

echo
echo "Detecting LAN interface..."

LAN_INTERFACE="$(
    ip route get "$LAN_GATEWAY" 2>/dev/null |
    awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i == "dev") {
                    print $(i+1)
                    exit
                }
            }
        }
    '
)"

if [[ -z "$LAN_INTERFACE" ]]; then
    echo
    echo "ERROR: Could not determine LAN interface."
    echo
    echo "Gateway:"
    echo "  $LAN_GATEWAY"
    echo
    echo "Check your network configuration."
    exit 1
fi

SERVER_LAN_IP="$(
    ip -4 addr show dev "$LAN_INTERFACE" |
    awk '
        /inet / {
            sub(/\/.*/, "", $2)
            print $2
            exit
        }
    '
)"

if [[ -z "$SERVER_LAN_IP" ]]; then
    echo
    echo "ERROR: Could not determine server LAN IP."
    exit 1
fi

# ------------------------------------------------------------
# Display configuration
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Configuration"
echo "============================================================"
echo
echo "Public endpoint : $PUBLIC_ENDPOINT"
echo "UDP port        : $OPENVPN_PORT"
echo "LAN gateway     : $LAN_GATEWAY"
echo "LAN subnet      : $LAN_SUBNET"
echo "LAN interface   : $LAN_INTERFACE"
echo "Server LAN IP   : $SERVER_LAN_IP"
echo "VPN subnet      : $VPN_CIDR"
echo "Client name     : $CLIENT_NAME"
echo "Install user    : $INSTALL_USER"
echo "Client directory: $CLIENT_DIR"
echo

read -r -p "Continue installation? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ------------------------------------------------------------
# Install packages
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Installing packages"
echo "============================================================"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    openvpn \
    easy-rsa \
    iptables \
    iptables-persistent

# ------------------------------------------------------------
# Stop existing OpenVPN service
# ------------------------------------------------------------

echo
echo "Stopping existing OpenVPN server if present..."

systemctl stop openvpn-server@server.service 2>/dev/null || true

# ------------------------------------------------------------
# Prepare directories
# ------------------------------------------------------------

echo
echo "Preparing directories..."

mkdir -p "$EASYRSA_DIR"
mkdir -p "$SERVER_DIR"
mkdir -p "$CLIENT_DIR"

chown "$INSTALL_USER:$INSTALL_USER" "$CLIENT_DIR"
chmod 700 "$CLIENT_DIR"

# ------------------------------------------------------------
# Install Easy-RSA
# ------------------------------------------------------------

echo
echo "Installing Easy-RSA..."

rm -rf "$EASYRSA_DIR"

mkdir -p "$EASYRSA_DIR"

cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"

chmod 700 "$EASYRSA_DIR"

cd "$EASYRSA_DIR"

# ------------------------------------------------------------
# Initialize PKI
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Initializing PKI"
echo "============================================================"

./easyrsa init-pki

# ------------------------------------------------------------
# Create CA
# ------------------------------------------------------------
#
# IMPORTANT:
#
# We intentionally let Easy-RSA interactively ask for the
# password. This is the safest and most compatible method
# with Easy-RSA 3.1.7.
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Creating Certificate Authority"
echo "============================================================"
echo
echo "You will be asked to enter a CA password."
echo
echo "REMEMBER THIS PASSWORD."
echo "You may need it later to create/revoke certificates."
echo

unset EASYRSA_BATCH
unset EASYRSA_REQ_CN
unset EASYRSA_PASSIN

./easyrsa build-ca

# Verify CA

if [[ ! -f "$EASYRSA_DIR/pki/ca.crt" ]]; then
    echo
    echo "ERROR: CA certificate was not created."
    exit 1
fi

if [[ ! -f "$EASYRSA_DIR/pki/private/ca.key" ]]; then
    echo
    echo "ERROR: CA private key was not created."
    exit 1
fi

chmod 600 "$EASYRSA_DIR/pki/private/ca.key"

# ------------------------------------------------------------
# Create server certificate
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Creating OpenVPN server certificate"
echo "============================================================"

unset EASYRSA_REQ_CN
unset EASYRSA_PASSIN

./easyrsa build-server-full server nopass

# ------------------------------------------------------------
# Generate DH
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Generating Diffie-Hellman parameters"
echo "============================================================"
echo
echo "This may take some time..."

./easyrsa gen-dh

# ------------------------------------------------------------
# Generate tls-crypt key
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Generating tls-crypt key"
echo "============================================================"

openvpn \
    --genkey \
    tls-crypt \
    "$EASYRSA_DIR/pki/ta.key"

# ------------------------------------------------------------
# Create first client
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Creating client certificate: $CLIENT_NAME"
echo "============================================================"

./easyrsa build-client-full "$CLIENT_NAME" nopass

# ------------------------------------------------------------
# Install server certificates
# ------------------------------------------------------------

echo
echo "Installing OpenVPN certificates..."

cp "$EASYRSA_DIR/pki/ca.crt" \
   "$SERVER_DIR/ca.crt"

cp "$EASYRSA_DIR/pki/issued/server.crt" \
   "$SERVER_DIR/server.crt"

cp "$EASYRSA_DIR/pki/private/server.key" \
   "$SERVER_DIR/server.key"

cp "$EASYRSA_DIR/pki/dh.pem" \
   "$SERVER_DIR/dh.pem"

cp "$EASYRSA_DIR/pki/ta.key" \
   "$SERVER_DIR/ta.key"

chmod 644 "$SERVER_DIR/ca.crt"
chmod 644 "$SERVER_DIR/server.crt"
chmod 600 "$SERVER_DIR/server.key"
chmod 600 "$SERVER_DIR/dh.pem"
chmod 600 "$SERVER_DIR/ta.key"

# ------------------------------------------------------------
# Create OpenVPN server configuration
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Creating OpenVPN server configuration"
echo "============================================================"

cat > "$SERVER_DIR/server.conf" <<EOF
port $OPENVPN_PORT
proto udp
dev tun

topology subnet
server $VPN_NETWORK $VPN_NETMASK

ca $SERVER_DIR/ca.crt
cert $SERVER_DIR/server.crt
key $SERVER_DIR/server.key
dh $SERVER_DIR/dh.pem

tls-crypt $SERVER_DIR/ta.key

keepalive 10 120

persist-key
persist-tun

user nobody
group nogroup

# Allow VPN clients to access the LAN
push "route $LAN_SUBNET"

# Use LAN gateway as DNS
push "dhcp-option DNS $LAN_GATEWAY"

tls-version-min 1.2

data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
data-ciphers-fallback AES-256-GCM

verb 3
EOF

chmod 600 "$SERVER_DIR/server.conf"

# ------------------------------------------------------------
# Enable IPv4 forwarding
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Enabling IPv4 forwarding"
echo "============================================================"

cat > /etc/sysctl.d/99-openvpn.conf <<EOF
net.ipv4.ip_forward = 1
EOF

sysctl --system

# ------------------------------------------------------------
# Configure NAT
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Configuring NAT"
echo "============================================================"

# Remove matching rules if the script is re-run.

iptables -t nat -D POSTROUTING \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j MASQUERADE \
    2>/dev/null || true

iptables -D FORWARD \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j ACCEPT \
    2>/dev/null || true

iptables -D FORWARD \
    -d "$VPN_CIDR" \
    -i "$LAN_INTERFACE" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT \
    2>/dev/null || true

# Add NAT

iptables -t nat -A POSTROUTING \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j MASQUERADE

# Allow VPN -> LAN

iptables -A FORWARD \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j ACCEPT

# Allow return traffic LAN -> VPN

iptables -A FORWARD \
    -d "$VPN_CIDR" \
    -i "$LAN_INTERFACE" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

# Save rules

netfilter-persistent save

# ------------------------------------------------------------
# Create client directory
# ------------------------------------------------------------

mkdir -p "$CLIENT_DIR"

chown "$INSTALL_USER:$INSTALL_USER" "$CLIENT_DIR"
chmod 700 "$CLIENT_DIR"

# ------------------------------------------------------------
# Create self-contained .ovpn
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Creating client configuration"
echo "============================================================"

CLIENT_OVPN="$CLIENT_DIR/${CLIENT_NAME}.ovpn"

{
    echo "client"
    echo "dev tun"
    echo "proto udp"
    echo
    echo "remote ${PUBLIC_ENDPOINT} ${OPENVPN_PORT}"
    echo
    echo "resolv-retry infinite"
    echo "nobind"
    echo
    echo "persist-key"
    echo "persist-tun"
    echo
    echo "remote-cert-tls server"
    echo "auth-nocache"
    echo
    echo "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305"
    echo "data-ciphers-fallback AES-256-GCM"
    echo
    echo "verb 3"
    echo
    echo "<ca>"
    cat "$SERVER_DIR/ca.crt"
    echo "</ca>"
    echo
    echo "<cert>"
    cat "$EASYRSA_DIR/pki/issued/${CLIENT_NAME}.crt"
    echo "</cert>"
    echo
    echo "<key>"
    cat "$EASYRSA_DIR/pki/private/${CLIENT_NAME}.key"
    echo "</key>"
    echo
    echo "<tls-crypt>"
    cat "$SERVER_DIR/ta.key"
    echo "</tls-crypt>"
} > "$CLIENT_OVPN"

# Client config contains private key.
chmod 600 "$CLIENT_OVPN"
chown "$INSTALL_USER:$INSTALL_USER" "$CLIENT_OVPN"

# ------------------------------------------------------------
# Start OpenVPN
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Starting OpenVPN"
echo "============================================================"

systemctl daemon-reload

systemctl enable openvpn-server@server.service

systemctl restart openvpn-server@server.service

sleep 3

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "============================================================"
echo "Verification"
echo "============================================================"

if systemctl is-active --quiet openvpn-server@server.service; then
    echo "OpenVPN service : RUNNING"
else
    echo
    echo "ERROR: OpenVPN failed to start."
    echo
    systemctl status openvpn-server@server.service --no-pager
    exit 1
fi

if ss -lun | grep -q ":${OPENVPN_PORT} "; then
    echo "UDP port        : LISTENING ($OPENVPN_PORT)"
else
    echo "WARNING: UDP port $OPENVPN_PORT was not detected."
fi

if [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]; then
    echo "IPv4 forwarding : ENABLED"
else
    echo "ERROR: IPv4 forwarding is disabled."
fi

if ip addr show tun0 >/dev/null 2>&1; then
    echo "VPN interface   : tun0 UP"
else
    echo "ERROR: tun0 was not created."
fi

# ------------------------------------------------------------
# Final information
# ------------------------------------------------------------

echo
echo "============================================================"
echo "           OPENVPN INSTALLATION COMPLETE"
echo "============================================================"
echo
echo "Server:"
echo
echo "  LAN IP          : $SERVER_LAN_IP"
echo "  LAN interface   : $LAN_INTERFACE"
echo "  LAN gateway     : $LAN_GATEWAY"
echo "  LAN subnet      : $LAN_SUBNET"
echo "  VPN subnet      : $VPN_CIDR"
echo "  UDP port        : $OPENVPN_PORT"
echo "  Public endpoint : $PUBLIC_ENDPOINT"
echo
echo "Client:"
echo
echo "  Name            : $CLIENT_NAME"
echo "  File            : $CLIENT_OVPN"
echo "  Owner           : $INSTALL_USER"
echo
echo "============================================================"
echo "ROUTER PORT FORWARD"
echo "============================================================"
echo
echo "Configure your router:"
echo
echo "  UDP $OPENVPN_PORT"
echo "       -> $SERVER_LAN_IP:$OPENVPN_PORT"
echo
echo "NO ROUTE IS REQUIRED ON THE ROUTER."
echo
echo "The Ubuntu server performs NAT for:"
echo
echo "  $VPN_CIDR -> $LAN_SUBNET"
echo
echo "============================================================"
echo
echo "Useful commands:"
echo
echo "  Check status:"
echo "    sudo systemctl status openvpn-server@server"
echo
echo "  Watch logs:"
echo "    sudo journalctl -u openvpn-server@server -f"
echo
echo "  Check listening port:"
echo "    sudo ss -lunp | grep $OPENVPN_PORT"
echo
echo "  Check NAT:"
echo "    sudo iptables -t nat -L POSTROUTING -n -v"
echo
echo "Client configuration:"
echo
echo "  $CLIENT_OVPN"
echo
echo "IMPORTANT:"
echo "The .ovpn file contains a private key."
echo "Keep it secure."
echo
echo "============================================================"
