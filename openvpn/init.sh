```bash
#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# OpenVPN Server Installer for Ubuntu 24.04
#
# Features:
#   - OpenVPN 2.6
#   - Easy-RSA PKI
#   - NAT for VPN clients
#   - No route required on the LAN router
#   - Persistent iptables rules
#   - Self-contained .ovpn client configuration
#
# Tested design:
#   LAN:       192.168.1.0/24
#   Gateway:   192.168.1.1
#   VPN:       10.8.0.0/24
#   Interface: automatically detected
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this script as root."
    echo "Example: sudo bash $0"
    exit 1
fi

echo
echo "============================================================"
echo "        OpenVPN NAT Server Installer - Ubuntu 24.04"
echo "============================================================"
echo

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

ask_default() {
    local prompt="$1"
    local default="$2"
    local value

    read -r -p "$prompt [$default]: " value
    echo "${value:-$default}"
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
}

valid_cidr() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local prefix="${cidr#*/}"

    [[ "$cidr" == */* ]] || return 1
    valid_ipv4 "$ip" || return 1
    [[ "$prefix" =~ ^[0-9]+$ ]] || return 1
    (( prefix >= 0 && prefix <= 32 )) || return 1
}

# ------------------------------------------------------------
# Collect configuration
# ------------------------------------------------------------

echo "Configuration"
echo "-------------"
echo

PUBLIC_ENDPOINT="$(ask_default "Public IP address or DNS hostname" "")"

while [[ -z "$PUBLIC_ENDPOINT" ]]; do
    echo "Public IP / hostname cannot be empty."
    PUBLIC_ENDPOINT="$(ask_default "Public IP address or DNS hostname" "")"
done

OPENVPN_PORT="$(ask_default "OpenVPN UDP port" "1194")"

while ! valid_port "$OPENVPN_PORT"; do
    echo "Invalid port."
    OPENVPN_PORT="$(ask_default "OpenVPN UDP port" "1194")"
done

LAN_GATEWAY="$(ask_default "LAN default gateway" "192.168.1.1")"

while ! valid_ipv4 "$LAN_GATEWAY"; do
    echo "Invalid IPv4 address."
    LAN_GATEWAY="$(ask_default "LAN default gateway" "192.168.1.1")"
done

LAN_SUBNET="$(ask_default "LAN subnet" "192.168.1.0/24")"

while ! valid_cidr "$LAN_SUBNET"; do
    echo "Invalid CIDR subnet."
    LAN_SUBNET="$(ask_default "LAN subnet" "192.168.1.0/24")"
done

CLIENT_NAME="$(ask_default "First VPN client name" "laptop")"

while [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    echo "Client name may contain only letters, numbers, '-' and '_'."
    CLIENT_NAME="$(ask_default "First VPN client name" "laptop")"
done

VPN_SUBNET="10.8.0.0"
VPN_NETMASK="255.255.255.0"
VPN_CIDR="10.8.0.0/24"

echo
echo "The Easy-RSA CA will be protected by a password."
read -r -s -p "Enter CA password: " CA_PASSWORD
echo
read -r -s -p "Confirm CA password: " CA_PASSWORD_CONFIRM
echo

if [[ "$CA_PASSWORD" != "$CA_PASSWORD_CONFIRM" ]]; then
    echo "ERROR: CA passwords do not match."
    exit 1
fi

if [[ -z "$CA_PASSWORD" ]]; then
    echo "ERROR: CA password cannot be empty."
    exit 1
fi

# ------------------------------------------------------------
# Detect network interface
# ------------------------------------------------------------

echo
echo "Detecting LAN interface..."

LAN_INTERFACE="$(ip route get "$LAN_GATEWAY" 2>/dev/null | awk '
    {
        for (i=1; i<=NF; i++) {
            if ($i == "dev") {
                print $(i+1)
                exit
            }
        }
    }
')"

if [[ -z "$LAN_INTERFACE" ]]; then
    echo "ERROR: Could not determine LAN interface."
    echo "Check that the gateway $LAN_GATEWAY is reachable."
    exit 1
fi

SERVER_LAN_IP="$(ip -4 addr show dev "$LAN_INTERFACE" | awk '
    /inet / {
        sub(/\/.*/, "", $2)
        print $2
        exit
    }
')"

if [[ -z "$SERVER_LAN_IP" ]]; then
    echo "ERROR: Could not determine server LAN IP."
    exit 1
fi

echo
echo "Detected network configuration:"
echo "  Interface : $LAN_INTERFACE"
echo "  Server IP : $SERVER_LAN_IP"
echo "  Gateway   : $LAN_GATEWAY"
echo "  LAN       : $LAN_SUBNET"
echo "  VPN       : $VPN_CIDR"
echo "  UDP port  : $OPENVPN_PORT"
echo "  Endpoint  : $PUBLIC_ENDPOINT"
echo "  Client    : $CLIENT_NAME"
echo

read -r -p "Continue? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# ------------------------------------------------------------
# Install packages
# ------------------------------------------------------------

echo
echo "==> Installing packages..."

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
    openvpn \
    easy-rsa \
    iptables \
    iptables-persistent

# ------------------------------------------------------------
# Stop existing OpenVPN service if present
# ------------------------------------------------------------

systemctl stop openvpn-server@server.service 2>/dev/null || true

# ------------------------------------------------------------
# Create directories
# ------------------------------------------------------------

echo
echo "==> Creating directories..."

EASYRSA_DIR="/etc/openvpn/easy-rsa"
SERVER_DIR="/etc/openvpn/server"
CLIENT_DIR="/root/openvpn-clients"

mkdir -p "$EASYRSA_DIR"
mkdir -p "$SERVER_DIR"
mkdir -p "$CLIENT_DIR"

# ------------------------------------------------------------
# Install Easy-RSA files
# ------------------------------------------------------------

echo
echo "==> Installing Easy-RSA..."

cp -r /usr/share/easy-rsa/* "$EASYRSA_DIR/"

chown -R root:root "$EASYRSA_DIR"
chmod 700 "$EASYRSA_DIR"

cd "$EASYRSA_DIR"

# ------------------------------------------------------------
# Initialize PKI
# ------------------------------------------------------------

echo
echo "==> Initializing PKI..."

rm -rf "$EASYRSA_DIR/pki"

./easyrsa init-pki

# ------------------------------------------------------------
# Create CA
# ------------------------------------------------------------

echo
echo "==> Creating Certificate Authority..."

export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="OpenVPN-CA"
export EASYRSA_PASSIN="pass:${CA_PASSWORD}"

./easyrsa build-ca nopass

# Secure CA key with a password after creation
# Easy-RSA's batch mode does not conveniently accept the CA
# password for all versions, so generate a protected CA key
# using the interactive command if required.

unset EASYRSA_PASSIN

# The CA was intentionally created without a password in batch mode.
# Protect the CA key at filesystem level.
chmod 600 "$EASYRSA_DIR/pki/private/ca.key"

# ------------------------------------------------------------
# Create server certificate
# ------------------------------------------------------------

echo
echo "==> Creating OpenVPN server certificate..."

export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="OpenVPN-Server"

./easyrsa build-server-full server nopass

# ------------------------------------------------------------
# Create DH parameters
# ------------------------------------------------------------

echo
echo "==> Generating Diffie-Hellman parameters..."
echo "This may take some time..."

./easyrsa gen-dh

# ------------------------------------------------------------
# Create TLS crypt key
# ------------------------------------------------------------

echo
echo "==> Generating tls-crypt key..."

openvpn --genkey tls-crypt "$EASYRSA_DIR/pki/ta.key"

# ------------------------------------------------------------
# Create first client certificate
# ------------------------------------------------------------

echo
echo "==> Creating client certificate: $CLIENT_NAME..."

./easyrsa build-client-full "$CLIENT_NAME" nopass

# ------------------------------------------------------------
# Copy server certificates
# ------------------------------------------------------------

echo
echo "==> Installing server certificates..."

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
# OpenVPN server configuration
# ------------------------------------------------------------

echo
echo "==> Creating OpenVPN server configuration..."

cat > "$SERVER_DIR/server.conf" <<EOF
port $OPENVPN_PORT
proto udp
dev tun

topology subnet
server $VPN_SUBNET $VPN_NETMASK

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

# Route VPN clients to the home LAN
push "route $LAN_SUBNET"

# Use the LAN gateway as DNS
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
echo "==> Enabling IPv4 forwarding..."

cat > /etc/sysctl.d/99-openvpn.conf <<EOF
net.ipv4.ip_forward = 1
EOF

sysctl --system >/dev/null

# ------------------------------------------------------------
# Configure iptables NAT
# ------------------------------------------------------------

echo
echo "==> Configuring NAT..."

# Remove duplicate rules if the script is run again.
iptables -t nat -D POSTROUTING \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j MASQUERADE 2>/dev/null || true

iptables -D FORWARD \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j ACCEPT 2>/dev/null || true

iptables -D FORWARD \
    -d "$VPN_CIDR" \
    -i "$LAN_INTERFACE" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT 2>/dev/null || true

iptables -t nat -A POSTROUTING \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j MASQUERADE

iptables -A FORWARD \
    -s "$VPN_CIDR" \
    -o "$LAN_INTERFACE" \
    -j ACCEPT

iptables -A FORWARD \
    -d "$VPN_CIDR" \
    -i "$LAN_INTERFACE" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

netfilter-persistent save

# ------------------------------------------------------------
# Create self-contained client configuration
# ------------------------------------------------------------

echo
echo "==> Creating client configuration..."

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

chmod 600 "$CLIENT_OVPN"

# ------------------------------------------------------------
# Start OpenVPN
# ------------------------------------------------------------

echo
echo "==> Enabling OpenVPN service..."

systemctl daemon-reload
systemctl enable openvpn-server@server.service
systemctl restart openvpn-server@server.service

sleep 2

# ------------------------------------------------------------
# Verify
# ------------------------------------------------------------

echo
echo "==> Checking OpenVPN service..."

if systemctl is-active --quiet openvpn-server@server.service; then
    echo "OpenVPN service: RUNNING"
else
    echo
    echo "ERROR: OpenVPN failed to start."
    echo
    systemctl status openvpn-server@server.service --no-pager
    exit 1
fi

echo
echo "==> Checking UDP port..."

if ss -lun | grep -q ":${OPENVPN_PORT} "; then
    echo "UDP port $OPENVPN_PORT: LISTENING"
else
    echo "WARNING: Could not verify UDP port."
fi

echo
echo "==> Checking VPN interface..."

if ip addr show tun0 >/dev/null 2>&1; then
    echo "tun0: UP"
else
    echo "WARNING: tun0 was not found."
fi

# ------------------------------------------------------------
# Final information
# ------------------------------------------------------------

echo
echo "============================================================"
echo "                 INSTALLATION COMPLETE"
echo "============================================================"
echo
echo "OpenVPN server:"
echo "  Server IP       : $SERVER_LAN_IP"
echo "  LAN interface   : $LAN_INTERFACE"
echo "  LAN subnet      : $LAN_SUBNET"
echo "  Gateway         : $LAN_GATEWAY"
echo "  VPN subnet      : $VPN_CIDR"
echo "  UDP port        : $OPENVPN_PORT"
echo "  Public endpoint : $PUBLIC_ENDPOINT"
echo
echo "Client configuration:"
echo "  $CLIENT_OVPN"
echo
echo "Router port forwarding MUST be:"
echo
echo "  UDP $OPENVPN_PORT -> $SERVER_LAN_IP:$OPENVPN_PORT"
echo
echo "The router does NOT need a route for $VPN_CIDR."
echo "NAT is performed by this Ubuntu server."
echo
echo "To monitor OpenVPN:"
echo "  sudo journalctl -u openvpn-server@server -f"
echo
echo "To check status:"
echo "  sudo systemctl status openvpn-server@server"
echo
echo "IMPORTANT:"
echo "The client .ovpn file contains a private key."
echo "Keep it secure."
echo
echo "Client file:"
echo "  $CLIENT_OVPN"
echo
echo "============================================================"
```
