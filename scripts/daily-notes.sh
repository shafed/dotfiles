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

# One tmux session per day, named after the note. On first use: pull the vault,
# then open the note in neovim with the cursor on the last line (+norm G).
tmux_session_name="$note_name"

if ! tmux has-session -t="$tmux_session_name" 2>/dev/null; then
  tmux new-session -d -s "$tmux_session_name" -c "$note_dir"
  tmux send-keys -t "$tmux_session_name" "git -C ~/obsidian pull && nvim +norm\\ G $full_path" C-m
else
  # Session exists but neovim was closed: reopen it, then press "s" in the
  # start screen.
  if ! tmux list-panes -t "$tmux_session_name" -F "#{pane_current_command}" | grep -q "nvim"; then
    tmux send-keys -t "$tmux_session_name" "nvim" C-m
    tmux send-keys -t "$tmux_session_name" "s"
  fi
fi

tmux switch-client -t "$tmux_session_name"
