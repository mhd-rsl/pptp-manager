# README.md

```markdown
# PPTP Manager

Simple PPTP VPN manager for Linux servers and Proxmox LXC containers.

## Installation

curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/pptp-manager/main/install.sh | sudo bash

## Usage

sudo pptp-manager

or

sudo pptp-manager setup
sudo pptp-manager start officevpn
sudo pptp-manager stop officevpn
sudo pptp-manager restart officevpn
sudo pptp-manager status
sudo pptp-manager logs officevpn

## Proxmox Support

sudo pptp-manager proxmox enable 101
pct reboot 101
```
