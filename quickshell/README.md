# Quickshell

Personal Hyprland top bar and desktop shell.

## Runtime

- `shell.qml` — base shell source.
- `prepare.py` — builds the runtime QML in `~/.cache/dots-shell/quickshell`.
- `start.sh` — prepares and starts Quickshell.
- `layout-watch.py` — pushes keyboard-layout changes to the bar immediately.
- `backend.py` — audio, network, Bluetooth, power, updates, agents, notifications and clipboard backend.

## Top bar

- 30 px high, Inter 14 px.
- occupied Hyprland workspaces only; active state and mouse switching are event-driven.
- keyboard language is the first item in the right status block.
- updates appear only when updates exist; AI appears only when agent data exists.
- BT / network / battery are laptop-only.
- clock is immediately before the system tray; clicking it opens a Monday-first monthly calendar with month navigation and today highlighting.
- battery still opens the power panel on laptops.

## Service

```sh
cd ~/github/dotfiles
git pull --ff-only origin main
systemctl --user daemon-reload
systemctl --user restart quickshell.service layout-osd.service
```

Logs:

```sh
journalctl --user -u quickshell.service -n 100 --no-pager
journalctl --user -u layout-osd.service -n 100 --no-pager
```

Check the bar font:

```sh
fc-match Inter
```

On Arch, if Inter is missing:

```sh
sudo pacman -S ttf-inter
```
