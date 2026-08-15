#!/usr/bin/env bash
# shellcheck shell=bash

# Shared helpers for the picker scripts in this directory (apps.sh,
# bookmarks.sh, youtube.sh, youtube-qat.sh). Sourced, not executed; everything
# here is safe under `set -euo pipefail`.

qat_config="$HOME/dotfiles/kitty/quick-access-terminal-center.conf"
kitty_bin="$(command -v kitty || echo /usr/bin/kitty)"

# Browser integration used by bookmarks/search/youtube. Environment overrides
# are intentionally dotfiles-specific so generic variables like BROWSER can
# still be used by other programs without changing the window-management logic.
browser_name="${DOTFILES_BROWSER_NAME:-Helium}"
browser_bin="${DOTFILES_BROWSER_BIN:-helium-browser}"
browser_class="${DOTFILES_BROWSER_CLASS:-helium}"
browser_desktop="${DOTFILES_BROWSER_DESKTOP:-helium.desktop}"
browser_profile_dir="${DOTFILES_BROWSER_PROFILE_DIR:-$HOME/.config/net.imput.helium/Default}"
# Helium stores cookies v11-encrypted with the key in the Secret Service
# keyring ("Chromium Safe Storage"). Under Hyprland yt-dlp cannot detect a DE,
# auto-picks the basictext keyring and decrypts 0 cookies ("no key found"), so
# the gnomekeyring backend must be forced explicitly.
browser_cookies_from_browser="${DOTFILES_BROWSER_COOKIES_FROM_BROWSER:-chromium+gnomekeyring:${browser_profile_dir}}"
browser_bruvtab_names="${DOTFILES_BROWSER_BRUVTAB_NAMES:-helium chromium}"
bruvtab_bin="${BRUVTAB_BIN:-$(command -v bruvtab || echo "$HOME/.local/bin/bruvtab")}"

# QAT pickers run under bash, so they do not reliably inherit the interactive
# zsh FZF_DEFAULT_OPTS. Keep their fzf palette pinned to kitty's Gruvbox
# Material Dark Medium theme.
export FZF_DEFAULT_OPTS="
  --color=bg:#282828,bg+:#32302f,fg:#d4be98,fg+:#d4be98
  --color=hl:#e78a4e,hl+:#e78a4e,gutter:#282828,alt-gutter:#282828
  --color=prompt:#7daea3,pointer:#d8a657,marker:#89b482
  --color=info:#d8a657,spinner:#d8a657,header:#a9b665
  --color=border:#3c3836,list-border:#3c3836,preview-border:#3c3836
  --color=scrollbar:#a89984,preview-scrollbar:#a89984,label:#d4be98
  --pointer='▌' --marker='┃' --scrollbar='▐▌'"

# Force the keyboard to English so fzf queries type as latin even when the
# active layout is Russian. Index 0 is "us" in hyprland.conf's kb_layout
# (us,ru). Best-effort: silently no-op outside Hyprland.
switch_to_english() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl switchxkblayout all 0 >/dev/null 2>&1 || true
}

# Print the remote-control socket of the MAIN kitty process. Each QAT creates
# its own /tmp/kitty-* socket; using the main one keeps hide/show commands from
# accidentally targeting another floating terminal.
main_kitty_socket() {
  local sock pid args

  for sock in /tmp/kitty-*; do
    [[ -S "$sock" ]] || continue
    pid="${sock##*-}"
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"

    # QAT panels (apps.sh/bookmarks.sh/youtube-qat.sh) are themselves launched as
    # `kitty +kitten panel --instance-group=...`, so their argv also starts with
    # the kitty binary and would otherwise false-match below. Skip them: which
    # socket sorts first among /tmp/kitty-* depends only on PID/start order, so
    # without this exclusion a panel process can outrank the real main kitty and
    # every toggle_qat/launch_qat call ends up talking to the wrong instance.
    [[ "$args" == *"+kitten panel"* ]] && continue

    # On Linux the launcher is usually the python entry point; match either the
    # resolved kitty binary or a bare "kitty" command in the process arguments.
    if [[ "$args" == "$kitty_bin"* || "$args" == kitty* || "$args" == *"/kitty "* ]]; then
      printf '%s\n' "$sock"
      return 0
    fi
  done

  return 1
}

