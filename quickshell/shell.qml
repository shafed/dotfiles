import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray

ShellRoot {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string backend: home + "/github/dotfiles/quickshell/backend.py"

  property var state: ({
    audio: { volume: 0, muted: false, sinks: [], streams: [] },
    network: { enabled: false, active: "", networks: [] },
    bluetooth: { powered: false, devices: [] },
    power: { profile: "", profiles: [], battery: -1, status: "", uptime: "" },
    brightness: -1,
    updates: { count: 0 },
    agents: [],
    workspace: 1,
    layout: "",
    notifications: { dnd: false, history: [] }
  })
  property string openPanel: ""
  property bool clipboardOpen: false
  property var clipboardRows: []
  property bool historyHydrated: false
  property int lastVolume: -1
  property int lastBrightness: -1
  property bool osdOpen: false
  property string osdIcon: "VOL"
  property string osdLabel: ""
  property int osdValue: 0
  property bool osdHasValue: true
  property var notificationRefs: ({})

  function run(args) {
    Quickshell.execDetached(args)
  }

  function backendAction(domain, action, arg) {
    var argv = ["python3", backend, "action", domain, action]
    if (arg !== undefined && arg !== null && String(arg) !== "") argv.push(String(arg))
    run(argv)
    fastRefreshDelay.restart()
    fullRefreshDelay.restart()
  }

  function togglePanel(name) {
    openPanel = openPanel === name ? "" : name
    if (openPanel !== "" && !fullProc.running) fullProc.running = true
  }

  function updateFast(next) {
    var merged = state
    if (next.audio) merged.audio = next.audio
    if (next.brightness !== undefined) merged.brightness = next.brightness
    if (next.workspace !== undefined) merged.workspace = next.workspace
    if (next.layout !== undefined) merged.layout = next.layout
    state = Object.assign({}, merged)

    if (next.audio && lastVolume >= 0 && Number(next.audio.volume) !== lastVolume) {
      showOsd(next.audio.muted ? "MUTE" : "VOL", Number(next.audio.volume) + "%", Number(next.audio.volume), true)
    }
    if (next.audio) lastVolume = Number(next.audio.volume)

    if (next.brightness !== undefined && Number(next.brightness) >= 0 &&
        lastBrightness >= 0 && Number(next.brightness) !== lastBrightness) {
      showOsd("SUN", Number(next.brightness) + "%", Number(next.brightness), true)
    }
    if (next.brightness !== undefined && Number(next.brightness) >= 0)
      lastBrightness = Number(next.brightness)
  }

  function updateFull(next) {
    state = next
    if (!historyHydrated && next.notifications && next.notifications.history) {
      historyModel.clear()
      for (var i = 0; i < next.notifications.history.length; i++)
        historyModel.append(next.notifications.history[i])
      historyHydrated = true
    }
    if (lastVolume < 0 && next.audio) lastVolume = Number(next.audio.volume)
    if (lastBrightness < 0 && Number(next.brightness) >= 0) lastBrightness = Number(next.brightness)
  }

  function refreshClipboard() {
    if (!clipboardProc.running) clipboardProc.running = true
  }

  function showOsd(icon, label, value, hasValue) {
    osdIcon = icon
    osdLabel = label
    osdValue = Number(value || 0)
    osdHasValue = hasValue !== false
    osdOpen = true
    osdTimer.restart()
  }

  function formatTokens(value) {
    var n = Number(value || 0)
    if (n >= 1000000) return (n / 1000000).toFixed(1) + "M"
    if (n >= 1000) return (n / 1000).toFixed(1) + "K"
    return String(n)
  }

  function receiveNotification(notification) {
    notification.tracked = true
    var stamp = Date.now()
    var item = {
      id: Number(notification.id || stamp),
      app: String(notification.appName || ""),
      summary: String(notification.summary || ""),
      body: String(notification.body || ""),
      timestamp: stamp
    }
    historyModel.insert(0, item)
    while (historyModel.count > 50) historyModel.remove(historyModel.count - 1)

    run(["python3", backend, "notify", "add", JSON.stringify(item)])

    if (state.notifications && state.notifications.dnd) {
      notification.tracked = false
      return
    }

    notificationRefs[String(item.id)] = notification
    toastModel.insert(0, item)
    while (toastModel.count > 4) releaseToast(toastModel.count - 1, true)
    toastTimer.restart()
  }

  function releaseToast(index, expired) {
    if (index < 0 || index >= toastModel.count) return
    var row = toastModel.get(index)
    var ref = notificationRefs[String(row.id)]
    toastModel.remove(index)
    if (ref) {
      try {
        if (expired && typeof ref.expire === "function") ref.expire()
        else if (typeof ref.dismiss === "function") ref.dismiss()
        else ref.tracked = false
      } catch (e) {}
      delete notificationRefs[String(row.id)]
    }
  }

  Component.onCompleted: {
    run(["pkill", "-x", "waybar"])
    fullProc.running = true
    fastProc.running = true
  }

  ListModel { id: historyModel }
  ListModel { id: toastModel }

  Process {
    id: fullProc
    command: ["python3", root.backend, "snapshot"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.updateFull(JSON.parse(text)) } catch (e) { console.warn("dots-shell full snapshot:", e) }
      }
    }
  }

  Process {
    id: fastProc
    command: ["python3", root.backend, "fast"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.updateFast(JSON.parse(text)) } catch (e) { console.warn("dots-shell fast snapshot:", e) }
      }
    }
  }

  Process {
    id: clipboardProc
    command: ["python3", root.backend, "clipboard-list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.clipboardRows = JSON.parse(text) } catch (e) { root.clipboardRows = [] }
      }
    }
  }

  Process {
    id: waybarRetire
    running: true
    command: ["bash", "-lc", "for i in $(seq 1 20); do pkill -x waybar >/dev/null 2>&1 || true; sleep 0.5; done"]
  }

  Process {
    id: clipCapture
    running: true
    command: ["bash", "-lc",
      "if command -v cliphist >/dev/null && command -v wl-paste >/dev/null; then exec wl-paste --type text --watch cliphist store; else exec sleep infinity; fi"]
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    onTriggered: if (!fullProc.running) fullProc.running = true
  }

  Timer {
    interval: 800
    repeat: true
    running: true
    onTriggered: if (!fastProc.running) fastProc.running = true
  }

  Timer {
    id: fastRefreshDelay
    interval: 250
    onTriggered: if (!fastProc.running) fastProc.running = true
  }

  Timer {
    id: fullRefreshDelay
    interval: 900
    onTriggered: if (!fullProc.running) fullProc.running = true
  }

  Timer {
    id: osdTimer
    interval: 1300
    onTriggered: root.osdOpen = false
  }

  Timer {
    id: toastTimer
    interval: 8000
    onTriggered: {
      if (toastModel.count > 0) root.releaseToast(toastModel.count - 1, true)
      if (toastModel.count > 0) restart()
    }
  }

  NotificationServer {
    id: notificationServer
    keepOnReload: false
    imageSupported: true
    actionsSupported: true
    bodyMarkupSupported: true
    onNotification: notification => root.receiveNotification(notification)
  }

  IpcHandler {
    target: "dots"
    function toggleClipboard(): string {
      root.clipboardOpen = !root.clipboardOpen
      if (root.clipboardOpen) root.refreshClipboard()
      return root.clipboardOpen ? "open" : "closed"
    }
    function panel(name: string): string {
      root.togglePanel(name)
      return root.openPanel
    }
    function refresh(): string {
      if (!root.fullProc.running) root.fullProc.running = true
      if (!root.fastProc.running) root.fastProc.running = true
      return "ok"
    }
    function showOsd(icon: string, label: string, value: string): string {
      root.showOsd(icon, label, Number(value), true)
      return "ok"
    }
  }

  component ClickButton: Rectangle {
    id: button
    property string label: ""
    property bool active: false
    signal pressed()
    implicitHeight: 28
    implicitWidth: Math.max(28, textItem.implicitWidth + 14)
    radius: 4
    color: mouse.containsMouse || active ? "#504945" : "transparent"

    Text {
      id: textItem
      anchors.centerIn: parent
      text: button.label
      color: "#ebdbb2"
      font.family: "monospace"
      font.pixelSize: 12
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.pressed()
    }
  }

  component PanelButton: Rectangle {
    id: pbutton
    property string label: ""
    property bool selected: false
    signal pressed()
    Layout.fillWidth: true
    implicitHeight: 36
    radius: 5
    color: selected ? "#504945" : (pmouse.containsMouse ? "#3c3836" : "#282828")
    border.width: 1
    border.color: "#504945"

    Text {
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      text: pbutton.label
      color: "#ebdbb2"
      font.family: "monospace"
      font.pixelSize: 12
      elide: Text.ElideRight
      width: parent.width - 24
    }

    MouseArea {
      id: pmouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pbutton.pressed()
    }
  }

  component Heading: Text {
    color: "#d8a657"
    font.family: "monospace"
    font.bold: true
    font.pixelSize: 13
    Layout.topMargin: 6
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: 30
      color: "#1d2021"
      exclusionMode: ExclusionMode.Auto
      WlrLayershell.namespace: "dots-bar"
      WlrLayershell.layer: WlrLayer.Top

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 3

        Row {
          Layout.alignment: Qt.AlignLeft
          spacing: 1
          Repeater {
            model: 10
            ClickButton {
              required property int index
              label: String(index + 1)
              active: Number(root.state.workspace || 1) === index + 1
              onPressed: root.backendAction("workspace", "focus", index + 1)
            }
          }
        }

        Item { Layout.fillWidth: true }

        Text {
          Layout.maximumWidth: 520
          Layout.alignment: Qt.AlignHCenter
          text: ToplevelManager.activeToplevel
                ? (ToplevelManager.activeToplevel.title || ToplevelManager.activeToplevel.appId || "")
                : ""
          color: "#d5c4a1"
          font.family: "monospace"
          font.pixelSize: 12
          elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        Row {
          Layout.alignment: Qt.AlignRight
          spacing: 1

          ClickButton {
            visible: Number(root.state.updates ? root.state.updates.count : 0) > 0
            label: "↑" + String(root.state.updates ? root.state.updates.count : 0)
            onPressed: root.togglePanel("updates")
          }

          ClickButton {
            visible: root.state.agents && root.state.agents.length > 0
            label: "AI"
            active: root.openPanel === "agents"
            onPressed: root.togglePanel("agents")
          }

          ClickButton {
            label: root.state.layout ? String(root.state.layout).replace("English (US)", "US").replace("Russian", "RU") : "--"
          }

          ClickButton {
            label: "BT"
            active: root.openPanel === "bluetooth"
            onPressed: root.togglePanel("bluetooth")
          }

          ClickButton {
            label: root.state.network && root.state.network.active ? "NET" : "NET!"
            active: root.openPanel === "network"
            onPressed: root.togglePanel("network")
          }

          ClickButton {
            label: root.state.audio && root.state.audio.muted
                   ? "MUTE"
                   : "VOL " + String(root.state.audio ? root.state.audio.volume : 0) + "%"
            active: root.openPanel === "audio"
            onPressed: root.togglePanel("audio")
          }

          ClickButton {
            visible: root.state.power && Number(root.state.power.battery) >= 0
            label: "BAT " + String(root.state.power ? root.state.power.battery : "") + "%"
            active: root.openPanel === "power"
            onPressed: root.togglePanel("power")
          }

          ClickButton {
            label: "CLIP"
            onPressed: {
              root.clipboardOpen = true
              root.refreshClipboard()
            }
          }

          ClickButton {
            label: (root.state.notifications && root.state.notifications.dnd) ? "DND" : "BELL"
            active: root.openPanel === "notifications"
            onPressed: root.togglePanel("notifications")
          }

          Repeater {
            model: SystemTray.items
            delegate: Rectangle {
              required property var modelData
              width: 28
              height: 28
              color: trayMouse.containsMouse ? "#504945" : "transparent"
              radius: 4
              Image {
                anchors.centerIn: parent
                width: 17
                height: 17
                source: modelData.icon
                fillMode: Image.PreserveAspectFit
              }
              MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) {
                  if (mouse.button === Qt.RightButton && typeof modelData.secondaryActivate === "function")
                    modelData.secondaryActivate()
                  else if (typeof modelData.activate === "function")
                    modelData.activate()
                }
              }
            }
          }

          ClickButton {
            label: Qt.formatDateTime(new Date(), "ddd HH:mm")
            onPressed: root.togglePanel("power")
          }
        }
      }
    }
  }

  PanelWindow {
    id: panelWindow
    visible: root.openPanel !== ""
    anchors { top: true; right: true }
    margins.top: 34
    margins.right: 6
    implicitWidth: 430
    implicitHeight: 560
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent
      color: "#1d2021"
      border.color: "#504945"
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: root.openPanel.toUpperCase()
            color: "#d8a657"
            font.family: "monospace"
            font.bold: true
            font.pixelSize: 14
          }
          ClickButton { label: "×"; onPressed: root.openPanel = "" }
        }

        Loader {
          Layout.fillWidth: true
          Layout.fillHeight: true
          sourceComponent: root.openPanel === "audio" ? audioPanel :
                           root.openPanel === "network" ? networkPanel :
                           root.openPanel === "bluetooth" ? bluetoothPanel :
                           root.openPanel === "power" ? powerPanel :
                           root.openPanel === "agents" ? agentsPanel :
                           root.openPanel === "updates" ? updatesPanel :
                           root.openPanel === "notifications" ? notificationsPanel : null
        }
      }
    }
  }

  Component {
    id: audioPanel
    Flickable {
      contentWidth: width
      contentHeight: audioColumn.implicitHeight
      clip: true

      ColumnLayout {
        id: audioColumn
        width: parent.width
        spacing: 7

        Heading { text: "Master" }
        RowLayout {
          Layout.fillWidth: true
          PanelButton {
            Layout.fillWidth: true
            label: root.state.audio && root.state.audio.muted ? "Unmute" : "Mute"
            onPressed: root.backendAction("audio", "mute", "")
          }
          PanelButton {
            Layout.preferredWidth: 74
            label: "-5%"
            onPressed: root.backendAction("audio", "delta", "-5")
          }
          PanelButton {
            Layout.preferredWidth: 74
            label: "+5%"
            onPressed: root.backendAction("audio", "delta", "5")
          }
        }

        Heading { text: "Outputs" }
        Repeater {
          model: root.state.audio ? root.state.audio.sinks : []
          PanelButton {
            required property var modelData
            label: (modelData.default ? "● " : "  ") + modelData.name
            selected: modelData.default
            onPressed: root.backendAction("audio", "sink", modelData.id)
          }
        }

        Heading { text: "Application streams" }
        Repeater {
          model: root.state.audio ? root.state.audio.streams : []
          PanelButton {
            required property var modelData
            label: modelData.name + "  " + modelData.volume + "%"
            onPressed: {
              var next = modelData.volume >= 90 ? 50 : modelData.volume + 10
              root.backendAction("audio", "stream:" + modelData.id, next)
            }
          }
        }
      }
    }
  }

  Component {
    id: networkPanel
    Flickable {
      contentWidth: width
      contentHeight: networkColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: networkColumn
        width: parent.width
        spacing: 7

        RowLayout {
          Layout.fillWidth: true
          PanelButton {
            label: root.state.network && root.state.network.enabled ? "Wi-Fi: on" : "Wi-Fi: off"
            onPressed: root.backendAction("network", "toggle", "")
          }
          PanelButton {
            label: "nmtui"
            onPressed: root.backendAction("network", "settings", "")
          }
        }

        Heading { text: "Networks" }
        Repeater {
          model: root.state.network ? root.state.network.networks : []
          PanelButton {
            required property var modelData
            label: (modelData.active ? "● " : "") + modelData.ssid + "  " + modelData.signal + "%  " + modelData.security
            selected: modelData.active
            onPressed: root.backendAction("network", "connect", modelData.ssid)
          }
        }
      }
    }
  }

  Component {
    id: bluetoothPanel
    Flickable {
      contentWidth: width
      contentHeight: bluetoothColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: bluetoothColumn
        width: parent.width
        spacing: 7

        PanelButton {
          label: root.state.bluetooth && root.state.bluetooth.powered ? "Bluetooth: on" : "Bluetooth: off"
          onPressed: root.backendAction("bluetooth", "toggle", "")
        }

        Heading { text: "Paired devices" }
        Repeater {
          model: root.state.bluetooth ? root.state.bluetooth.devices : []
          PanelButton {
            required property var modelData
            label: (modelData.connected ? "● " : "") + modelData.name +
                   (Number(modelData.battery) >= 0 ? "  " + modelData.battery + "%" : "")
            selected: modelData.connected
            onPressed: root.backendAction("bluetooth", modelData.connected ? "disconnect" : "connect", modelData.mac)
          }
        }
      }
    }
  }

  Component {
    id: powerPanel
    Flickable {
      contentWidth: width
      contentHeight: powerColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: powerColumn
        width: parent.width
        spacing: 7

        Heading { text: "Power profile" }
        Repeater {
          model: root.state.power ? root.state.power.profiles : []
          PanelButton {
            required property var modelData
            label: String(modelData)
            selected: root.state.power && root.state.power.profile === String(modelData)
            onPressed: root.backendAction("power", "profile", modelData)
          }
        }

        Heading { text: "System" }
        Text {
          Layout.fillWidth: true
          text: (root.state.power && Number(root.state.power.battery) >= 0
                 ? "Battery: " + root.state.power.battery + "% (" + root.state.power.status + ")\n"
                 : "") +
                "Uptime: " + (root.state.power ? root.state.power.uptime : "")
          color: "#d5c4a1"
          font.family: "monospace"
          font.pixelSize: 12
        }

        RowLayout {
          Layout.fillWidth: true
          PanelButton { label: "Lock"; onPressed: root.backendAction("power", "lock", "") }
          PanelButton { label: "Suspend"; onPressed: root.backendAction("power", "suspend", "") }
        }
        RowLayout {
          Layout.fillWidth: true
          PanelButton { label: "Reboot"; onPressed: root.backendAction("power", "reboot", "") }
          PanelButton { label: "Shutdown"; onPressed: root.backendAction("power", "shutdown", "") }
        }
      }
    }
  }

  Component {
    id: agentsPanel
    Flickable {
      contentWidth: width
      contentHeight: agentsColumn.implicitHeight
      clip: true
      ColumnLayout {
        id: agentsColumn
        width: parent.width
        spacing: 9

        Repeater {
          model: root.state.agents || []
          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: agentColumn.implicitHeight + 20
            radius: 6
            color: "#282828"
            border.color: "#504945"

            ColumnLayout {
              id: agentColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 10
              spacing: 5

              Heading { text: modelData.name }
              Text {
                text: "Today " + root.formatTokens(modelData.today) +
                      " · 7d " + root.formatTokens(modelData.week) +
                      " · " + modelData.sessions + " sessions"
                color: "#d5c4a1"
                font.family: "monospace"
                font.pixelSize: 12
              }
              Repeater {
                model: modelData.models || []
                Text {
                  required property var modelData
                  text: modelData.name + "  " + root.formatTokens(modelData.tokens)
                  color: "#a89984"
                  font.family: "monospace"
                  font.pixelSize: 11
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: updatesPanel
    ColumnLayout {
      spacing: 10
      Text {
        Layout.fillWidth: true
        text: Number(root.state.updates ? root.state.updates.count : 0) === 0
              ? "System is up to date."
              : String(root.state.updates.count) + " package updates available."
        color: "#d5c4a1"
        font.family: "monospace"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
      }
      PanelButton {
        visible: Number(root.state.updates ? root.state.updates.count : 0) > 0
        label: "Open update in kitty"
        onPressed: root.backendAction("updates", "run", "")
      }
      Item { Layout.fillHeight: true }
    }
  }

  Component {
    id: notificationsPanel
    ColumnLayout {
      spacing: 8
      RowLayout {
        Layout.fillWidth: true
        PanelButton {
          label: root.state.notifications && root.state.notifications.dnd ? "Do Not Disturb: ON" : "Do Not Disturb: OFF"
          onPressed: {
            var next = !(root.state.notifications && root.state.notifications.dnd)
            var n = root.state.notifications || { history: [] }
            n.dnd = next
            root.state.notifications = n
            root.state = Object.assign({}, root.state)
            root.run(["python3", root.backend, "notify", "dnd", next ? "true" : "false"])
          }
        }
        PanelButton {
          label: "Clear"
          onPressed: {
            historyModel.clear()
            root.run(["python3", root.backend, "notify", "clear"])
          }
        }
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: notificationColumn.implicitHeight
        clip: true

        ColumnLayout {
          id: notificationColumn
          width: parent.width
          spacing: 6
          Repeater {
            model: historyModel
            Rectangle {
              required property string summary
              required property string body
              required property string app
              Layout.fillWidth: true
              implicitHeight: notifText.implicitHeight + 20
              radius: 5
              color: "#282828"
              border.color: "#3c3836"
              Text {
                id: notifText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                anchors.verticalCenter: parent.verticalCenter
                text: (app ? app + " · " : "") + summary + (body ? "\n" + body : "")
                textFormat: Text.PlainText
                color: "#d5c4a1"
                font.family: "monospace"
                font.pixelSize: 11
                wrapMode: Text.WordWrap
              }
            }
          }
        }
      }
    }
  }

  PanelWindow {
    id: clipboardWindow
    visible: root.clipboardOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      width: Math.min(760, parent.width - 80)
      height: Math.min(620, parent.height - 100)
      anchors.centerIn: parent
      color: "#1d2021"
      border.color: "#504945"
      border.width: 1
      radius: 8

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text {
            Layout.fillWidth: true
            text: "Clipboard"
            color: "#d8a657"
            font.family: "monospace"
            font.bold: true
            font.pixelSize: 15
          }
          ClickButton { label: "×"; onPressed: root.clipboardOpen = false }
        }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: clipColumn.implicitHeight
          clip: true

          ColumnLayout {
            id: clipColumn
            width: parent.width
            spacing: 5
            Repeater {
              model: root.clipboardRows
              PanelButton {
                required property var modelData
                label: modelData.text
                onPressed: {
                  root.clipboardOpen = false
                  root.run(["python3", root.backend, "clipboard-paste", String(modelData.id)])
                }
              }
            }
          }
        }
      }

      Keys.onEscapePressed: root.clipboardOpen = false
    }
  }

  PanelWindow {
    visible: toastModel.count > 0
    anchors { top: true; right: true }
    margins.top: 42
    margins.right: 14
    implicitWidth: 368
    implicitHeight: Math.min(560, toastColumn.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    ColumnLayout {
      id: toastColumn
      width: parent.width
      spacing: 9

      Repeater {
        model: toastModel
        Item {
          id: toastDelegate
          required property int index
          required property string summary
          required property string body
          required property string app
          Layout.fillWidth: true
          implicitHeight: toastCard.implicitHeight + 4
          opacity: 0
          scale: 0.985

          Component.onCompleted: {
            opacity = 1
            scale = 1
          }

          Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
          }
          Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
          }

          Rectangle {
            anchors.fill: toastCard
            anchors.topMargin: 3
            anchors.leftMargin: 2
            anchors.rightMargin: -2
            color: "#66000000"
            radius: 10
          }

          Rectangle {
            id: toastCard
            width: parent.width - 4
            implicitHeight: toastContent.implicitHeight + 26
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            color: toastMouse.containsMouse ? "#32302f" : "#282828"
            border.color: toastMouse.containsMouse ? "#665c54" : "#504945"
            border.width: 1
            radius: 10

            Rectangle {
              width: 4
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              anchors.topMargin: 8
              anchors.bottomMargin: 8
              color: "#458588"
              radius: 2
            }

            ColumnLayout {
              id: toastContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.leftMargin: 17
              anchors.rightMargin: 16
              anchors.topMargin: 12
              spacing: 4

              Text {
                visible: app.length > 0
                Layout.fillWidth: true
                text: app.toUpperCase()
                textFormat: Text.PlainText
                color: "#928374"
                font.family: "monospace"
                font.pixelSize: 9
                font.letterSpacing: 0.6
                elide: Text.ElideRight
              }

              Text {
                Layout.fillWidth: true
                text: summary
                textFormat: Text.PlainText
                color: "#ebdbb2"
                font.family: "sans-serif"
                font.bold: true
                font.pixelSize: 13
                wrapMode: Text.WordWrap
              }

              Text {
                visible: body.length > 0
                Layout.fillWidth: true
                text: body
                textFormat: Text.PlainText
                color: "#d5c4a1"
                font.family: "sans-serif"
                font.pixelSize: 12
                lineHeight: 1.15
                wrapMode: Text.WordWrap
              }
            }

            MouseArea {
              id: toastMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: toastTimer.stop()
              onExited: if (toastModel.count > 0) toastTimer.restart()
              onClicked: root.releaseToast(index, false)
            }
          }
        }
      }
    }
  }

  PanelWindow {
    visible: root.osdOpen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dots-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
      width: 330
      height: 76
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 70
      radius: 8
      color: "#f51d2021"
      border.color: "#504945"

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
          text: root.osdIcon
          color: "#d8a657"
          font.family: "monospace"
          font.bold: true
          font.pixelSize: 13
        }

        Rectangle {
          visible: root.osdHasValue
          Layout.fillWidth: true
          height: 7
          radius: 3
          color: "#504945"
          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.osdValue / 100))
            height: parent.height
            radius: 3
            color: "#a9b665"
          }
        }

        Text {
          text: root.osdLabel
          color: "#ebdbb2"
          font.family: "monospace"
          font.bold: true
          font.pixelSize: 12
        }
      }
    }
  }
}
