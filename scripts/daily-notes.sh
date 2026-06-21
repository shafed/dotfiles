#!/usr/bin/env bash

# Open today's daily note in neovim inside a per-day tmux session, creating the
# note (and its year/month directory) on first use.
#
# Layout: ~/obsidian/periodic/<YYYY>/<MM-Mon>/<YYYY-MM-DD-Weekday>.md

set -euo pipefail

main_note_dir="$HOME/obsidian/periodic"

current_year=$(date +"%Y")
current_month_num=$(date +"%m")
current_month_abbr=$(date +"%b")
current_day=$(date +"%d")
current_weekday=$(date +"%A")

note_dir="${main_note_dir}/${current_year}/${current_month_num}-${current_month_abbr}"
note_name="${current_year}-${current_month_num}-${current_day}-${current_weekday}"
full_path="${note_dir}/${note_name}.md"

mkdir -p "$note_dir"

# Create the daily note if it does not already exist.
if [[ ! -f "$full_path" ]]; then
  cat <<EOF >"$full_path"
# ${note_name}

## Notes

EOF
fi

# One kitty session per day, named after the note. On first use: pull the vault,
# then open the note in neovim with the cursor on the last line (+norm G).
# persistence.load() reproduces the "reopen session" behaviour the old tmux
# script achieved by pressing "s" in the start screen.

kitty_session_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kitty-sessions"
mkdir -p "$kitty_session_dir"
session_file="${kitty_session_dir}/daily-${note_name}.kitty-session"

cat >"$session_file" <<EOF
layout tall
cd ${note_dir}
launch --title "${note_name}" zsh -ic 'git -C ~/obsidian pull && nvim "+norm G" "+lua require(\"persistence\").load()" ${full_path}; exec zsh'
focus
focus_os_window
EOF

kitten @ action goto_session "$session_file"