# Focus the main kitty OS window. Best-effort: silent no-op outside Hyprland.
# The QAT panel is its own overlay OS window, so picking a session inside a
# panel switches the session in the main kitty but leaves OS focus on whatever
# was focused before the panel opened; this is what pulls the main kitty to the
# front. (class:kitty matches only the main window — panels are layer-shell
# overlays that hyprctl clients does not list.)
focus_main_kitty() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  hyprctl dispatch "hl.dsp.focus({ window = \"class:kitty\" })" >/dev/null 2>&1 || true
}

# run_qat_panel <instance-group> [command...] — show (or toggle) the QAT panel
# of that group, running [command...] inside it on a cold start. The panel is
# single-instance per instance-group, so re-sending the same launch command
# flips its visibility instead of spawning a second panel. Requires a running
# main kitty (the panel is hosted on it); callers decide whether to create one.
run_qat_panel() {
  local group="$1" sock
  shift

  sock="$(main_kitty_socket)" || return 1

  # The socket file existing does not guarantee the listener accepts yet (tiny
  # window on a cold start), so retry instead of failing the whole picker on a
  # flaky first attempt.
  local i
  for i in {1..3}; do
    if "$kitty_bin" @ --to "unix:${sock}" \
      action launch --type=background kitten quick-access-terminal \
      --config "$qat_config" \
      --instance-group "$group" \
      "$@"; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

# toggle_qat <instance-group> — hide/show the QAT panel of that group. Because
# the panel is single-instance per instance-group, re-sending the same launch
# command flips its visibility instead of spawning a second panel — this is
# what makes re-triggers instant.
toggle_qat() {
  local group="$1"
  run_qat_panel "$group" >/dev/null 2>&1 || true
}

# launch_qat <instance-group> [command...] — show (or toggle) the QAT panel of
# that group, running [command...] inside it on a cold start.
#
# Forces the English layout first: this runs on EVERY hotkey press, and when
# the panel already exists kitty merely toggles its visibility — the picker
# loop's own switch_to_english never re-runs — so doing it here guarantees the
# layout flips to "us" each time the panel is shown.
#
# Only the session pickers (kitty-zoxide-session.sh, kitty-list-sessions.sh)
# set qat_need_kitty=1 and get the main kitty started for them when none is
# running. Every other picker (apps, bookmarks, youtube, search) needs a kitty
# host to draw its panel but must never create one, so it silently does
# nothing when no main kitty is running.
launch_qat() {
  local group="$1"
  shift

  switch_to_english

  if [[ -z "$(main_kitty_socket)" ]]; then
    if [[ "${qat_need_kitty:-0}" != 1 ]]; then
      return 0
    fi
    # No main kitty running: start one so the QAT has a host to attach to. Its
    # socket only appears a moment after launch, so poll for it.
    setsid -f "$kitty_bin" >/dev/null 2>&1 </dev/null || true
    for _ in {1..40}; do
      [[ -n "$(main_kitty_socket)" ]] && break
      sleep 0.25
    done
    [[ -n "$(main_kitty_socket)" ]] || {
      echo "No main kitty socket found."
      exit 1
    }
  fi

  run_qat_panel "$group" "$@"
}

# goto_kitty_session <session-arg> — switch to a kitty session and bring the
# main kitty window to the front. Used by the session pickers
# (kitty-zoxide-session.sh, kitty-list-sessions.sh), which run inside the QAT
# panel: goto_session alone switches the session but does not raise the main
# kitty window over the panel's overlay (nor over whatever had focus before the
# panel opened). Focus first while the panel is still up (same pattern as
# apps.sh's focus_app), then hide the panel so focus stays on the main kitty.
#
# The hide/focus only happens when qat_in_panel is set (the pickers' --qat
# branch); external callers like nvim-edit-handler.sh's --named flow do their
# own focusing, and toggling there would flip a non-existent panel into a fresh
# blank overlay (toggle_qat creates a panel when none exists).
goto_kitty_session() {
  kitten @ action goto_session "$@"
  if [[ "${qat_in_panel:-0}" == 1 ]]; then
    focus_main_kitty
    toggle_qat "${qat_group:-}" || true
  fi
}

###############################################################################
#                    Browser window helpers (Hyprland + jq)
###############################################################################

# True when any configured browser window exists.
browser_running() {
  hyprctl clients -j 2>/dev/null | jq -e --arg class "$browser_class" '
    any(.[]; .class == $class)
  ' >/dev/null 2>&1
}

# Print the Hyprland addresses of all current browser windows, one per line.
browser_window_addresses() {
  hyprctl clients -j 2>/dev/null | jq -r --arg class "$browser_class" '
    .[] | select(.class == $class) | .address
  ' 2>/dev/null
}

# Print the address of a browser window that is NOT on the given workspace, or
# nothing if every browser window is on it (or none exist).
browser_window_off_workspace() {
  hyprctl clients -j 2>/dev/null | jq -r --arg class "$browser_class" --argjson ws "$1" '
    .[] | select(.class == $class and .workspace.id != $ws) | .address
  ' 2>/dev/null | head -n1
}

# open_browser_url <url> — open a URL in the configured browser without giving
# the browser the caller's tty. Used for normal "new tab" delivery.
open_browser_url() {
  local url="$1"

  "$browser_bin" "$url" </dev/null >/dev/null 2>&1 &
  disown
  return 0
}

# open_in_new_browser_window <url> <workspace> — open the URL in a fresh browser
# window, then move that window (and only that window) to <workspace> and focus
# it. The window address set is diffed before/after the launch so the move
# targets the newly created window rather than an existing one.
open_in_new_browser_window() {
  local url="$1" workspace="$2" before after i new_addr=""

  before="$(browser_window_addresses)"
  # </dev/null: never hand the browser the caller's tty. A QAT panel stays open
  # while any process holds its tty (kitty close_on_child_death=no), and a
  # browser tied to that tty gets killed when the panel is force-closed.
  "$browser_bin" --new-window "$url" </dev/null >/dev/null 2>&1 &
  disown

  # Wait for a window address that was not present before the launch.
  for i in {1..10}; do
    after="$(browser_window_addresses)"
    new_addr="$(comm -13 <(printf '%s\n' "$before" | sort) <(printf '%s\n' "$after" | sort) | head -n1)"
    [[ -n "$new_addr" ]] && break
    sleep 0.25
  done

  if [[ -n "$new_addr" ]]; then
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"${workspace}\", window = \"address:${new_addr}\" })" >/dev/null 2>&1 || true
    hyprctl dispatch "hl.dsp.focus({ window = \"address:${new_addr}\" })" >/dev/null 2>&1 || true
  fi
  return 0
}

# move_browser_when_up <workspace> — poll for a browser window (e.g. right
# after a cold-start browser launch), then move it to <workspace> and focus it.
#
# The window can take several seconds to appear on a true cold start (process
# launch + profile load + first paint), far longer than the warm case where a
# running browser opens a tab almost instantly. So poll generously — ~12s — or
# the cold-start window never gets moved and the tab opens on whatever workspace
# the browser came up on instead of <workspace>.
move_browser_when_up() {
  local workspace="$1" i

  for i in {1..48}; do
    if browser_running; then
      hyprctl dispatch "hl.dsp.window.move({ workspace = \"${workspace}\", window = \"class:${browser_class}\" })" >/dev/null 2>&1 || true
      hyprctl dispatch "hl.dsp.focus({ window = \"class:${browser_class}\" })" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  return 0
}

# Raise the browser in Hyprland. On a cold start only, move the freshly-launched
# window to <workspace>; an already-running browser is focused wherever it lives.
focus_browser() {
  local workspace="$1" i cold_start=false
  sleep 0.15

  if ! browser_running; then
    cold_start=true
  fi

  for i in {1..10}; do
    if browser_running; then
      if [[ "$cold_start" == true ]]; then
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"${workspace}\", window = \"class:${browser_class}\" })" >/dev/null 2>&1 || true
      fi
      hyprctl dispatch "hl.dsp.focus({ window = \"class:${browser_class}\" })" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.25
  done
  return 0
}

# Raise the browser window whose active tab bruvtab just activated, identified by
# the tab title that becomes the window title after activation. Falls back to
# focus_browser when no window matches.
focus_browser_for_title() {
  local title="$1" workspace="$2" i addr
  [[ -n "$title" ]] || {
    focus_browser "$workspace"
    return 0
  }

  for i in {1..5}; do
    addr="$(
      hyprctl clients -j 2>/dev/null | jq -r --arg class "$browser_class" --arg t "$title" '
        .[] | select(.class == $class and (.title | startswith($t))) | .address
      ' 2>/dev/null | head -n1
    )"
    if [[ -n "$addr" ]]; then
      hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 0.15
  done

  focus_browser "$workspace"
  return 0
}

