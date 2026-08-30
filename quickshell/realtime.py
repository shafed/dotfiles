#!/usr/bin/env python3
"""Apply realtime service bindings to the generated Quickshell QML."""

from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"realtime.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    "import Quickshell.Hyprland\n",
    "import Quickshell.Hyprland\nimport Quickshell.Services.Pipewire\n",
    "PipeWire import",
)

replace_once(
    "  property int lastVolume: -1\n",
    "  property int lastVolume: -1\n"
    "  property int lastNativeVolume: -1\n"
    "  property var lastNativeMuted: null\n"
    "  readonly property var liveAudioSink: Pipewire.defaultAudioSink\n"
    "  readonly property int liveVolume: liveAudioSink && liveAudioSink.audio\n"
    "                                    ? Math.round(liveAudioSink.audio.volume * 100)\n"
    "                                    : Number(state.audio ? state.audio.volume : 0)\n"
    "  readonly property bool liveMuted: liveAudioSink && liveAudioSink.audio\n"
    "                                    ? liveAudioSink.audio.muted\n"
    "                                    : !!(state.audio && state.audio.muted)\n"
    "  onLiveVolumeChanged: handleNativeAudioChange()\n"
    "  onLiveMutedChanged: handleNativeAudioChange()\n",
    "native audio state",
)

replace_once(
    "  function run(args) {\n",
    "  function handleNativeAudioChange() {\n"
    "    if (!liveAudioSink || !liveAudioSink.ready || !liveAudioSink.audio) return\n"
    "    var volume = liveVolume\n"
    "    var muted = liveMuted\n"
    "    if (lastNativeVolume < 0 || lastNativeMuted === null) {\n"
    "      lastNativeVolume = volume\n"
    "      lastNativeMuted = muted\n"
    "      return\n"
    "    }\n"
    "    var changed = volume !== lastNativeVolume || muted !== lastNativeMuted\n"
    "    lastNativeVolume = volume\n"
    "    lastNativeMuted = muted\n"
    "    if (changed) showOsd(muted ? \"MUTE\" : \"VOL\", volume + \"%\", volume, true)\n"
    "  }\n\n"
    "  function run(args) {\n",
    "native audio handler",
)

replace_once(
    "  ListModel { id: historyModel }\n",
    "  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }\n\n"
    "  Timer {\n"
    "    interval: 200\n"
    "    repeat: true\n"
    "    running: root.lastNativeVolume < 0\n"
    "    onTriggered: root.handleNativeAudioChange()\n"
    "  }\n\n"
    "  ListModel { id: historyModel }\n",
    "PipeWire tracker",
)

# OSD is now driven by PipeWire and the dedicated brightness watcher. Fast
# snapshots may still refresh panel data after explicit backend actions, but
# must not emit delayed duplicate OSDs.
replace_once(
    "\n    if (next.audio && lastVolume >= 0 && Number(next.audio.volume) !== lastVolume) {\n"
    "      showOsd(next.audio.muted ? \"MUTE\" : \"VOL\", Number(next.audio.volume) + \"%\", Number(next.audio.volume), true)\n"
    "    }\n"
    "    if (next.audio) lastVolume = Number(next.audio.volume)\n\n"
    "    if (laptop && next.brightness !== undefined && Number(next.brightness) >= 0 &&\n"
    "        lastBrightness >= 0 && Number(next.brightness) !== lastBrightness) {\n"
    "      showOsd(\"SUN\", Number(next.brightness) + \"%\", Number(next.brightness), true)\n"
    "    }\n"
    "    if (next.brightness !== undefined && Number(next.brightness) >= 0)\n"
    "      lastBrightness = Number(next.brightness)\n",
    "polling OSD logic",
)

replace_once(
    "  Component.onCompleted: {\n"
    "    run([\"pkill\", \"-x\", \"waybar\"])\n"
    "    fullProc.running = true\n"
    "    fastProc.running = true\n"
    "    workspaceProc.running = true\n"
    "  }\n",
    "  Component.onCompleted: {\n"
    "    run([\"pkill\", \"-x\", \"waybar\"])\n"
    "    fullProc.running = true\n"
    "  }\n",
    "startup polling",
)

replace_once(
    "  Timer {\n"
    "    interval: 800\n"
    "    repeat: true\n"
    "    running: true\n"
    "    onTriggered: {\n"
    "      if (!fastProc.running) fastProc.running = true\n"
    "      if (!workspaceProc.running) workspaceProc.running = true\n"
    "    }\n"
    "  }\n\n",
    "",
    "800ms polling timer",
)

replace_once(
    "          ClickButton {\n"
    "            label: root.state.audio && root.state.audio.muted\n"
    "                   ? \"MUTE\"\n"
    "                   : \"VOL \" + String(root.state.audio ? root.state.audio.volume : 0) + \"%\"\n"
    "            active: root.openPanel === \"audio\"\n",
    "          ClickButton {\n"
    "            label: root.liveMuted ? \"MUTE\" : \"VOL \" + String(root.liveVolume) + \"%\"\n"
    "            active: root.openPanel === \"audio\"\n",
    "top bar audio",
)

replace_once(
    "            label: root.state.audio && root.state.audio.muted ? \"Unmute\" : \"Mute\"\n",
    "            label: root.liveMuted ? \"Unmute\" : \"Mute\"\n",
    "audio panel mute label",
)

path.write_text(text)
