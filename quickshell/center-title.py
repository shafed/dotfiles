#!/usr/bin/env python3
"""Center the active-window title against the physical bar width."""

from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

old_title = '''        Item { Layout.fillWidth: true }

        Text {
          Layout.maximumWidth: 520
          Layout.alignment: Qt.AlignHCenter
          text: ToplevelManager.activeToplevel
                ? (ToplevelManager.activeToplevel.title || ToplevelManager.activeToplevel.appId || "")
                : ""
          color: "#fbf1c7"
          font.family: "Inter"
          font.pixelSize: 14
          elide: Text.ElideRight
        }

        Item { Layout.fillWidth: true }

        Row {
'''

new_title = '''        Item { Layout.fillWidth: true }

        Row {
'''

if old_title not in text:
    raise RuntimeError("center-title.py: active-window title block not found")
text = text.replace(old_title, new_title, 1)

anchor = '''        }
      }
    }
  }

  PanelWindow {
    id: panelWindow
'''

overlay = '''        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(520, parent.width * 0.45)
        horizontalAlignment: Text.AlignHCenter
        text: ToplevelManager.activeToplevel
              ? (ToplevelManager.activeToplevel.title || ToplevelManager.activeToplevel.appId || "")
              : ""
        color: "#fbf1c7"
        font.family: "Inter"
        font.pixelSize: 14
        elide: Text.ElideRight
        z: 2
      }
    }
  }

  PanelWindow {
    id: panelWindow
'''

if anchor not in text:
    raise RuntimeError("center-title.py: bar boundary not found")
text = text.replace(anchor, overlay, 1)
path.write_text(text)