# Decide how to deliver a new tab without landing on the avoided workspace:
#   "tab"       - a browser window already lives off the avoided ws; focus it.
#   "newwindow" - browser is running but only on the avoided ws.
#   "cold"      - no browser window yet.
prepare_browser_for_new_tab() {
  local avoid_workspace="$1" addr
  sleep 0.15

  addr="$(browser_window_off_workspace "$avoid_workspace")"
  if [[ -n "$addr" ]]; then
    hyprctl dispatch "hl.dsp.focus({ window = \"address:${addr}\" })" >/dev/null 2>&1 || true
    printf 'tab\n'
    return 0
  fi

  if browser_running; then
    printf 'newwindow\n'
    return 0
  fi

  printf 'cold\n'
  return 0
}

# Normalise a URL for loose comparison: strip scheme, a trailing slash, and any
# #fragment so "https://x.com/" and "http://x.com" match the same open tab.
normalize_url() {
  local u="$1"
  u="${u#http://}"
  u="${u#https://}"
  u="${u%%#*}"
  u="${u%/}"
  printf '%s\n' "$u"
}

# Print bruvtab tab-id prefixes for the configured browser, one per line. This
# prevents a leftover Firefox bruvtab client from stealing a Helium migration.
bruvtab_browser_prefixes() {
  [[ -x "$bruvtab_bin" ]] || return 0

  "$bruvtab_bin" clients 2>/dev/null | awk -v names="$browser_bruvtab_names" '
    BEGIN {
      count = split(tolower(names), parts, /[[:space:],]+/)
      for (i = 1; i <= count; i++) {
        if (parts[i] != "") want[parts[i]] = 1
      }
    }
    {
      prefix = $1
      sub(/\.$/, "", prefix)

      browser = $0
      sub("^[^\t]*\t[^\t]*\t[^\t]*\t", "", browser)
      if (browser == $0) browser = $4
      browser = tolower(browser)

      for (name in want) {
        if (prefix != "" && (browser == name || index(browser, name) > 0)) {
          print prefix
          next
        }
      }
    }
  '
}

