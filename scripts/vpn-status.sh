#!/bin/bash
VPN_CONFIG=$(cat ~/.config/waybar/vpn.conf 2>/dev/null || echo "wg0")

if ip link show "$VPN_CONFIG" &> /dev/null; then
    echo '{"text": "󰦝", "class": "active", "tooltip": "VPN: Connected ('$VPN_CONFIG')"}'
else
    echo '{"text": "󰦞", "class": "inactive", "tooltip": "VPN: Disconnected"}'
fi
