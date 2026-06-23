#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root or via sudo."
    exit 1
fi

# ===================================================
# SMART UNINSTALLER MODE (Option 4)
# ===================================================
uninstall_vpn() {
    echo "==================================================="
    echo "Starting Deep-Clean of PPTP VPN Installations..."
    echo "==================================================="

    # Find and stop any managed systemd services dynamically
    SERVICES=$(ls /etc/systemd/system/pptp-*.service 2>/dev/null || true)
    
    if [ -n "$SERVICES" ]; then
        for SVC_PATH in $SERVICES; do
            SVC_NAME=$(basename "$SVC_PATH")
            echo "Stopping and disabling service: $SVC_NAME..."
            systemctl stop "$SVC_NAME" 2>/dev/null || true
            systemctl disable "$SVC_NAME" 2>/dev/null || true
            rm -f "$SVC_PATH"
        done
        systemctl daemon-reload
    fi

    # Kill any runaway active connections
    echo "Terminating any lingering ppp active connections..."
    killall pppd 2>/dev/null || true
    poff -a 2>/dev/null || true

    # Clean configuration profiles completely
    if [ -d /etc/ppp/peers ]; then
        echo "Removing peer files..."
        rm -rf /etc/ppp/peers/*
    fi

    # Scrub credentials securely from chap-secrets
    if [ -f /etc/ppp/chap-secrets ]; then
        echo "Cleaning credentials file..."
        cp /etc/ppp/chap-secrets /etc/ppp/chap-secrets.bak
        echo -n "" > /etc/ppp/chap-secrets
        chmod 600 /etc/ppp/chap-secrets
        rm -f /etc/ppp/chap-secrets.bak
    fi

    echo "Success! All PPTP VPN configurations, credentials, and background services have been completely removed."
    exit 0
}

# ===================================================
# VPN STATUS CHECK ENGINE (Option 3)
# ===================================================
check_vpn_status() {
    echo "==================================================="
    echo "PPTP VPN Diagnostics and Connection Status"
    echo "==================================================="

    # 1. Check for Active Interfaces
    echo -n "1. Network Interfaces: "
    if ip addr show dev ppp0 > /dev/null 2>&1; then
        echo "ACTIVE (ppp0 interface found)"
        ip addr show dev ppp0 | grep -E 'inet ' || true
    else
        echo "INACTIVE (No ppp0 interface detected)"
    fi

    # 2. Check Background Daemons / Systemd
    echo -n "2. Systemd Watchdogs:   "
    ACTIVE_SVCS=$(systemctl list-units --type=service | grep pptp- || true)
    if [ -n "$ACTIVE_SVCS" ]; then
        echo "RUNNING"
        echo "$ACTIVE_SVCS"
    else
        echo "NONE (No active pptp watchdog services found)"
    fi

    # 3. Present External IP Information
    echo -n "3. Public Facing IP:   "
    if command -v curl &> /dev/null; then
        EXT_IP=$(curl -s --max-time 3 ifconfig.me || echo "Timeout or offline")
        echo "$EXT_IP"
    else
        echo "curl tool not found, skipping..."
    fi
    echo "==================================================="
    exit 0
}

# ===================================================
# PROXMOX HOST CONFIGURATOR (Option 2)
# ===================================================
configure_proxmox_host() {
    echo "==================================================="
    echo "Proxmox Host Admin Mode Enabled"
    echo "==================================================="
    
    if command -v pct &> /dev/null; then
        echo "Available LXC Containers on this host:"
        pct list || true
    else
        echo "Error: 'pct' command not found. Are you sure this is a Proxmox Host?"
        exit 1
    fi

    read -p "Enter the CT ID (Container ID) you want to enable PPTP for: " CT_ID
    if [ -z "$CT_ID" ] || ! [[ "$CT_ID" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid Container ID."
        exit 1
    fi

    CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"
    if [ ! -f "$CONF_FILE" ]; then
        echo "Error: Configuration file for Container ID $CT_ID not found."
        exit 1
    fi

    modprobe ppp_generic || true

    echo "Injecting device nodes into container configuration..."
    if ! grep -q "lxc.cgroup2.devices.allow: c 108:0 rwm" "$CONF_FILE"; then
        echo "lxc.cgroup2.devices.allow: c 108:0 rwm" >> "$CONF_FILE"
    fi
    if ! grep -q "lxc.mount.entry: /dev/ppp dev/ppp none bind,optional,create=file" "$CONF_FILE"; then
        echo "lxc.mount.entry: /dev/ppp dev/ppp none bind,optional,create=file" >> "$CONF_FILE"
    fi

    echo "Success! Proxmox host configuration updated for Container $CT_ID."
    echo "Please restart the container ($CT_ID) to apply changes: 'pct reboot $CT_ID'"
    exit 0
}

# --- Main Menu Menu Selection ---
echo "==================================================="
echo "     Universal PPTP VPN Management Script          "
echo "==================================================="
echo "1) Setup & Connect to a PPTP VPN Client"
echo "2) Proxmox Host Admin: Enable PPP pass-through for an LXC"
echo "3) Check Active VPN Status / Connection Diagnostics"
echo "4) Uninstall / Wipe ALL PPTP Settings and Services"
echo "5) Exit"
read -p "Select an option [1-5]: " SCRIPT_MODE

case $SCRIPT_MODE in
    2) configure_proxmox_host ;;
    3) check_vpn_status ;;
    4) uninstall_vpn ;;
    5) echo "Exiting."; exit 0 ;;
    1) echo "Proceeding to client installation..." ;;
    *) echo "Invalid option."; exit 1 ;;
esac

# ===================================================
# CLIENT INSTALLATION & CONNECTION MODE (Option 1)
# ===================================================

# 1. Environment and OS Detection
if [ -f /etc/debian_version ] || [ -f /etc/proxmox-release ]; then
    OS="debian"
    apt-get update -y
    apt-get install -y pptp-linux network-manager-pptp iproute2 psmisc
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
    yum install -y epel-release
    yum install -y pptp network-manager-pptp iproute psmisc
else
    echo "Error: Unsupported OS."
    exit 1
fi

# 2. Check for LXC Container Environment
if [ -f /proc/user_beancounters ] || [ -d /sys/is_container ] || grep -q 'container=lxc' /proc/1/environ; then
    if [ ! -c /dev/ppp ]; then
        echo "Error: /dev/ppp device node is missing in this container."
        echo "Please run this script on your Proxmox Host first and select Option (2) to map it."
        exit 1
    fi
else
    modprobe ppp_mppe || echo "Warning: ppp_mppe module could not be loaded."
fi

# 3. Gather VPN Server Credentials
echo "---------------------------------------------------"
echo "Please enter your PPTP VPN configuration details:"
echo "---------------------------------------------------"

read -p "Tunnel Name (e.g., officevpn): " TUNNEL_NAME
TUNNEL_NAME=${TUNNEL_NAME:-officevpn}

read -p "VPN Server IP/Hostname: " VPN_SERVER
if [ -z "$VPN_SERVER" ]; then echo "Error: Server cannot be empty."; exit 1; fi

read -p "VPN Username: " VPN_USER
if [ -z "$VPN_USER" ]; then echo "Error: Username cannot be empty."; exit 1; fi

read -s -p "VPN Password: " VPN_PASS
echo ""
if [ -z "$VPN_PASS" ]; then echo "Error: Password cannot be empty."; exit 1; fi

# 4. Create Configuration Profiles
echo "Generating configurations..."
mkdir -p /etc/ppp/peers

cat <<EOF > "/etc/ppp/peers/$TUNNEL_NAME"
pty "pptp $VPN_SERVER --nolaunchpptp"
name "$VPN_USER"
remotename $TUNNEL_NAME
require-mppe-128
require-mschap-v2
refuse-eap
refuse-pap
refuse-chap
refuse-mschap
file /etc/ppp/options.pptp
ipparam $TUNNEL_NAME
persist
maxfail 0
EOF

# Safely manage credentials inside chap-secrets
sed -i "/$VPN_USER $TUNNEL_NAME/d" /etc/ppp/chap-secrets
echo "$VPN_USER $TUNNEL_NAME \"$VPN_PASS\" *" >> /etc/ppp/chap-secrets
chmod 600 /etc/ppp/chap-secrets

# 5. Optional Persistent Auto-Reconnect Service Definition
read -p "Do you want to create a Systemd Service for Auto-Reconnect on boot? (y/n): " AUTO_START
if [[ "$AUTO_START" =~ ^[Yy]$ ]]; then
    echo "Creating systemd daemon..."
    
    cat <<EOF > "/etc/systemd/system/pptp-$TUNNEL_NAME.service"
[Unit]
Description=PPTP VPN Keep-Alive Tunnel ($TUNNEL_NAME)
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/pon $TUNNEL_NAME
ExecStop=/usr/sbin/poff $TUNNEL_NAME
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "pptp-$TUNNEL_NAME.service"
    systemctl start "pptp-$TUNNEL_NAME.service"
    echo "Systemd service deployment complete."
else
    echo "Starting direct terminal connection..."
    pon "$TUNNEL_NAME"
fi

# 6. Post Execution Verification Check
sleep 4
if ip addr show dev ppp0 > /dev/null 2>&1; then
    echo "==================================================="
    echo "Success! Active connection confirmed via interface ppp0."
    echo "==================================================="
else
    echo "==================================================="
    echo "Initialization sequence finished. System networking stack will initialize routing dynamically."
    echo "==================================================="
fi
