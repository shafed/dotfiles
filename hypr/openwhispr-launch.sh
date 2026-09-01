#!/bin/sh

# OpenWhispr 1.9.2+ persists its Hyprland shortcut by rewriting the active
# config. Point that integration at disposable session state; the real binding
# remains in modules/binds.lua.
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/openwhispr-hyprland"
runtime_config="$runtime_dir/hyprland.lua"

mkdir -p "$runtime_dir" || exit 1
: >"$runtime_config" || exit 1

exec env HYPRLAND_CONFIG="$runtime_config" openwhispr
