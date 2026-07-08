---
title: keymap
type: topic
updated: 2026-07-08
covers:
  - kanata/config.kbd
  - hypr/hyprland.conf
  - kitty/kitty.conf
  - zsh/zshrc
---

# keymap — end-to-end key map

🚧 Partially filled in. Single source of truth for hotkeys — so layers don't
conflict or get forgotten. See component pages [kanata](kanata.md),
[hypr](hypr.md), [kitty](kitty.md).

## Three levels and the boundary between them

1. **kanata** (`process-unmapped-keys (all-except lctl ralt)`) — intercepts
   nearly the entire physical keyboard, does HRM, chords, layers, symbols. Modifies
   streams at the level **before** the window manager.
2. **hypr** — catches only `Super` bindings (`$mainMod`). kanata doesn't touch Super
   (except `numws`/`movews`, where Super is **baked into the keycode** and goes
   to hypr as Super+digit).
3. **kitty** — catches `C-S-` (`kitty_mod = ctrl+shift`) for sessions/splits.

Key separation: **kanata sends `C-S-` hotkeys to kitty** (via `kitty-send`,
after focusing kitty), while **hypr listens for `Super`**. There's no overlap,
because kitty only catches C-S combos when focused, while hypr catches Super globally.

## kanata layers (what's where)

- **base** — letters + HRM (AGCS) + functional thumb/letter-holds.
- **normal** — a "safe" layer (letters as-is, `lsft`=switch-lang), entered via
  hold Enter; return to base from base via Enter-hold / `lsft+rsft`.
- **apps** (hold thumb) — launcher: apps, kitty sessions (`kitty-send C-S-*`),
  fzf pickers, killactive (`q`), browser sub-layer (`s` hold → `browser`).
- **browser** (from apps, hold `s`) — direct URLs (gmail, perplexity, chatgpt, claude…).
- **symbols / symbols2** (hold `e`/`r` or chords `s+d` / `s+d+f`) — programmer
  symbols on the right hand; xkb is forced to US (see [kanata](kanata.md)).
- **navi** (hold `w` or toggle via caps-hold) — arrows/navigation on the right
  hand, mods free on the left.
- **numplain / numplain2** (chords `k+l` / `j+k+l`) — digits and shifted symbols
  of the digit row on the left hand.
- **numws / movews** (from apps hold `l`, or chord `j+l`) — `Super+digit` /
  `Super+Shift+digit` on the left hand → hypr workspaces / move-to-workspace.

## Potential conflicts and how they're resolved

| Keys | Who owns it | Resolution |
|---|---|---|
| `h j k l` | kanata HRM (base) / navi / hypr Super | HRM only on hold with opposite-hand; hypr `Super+hjkl`=movefocus, kanata doesn't touch Super |
| digits `1-0` | numplain (left hand) / hypr `Super+N` | numplain gives **plain** digits; workspace-switching only via numws (Super baked in) |
| `C-tab` / `C-S-tab` | navi (browser tabs) / kitty | in navi this is `@j/k-navi` (fork on alt); kitty catches `C-S-*` only when focused |
| `Alt-t` / `^[t` | kitty/zsh/nvim companion toggle | zsh binds `^[t` through zsh-vi-mode to `kitty_other_window` from `zvm_after_init` (with `ZVM_LAZY_KEYBINDINGS=false`, so the binding exists from the first prompt instead of only after a mode switch); `ZVM_ESCAPE_KEYTIMEOUT=0.2` keeps the ESC-prefixed sequence together despite kanata's tap-hold delay. See [zsh](zsh.md). |
| one-handed Ctrl+Shift | HRM no longer gives this (same-hand=tap) | moved to chords `d+f` / `j+k` (hold) |
| `w+e` | letter roll vs. Tab chord | `mod-chord-time 35` + `chords-v2-min-idle 80` separate rolling from an intentional chord |

## RU/US and force-English

Two logics for forcing the US layout, both via
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh) on the xkb device
`kanata`:

- **symbol layers** (`enter`/`leave`): switch to US for the duration the layer is
  held and restore the previous index — so `S-...` keycodes give the same
  symbols on RU and US.
- **apps actions** (`app`): hard-force US index 0 when launching a picker/session
  action — so fzf/rofimoji start in English.

Switching language during normal work: tap `ralt` (`@sw` → `hyprctl
switchxkblayout kanata next`), or `lsft` in the `normal` layer.

nvim drives the same `kanata` device for its modes: normal mode forces US
(`InsertLeave`/`VimEnter`/`CmdlineLeave`), entering insert restores the layout
last used there; a fixed `langmap` covers the async switch gap — see
[nvim](nvim.md).
