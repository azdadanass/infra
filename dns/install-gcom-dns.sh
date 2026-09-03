#!/bin/bash

set -e

# ============================================================
# CONFIGURATION
# ============================================================

DNS_IP="192.168.100.201"

ZONE1="3gcominside.com"
ZONE1_IP="192.168.100.70"

ZONE2="3gcom.test"
ZONE2_IP="192.168.100.60"

VPN_NETWORK="10.8.0.0/24"
LAN_NETWORK="192.168.100.0/24"

# ============================================================
# CHECK
# ============================================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root:"
    echo "sudo $0"
    exit 1
fi

echo "=========================================="
echo " Installing Bind9"
echo "=========================================="

# Check that DNS_IP exists on this machine
if ! ip addr show | grep -q "$DNS_IP"; then
    echo
    echo "ERROR: $DNS_IP is not configured on this server."
    echo
    echo "Available IP addresses:"
    ip -br addr
    echo
    echo "Change DNS_IP at the top of this script."
    exit 1
fi

# Check whether port 53 is already being used
if ss -lntup | grep -q ':53 '; then
    echo
    echo "WARNING: Something is already listening on port 53:"
    ss -lntup | grep ':53 '
    echo
    read -p "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
fi

# ============================================================
# INSTALL BIND9
# ============================================================

apt update
apt install -y bind9 bind9-utils dnsutils

# ============================================================
# BIND OPTIONS
# ============================================================

cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    listen-on {
        127.0.0.1;
        ${DNS_IP};
    };

    listen-on-v6 { none; };

    allow-query {
        localhost;
        ${LAN_NETWORK};
        ${VPN_NETWORK};
    };

    recursion no;

    dnssec-validation no;
};
EOF

# ============================================================
# ZONE DEFINITIONS
# ============================================================

cat > /etc/bind/named.conf.local <<EOF
zone "${ZONE1}" {
    type master;
    file "/etc/bind/db.${ZONE1}";
};

zone "${ZONE2}" {
    type master;
    file "/etc/bind/db.${ZONE2}";
};
EOF

# ============================================================
# ZONE 1
# *.3gcominside.com -> 192.168.100.70
# ============================================================

cat > "/etc/bind/db.${ZONE1}" <<EOF
\$TTL 3600

@       IN      SOA     ns1.${ZONE1}. admin.${ZONE1}. (
                        2026090301
                        3600
                        900
                        604800
                        3600 )

        IN      NS      ns1.${ZONE1}.

ns1     IN      A       ${DNS_IP}

@       IN      A       ${ZONE1_IP}
*       IN      A       ${ZONE1_IP}
EOF

# ============================================================
# ZONE 2
# *.3gcom.test -> 192.168.100.60
# ============================================================

cat > "/etc/bind/db.${ZONE2}" <<EOF
\$TTL 3600

@       IN      SOA     ns1.${ZONE2}. admin.${ZONE2}. (
                        2026090301
                        3600
                        900
                        604800
                        3600 )

        IN      NS      ns1.${ZONE2}.

ns1     IN      A       ${DNS_IP}

@       IN      A       ${ZONE2_IP}
*       IN      A       ${ZONE2_IP}
EOF

# ============================================================
# VALIDATE CONFIGURATION
# ============================================================

echo
echo "Checking Bind9 configuration..."

named-checkconf

named-checkzone "${ZONE1}" "/etc/bind/db.${ZONE1}"
named-checkzone "${ZONE2}" "/etc/bind/db.${ZONE2}"

# ============================================================
# START BIND9
# ============================================================

systemctl enable bind9
systemctl restart bind9

echo
echo "=========================================="
echo " Bind9 installed successfully"
echo "=========================================="
echo
echo "DNS server:"
echo "  ${DNS_IP}"
echo
echo "Zones:"
echo "  *.${ZONE1} -> ${ZONE1_IP}"
echo "  *.${ZONE2} -> ${ZONE2_IP}"
echo
echo "VPN network:"
echo "  ${VPN_NETWORK}"
echo
echo "Testing DNS..."
echo

dig @${DNS_IP} test.${ZONE1} +short
dig @${DNS_IP} test.${ZONE2} +short

echo
echo "=========================================="
echo " DONE, try reboot server"
echo "=========================================="