#!/usr/bin/env python3
"""Apply event-driven state hooks to the generated Quickshell QML."""

from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    if old not in text:
        raise RuntimeError(f"event-state.py: missing expected {label} block")
    text = text.replace(old, new, 1)


replace_once(
    "  property int lastBrightness: -1\n",
    "  property int lastBrightness: -1\n"
    "  property bool audioEventReady: false\n"
    "  property bool brightnessEventReady: false\n",
    "event state flags",
)

replace_once(
    "  function updateFull(next) {\n"
    "    if (state.layout) next.layout = state.layout\n"
    "    state = next\n",
    "  function updateFull(next) {\n"
    "    if (state.layout) next.layout = state.layout\n"
    "    if (audioEventReady) next.audio = state.audio\n"
    "    if (brightnessEventReady) next.brightness = state.brightness\n"
    "    state = next\n",
    "full snapshot event preservation",
)

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
    "",
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
    "    function layoutChanged(label: string): string {\n"
    "      var merged = root.state\n"
    "      merged.layout = label\n"
    "      root.state = Object.assign({}, merged)\n"
    "      return \"ok\"\n"
    "    }\n",
    "    function layoutChanged(label: string): string {\n"
    "      var merged = root.state\n"
    "      merged.layout = label\n"
    "      root.state = Object.assign({}, merged)\n"
    "      return \"ok\"\n"
    "    }\n"
    "    function audioChanged(volume: string, muted: string, notify: string): string {\n"
    "      var value = Math.max(0, Math.min(150, Number(volume)))\n"
    "      var isMuted = muted === \"1\" || muted === \"true\"\n"
    "      var merged = root.state\n"
    "      var audio = Object.assign({}, merged.audio || {})\n"
    "      var changed = Number(audio.volume) !== value || !!audio.muted !== isMuted\n"
    "      audio.volume = value\n"
    "      audio.muted = isMuted\n"
    "      merged.audio = audio\n"
    "      root.audioEventReady = true\n"
    "      root.state = Object.assign({}, merged)\n"
    "      if (notify === \"1\" && changed)\n"
    "        root.showOsd(isMuted ? \"MUTE\" : \"VOL\", String(value) + \"%\", value, true)\n"
    "      return \"ok\"\n"
    "    }\n"
    "    function brightnessChanged(value: string, notify: string): string {\n"
    "      var nextValue = Math.max(0, Math.min(100, Number(value)))\n"
    "      var merged = root.state\n"
    "      var changed = Number(merged.brightness) !== nextValue\n"
    "      merged.brightness = nextValue\n"
    "      root.brightnessEventReady = true\n"
    "      root.state = Object.assign({}, merged)\n"
    "      if (notify === \"1\" && changed)\n"
    "        root.showOsd(\"SUN\", String(nextValue) + \"%\", nextValue, true)\n"
    "      return \"ok\"\n"
    "    }\n",
    "event IPC",
)

path.write_text(text)
