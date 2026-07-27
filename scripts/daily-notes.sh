#!/usr/bin/env bash

# Open today's daily note in neovim inside a per-day kitty session, creating the
# note (and its year directory) on first use.
#
# Layout: ~/obsidian/journal/<YYYY>/<YYYY-MM-DD-Weekday>.md

set -euo pipefail

main_note_dir="$HOME/obsidian/journal"

current_year=$(date +"%Y")
current_month_num=$(date +"%m")
current_day=$(date +"%d")
current_weekday=$(date +"%A")

note_dir="${main_note_dir}/${current_year}"
note_name="${current_year}-${current_month_num}-${current_day}-${current_weekday}"
full_path="${note_dir}/${note_name}.md"

mkdir -p "$note_dir"

# Create the daily note if it does not already exist.
if [[ ! -f "$full_path" ]]; then
  cat <<EOF >"$full_path"
# ${note_name}

EOF
fi

# One kitty session per day, named after the note. On first use: pull the vault,
# then always open straight into the note (cursor on the last line, +norm G) --
# deliberately no persistence.load(), so a stale restored layout from a
# previous day in this same yearly folder never gets in the way.

kitty_session_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kitty-sessions"
mkdir -p "$kitty_session_dir"
session_file="${kitty_session_dir}/daily-${note_name}.kitty-session"

cat >"$session_file" <<EOF
layout tall
cd ${note_dir}
launch --title "${note_name}" zsh -ic '~/dotfiles/scripts/obsidian-sync.sh pull && nvim "+norm G" ${full_path}; exec zsh'
focus
focus_os_window
EOF

kitten @ action goto_session "$session_file"
