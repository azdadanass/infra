#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
# OpenVPN Client File Generator
# Ubuntu 24.04 / OpenVPN 2.6 / Easy-RSA 3.1.x
#
# Generates a self-contained .ovpn client file using the
# certificates and keys already installed on the VPN server.
# ============================================================

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

cidr_to_netmask() {
    local cidr="$1"
    local prefix="${cidr#*/}"

    if (( prefix == 0 )); then
        echo "0.0.0.0"
        return
    fi

    local mask=$(( 0xffffffff << (32 - prefix) ))

    printf "%d.%d.%d.%d\n" \
        $(( (mask >> 24) & 255 )) \
        $(( (mask >> 16) & 255 )) \
        $(( (mask >> 8) & 255 )) \
        $(( mask & 255 ))
}

valid_dns_domain() {
    local domain="$1"

    [[ -n "$domain" ]] || return 1

    [[ "$domain" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]]
}

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

VPN_GATEWAY="10.8.0.1"

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

echo
echo "============================================================"
echo "       OpenVPN Client Configuration Generator"
echo "============================================================"
echo
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
    "41.248.252.127")"

while [[ -z "$PUBLIC_ENDPOINT" ]]; do
    echo "ERROR: Public IP / hostname cannot be empty."
    PUBLIC_ENDPOINT="$(ask_default \
        "Public IP address or DNS hostname" \
        "41.248.252.127")"
done

OPENVPN_PORT="$(ask_default \
    "OpenVPN UDP port" \
    "51820")"

while ! valid_port "$OPENVPN_PORT"; do
    echo "ERROR: Invalid UDP port."
    OPENVPN_PORT="$(ask_default \
        "OpenVPN UDP port" \
        "51820")"
done

LAN_SUBNET="$(ask_default \
    "LAN subnet" \
    "192.168.100.0/24")"

while ! valid_cidr "$LAN_SUBNET"; do
    echo "ERROR: Invalid CIDR subnet."
    LAN_SUBNET="$(ask_default \
        "LAN subnet" \
        "192.168.100.0/24")"
done

LAN_NETMASK="$(cidr_to_netmask "$LAN_SUBNET")"

INTERNAL_DNS="$(ask_default \
    "Internal DNS server" \
    "192.168.100.201")"

while ! valid_ipv4 "$INTERNAL_DNS"; do
    echo "ERROR: Invalid DNS server IPv4 address."
    INTERNAL_DNS="$(ask_default \
        "Internal DNS server" \
        "192.168.100.201")"
done

INTERNAL_DNS_DOMAIN="$(ask_default \
    "Internal DNS domain" \
    "3gcominside.com")"

while ! valid_dns_domain "$INTERNAL_DNS_DOMAIN"; do
    echo "ERROR: Invalid DNS domain."
    echo "Example: 3gcominside.com"
    INTERNAL_DNS_DOMAIN="$(ask_default \
        "Internal DNS domain" \
        "3gcominside.com")"
done

CLIENT_NAME="$(ask_default \
    "VPN client name" \
    "gcom")"

while [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; do
    echo "ERROR: Client name may contain only:"
    echo "       letters, numbers, '-' and '_'."
    CLIENT_NAME="$(ask_default \
        "VPN client name" \
        "gcom")"
done

# ------------------------------------------------------------
# Check required certificate/key files
# ------------------------------------------------------------

CA_FILE="$SERVER_DIR/ca.crt"
CLIENT_CERT="$EASYRSA_DIR/pki/issued/${CLIENT_NAME}.crt"
CLIENT_KEY="$EASYRSA_DIR/pki/private/${CLIENT_NAME}.key"
TLS_CRYPT_KEY="$SERVER_DIR/ta.key"

echo
echo "============================================================"
echo "Checking certificates and keys"
echo "============================================================"
echo

if [[ ! -f "$CA_FILE" ]]; then
    echo "ERROR: CA certificate not found:"
    echo "       $CA_FILE"
    exit 1
fi

if [[ ! -f "$CLIENT_CERT" ]]; then
    echo "ERROR: Client certificate not found:"
    echo "       $CLIENT_CERT"
    echo
    echo "Create the client certificate first with:"
    echo
    echo "  cd $EASYRSA_DIR"
    echo "  ./easyrsa build-client-full $CLIENT_NAME nopass"
    exit 1
fi

if [[ ! -f "$CLIENT_KEY" ]]; then
    echo "ERROR: Client private key not found:"
    echo "       $CLIENT_KEY"
    exit 1
fi

if [[ ! -f "$TLS_CRYPT_KEY" ]]; then
    echo "ERROR: tls-crypt key not found:"
    echo "       $TLS_CRYPT_KEY"
    exit 1
fi

# ------------------------------------------------------------
# Display configuration
# ------------------------------------------------------------

echo "Public endpoint : $PUBLIC_ENDPOINT"
echo "UDP port        : $OPENVPN_PORT"
echo "LAN subnet      : $LAN_SUBNET"
echo "VPN gateway     : $VPN_GATEWAY"
echo "Internal DNS    : $INTERNAL_DNS"
echo "DNS domain      : $INTERNAL_DNS_DOMAIN"
echo "Client name     : $CLIENT_NAME"
echo "Client directory: $CLIENT_DIR"
echo

read -r -p "Generate client configuration? [Y/n]: " CONFIRM
CONFIRM="${CONFIRM:-Y}"

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

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
    echo "route-nopull"
    echo "route ${LAN_SUBNET%/*} $LAN_NETMASK $VPN_GATEWAY"
    echo
    echo "dhcp-option DNS $INTERNAL_DNS"
    echo "dhcp-option DOMAIN $INTERNAL_DNS_DOMAIN"
    echo "dhcp-option DOMAIN-ROUTE ~${INTERNAL_DNS_DOMAIN}"
    echo
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
    cat "$CA_FILE"
    echo "</ca>"
    echo
    echo "<cert>"
    cat "$CLIENT_CERT"
    echo "</cert>"
    echo
    echo "<key>"
    cat "$CLIENT_KEY"
    echo "</key>"
    echo
    echo "<tls-crypt>"
    cat "$TLS_CRYPT_KEY"
    echo "</tls-crypt>"
} > "$CLIENT_OVPN"

# Client config contains private key.
chmod 600 "$CLIENT_OVPN"
chown "$INSTALL_USER:$INSTALL_USER" "$CLIENT_OVPN"

# ------------------------------------------------------------
# Final information
# ------------------------------------------------------------

echo
echo "============================================================"
echo "           CLIENT CONFIGURATION CREATED"
echo "============================================================"
echo
echo "Client:"
echo
echo "  Name : $CLIENT_NAME"
echo "  File : $CLIENT_OVPN"
echo "  Owner: $INSTALL_USER"
echo
echo "============================================================"
echo
echo "IMPORTANT:"
echo "The .ovpn file contains a private key."
echo "Keep it secure."
echo
echo "============================================================"
