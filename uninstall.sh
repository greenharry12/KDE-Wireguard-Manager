#!/usr/bin/env bash
# uninstall.sh — WireGuard Manager uninstaller

set -euo pipefail

PLASMOID_ID="org.kde.wireguardmanager"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_APPS="$HOME/.local/share/applications"

echo "Removing WireGuard Manager..."

kpackagetool6 --type=Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null \
    && echo "  Plasmoid removed." \
    || echo "  Plasmoid was not installed (skipping)."

rm -f "$LOCAL_BIN/wireguard-config"
rm -f "$LOCAL_APPS/wireguard-config.desktop"

echo "  Config app removed."
echo ""
echo "Done. WireGuard profiles in /etc/wireguard/ were NOT touched."
