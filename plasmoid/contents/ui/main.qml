import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── Runtime state ──────────────────────────────────────────────────────
    property bool   vpnConnected:        false
    property string activeInterface:     ""
    property var    availableInterfaces: []
    property string selectedInterface:   ""

    // ── Plasmoid tooltip (shown on hover in compact mode) ──────────────────
    toolTipMainText: "WireGuard Manager"
    toolTipSubText: vpnConnected
        ? "Connected: " + activeInterface
        : availableInterfaces.length > 0
            ? "Disconnected (" + availableInterfaces.length + " profile(s) available)"
            : "No profiles found – open Config Manager to import one"

    preferredRepresentation: compactRepresentation

    // ── Status polling ─────────────────────────────────────────────────────
    Timer {
        interval: 3000
        running: true
        repeat:  true
        onTriggered: checkStatus()
    }

    Component.onCompleted: checkStatus()

    // Keep selectedInterface in sync when profile list changes
    onAvailableInterfacesChanged: {
        if (selectedInterface === "" && availableInterfaces.length > 0) {
            selectedInterface = availableInterfaces[0]
        } else if (availableInterfaces.length === 0) {
            selectedInterface = ""
        }
    }

    // ── Actions ────────────────────────────────────────────────────────────
    function checkStatus() {
        statusExec.exec("wg show interfaces 2>/dev/null")
        listExec.exec("bash -c \"cat $HOME/.local/share/wireguard-manager/profiles 2>/dev/null | xargs echo\"")
    }

    // Auto-save any detected active interface to the cache so the profile
    // persists in the list after the VPN is disconnected.
    onActiveInterfaceChanged: {
        if (activeInterface !== "") {
            cacheExec.exec("bash -c \"mkdir -p $HOME/.local/share/wireguard-manager && grep -qxF '" + activeInterface + "' $HOME/.local/share/wireguard-manager/profiles 2>/dev/null || echo '" + activeInterface + "' >> $HOME/.local/share/wireguard-manager/profiles\"")
            if (availableInterfaces.indexOf(activeInterface) < 0) {
                availableInterfaces = availableInterfaces.concat([activeInterface])
                selectedInterface = activeInterface
            }
        }
    }

    function toggleVPN() {
        if (vpnConnected && activeInterface !== "") {
            toggleExec.exec("pkexec wg-quick down " + activeInterface)
        } else if (!vpnConnected) {
            var iface = selectedInterface !== ""
                ? selectedInterface
                : (availableInterfaces.length > 0 ? availableInterfaces[0] : "")
            if (iface !== "") {
                toggleExec.exec("pkexec wg-quick up " + iface)
            }
        }
    }

    function openConfigApp() {
        launchExec.exec("bash -c 'nohup wireguard-config >/dev/null 2>&1 &'")
    }

    // ── Executable DataSources ─────────────────────────────────────────────
    P5Support.DataSource {
        id: statusExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var ifaces = data["stdout"].trim()
            root.vpnConnected    = ifaces !== ""
            root.activeInterface = ifaces !== "" ? ifaces.split('\n')[0].trim() : ""
            disconnectSource(source)
        }
        function exec(cmd) { connectSource(cmd) }
    }

    P5Support.DataSource {
        id: listExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            var raw = data["stdout"].trim()
            root.availableInterfaces = raw !== ""
                ? raw.split(' ').filter(function(s) { return s.trim() !== "" })
                : []
            disconnectSource(source)
        }
        function exec(cmd) { connectSource(cmd) }
    }

    P5Support.DataSource {
        id: toggleExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
            refreshTimer.restart()
        }
        function exec(cmd) { connectSource(cmd) }
    }

    P5Support.DataSource {
        id: launchExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source) }
        function exec(cmd) { connectSource(cmd) }
    }

    P5Support.DataSource {
        id: cacheExec
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source) }
        function exec(cmd) { connectSource(cmd) }
    }

    Timer {
        id: refreshTimer
        interval: 2000
        running: false
        repeat:  false
        onTriggered: checkStatus()
    }

    // ══════════════════════════════════════════════════════════════════════
    // Compact representation – panel icon + status dot
    // ══════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        id: compactRoot

        implicitWidth:  Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium

        Kirigami.Icon {
            anchors.centerIn: parent
            width:  Math.min(parent.width, parent.height) - 4
            height: width
            source: "network-vpn"
            opacity: root.vpnConnected ? 1.0 : 0.55

            Behavior on opacity { NumberAnimation { duration: 300 } }
        }

        // Coloured status dot (green = connected, red = disconnected)
        Rectangle {
            anchors {
                right:        parent.right
                bottom:       parent.bottom
                rightMargin:  1
                bottomMargin: 1
            }
            width:  8
            height: 8
            radius: 4
            color:  root.vpnConnected ? "#4caf50" : "#f44336"
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1

            Behavior on color { ColorAnimation { duration: 300 } }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // Full representation – popup panel
    // ══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        id: fullRoot

        implicitWidth:  Kirigami.Units.gridUnit * 22
        implicitHeight: Kirigami.Units.gridUnit * 15

        ColumnLayout {
            anchors {
                fill:    parent
                margins: Kirigami.Units.largeSpacing
            }
            spacing: Kirigami.Units.largeSpacing

            // ── Header: icon + status label + toggle switch ────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "network-vpn"
                    width:  Kirigami.Units.iconSizes.large
                    height: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents.Label {
                        text:      "WireGuard VPN"
                        font.bold: true
                    }

                    PlasmaComponents.Label {
                        text: root.vpnConnected
                            ? "Connected — " + root.activeInterface
                            : root.availableInterfaces.length > 0
                                ? "Disconnected"
                                : "No profiles found"
                        opacity: 0.75
                        color: root.vpnConnected ? "#4caf50" : Kirigami.Theme.textColor
                    }
                }

                // Toggle switch
                PlasmaComponents.Switch {
                    id: vpnToggle
                    enabled: root.availableInterfaces.length > 0 || root.vpnConnected

                    Component.onCompleted: checked = root.vpnConnected

                    Connections {
                        target: root
                        function onVpnConnectedChanged() {
                            vpnToggle.checked = root.vpnConnected
                        }
                    }

                    onClicked: root.toggleVPN()
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ── Profile selector (shown when > 1 profile available) ────────
            RowLayout {
                Layout.fillWidth: true
                visible: root.availableInterfaces.length > 1

                PlasmaComponents.Label { text: "Profile:" }

                PlasmaComponents.ComboBox {
                    Layout.fillWidth: true
                    model: root.availableInterfaces
                    currentIndex: root.availableInterfaces.indexOf(root.selectedInterface)

                    onCurrentTextChanged: {
                        if (currentText !== "") {
                            root.selectedInterface = currentText
                        }
                    }
                }
            }

            // ── Single profile info (only 1 profile) ──────────────────────
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.availableInterfaces.length === 1
                text: "Profile: " + (root.availableInterfaces[0] || "")
                opacity: 0.75
            }

            // ── No profiles warning ────────────────────────────────────────
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: root.availableInterfaces.length === 0
                text: "No WireGuard profiles found.\nOpen Config Manager to import a .conf file."
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                opacity: 0.65
                font.italic: true
            }

            Item { Layout.fillHeight: true }

            Kirigami.Separator { Layout.fillWidth: true }

            // ── Config Manager button ──────────────────────────────────────
            PlasmaComponents.Button {
                Layout.fillWidth: true
                icon.name: "settings-configure"
                text: "Open WireGuard Config Manager"

                onClicked: {
                    root.openConfigApp()
                    root.expanded = false
                }
            }
        }
    }
}
