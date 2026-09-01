import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower

Item {
  id: service

  readonly property var network: networkService
  readonly property var updates: updatesService

  readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
  readonly property bool bluetoothPowered: !!bluetoothAdapter && bluetoothAdapter.enabled
  readonly property var bluetoothDevices: bluetoothAdapter && bluetoothAdapter.devices
                                          ? bluetoothAdapter.devices.values.filter(function(device) {
                                              return device && device.paired
                                            })
                                          : []
  readonly property bool bluetoothConnected: {
    var values = bluetoothDevices || []
    for (var i = 0; i < values.length; i++)
      if (values[i] && values[i].connected) return true
    return false
  }

  readonly property var batteryDevice: UPower.displayDevice
  readonly property bool hasBattery: {
    var values = UPower.devices && UPower.devices.values ? UPower.devices.values : []
    for (var i = 0; i < values.length; i++)
      if (values[i] && values[i].isLaptopBattery) return true
    return false
  }
  readonly property int batteryPercent: hasBattery && batteryDevice && batteryDevice.ready
                                        ? Math.round(Number(batteryDevice.percentage) * 100)
                                        : -1
  readonly property string batteryStatus: hasBattery && batteryDevice && batteryDevice.ready
                                          ? UPowerDeviceState.toString(batteryDevice.state)
                                          : ""
  readonly property string powerProfile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
                                          : PowerProfiles.profile === PowerProfile.Performance ? "performance"
                                          : "balanced"
  readonly property var powerProfiles: PowerProfiles.hasPerformanceProfile
                                       ? ["power-saver", "balanced", "performance"]
                                       : ["power-saver", "balanced"]
  property string uptime: ""

  NetworkService { id: networkService }
  UpdatesService { id: updatesService }

  function setBluetoothPowered(enabled) {
    if (bluetoothAdapter) bluetoothAdapter.enabled = !!enabled
  }

  function toggleBluetooth() {
    setBluetoothPowered(!bluetoothPowered)
  }

  function toggleBluetoothDevice(device) {
    if (!device) return
    if (device.connected) device.disconnect()
    else device.connect()
  }

  function setPowerProfile(profile) {
    var value = String(profile || "")
    if (value === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver
    else if (value === "performance" && PowerProfiles.hasPerformanceProfile)
      PowerProfiles.profile = PowerProfile.Performance
    else PowerProfiles.profile = PowerProfile.Balanced
  }

  function formatUptime(raw) {
    var seconds = Math.max(0, Math.floor(Number(String(raw || "").split(/\s+/)[0]) || 0))
    var days = Math.floor(seconds / 86400)
    var hours = Math.floor((seconds % 86400) / 3600)
    var minutes = Math.floor((seconds % 3600) / 60)
    var parts = []
    if (days > 0) parts.push(days + "d")
    if (hours > 0 || days > 0) parts.push(hours + "h")
    parts.push(minutes + "m")
    return parts.join(" ")
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    onTextChanged: service.uptime = service.formatUptime(text())
  }

  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: uptimeFile.reload()
  }
}