# open_or_focus_url <url> <target-workspace> <avoid-workspace> — open a URL,
# preferring an already-open bruvtab tab in the configured browser. New tabs are
# kept away from <avoid-workspace>; when the browser only has windows there, a
# fresh window is opened on <target-workspace>.
open_or_focus_url() {
  local url="$1" target_workspace="$2" avoid_workspace="$3"
  local want prefixes match tab_id tab_title

  if [[ -x "$bruvtab_bin" ]]; then
    want="$(normalize_url "$url")"
    prefixes="$(bruvtab_browser_prefixes)"
    if [[ -n "$prefixes" ]]; then
      match="$(
        "$bruvtab_bin" list 2>/dev/null | awk -F'\t' -v want="$want" -v prefixes="$prefixes" '
          BEGIN {
            count = split(prefixes, parts, /\n/)
            for (i = 1; i <= count; i++) {
              if (parts[i] != "") ok[parts[i]] = 1
            }
          }
          {
            id = $1
            prefix = id
            sub(/\..*/, "", prefix)
            if (!(prefix in ok)) next

            u = $3
            sub(/^https?:\/\//, "", u)
            sub(/#.*$/, "", u)
            sub(/\/$/, "", u)
            if (u == want) { print $1 "\t" $2; exit }
          }
        '
      )"
      if [[ -n "$match" ]]; then
        IFS=$'\t' read -r tab_id tab_title <<<"$match"
        "$bruvtab_bin" activate --focused "$tab_id" >/dev/null 2>&1 || true
        focus_browser_for_title "$tab_title" "$target_workspace"
        return 0
      fi
    fi
  fi

  case "$(prepare_browser_for_new_tab "$avoid_workspace")" in
  newwindow)
    open_in_new_browser_window "$url" "$target_workspace"
    ;;
  cold)
    open_browser_url "$url"
    move_browser_when_up "$target_workspace"
    ;;
  *)
    open_browser_url "$url"
    ;;
  esac
  return 0
}
