#!/bin/bash
VPN_CONFIG=$(cat ~/.config/waybar/vpn.conf 2>/dev/null || echo "wg0")

if ip link show "$VPN_CONFIG" &> /dev/null; then
    sudo wg-quick down "$VPN_CONFIG" 2>/dev/null
    notify-send "VPN" "Disconnected from $VPN_CONFIG" -i network-vpn-disconnected
else
    sudo wg-quick up "$VPN_CONFIG" 2>/dev/null
    notify-send "VPN" "Connected to $VPN_CONFIG" -i network-vpn
fi
