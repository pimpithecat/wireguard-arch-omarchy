# Complete Guide: WireGuard VPN Server Setup with WG-Easy v15 on Ubuntu Server and Client Setup on Arch Linux with Waybar Toggle

A comprehensive guide for installing a WireGuard VPN server using WG-Easy v15 on Ubuntu Server, and setting up a client on Arch Linux with toggle on/off functionality in Waybar.

---

## Part 1: Server Setup (Ubuntu VPS)

### 1.1 Install Docker & Docker Compose

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 1.2 Setup Firewall (UFW)

```bash
# Set default policy
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (IMPORTANT! Don't lock yourself out)
sudo ufw allow 22/tcp

# Allow WireGuard VPN port
sudo ufw allow 51820/udp

# Allow Web UI (optional: can be restricted to specific IP)
sudo ufw allow 51821/tcp

# Or restrict to specific IP:
# sudo ufw allow from YOUR_IP to any port 51821 proto tcp

# Enable UFW
sudo ufw enable

# Check status
sudo ufw status verbose

# Add docker user to sudo group
sudo usermod -aG docker $USER
newgrp docker
```

### 1.3 Create Docker Compose File

```bash
# Create directory
mkdir -p ~/wg-easy
cd ~/wg-easy

# Create wireguard.yml file
nano wireguard.yml
```

**wireguard.yml contents:**

```yaml
# WG-Easy v15 Docker Compose - Minimal Configuration
# File: wireguard.yml

volumes:
  etc_wireguard:

services:
  wg-easy:
    environment:
      # Minimal required for v15 fresh install
      - INSECURE=true  # Required for HTTP access
    
    image: ghcr.io/wg-easy/wg-easy:15
    container_name: wg-easy
    
    volumes:
      - etc_wireguard:/etc/wireguard
      - /lib/modules:/lib/modules:ro
    
    ports:
      - "51820:51820/udp"  # WireGuard VPN port
      - "51821:51821/tcp"  # Web UI port
    
    restart: unless-stopped
    
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
      - net.ipv6.conf.all.forwarding=1
      - net.ipv6.conf.default.forwarding=1
```

### 1.4 Deploy WG-Easy

```bash
# Start container
sudo docker compose -f wireguard.yml up -d

# Check container status
sudo docker ps

# Check logs (if there are issues)
sudo docker logs wg-easy

# Check WireGuard interface in container
sudo docker exec wg-easy wg show
```

### 1.5 Access Web UI and Setup Password

1. Open browser: `http://YOUR_SERVER_IP:51821`
2. On first access, you'll be prompted to setup username & password
3. Create a strong username and password
4. Login with the newly created credentials

### 1.6 Create VPN Client

1. Click "Administrator - Admin panel - Config" and set:
   - Persistent Keepalive: `25`
   - MTU: `1420` (default)
   - DNS: `1.1.1.1` (or as needed)

2. Return to main page, click "+ New" to create new client
3. Name the client (e.g., Omarchy or arch-laptop)
4. Expire date (optional)
5. Click Create
6. Download the generated `.conf` file

---

## Part 2: Client Setup (Arch Linux)

### 2.1 Install WireGuard Tools

```bash
# Install WireGuard and dependencies
sudo pacman -S wireguard-tools openresolv

# Verify installation
which wg
which wg-quick
```

### 2.2 Fix resolv.conf (If DNS Issues Occur)

```bash
# Update resolv.conf
sudo resolvconf -u

# Or if still getting errors:
sudo chattr -i /etc/resolv.conf
sudo rm /etc/resolv.conf
sudo ln -sf /run/resolvconf/resolv.conf /etc/resolv.conf
sudo resolvconf -u
```

### 2.3 Setup WireGuard Config

```bash
# Copy downloaded config file to /etc/wireguard
sudo cp ~/Downloads/YourFileName.conf /etc/wireguard/wg0.conf

# Set permissions (IMPORTANT for security)
sudo chmod 600 /etc/wireguard/wg0.conf

# Verify
sudo ls -la /etc/wireguard/
```

