# Graphical WireGuard Manager for KDE Plasma

A KDE Plasma 6 panel widget + GUI app for managing WireGuard VPN connections. Built and tested for Fedora with KDE Plasma 6.

<img width="300" height="auto" alt="image" src="https://github.com/user-attachments/assets/b4ccd62b-746d-46f4-ab76-2b744ecedb68" />

<!> Disclosure: not affilitated with the official WireGuard project or it's maintainers! <!>

## Features

- **Panel widget**: Place in your plasma taskbar as pictured above! 
- **Status Indicator**: Shows connection status using a coloured dot (green = connected, red = disconnected)
- **Toggle switch**: Click the widget to open a popup with a one-click on/off switch
- **Profile selector**: if you have multiple `.conf` files, pick the one to connect to
- **WireGuard Config Manager**: full GUI app to import, edit, and manage `/etc/wireguard/*.conf` files without touching the terminal

## Requirements
| Dependency | Install |
|---|---|
| `wireguard-tools` | `sudo dnf install wireguard-tools` |
| `python3` | usually pre-installed |
| `PyQt6` | installed automatically by `install.sh` |
| KDE Plasma 6 | tested on Plasma 6.6.x |

## Installation
Download the installer using wget or curl (wget reccomended if available):
```bash
wget https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/refs/heads/master/install.sh
```
**Use curl instead if wget doesn't work or is not installed on your system:**
```bash
curl -O https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/refs/heads/master/install.sh
```

Make executable using chmod, then run it from your terminal:
```bash
chmod +x ./install.sh
./install.sh
```

The installer will:
- Check for `wireguard-tools`, `python3`, `kpackagetool6`
- Install **PyQt6** via `pip3 install --user PyQt6` ***if missing***
- Register the Plasma applet as `org.kde.wireguardmanager`
- Copy the config app to `~/.local/bin/wireguard-config`
- Install a `.desktop` entry so it appears in app menus

### Add the widget to your panel like any other widget

- Right-click the KDE panel -> **Add Widgets...**
- Search for **WireGuard Manager**
- Drag it into your panel

## Importing a config file

- Click the **WireGuard Manager** icon in the panel
- Click **Open WireGuard Config Manager**
- Click **Import** (bottom-left)
- Navigate to your `.conf` file and select it
- Click **Yes** when prompted to save to `/etc/wireguard/`
- The profile now appears in the list - click **Connect** or use the panel toggle

## Passwordless operation (recommended)

By default, every privileged operation (connecting, disconnecting, reading, saving, or deleting a profile) will show a KDE authentication prompt.
Installing the polkit rule removes all prompts for members of the `wheel` group:

```bash
wget -q https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/master/polkit/50-wireguard-manager.rules -O /tmp/wg-polkit.rules
sudo install -m 644 /tmp/wg-polkit.rules /etc/polkit-1/rules.d/50-wireguard-manager.rules
```

This grants passwordless `pkexec` access to `wheel` group members only.

## Launching the config manager standalone (without the widget)

```bash
wireguard-config
```

## Using the uninstaller

Download the uninstaller script using wget (reccomended) or curl:
```bash
wget https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/refs/heads/master/uninstall.sh
```
```bash
curl -O https://raw.githubusercontent.com/greenharry12/KDE-Wireguard-Manager/refs/heads/master/uninstall.sh
```
Make it executable and then run it:
```bash
chmod +x ./uninstall.sh
./uninstall.sh
```

## Developer Note:
- WireGuard profiles in `/etc/wireguard/` are never removed by the uninstaller.
- Private keys in `.conf` files are secure and private. The files are stored in the default wireguard-tools location with `chmod 600`: `/etc/wireguard/`.
- All privileged operations go through `pkexec`, which uses the KDE polkit authentication agent.
