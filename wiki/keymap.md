---
title: keymap
type: topic
updated: 2026-08-14
covers:
  - kanata/config.kbd
  - hypr/hyprland.lua
  - kitty/kitty.conf
  - zsh/zshrc
---

# keymap — end-to-end key map

Single source of truth for how the layers divide the keyboard. Component detail:
[kanata](kanata.md), [hypr](hypr.md), [kitty](kitty.md).

## Three levels and why they don't collide

1. **kanata** (`process-unmapped-keys (all-except lctl ralt)`) intercepts nearly
   the whole physical keyboard — HRM, chords, layers, symbols — *before* the
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
- **apps** (hold thumb) — launcher: applications, kitty sessions, fzf pickers,
  and a browser sub-layer on hold `s`. ⚠️ `q` here is `hl.dsp.window.close()`,
  **not** kill — so tray apps minimize instead of being SIGKILL'd.
- **symbols / symbols2** (hold `e`/`r`, or chords `s+d` / `s+d+f`) — programmer
  symbols on the right hand, with xkb forced to US ([kanata](kanata.md)).
- **navi** (hold `w`, or toggle via caps-hold) — arrows and navigation on the
  right hand, left-hand mods free.
- **numplain / numplain2** (chords `k+l` / `j+k+l`) — digits and their shifted
  symbols on the left hand.
- **numws / movews** (apps hold `l`, or chord `j+l`) — `Super+digit` /
  `Super+Shift+digit`, i.e. hypr workspace switch and move-to-workspace.

## Collisions that had to be resolved

| Keys                | Contenders                            | Resolution                                                                      |
| ------------------- | ------------------------------------- | ------------------------------------------------------------------------------- |
| `h j k l`           | kanata HRM / navi / hypr `Super+hjkl` | HRM fires only on opposite-hand hold; kanata never touches Super                 |
| digits `1-0`        | numplain / hypr `Super+N`             | numplain emits **plain** digits; workspace switching only via numws              |
| `C-tab` / `C-S-tab` | navi (browser tabs) / kitty           | kitty only catches `C-S-*` while focused                                         |
| one-handed `C-S`    | HRM can't (same-hand = tap)           | moved to the `d+f` / `j+k` chords                                                |
| `w+e`               | letter roll vs. Tab chord             | `mod-chord-time 35` + `chords-v2-min-idle 80` separate a roll from a chord       |
| `Alt-t` / `^[t`     | kitty / zsh / nvim companion toggle   | zsh needs three zsh-vi-mode settings before this fires reliably — [zsh](zsh.md)  |

## Forcing the US layout

Everything that must type ASCII drives the **`kanata` xkb device** (never the
global layout), through
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh):

- **symbol layers** switch to US for as long as the layer is held, then restore
  the remembered index — so `S-...` yields the same symbols under RU and US.
- **apps actions** hard-force US index 0 when launching a picker, so fzf starts
  in English.
- **nvim** does the same for normal mode on its own, with a `langmap` covering
  the async gap ([nvim-layout](nvim-layout.md)).

Switching language during normal work: tap `ralt`, or `lsft` in the `normal`
layer.