### 2.4 Edit Config (Ensure PersistentKeepalive = 25)

```bash
sudo nvim /etc/wireguard/wg0.conf
```

**Config should look like this:**

```ini
[Interface]
PrivateKey = (will be auto-filled)
Address = 10.8.0.2/24, fdcc:ad94:bacf:61a4::cafe:2/112
DNS = 1.1.1.1
MTU = 1420

[Peer]
PublicKey = (will be auto-filled)
PresharedKey = (will be auto-filled)
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25  # IMPORTANT: Change from 0 to 25 if needed
Endpoint = YOUR_SERVER_IP:51820
```

**Important changes:**
- `PersistentKeepalive = 25` (if still 0)
- `DNS = 1.1.1.1` (remove IPv6 DNS if there are issues)

### 2.5 Test Manual Connection

```bash
# Connect
sudo wg-quick up wg0

# Check status (should show "latest handshake")
sudo wg show

# Test IP (should show your VPS server IP)
curl ifconfig.me

# Test ping
ping -c 4 google.com

# Disconnect
sudo wg-quick down wg0
```

### 2.6 Auto-start VPN (Optional)

```bash
# Enable auto-start on boot
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0

# Check status
sudo systemctl status wg-quick@wg0
```

---

## Part 3: VPN Toggle Setup in Waybar

### 3.1 Add Sudoers Rule (For Passwordless Operation)

```bash
sudo visudo
```

Add at the bottom:

```
user ALL=(ALL) NOPASSWD: /usr/bin/wg-quick
```

Replace `user` with your username.

Save: Ctrl+O, Enter, Ctrl+X or Esc, :, wq if using nvim or vim

### 3.2 Create Scripts Directory

```bash
mkdir -p ~/.config/waybar/scripts
cd ~/.config/waybar/scripts
```

### 3.3 Create VPN Config File

```bash
nvim ~/.config/waybar/vpn.conf
```

Contents:

```
wg0
```

Save.

### 3.4 Create VPN Status Script

```bash
nvim ~/.config/waybar/scripts/vpn-status.sh
```

Contents:

```bash
#!/bin/bash
VPN_CONFIG=$(cat ~/.config/waybar/vpn.conf 2>/dev/null || echo "wg0")

if ip link show "$VPN_CONFIG" &> /dev/null; then
    echo '{"text": "󰌾", "class": "active", "tooltip": "VPN: Connected ('$VPN_CONFIG')"}'
else
    echo '{"text": "󰌿", "class": "inactive", "tooltip": "VPN: Disconnected"}'
fi
```

Make executable:

```bash
chmod +x ~/.config/waybar/scripts/vpn-status.sh
```

### 3.5 Create VPN Toggle Script

```bash
nvim ~/.config/waybar/scripts/vpn-toggle.sh
```

Contents:

```bash
#!/bin/bash
VPN_CONFIG=$(cat ~/.config/waybar/vpn.conf 2>/dev/null || echo "wg0")

if ip link show "$VPN_CONFIG" &> /dev/null; then
    sudo wg-quick down "$VPN_CONFIG" 2>/dev/null
    notify-send "VPN" "Disconnected from $VPN_CONFIG" -i network-vpn-disconnected
else
    sudo wg-quick up "$VPN_CONFIG" 2>/dev/null
    notify-send "VPN" "Connected to $VPN_CONFIG" -i network-vpn
fi
```

Make executable:

```bash
chmod +x ~/.config/waybar/scripts/vpn-toggle.sh
```

### 3.6 Install Notification Daemon (Optional)

```bash
sudo pacman -S libnotify
```

### 3.7 Edit Waybar Config

```bash
nvim ~/.config/waybar/config.jsonc
```

Add `custom/vpn` to modules:

```json
{
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["custom/vpn", "pulseaudio", "network", "battery", "tray"]
}
```

Add module definition:

```json
"custom/vpn": {
    "format": "{}",
    "return-type": "json",
    "interval": 5,
    "exec": "~/.config/waybar/scripts/vpn-status.sh",
    "on-click": "~/.config/waybar/scripts/vpn-toggle.sh",
    "tooltip": true
}
```

