# Personal Quickshell shell

Standalone Quickshell desktop layer inspired by Omarchy's single-shell design. It does not depend on Omarchy.

## Included

- multi-monitor top bar with Hyprland workspaces, active window and system tray
- volume/brightness OSD
- notification daemon with popup history and persistent DND state
- clipboard overlay (`cliphist` + `wl-clipboard`, with CopyQ history as fallback)
- audio popup: master mute/volume, output selection and per-stream volume stepping
- network popup: Wi-Fi state, scan/list, saved-network connection and `nmtui`
- Bluetooth popup: radio toggle and paired-device connect/disconnect/battery
- power popup: battery, power profiles, lock/suspend/reboot/shutdown
- Claude Code / Codex usage panel with local token/session statistics
- Arch + AUR update indicator

## Runtime dependencies

Required core: `quickshell`, `python`, `wireplumber` (`wpctl`), `hyprland`.

Feature dependencies: `networkmanager`, `bluez-utils`, `power-profiles-daemon`, `brightnessctl`, `pacman-contrib`, `wl-clipboard`, `cliphist`. `yay` or `paru` adds AUR update counting; CopyQ is used as clipboard-history fallback when `cliphist` is absent.

The tracked `systemd/user/graphical-session.target.wants/quickshell.service` symlink starts the shell with the graphical session. The shell retires the old Waybar after startup, so `hypr/hyprland.lua` can stay untouched during the migration.

## IPC

```sh
bash ~/github/dotfiles/quickshell/dots-shell toggleClipboard
bash ~/github/dotfiles/quickshell/dots-shell panel audio
bash ~/github/dotfiles/quickshell/dots-shell panel network
bash ~/github/dotfiles/quickshell/dots-shell panel bluetooth
bash ~/github/dotfiles/quickshell/dots-shell panel power
bash ~/github/dotfiles/quickshell/dots-shell panel agents
bash ~/github/dotfiles/quickshell/dots-shell panel notifications
```

This leaves Kanata, hyprlauncher, Kitty sessions, hypridle and hyprlock unchanged.
