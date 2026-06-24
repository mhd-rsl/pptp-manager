# uninstall.sh

```bash
#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

rm -rf /opt/pptp-manager
rm -f /usr/local/bin/pptp-manager

rm -rf /etc/ppp/peers/*
rm -f /etc/systemd/system/pptp-*.service

killall pppd 2>/dev/null || true
poff -a 2>/dev/null || true

systemctl daemon-reload

echo "PPTP Manager removed successfully."
```