### 3.8 Edit Waybar Style (Optional - For Colors)

```bash
nvim ~/.config/waybar/style.css
```

Add styling:

```css
#cpu,
#battery,
#pulseaudio,
#custom-vpn, /* add this! */
#custom-omarchy,
#custom-screenrecording-indicator,
#custom-update {
  min-width: 12px;
  margin: 0 7.5px;
}

/* VPN Toggle Styling */
#custom-vpn.active {
    color: #a6e3a1; /* Green when connected */
    padding: 0 10px;
}

#custom-vpn.inactive {
    color: #f38ba8; /* Red when disconnected */
    padding: 0 10px;
}

#custom-vpn {
    font-size: 16px;
}
```

### 3.9 Restart Waybar

```bash
# Kill waybar
killall waybar

# Start waybar
waybar &

# Or if using Hyprland, reload config
# Ctrl+Shift+R (or your bind key)
```

---

## Usage

**Toggle VPN from Waybar:**
- Click icon in Waybar to connect/disconnect
- Icon 󰌾 (green) = VPN Connected
- Icon 󰌿 (red) = VPN Disconnected
- Hover to see tooltip status

**Manual from Terminal:**

```bash
# Connect
sudo wg-quick up wg0

# Disconnect
sudo wg-quick down wg0

# Status
sudo wg show

# Check IP
curl ifconfig.me
```

---

## Troubleshooting

### 1. VPN Won't Connect (0 B received)

**Check on Server:**

```bash
# Check container running
sudo docker ps

# Check logs
sudo docker logs wg-easy

# Check port listening
sudo ss -ulnp | grep 51820
```

**Check on Client:**

```bash
# Ensure PersistentKeepalive = 25
sudo nano /etc/wireguard/wg0.conf

# Restart connection
sudo wg-quick down wg0
sudo wg-quick up wg0

# Wait 10 seconds, then check
sudo wg show
```

### 2. resolv.conf Error

```bash
sudo resolvconf -u
```

Or comment DNS in config:

```bash
sudo nano /etc/wireguard/wg0.conf
# DNS = 1.1.1.1  # Comment this
```

### 3. Sudo Password Still Required

```bash
# Clear sudo cache
sudo -k

# Test again
sudo ls
```

### 4. Waybar Icon Not Showing

```bash
# Reload waybar
killall waybar
waybar &

# Or check script permissions
ls -la ~/.config/waybar/scripts/
chmod +x ~/.config/waybar/scripts/*.sh
```

### 5. Port Conflict

If port 51820 or 51821 is already in use:

**Edit docker-compose:**

```yaml
ports:
  - "51822:51820/udp"  # Change host port
  - "51821:51821/tcp"
```

**Update UFW:**

```bash
sudo ufw allow 51822/udp
```

**Update client config:**

```
Endpoint = YOUR_SERVER_IP:51822
```

---

## Security Tips

**Monitor logs:**

```bash
# Server
sudo docker logs -f wg-easy

# Client
sudo journalctl -u wg-quick@wg0 -f
```

**Backup WireGuard config:**

```bash
# On server
sudo docker exec wg-easy cat /etc/wireguard/wg0.conf > wg0-backup.conf
```

**Use SSH Tunnel for Web UI access:**

```bash
# From laptop
ssh -L 8080:localhost:51821 user@YOUR_SERVER_IP
# Access: http://localhost:8080
```

**Restrict Web UI access:**

```bash
# Only allow from specific IP
sudo ufw delete allow 51821/tcp
sudo ufw allow from YOUR_HOME_IP to any port 51821 proto tcp
```

---

## Conclusion

Now you have:
✅ WireGuard VPN server with WG-Easy v15
✅ VPN client on Arch Linux
✅ Toggle VPN on/off from Waybar
✅ Notifications on connect/disconnect
✅ No password required for VPN toggle

Congratulations! Your VPN is ready to use! 🎉
