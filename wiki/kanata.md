---
title: kanata
type: component
updated: 2026-08-15
covers:
  - kanata/config.kbd
  - kanata/switchApp.sh
  - scripts/symlayout-watch.sh
  - systemd/user/kanata.service
---

# kanata

The most thought-out and fragile part of the keymap. See also
[keymap](keymap.md) and [sessions](sessions.md).

## Runs as a systemd user service

`../systemd/user/kanata.service`, not Hyprland's `exec-once` — kanata isn't
Wayland-specific, it just needs `/dev/uinput`. Reload after editing
`config.kbd` with `systemctl --user restart kanata`.

⚠️ Gotcha: the unit needs `After=`, `BindsTo=`, **and** `WantedBy=` on
`graphical-session.target` — not `default.target`. Several bindings shell out to
`hyprctl` (`sw`, `x`, `z`, `q`), which needs `HYPRLAND_INSTANCE_SIGNATURE` in
the environment. `After=` alone only *orders* two units that are both already
starting; it doesn't make kanata wait for the target or pull it in. Under the
old `WantedBy=default.target`, kanata started via that unrelated path up to a
couple of seconds *before* the target went active — so it came up with no
Hyprland env and those bindings silently failed (`HYPRLAND_INSTANCE_SIGNATURE
not set!` in the journal). `WantedBy=graphical-session.target` makes it a real
dependent of the target's start job; `BindsTo=` also stops it when the session
goes away, which is right since its `hyprctl` calls are meaningless without one.

⚠️ `Requisite=graphical-session.target` was tried first and made it **worse**:
it doesn't wait, it checks at job-scheduling time and hard-fails the start if
the target isn't active yet — and because that's a dependency-job failure rather
than a crash, `Restart=on-failure` never fires, so kanata didn't start at all.

⚠️ **Kanata's config lexer has no escaping, and `(cmd ...)` runs without a
shell.** `(`/`)` are always list structure and `'` is not a string delimiter, so
an inline Lua expression gets flattened and its quotes dropped. Pass the whole
dispatch as **one token**: `(cmd hyprctl dispatch "hl.dsp.window.kill()")`. When
the Lua itself contains quotes, a normal `"..."` can't hold them — use a raw
string: `(cmd hyprctl dispatch r#"hl.dsp.focus({ workspace = "previous" })"#)`.
Don't reach for `bash -c` to work around this. (Since Hyprland 0.55 the legacy
`hyprctl dispatch killactive` form is rejected outright — [hypr](hypr.md).)

## Opposite-hand HRM (home-row mods)

**AGCS** from pinky to index, mirrored (`a/;`=Alt, `s/l`=Super, `d/k`=Ctrl,
`f/j`=Shift), via `tap-hold-opposite-hand-release` on top of `defhands`: hold
fires **only if the next key is on the other hand**. This removed misfires like
`sh → Super+h` without the hand-maintained "typing keys" lists it used to need.

Why the `-release` variant: the decision happens on the **release** of the
interrupting key, so during a fast roll, if the second key comes up before the
HRM key does, both resolve as letters. That is the main killer of cross-hand
misfires.

- `(neutral hold)` + `neutral-keys` (digits, spc/tab/ret/bspc/esc) — outside
  `defhands`, but must preserve hold so Super+2, Ctrl+Space, Shift+Tab work.
- `(timeout hold)` — if the interrupting key was *held* past the timeout, force
  hold, giving combos like `hold j` + `hold v` → `C-S-v`.
- ⚠️ Gotcha: same-hand defaults to **tap**, so one-handed mod combos don't work
  through HRM at all. One-handed Ctrl+Shift moved out to a chord.

## Chords and timings

⚠️ The core trade-off, and the reason these numbers look arbitrary: too wide a
window catches false mod-combos during rolls, too narrow and you can't press one
on purpose. Tuned empirically — change with care.

- `mod-chord-time 35` — both keys must land almost simultaneously, so a
  sequential roll like `fd` does **not** become Ctrl+Shift.
- `chords-v2-min-idle 80` — chords are skipped for 80 ms after any non-chord
  key, so a chord fires instantly after a pause but never mid-typing.
