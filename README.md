# Universal PPTP VPN Manager for Linux & Proxmox VE

A robust, interactive Bash script designed to easily configure, manage, and maintain PPTP VPN connections. This script is fully optimized to run seamlessly across standard **Linux Servers (Debian/RHEL)**, **Desktop Clients**, **Virtual Machines**, and **Proxmox VE Hosts/LXC Containers**.

## 🚀 Key Features

* **Multi-Environment Support**: Works on Debian, Ubuntu, CentOS, RHEL, Proxmox VE hosts, VMs, and LXC containers.
* **Proxmox Host Admin Mode**: Automatically maps and injects required host devices (`/dev/ppp`) into unprivileged LXC containers.
* **Smart Routing**: Choice between **Full-Tunnel** (all internet traffic over VPN) or **Split-Tunnel** (only specific subnets over VPN).
* **Persistent Auto-Reconnect**: Optional Systemd service wrapper to instantly reconnect the VPN tunnel if dropped or after a host reboot.
* **Clean Uninstaller**: Safely tears down interfaces, configuration profiles, credentials, and background services without leaving system clutter.

---

## 💻 Quick Start & Usage

To launch the interactive management wizard, copy and paste the command below into your terminal as **root** (or use `sudo`). 

> **Note**: We use `bash <(curl ...)` to ensure the interactive terminal input stays open during selection.

```bash
bash <(curl -fsSL https://githubusercontent.com)
```

### Alternative: Manual Download
If your firewall blocks process substitution, you can download and run the script locally:
```bash
wget -O vpn-manager.sh https://githubusercontent.com
chmod +x vpn-manager.sh
./vpn-manager.sh
```

---

## 🛠️ Step-by-Step Deployment Modes

When you execute the script, you will be presented with a menu. Choose your path based on your deployment strategy:

### 1. Setup & Connect (Standard Server, VM, Client)
* Use this for standard Linux hardware or virtual machines.
* Provide your custom **Tunnel Name**, **VPN Host Address**, **Username**, and **Password**.
* Choose your routing profile (Full vs Split).
* Choose whether to enable a background watchdog service for **auto-reconnect**.

### 2. Proxmox Host Admin Mode (LXC Configuration)
By default, unprivileged Proxmox LXC containers lack access to the host's PPP kernel network modules. This script simplifies the pass-through process entirely:
1. Run this script directly on your **Proxmox Host**.
2. Select **Option 2**.
3. Input the **Target CT ID** (e.g., `100`).
4. The script automatically injects device permissions and mounts `/dev/ppp` to the container config.
5. **Important**: You must reboot the container (`pct reboot <CT_ID>`) after running this option.
6. Once rebooted, log into the LXC container, run this script again, and select **Option 1** to establish your VPN.

### 3. Uninstall / Remove Tunnel
* Select **Option 3** to completely purge a specific VPN tunnel. 
* This completely deletes the credential profile, drops the systemd service, and terminates active network routing modifications cleanly.

---

## 🔍 Troubleshooting & Verification

### Checking VPN Status
Verify that your interface `ppp0` is successfully up and has received an IP address from your VPN gateway:
```bash
ip addr show dev ppp0
```

### Managing Tunnels Manually
If you did **not** opt for the background systemd daemon service, you can spin the connection up or down manually using native tooling:
```bash
# Start your tunnel
pon <tunnel_name>

# Stop your tunnel
poff <tunnel_name>
```

### Inspecting Log Activity
If the tunnel is stuck or failing to authenticate, check your host syslog parameters using your local logging facility:
```bash
journalctl -u pptp-<tunnel_name>.service -f
# OR
tail -f /var/log/syslog | grep ppp
```

---

## 📄 License
This project is open-source software licensed under the [MIT License](LICENSE). Feel free to clone, modify, and distribute it.
