#!/bin/bash
set -e
rm -rf /opt/pptp-manager
rm -f /usr/local/bin/pptp-manager
rm -f /etc/systemd/system/pptp-*.service
killall pppd 2>/dev/null || true
poff -a 2>/dev/null || true
systemctl daemon-reload
echo "PPTP Manager removed."