- `all-released` holds modifiers until both keys come up, letting a third key
  join (e.g. `C-S-tab`).

⚠️ Related trade-off: press-decided layer-holds on frequent letters (`n`, `e`,
`r`, `w`) are instant, but "letter + bigram" can misfire. Deliberate, in
exchange for fast layer entry.

## Symbol layers + xkb US-wrap

⚠️ The problem: on the RU layout `S-2` produces `"`, not `@`. So layer entry
switches kanata's **xkb device** to US (index 0) and restores the previous index
on exit, making `S-...` yield the same symbols under either language.

The `sym-enter` aliases wrap `layer-while-held` in
`(on-press tap-vkey sym-us)` / `(on-release tap-vkey sym-restore)`, which call
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh) directly — no
TCP server. It stores the previous index in `/tmp/symlayout-watch-$UID-kanata.layout`
and guards against a double enter.

The layout is **frequency-ordered**: hot symbols on the strong home row, with
`symbols2` as an escalation (add the index finger) for rarer ones. Symbols are
never duplicated between the two — shorter chord means hotter symbol.

⚠️ **Don't trust the inline `;;` comments in `config.kbd`, and don't mirror the
mapping here.** They have drifted from the real `deflayermap` before — claiming
keys lived on `symbols2` when they were on `symbols`, and describing no-ops as
functional. Re-derive from the actual key codes when auditing.

## kitty-send (the tmux prefix replacement)

`deftemplate kitty-send` focuses kitty (`@aterm` →
[`switchApp.sh`](../kanata/switchApp.sh), focus-or-launch), waits
`aterm-settle 250` ms, then sends a `C-S-` hotkey that kitty turns into a
session action ([sessions](sessions.md)). ⚠️ Gotcha: without the settle delay
the hotkey goes out before kitty has focus and the session doesn't switch.

⚠️ **`switchApp.sh`'s else-branch also now `pkill -x`s the app before
launching it** (2026-08-15): a windowless-but-running process (e.g. one stuck
retrying a failed EGL context) blocks `hyprctl clients | grep -q "class:
..."` forever and, for single-instance apps, absorbs every further launch
attempt via IPC without ever showing a window — so the key silently does
nothing. Killing whatever's already running by that name before relaunching
clears that stuck state.

⚠️ **Gotcha — `cmd`'s `zsh -lc` is a login shell but not an *interactive*
one, so `.zshrc` never sources**, only `.zshenv`/`.zprofile`. Any `PATH`
prepend that lives in `.zshrc` (here: `~/.local/bin`, see `.zshrc:178`) is
invisible to every `(cmd zsh -lc "...")` binding. This silently broke the `z`
binding for [sioyek](sioyek.md): it called bare `sioyek`, which under
kanata's shell resolved to `/usr/bin/sioyek` instead of the
`~/.local/bin/sioyek` wrapper that forces `QT_QPA_PLATFORM=xcb` — so it hit
the EGL_BAD_MATCH bug every time, while the exact same `sioyek` command
worked fine from an interactive shell. Fix: reference launcher wrappers by
full path (`$HOME/.local/bin/sioyek`) in `config.kbd` instead of relying on
`PATH`.

## apps layer + force-English

Holding the thumb key gives the `apps` launcher layer. ⚠️ The layer itself does
**not** touch the layout — force-English is attached to the *actions*
(`(on-press tap-vkey apps-us)` → `symlayout-watch.sh app`), so fzf pickers and
rofimoji always start in English while a bare hold/release stays harmless.

## Screenshots

`s` in the **navi** layer is a tap-hold between two `hyprshot` calls, both
straight to the clipboard: tap = whole monitor, hold = interactive region. The
split exists so the fast full-screen path doesn't pay the region-select cost.

Deliberately removed and not to be reinstated: `flameshot` + its service
(2026-07-18, no daemon needed since hyprshot runs on demand) and `satty`
annotation on the region path (2026-08-03).

## numplain2

`numplain` gives plain digits on the left hand; `numplain2` gives the *shifted*
symbols of the digit row from the same positions. Why a separate layer rather
than a real Shift: it preserves digit-position muscle memory and avoids leaving
for the symbol layers.
