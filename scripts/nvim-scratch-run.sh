#!/usr/bin/env bash
# Wrapper run inside the QAT scratch panel (see nvim-scratch-toggle.sh):
# opens the scratch file in nvim, then hands off to the quit hook once nvim
# exits. Kept as a real script file -- rather than an inline `bash -c
# "nvim ...; exec ..."` string -- because that string has to survive being
# re-serialized across kitty's remote-control protocol and the
# quick-access-terminal kitten before it becomes argv for this process; a
# semicolon-joined string with embedded quotes did not survive that trip
# intact (nvim ended up invoked with zero arguments, landing on its
# dashboard instead of the scratch file). A plain script path + two plain
# argv tokens has no shell metacharacters left to mangle.

set -euo pipefail

scratch_file="$1"
quit_script="$2"

# VimLeavePre + write: the buffer must reach disk no matter HOW nvim exits,
# because the user's "fast quit" maps (<M-q>/<M-Esc>, all modes including
# insert -- nvim/lua/config/keymaps.lua) run `:q!`, which discards the
# buffer -- the quit hook then finds an empty scratch file and pastes
# nothing. For this scratchpad every exit means "I'm done, paste it".
nvim +startinsert "+autocmd VimLeavePre * silent! write" -- "$scratch_file"
exec "$quit_script"
