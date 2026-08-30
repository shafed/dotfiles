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
2. **hypr** catches only `Super`. kanata never touches Super, except in
   `numws`/`movews` where Super is **baked into the keycode** and arrives at
   hypr as a normal Super+digit.
3. **kitty** catches `C-S-` (`kitty_mod`) for sessions and splits.

The separation works because **kanata sends `C-S-` to kitty** (via `kitty-send`,
after focusing it) while **hypr listens for `Super`** — and kitty only sees C-S
combos when focused, whereas hypr catches Super globally.

## kanata layers

- **base** — letters + HRM + functional thumb/letter holds.
- **normal** — a "safe" layer (letters as-is, `lsft` = switch language), entered
  by holding Enter.
- **apps** (hold thumb) — launcher layer. `a` opens the Quickshell Applications
  picker and `b` opens the separate Quickshell Bookmarks picker; projects,
  YouTube and kitty-session pickers remain QAT/fzf where the terminal is still
  the better frontend. The browser sub-layer remains on hold `s`. ⚠️ `q` here
  runs [close-window.sh](kanata.md), which is `hl.dsp.window.close()` for most
  apps — **not** kill, so tray apps minimize instead of being SIGKILL'd — except
  Telegram, which is force-killed since a graceful close just minimizes it to
  tray instead of quitting.
- **symbols / symbols2** (hold `e`/`r`, or chords `s+d` / `s+d+f`) — programmer
  symbols on the right hand, with xkb forced to US ([kanata](kanata.md)).
- **navi** (hold `w`, or toggle via caps-hold) — arrows and navigation on the
  right hand, left-hand mods free.
- **numplain / numplain2** (chords `k+l` / `j+k+l`) — digits and their shifted
  symbols on the left hand.
- **numws / movews** (apps hold `l`, or chord `j+l`) — `Super+digit` /
  `Super+Shift+digit`, i.e. hypr workspace switch and move-to-workspace.

## Quickshell desktop bindings

Hyprland owns the direct desktop-shell bindings while kanata provides the
thumb-layer routes above. `Super+Space` opens Applications and `Super+V` opens
Clipboard. `Super+Shift+A/W/B/P/I/U/N` open Audio, Network, Bluetooth, Power,
Agents, Updates and Notifications respectively.

These system panels are mutually exclusive popovers: opening one closes other
overlays; `Esc` or the first click outside closes the active panel. This is a UI
contract rather than a kanata-layer rule, so its implementation belongs to
[quickshell](quickshell.md).

## Collisions that had to be resolved

| Keys                | Contenders                            | Resolution                                                                      |
| ------------------- | ------------------------------------- | ------------------------------------------------------------------------------- |
| `h j k l`           | kanata HRM / navi / hypr `Super+hjkl` | HRM fires only on opposite-hand hold; kanata never touches Super                |
| digits `1-0`        | numplain / hypr `Super+N`             | numplain emits **plain** digits; workspace switching only via numws             |
| `C-tab` / `C-S-tab` | navi (browser tabs) / kitty           | kitty only catches `C-S-*` while focused                                        |
| one-handed `C-S`    | HRM can't (same-hand = tap)           | moved to the `d+f` / `j+k` chords                                               |
| `w+e`               | letter roll vs. Tab chord             | `mod-chord-time 35` + `chords-v2-min-idle 80` separate a roll from a chord      |
| `Alt-t` / `^[t`     | kitty / zsh / nvim companion toggle   | zsh needs three zsh-vi-mode settings before this fires reliably — [zsh](zsh.md) |

## Forcing the US layout

Everything that must type ASCII drives the **`kanata` xkb device** (never the
global layout), through
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh):

- **symbol layers** switch to US for as long as the layer is held, then restore
  the remembered index — so `S-...` yields the same symbols under RU and US.
- **apps actions** hard-force US index 0 before opening a picker. This remains
  useful for both Quickshell text inputs and the QAT/fzf pickers that remain.
- **nvim** does the same for normal mode on its own, with a `langmap` covering
  the async gap ([nvim-layout](nvim-layout.md)).

Switching language during normal work: tap `ralt`, or `lsft` in the `normal`
layer.
