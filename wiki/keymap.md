---
title: keymap
type: topic
updated: 2026-08-30
covers:
  - kanata/config.kbd
  - hypr/hyprland.lua
  - kitty/kitty.conf
  - zsh/zshrc
---

# keymap — end-to-end key map

Single source of truth for how the layers divide the keyboard. Component detail:
[kanata](kanata.md), [hypr](hypr.md), [kitty](kitty.md). Quickshell picker
behaviour is in [quickshell-pickers](quickshell-pickers.md).

## Three levels and why they don't collide

1. **kanata** (`process-unmapped-keys (all-except lctl ralt)`) intercepts nearly
   the whole physical keyboard — HRM, chords, layers, symbols — _before_ the
   compositor sees anything.
2. **hypr** owns compositor shortcuts plus the standard XF86 volume/brightness
   keys. kanata normally leaves Super alone, except in `numws`/`movews` where
   Super is baked into the output keycode; apps-layer system chords emit XF86
   keys and let Hyprland remain the only owner of `wpctl`/`brightnessctl`.
3. **kitty** catches `C-S-` (`kitty_mod`) for sessions and splits.

The separation works because kanata emits key events rather than duplicating
system actions: `C-S-` goes to kitty after it is focused, XF86 media/backlight
keys go to Hyprland, and workspace chords arrive as normal Super+digit events.

## kanata layers

- **base** — letters + HRM + functional thumb/letter holds.
- **normal** — a "safe" layer (letters as-is, `lsft` = switch language), entered
  by holding Enter.
- **apps** (hold thumb) — launcher layer. `a` opens the Quickshell Applications
  picker and `b` opens the separate Quickshell Bookmarks picker; projects,
  YouTube and kitty-session pickers remain QAT/fzf where the terminal is still
  the better frontend. The browser sub-layer remains on hold `s`. System chords
  are `u+i` volume down, `i+o` volume up, `o+p` mute, `j+k` brightness down,
  `k+l` brightness up, and `w+e` the compact Quickshell system overview. The
  volume/brightness chords emit standard XF86 keycodes instead of running
  system commands themselves. ⚠️ `q` here runs [close-window.sh](kanata.md),
  which is `hl.dsp.window.close()` for most apps — **not** kill, so tray apps
  minimize instead of being SIGKILL'd — except Telegram, which is force-killed
  since a graceful close just minimizes it to tray instead of quitting.
- **symbols / symbols2** (hold `e`/`r`, or chords `s+d` / `s+d+f`) — programmer
  symbols on the right hand, with xkb forced to US ([kanata](kanata.md)).
- **navi** (hold `w`, or toggle via caps-hold) — arrows and navigation on the
  right hand, left-hand mods free.
- **numplain / numplain2** — outside `apps`, chords `k+l` / `j+k+l` give digits
  and their shifted symbols on the left hand. Inside `apps`, `k+l` is brightness up.
- **numws / movews** (apps hold `l`, or chord `j+l`) — `Super+digit` /
  `Super+Shift+digit`, i.e. hypr workspace switch and move-to-workspace.

## Quickshell desktop bindings

Hyprland owns the direct desktop-shell bindings while kanata provides the
thumb-layer routes above. `Super+Space` opens Applications and `Super+V` opens
Clipboard. `Super+Shift+A/W/B/P/I/U/N` open Audio, Network, Bluetooth, Power,
Agents, Updates and Notifications respectively. `apps+w+e` toggles the compact
system overview through `dots-shell system`.

The old direct `Super+=`, `Super+-`, `Super+M`, `Super+]` and `Super+[` system
control shortcuts are removed. Volume/mute/brightness actions now have one
Hyprland source of truth: the standard XF86 bindings, reached either by real
multimedia keys or by Kanata's emitted keycodes.

These system panels are mutually exclusive popovers: opening one closes other
overlays; `Esc` or the first click outside closes the active panel. Applications,
Bookmarks and Clipboard close the system overview and vice versa. This is a UI
contract rather than a kanata-layer rule, so its implementation belongs to
[quickshell](quickshell.md).

## Collisions that had to be resolved

| Keys                | Contenders                                      | Resolution                                                                                           |
| ------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `h j k l`           | kanata HRM / navi / hypr `Super+hjkl`           | HRM fires only on opposite-hand hold; kanata never consumes a real Super                             |
| digits `1-0`        | numplain / hypr `Super+N`                       | numplain emits **plain** digits; workspace switching only via numws                                  |
| `C-tab` / `C-S-tab` | navi (browser tabs) / kitty                     | kitty only catches `C-S-*` while focused                                                             |
| one-handed `C-S`    | HRM can't (same-hand = tap)                     | `j+k` keeps its Enter/C-S behavior outside `apps`; inside `apps` it is brightness down                |
| `w+e`               | Tab chord / requested system overview           | one chord uses `switch` on active layer: `apps` = system overview, otherwise Tab                     |
| `k+l`               | numplain / requested brightness up              | one chord uses `switch` on active layer: `apps` = brightness up, otherwise `numplain`                |
| `j+k/k+l/w+e`       | global chords / apps actions                    | duplicate chord sets are forbidden, so each pair has one definition with an active-layer branch     |
| `Alt-t` / `^[t`     | kitty / zsh / nvim companion toggle             | zsh needs three zsh-vi-mode settings before this fires reliably — [zsh](zsh.md)                      |

## Forcing the US layout

Everything that must type ASCII drives the **`kanata` xkb device** (never the
global layout), through
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh):

- **symbol layers** switch to US for as long as the layer is held, then restore
  the remembered index — so `S-...` yields the same symbols under RU and US.
- **apps actions** hard-force US index 0 before opening a picker. This remains
  useful for both Quickshell text inputs and the QAT/fzf pickers that remain.
  Apps system chords themselves use physical keycodes, so they do not depend on
  whether the active xkb layout is RU or US.
- **nvim** does the same for normal mode on its own, with a `langmap` covering
  the async gap ([nvim-layout](nvim-layout.md)).

Switching language during normal work: tap `ralt`, or `lsft` in the `normal`
layer.
