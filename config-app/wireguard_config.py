#!/usr/bin/env python3
"""
WireGuard Config Manager
A PyQt6 GUI for importing, editing, and managing WireGuard VPN profiles.
Requires: python3-pyqt6 (install via: pip3 install --user PyQt6)
"""

import sys
import os
import subprocess
import tempfile
from pathlib import Path

from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QTextEdit, QListWidget, QListWidgetItem, QFileDialog,
    QMessageBox, QLabel, QStatusBar, QSplitter, QDialog, QLineEdit,
    QFormLayout, QFrame, QToolBar,
)
from PyQt6.QtCore import Qt, QSize
from PyQt6.QtGui import QFont, QIcon, QAction

WG_DIR = "/etc/wireguard"


# ─────────────────────────────────────────────────────────────────────────────
class WireGuardManager(QMainWindow):
    def __init__(self):
        super().__init__()
        self.current_profile: str | None = None
        self.setWindowTitle("WireGuard Config Manager")
        self.setMinimumSize(860, 540)
        self.resize(960, 620)
        self._build_ui()
        self._refresh_profiles()

    # ── UI construction ───────────────────────────────────────────────────────
    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root_layout = QHBoxLayout(central)
        root_layout.setSpacing(0)
        root_layout.setContentsMargins(0, 0, 0, 0)

        splitter = QSplitter(Qt.Orientation.Horizontal)

        # ── Left panel: profile list ──────────────────────────────────────────
        left = QWidget()
        left.setMinimumWidth(170)
        left.setMaximumWidth(230)
        left_layout = QVBoxLayout(left)
        left_layout.setContentsMargins(8, 10, 8, 8)
        left_layout.setSpacing(6)

        lbl = QLabel("VPN Profiles")
        lbl.setStyleSheet("font-weight: bold; font-size: 13px;")
        left_layout.addWidget(lbl)

        self.profile_list = QListWidget()
        self.profile_list.setAlternatingRowColors(True)
        self.profile_list.currentItemChanged.connect(self._on_profile_selected)
        left_layout.addWidget(self.profile_list)

        btn_row = QHBoxLayout()
        btn_row.setSpacing(4)

        self.btn_import = QPushButton("Import")
        self.btn_import.setToolTip("Import a WireGuard .conf file")
        self.btn_import.clicked.connect(self._import_config)

        self.btn_new = QPushButton("New")
        self.btn_new.setToolTip("Create a new blank profile")
        self.btn_new.clicked.connect(self._new_config)

        self.btn_delete = QPushButton("Delete")
        self.btn_delete.setToolTip("Delete the selected profile from /etc/wireguard/")
        self.btn_delete.clicked.connect(self._delete_config)

        btn_row.addWidget(self.btn_import)
        btn_row.addWidget(self.btn_new)
        btn_row.addWidget(self.btn_delete)
        left_layout.addLayout(btn_row)

        splitter.addWidget(left)

        # ── Right panel: editor + actions ─────────────────────────────────────
        right = QWidget()
        right_layout = QVBoxLayout(right)
        right_layout.setContentsMargins(8, 10, 8, 8)
        right_layout.setSpacing(6)

        editor_lbl = QLabel("Configuration Editor")
        editor_lbl.setStyleSheet("font-weight: bold; font-size: 13px;")
        right_layout.addWidget(editor_lbl)

        self.editor = QTextEdit()
        self.editor.setFont(QFont("Monospace", 10))
        self.editor.setPlaceholderText(
            "Select a profile from the left panel to edit it,\n"
            "or use Import / New to create one."
        )
        right_layout.addWidget(self.editor)

        action_row = QHBoxLayout()
        action_row.setSpacing(8)

        self.btn_save = QPushButton("💾  Save to /etc/wireguard/")
        self.btn_save.setToolTip("Write the current config to /etc/wireguard/<name>.conf (requires auth)")
        self.btn_save.clicked.connect(self._save_config)

        self.btn_connect = QPushButton("▶  Connect")
        self.btn_connect.setToolTip("Run wg-quick up <profile> (requires auth)")
        self.btn_connect.setStyleSheet(
            "QPushButton { background-color: #2e7d32; color: white; padding: 4px 12px; }"
            "QPushButton:hover { background-color: #388e3c; }"
            "QPushButton:pressed { background-color: #1b5e20; }"
        )
        self.btn_connect.clicked.connect(self._connect)

        self.btn_disconnect = QPushButton("■  Disconnect")
        self.btn_disconnect.setToolTip("Run wg-quick down <profile> (requires auth)")
        self.btn_disconnect.setStyleSheet(
            "QPushButton { background-color: #c62828; color: white; padding: 4px 12px; }"
            "QPushButton:hover { background-color: #d32f2f; }"
            "QPushButton:pressed { background-color: #b71c1c; }"
        )
        self.btn_disconnect.clicked.connect(self._disconnect)

        action_row.addWidget(self.btn_save)
        action_row.addStretch()
        action_row.addWidget(self.btn_connect)
        action_row.addWidget(self.btn_disconnect)
        right_layout.addLayout(action_row)

        splitter.addWidget(right)
        splitter.setSizes([200, 760])
        root_layout.addWidget(splitter)

        self.status_bar = QStatusBar()
        self.setStatusBar(self.status_bar)
        self.status_bar.showMessage("Ready")

    # ── Profile list ────────────────────────────────────────────────
    def _refresh_profiles(self):
        self.profile_list.clear()
        names: list[str] = []

        # Primary: read from user-writable cache (avoids /etc/wireguard/ perm issues)
        if self._CACHE_FILE.exists():
            names = sorted(n.strip() for n in self._CACHE_FILE.read_text().splitlines() if n.strip())

        # Fallback: direct glob (works if user has read access, e.g. after chmod)
        if not names:
            wg_path = Path(WG_DIR)
            try:
                names = sorted(c.stem for c in wg_path.glob("*.conf"))
            except PermissionError:
                pass

        for name in names:
            item = QListWidgetItem(name)
            item.setData(Qt.ItemDataRole.UserRole, f"{WG_DIR}/{name}.conf")
            self.profile_list.addItem(item)

        count = self.profile_list.count()
        self.status_bar.showMessage(
            f"Found {count} profile(s)"
            if count else "No profiles found — use Import or New"
        )

    def _on_profile_selected(self, current: QListWidgetItem, _):
        if current is None:
            return
        self.current_profile = current.text()
        path = current.data(Qt.ItemDataRole.UserRole)
        content = self._read_file(path)
        if content is not None:
            self.editor.setPlainText(content)
            self.status_bar.showMessage(f"Editing: {path}")

    # ── Profile cache ───────────────────────────────────────────────
    _CACHE_DIR  = Path.home() / ".local" / "share" / "wireguard-manager"
    _CACHE_FILE = _CACHE_DIR / "profiles"

    def _update_cache(self, name: str, remove: bool = False):
        """Keep ~/.local/share/wireguard-manager/profiles in sync with /etc/wireguard/."""
        self._CACHE_DIR.mkdir(parents=True, exist_ok=True)
        names: set[str] = set()
        if self._CACHE_FILE.exists():
            names = {n.strip() for n in self._CACHE_FILE.read_text().splitlines() if n.strip()}
        if remove:
            names.discard(name)
        else:
            names.add(name)
        self._CACHE_FILE.write_text('\n'.join(sorted(names)) + ('\n' if names else ''))

    # ── File helpers ────────────────────────────────────────────────
    def _read_file(self, path: str) -> str | None:
        """Read a file, escalating via pkexec if needed."""
        try:
            with open(path, "r") as fh:
                return fh.read()
        except PermissionError:
            result = subprocess.run(
                ["pkexec", "bash", "-c", f'cat "{path}"'],
                capture_output=True, text=True, timeout=30,
            )
            if result.returncode == 0:
                return result.stdout
            QMessageBox.warning(self, "Permission Denied", f"Cannot read {path}")
            return None
        except Exception as exc:
            QMessageBox.critical(self, "Read Error", str(exc))
            return None

    def _write_to_etc(self, name: str, content: str) -> bool:
        """Write config to /etc/wireguard/<name>.conf using pkexec."""
        dest = f"{WG_DIR}/{name}.conf"
        with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False) as tmp:
            tmp.write(content)
            tmp_path = tmp.name
        try:
            result = subprocess.run(
                ["pkexec", "bash", "-c",
                 f'cp "{tmp_path}" "{dest}" && chmod 600 "{dest}"'],
                capture_output=True, text=True, timeout=60,
            )
            if result.returncode == 0:
                self.status_bar.showMessage(f"Saved: {dest}")
                self._update_cache(name)
                self._refresh_profiles()
                # Re-select the just-saved profile
                for i in range(self.profile_list.count()):
                    if self.profile_list.item(i).text() == name:
                        self.profile_list.setCurrentRow(i)
                        break
                return True
            else:
                QMessageBox.critical(
                    self, "Save Failed",
                    result.stderr or result.stdout or "Unknown error",
                )
                return False
        finally:
            os.unlink(tmp_path)

    # ── Actions ───────────────────────────────────────────────────────────────
    def _import_config(self):
        path, _ = QFileDialog.getOpenFileName(
            self, "Import WireGuard Config",
            str(Path.home()),
            "WireGuard Config (*.conf);;All Files (*)",
        )
        if not path:
            return
        content = self._read_file(path)
        if content is None:
            return
        name = Path(path).stem
        self.editor.setPlainText(content)
        self.current_profile = name

        reply = QMessageBox.question(
            self, "Import Configuration",
            f"Save as /etc/wireguard/{name}.conf?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply == QMessageBox.StandardButton.Yes:
            self._write_to_etc(name, content)

    def _new_config(self):
        dlg = QDialog(self)
        dlg.setWindowTitle("New Profile")
        layout = QFormLayout(dlg)
        name_edit = QLineEdit()
        name_edit.setPlaceholderText("e.g. home-vpn")
        layout.addRow("Profile name:", name_edit)
        btns = QHBoxLayout()
        ok_btn = QPushButton("Create")
        cancel_btn = QPushButton("Cancel")
        ok_btn.clicked.connect(dlg.accept)
        cancel_btn.clicked.connect(dlg.reject)
        btns.addWidget(ok_btn)
        btns.addWidget(cancel_btn)
        layout.addRow(btns)

        if dlg.exec() != QDialog.DialogCode.Accepted:
            return
        name = name_edit.text().strip()
        if not name:
            return

        template = (
            "[Interface]\n"
            "PrivateKey = \n"
            "Address = 10.0.0.2/24\n"
            "DNS = 1.1.1.1\n"
            "\n"
            "[Peer]\n"
            "PublicKey = \n"
            "AllowedIPs = 0.0.0.0/0\n"
            "Endpoint = server:51820\n"
            "PersistentKeepalive = 25\n"
        )
        self.editor.setPlainText(template)
        self.current_profile = name
        self.status_bar.showMessage(f"New profile '{name}' (unsaved — click Save to write to disk)")

    def _save_config(self):
        if not self.current_profile:
            QMessageBox.warning(self, "No Profile", "Select or create a profile first.")
            return
        self._write_to_etc(self.current_profile, self.editor.toPlainText())

    def _connect(self):
        if not self.current_profile:
            QMessageBox.warning(self, "No Profile", "Select a profile first.")
            return
        result = subprocess.run(
            ["pkexec", "wg-quick", "up", self.current_profile],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            self.status_bar.showMessage(f"Connected to {self.current_profile}")
            QMessageBox.information(self, "Connected",
                                    f"Successfully connected to {self.current_profile}.")
        else:
            QMessageBox.critical(self, "Connect Failed",
                                 result.stderr or result.stdout or "Unknown error")

    def _disconnect(self):
        if not self.current_profile:
            QMessageBox.warning(self, "No Profile", "Select a profile first.")
            return
        result = subprocess.run(
            ["pkexec", "wg-quick", "down", self.current_profile],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            self.status_bar.showMessage(f"Disconnected from {self.current_profile}")
            QMessageBox.information(self, "Disconnected",
                                    f"Disconnected from {self.current_profile}.")
        else:
            QMessageBox.critical(self, "Disconnect Failed",
                                 result.stderr or result.stdout or "Unknown error")

    def _delete_config(self):
        if not self.current_profile:
            return
        reply = QMessageBox.question(
            self, "Delete Profile",
            f"Permanently delete profile '{self.current_profile}'?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        dest = f"{WG_DIR}/{self.current_profile}.conf"
        result = subprocess.run(
            ["pkexec", "rm", dest],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0:
            self._update_cache(dest.split('/')[-1].replace('.conf', ''), remove=True)
            self.editor.clear()
            self.current_profile = None
            self._refresh_profiles()
            self.status_bar.showMessage("Profile deleted")
        else:
            QMessageBox.critical(self, "Delete Failed",
                                 result.stderr or result.stdout or "Unknown error")


# ─────────────────────────────────────────────────────────────────────────────
def main():
    app = QApplication(sys.argv)
    app.setApplicationName("WireGuard Config Manager")
    app.setApplicationDisplayName("WireGuard Config Manager")
    app.setStyle("Fusion")

    win = WireGuardManager()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
