---
title: kanata
type: component
updated: 2026-07-04
covers:
  - kanata/config.kbd
  - kanata/switchApp.sh
  - scripts/symlayout-watch.sh
  - systemd/user/kanata.service
---

# kanata

🚧 Partially filled in. The most thought-out and fragile part of the keymap. See
also the cross-cutting [keymap](keymap.md) and [sessions](sessions.md).

## Runs as a systemd user service

kanata is launched by `../systemd/user/kanata.service`
(`WantedBy=default.target`), not Hyprland's `exec-once` — it's not
Wayland-specific, just a userspace process needing `/dev/uinput` (group
`uinput`). This gives login-independent-of-compositor startup, automatic
restart on crash (`Restart=on-failure`), and `journalctl --user -u kanata`
for logs, matching the pattern used by `adrop.service` (see
[hypr](hypr.md)/[bootstrap](bootstrap.md)). After editing
`kanata/config.kbd`, reload with
`systemctl --user restart kanata` (or `--check` first, per the comment
that used to live next to the old `exec-once` line).

⚠️ Gotcha: the unit also needs `After=graphical-session.target`. Several
kanata bindings shell out to `hyprctl` (layout switch on `sw`, `x`/`z`
window/workspace nav, `q` killactive — see config.kbd), which requires
`HYPRLAND_INSTANCE_SIGNATURE` in the process environment. Without that
ordering, `default.target` can be reached (and kanata started) before uwsm
finalizes the session environment into systemd, so kanata starts with no
Hyprland env vars at all and those bindings silently fail
(`hyprctl` prints `HYPRLAND_INSTANCE_SIGNATURE not set!` to the journal).

## Opposite-hand HRM (home-row mods)

Home-row mods follow the **AGCS** scheme (Alt-GUI-Ctrl-Shift from pinky to index
finger, mirrored: `a/;`=Alt, `s/l`=Super, `d/k`=Ctrl, `f/j`=Shift). Implemented
via `tap-hold-opposite-hand-release` (kanata PR #1955) on top of `defhands` —
hold fires **only if the next key is on the other hand**. This removed misfires
like `sh → Super+h` without the manual "typing keys" lists that had to be
maintained before.

Why the `-release` variant specifically: the decision is made on the **release**
of the interrupting key. If during a fast roll/bigram the second key comes up
before the HRM key does, both resolve as letters. This is the main killer of
cross-hand misfires.

Settings inside the `hrm` template:

- `(neutral hold)` + `neutral-keys` (digits, spc/tab/ret/bspc/esc) — these keys
  are outside `defhands`, but must **preserve** hold so that Super+2,
  Ctrl+Space, Shift+Tab, Ctrl+Enter work.
- `(timeout hold)` — if the interrupting key was **held** longer than the
  timeout (and `-release` didn't fire), force hold. This produces combos like
  `hold j (Shift) + hold v (C-v) → C-S-v`.
- ⚠️ Gotcha: same-hand defaults to `tap`. One-handed mod combos (e.g. `d+f` as
  Ctrl+Shift **on one left hand**) no longer work through HRM — they have to be
  taken across different hands. One-handed Ctrl+Shift is moved out to a separate
  chord (see below).

## Chords (chords-v2) and timings

`concurrent-tap-hold yes` + `defchordsv2`. Key timings:

- `mod-chord-time 35` — a very narrow window for one-handed mod chords (`d+f`,
  `j+k`, `s+f`, `k+l`…): both keys must land almost simultaneously so that a
  sequential roll like `fd` does **not** trigger Ctrl+Shift.
- `chords-v2-min-idle 80` — after any non-chord keypress, chords are skipped for
  80 ms. The result: a one-handed mod chord fires almost instantly after a short
  pause, but not in the middle of fast typing.
- `all-released` in most chords holds the modifiers until both keys come up —
  letting you add a third one (e.g. `C-S-tab`).

⚠️ Gotcha (rolls vs. mod-combos): this is a fundamental trade-off. Too wide a
window catches false mod combos on rolls; too narrow a window doesn't let you
press a combo intentionally. The 35/80 values were tuned empirically; change
with care.

What lives on chords: `d+f`=tap Esc / hold C-S, `j+k`=tap Enter / hold C-S,
`s+f`=Super+Shift, `w+e`=Tab, `k+l`=numplain, `j+k+l`=numplain2 (shifted
numbers), `s+d`=symbols, `s+d+f`=symbols2, `j+l`=movews, `lsft+rsft`=exit to
base.

## Symbol layers + xkb US-wrap

Symbols (`symbols`, `symbols2`) hold `S-...` keycodes on the right hand (the
left holds the entry key). ⚠️ Problem: on the RU layout `S-2` produces `"`, not
`@`. The fix is to switch **kanata's xkb device to US** (index 0) on layer
entry, and restore the previous index on exit. That way `S-...` produces the
same symbols on US and RU.

Mechanics: the `sym-enter`/`sym-enter2` aliases wrap `layer-while-held` in
`(on-press tap-vkey sym-us)` / `(on-release tap-vkey sym-restore)`. Vkeys call
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh) `enter`/`leave`
directly (no TCP server; a POSIX port of the old Python — about 13 ms faster per
call). The script stores the previous index in
`/tmp/symlayout-watch-$UID-kanata.layout` and guards against a double enter.

The symbol layout is **frequency-ordered**: hot symbols sit on the strong home
row — `()` on `j k`, `@` on `h`, `|` on `l`, `` ` `` on `y`. `symbols2` is an
escalation: adding the index finger `f` gets you into rarer `! # * & % < >`.
Symbols aren't duplicated between layers (shorter = hotter chord).

## kitty-send (tmux prefix replacement)

`deftemplate kitty-send` replaced the old tmux-prefix scheme (`C-s`). Now kanata
**focuses kitty** (`@aterm` → [`switchApp.sh`](../kanata/switchApp.sh)
focus-or-launch), waits `aterm-settle 250` ms for the focus to settle, then
sends a `C-S-` hotkey (kitty's `kitty_mod = C-S-`), which drives native
sessions. See [sessions](sessions.md). ⚠️ Gotcha: without the delay the hotkey goes out
before kitty received focus, and the session doesn't switch.

## apps layer + force-English

Holding the thumb key (`lalt`/`ralt`, tap=bspc/switch-lang) gives the `apps`
layer — the launcher for apps/sessions/pickers. The `apps` layer itself does
**not** change the layout: `apps-enter` is just `layer-while-held apps`.

Force-English is done by **actions**, not by entering the layer: picker/session
actions start with `(on-press tap-vkey apps-us)` → `symlayout-watch.sh app`
(hard-forcing xkb US index 0). This way fzf pickers
(bookmarks/youtube/apps/search) and rofimoji always start on the English layout
regardless of the current language. A plain hold/release of the apps key with no
action is harmless.

## Shifted number layer (numplain2)

`numplain` — plain digits on the left hand (home row 1-5, top row 6-0), entered
via the `k+l` chord. `numplain2` — same positions, but `S-...` (symbols above
the digits: `! @ # $ % ...`), entered via the longer `j+k+l` chord. Why a
separate layer: it lets you type shifted symbols of the digit row without
leaving for the symbol layers and without a real Shift, preserving muscle memory
for digit positions.

⚠️ Gotcha about timings in general: press-decided layer-holds on frequent
letters (`n`, `e`, `r`, `w`) are instant, but "letter + bigram" can misfire —
this is a deliberate trade-off for speed of entering layers.
