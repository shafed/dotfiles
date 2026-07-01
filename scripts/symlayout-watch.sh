#!/bin/sh
# Force the US xkb layout while kanata's symbol layers are active.
#
#   symlayout-watch.sh enter
#   symlayout-watch.sh leave
#   symlayout-watch.sh app
#
# Called directly by kanata actions (no TCP server needed). POSIX-shell port of
# the old Python version: same enter/leave/state-file semantics, but ~13ms
# faster per call by skipping the Python interpreter startup. The only real work
# is one or two hyprctl calls.

DEV=kanata
STATE_FILE="/tmp/symlayout-watch-$(id -u)-${DEV}.layout"

# Active layout index for $DEV, or 0 if unknown. Parses the plain-text
# `hyprctl devices` (cheaper than `-j devices` + JSON). The block for our device
# starts at a line that is exactly the device name (tab-indented).
current_layout_index() {
	hyprctl devices 2>/dev/null | awk -v dev="$DEV" '
		# device-name line: trimmed value equals dev, and the next lines
		# (rules/active layout index) are more deeply indented.
		{ line = $0; sub(/^[ \t]+/, "", line); sub(/[ \t]+$/, "", line) }
		line == dev { in_dev = 1; next }
		in_dev && line ~ /^active layout index:/ {
			sub(/^active layout index:[ \t]*/, "", line)
			print line + 0
			exit
		}
		# a new top-ish level entry ends our device block before we found it
		in_dev && $0 ~ /^[ \t][^ \t]/ { in_dev = 0 }
	'
}

enter_symbol_layer() {
	# guard against double-enter (mirrors the Python os.path.exists check)
	[ -e "$STATE_FILE" ] && return 0

	idx=$(current_layout_index)
	[ -n "$idx" ] || idx=0
	printf '%s' "$idx" >"$STATE_FILE"

	[ "$idx" -ne 0 ] && hyprctl switchxkblayout "$DEV" 0 >/dev/null 2>&1
	return 0
}

leave_symbol_layer() {
	[ -e "$STATE_FILE" ] || return 0
	idx=$(cat "$STATE_FILE" 2>/dev/null)
	rm -f "$STATE_FILE"

	case "$idx" in
		'' | *[!0-9]*) return 0 ;;  # missing/non-numeric -> nothing to restore
	esac
	[ "$idx" -ne 0 ] && hyprctl switchxkblayout "$DEV" "$idx" >/dev/null 2>&1
	return 0
}

force_app_layout() {
	hyprctl switchxkblayout "$DEV" 0 >/dev/null 2>&1 || true
	return 0
}

case "$1" in
	enter) enter_symbol_layer ;;
	leave) leave_symbol_layer ;;
	app) force_app_layout ;;
	*) echo "usage: $0 enter|leave|app" >&2; exit 1 ;;
esac
