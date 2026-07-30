#!/usr/bin/env bash
# sudo wrapper: notifies when a password prompt is about to be shown
# and the terminal window is not currently focused (Hyprland only).
# Falls through transparently to the real /usr/bin/sudo in all cases.

set -o pipefail

REAL_SUDO=/usr/bin/sudo

# Terminal emulator process names recognized when walking up the
# process tree to find "the terminal this sudo call lives in".
TERMINAL_COMMS='kitty|alacritty|foot|wezterm|xterm|konsole|gnome-terminal-server|urxvt|st|wave'

notify_if_unfocused() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v notify-send >/dev/null 2>&1 || return 0

    local active_json active_pid
    active_json=$(hyprctl activewindow -j 2>/dev/null) || return 0
    active_pid=$(echo "$active_json" | grep -o '"pid": *[0-9]*' | head -1 | grep -o '[0-9]*$')
    [ -z "$active_pid" ] && return 0

    # Walk up from this process to find the enclosing terminal emulator pid.
    local p=$$ term_pid=""
    for _ in $(seq 1 12); do
        local line comm ppid
        line=$(ps -o ppid=,comm= -p "$p" 2>/dev/null) || break
        [ -z "$line" ] && break
        ppid=$(echo "$line" | awk '{print $1}')
        comm=$(echo "$line" | awk '{print $2}')
        if echo "$comm" | grep -qE "^($TERMINAL_COMMS)$"; then
            term_pid=$p
            break
        fi
        [ -z "$ppid" ] || [ "$ppid" = "0" ] && break
        p=$ppid
    done

    [ -z "$term_pid" ] && return 0

    if [ "$active_pid" != "$term_pid" ]; then
        notify-send -a sudo "Password required" "sudo is waiting for a password in an unfocused terminal"
    fi
}

# Quick, non-interactive check: does a valid sudo timestamp already exist?
# If so, no password prompt will occur, so there is nothing to notify about.
if ! "$REAL_SUDO" -n true 2>/dev/null; then
    notify_if_unfocused
fi

exec "$REAL_SUDO" "$@"
