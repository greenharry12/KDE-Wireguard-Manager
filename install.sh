#!/usr/bin/env bash
# install.sh - WireGuard Manager installer
# Works two ways:
#   1. Run from inside the cloned repo  (uses local files)
#   2. Downloaded and run standalone    (fetches files from GitHub)

set -euo pipefail

PLASMOID_ID="org.kde.wireguardmanager"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_APPS="$HOME/.local/share/applications"
GITHUB_RAW="https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/master"

# Detect whether we are running from inside the repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/plasmoid/metadata.json" ]]; then
    SOURCE_DIR="$SCRIPT_DIR"
    CLEANUP=false
else
    SOURCE_DIR="$(mktemp -d)"
    CLEANUP=true
fi

echo "======================================"
echo "  WireGuard Manager - Installer"
echo "======================================"
echo ""

# ── 1. Dependency checks ───────────────────────────────────────────────────
echo "[1/5] Checking dependencies..."

if ! command -v python3 &>/dev/null; then
    echo "  ERROR: python3 not found."
    exit 1
fi

if ! command -v wg &>/dev/null; then
    echo "  ERROR: wireguard-tools not installed."
    echo "         Run: sudo dnf install wireguard-tools"
    exit 1
fi

if ! command -v pkexec &>/dev/null; then
    echo "  WARNING: pkexec not found - privilege escalation will not work."
fi

if ! command -v kpackagetool6 &>/dev/null; then
    echo "  ERROR: kpackagetool6 not found. Is plasma-workspace installed?"
    exit 1
fi

if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    echo "  ERROR: curl or wget is required."
    exit 1
fi

echo "  Dependencies OK."

# ── 2. Download files if running standalone ────────────────────────────────
if [[ "$CLEANUP" == true ]]; then
    echo ""
    echo "[2/5] Downloading files from GitHub..."

    _fetch() {
        local url="$1" dest="$2"
        mkdir -p "$(dirname "$dest")"
        if command -v wget &>/dev/null; then
            wget -q "$url" -O "$dest"
        else
            curl -fsSL "$url" -o "$dest"
        fi
    }

    _fetch "$GITHUB_RAW/plasmoid/metadata.json" \
        "$SOURCE_DIR/plasmoid/metadata.json"
    _fetch "$GITHUB_RAW/plasmoid/contents/ui/main.qml" \
        "$SOURCE_DIR/plasmoid/contents/ui/main.qml"
    _fetch "$GITHUB_RAW/config-app/wireguard_config.py" \
        "$SOURCE_DIR/config-app/wireguard_config.py"
    _fetch "$GITHUB_RAW/config-app/wireguard-config.desktop" \
        "$SOURCE_DIR/config-app/wireguard-config.desktop"

    echo "  Download complete."
else
    echo ""
    echo "[2/5] Running from repo - using local files."
fi

# ── 3. Install PyQt6 ───────────────────────────────────────────────────────
echo ""
echo "[3/5] Checking PyQt6..."

if ! python3 -c "import PyQt6" 2>/dev/null; then
    echo "  Installing PyQt6 via pip..."
    pip3 install --user --quiet PyQt6
    echo "  PyQt6 installed."
else
    echo "  PyQt6 already installed."
fi

# ── 4. Install the Plasma applet ───────────────────────────────────────────
echo ""
echo "[4/5] Installing Plasma applet..."

kpackagetool6 --type=Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true
kpackagetool6 --type=Plasma/Applet --install "$SOURCE_DIR/plasmoid"
echo "  Applet installed: $PLASMOID_ID"

# ── 5. Install the config app ──────────────────────────────────────────────
echo ""
echo "[5/5] Installing WireGuard Config Manager..."

mkdir -p "$LOCAL_BIN" "$LOCAL_APPS"

install -m 755 "$SOURCE_DIR/config-app/wireguard_config.py" \
    "$LOCAL_BIN/wireguard-config"

install -m 644 "$SOURCE_DIR/config-app/wireguard-config.desktop" \
    "$LOCAL_APPS/wireguard-config.desktop"

echo "  Installed: $LOCAL_BIN/wireguard-config"

# ── Cleanup temp dir if used ───────────────────────────────────────────────
if [[ "$CLEANUP" == true ]]; then
    rm -rf "$SOURCE_DIR"
fi

# ── PATH check ─────────────────────────────────────────────────────────────
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo "  NOTE: $HOME/.local/bin is not in your PATH."
    echo "  Add to ~/.bashrc then run: source ~/.bashrc"
    echo ""
    echo '    export PATH="$HOME/.local/bin:$PATH"'
fi

# ── Done ───────────────────────────────────────────────────────────────────
echo ""
echo "======================================"
echo "  Installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Add widget: right-click panel -> Add Widgets -> 'WireGuard Manager'"
echo "  2. Import config: click widget -> Open WireGuard Config Manager -> Import"
echo ""
echo "Optional - remove auth prompts for wheel group members:"
echo "  wget -q $GITHUB_RAW/polkit/50-wireguard-manager.rules -O /tmp/wg-polkit.rules"
echo "  sudo install -m 644 /tmp/wg-polkit.rules /etc/polkit-1/rules.d/50-wireguard-manager.rules"
echo ""
