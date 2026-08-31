---
title: sioyek
type: component
updated: 2026-08-31
covers:
  - sioyek/
  - scripts/dots-apply.sh
---

# sioyek

PDF viewer for papers/technical books. Config in `../sioyek/` is only
`prefs_user.config` (inverse search into nvim, `always_copy_selected_text`)

- `keys_user.config` (vim-style rebinds, deliberately overriding stock keys —
  the startup "Warning: key overwritten by keys_user.config" lines are
  expected, not an error).

The non-trivial part is **not** the config — it's getting the window to appear
at all on this machine.

## Why launches go through `~/.local/bin/sioyek`

On the desktop (nvidia GTX 1060, proprietary `nvidia-580xx`) under Hyprland,
sioyek's Qt6 cannot create an EGL context on native Wayland:

```
QEGLPlatformContext: Failed to create context: 3009   # 3009 = EGL_BAD_MATCH
QOpenGLWidget: Failed to create context
```

[hypr](hypr.md) sets `QT_QPA_PLATFORM = wayland` globally (for crisp fractional
scaling), so sioyek inherits it and breaks. Forcing XWayland fixes it. Verified
matrix (same PDF, all four combinations):

| platform | GL       | window? |
| -------- | -------- | ------- |
| wayland  | hardware | no      |
| wayland  | software | no      |
| xcb      | software | no      |
| **xcb**  | hardware | **yes** |

⚠️ **Gotcha**: the long-standing `LIBGL_ALWAYS_SOFTWARE=1` workaround was
**itself a second bug**, not a fix — it breaks sioyek even on xcb. That variable
only redirects _Mesa's_ GL to llvmpipe, while EGL still resolves to the nvidia
vendor library through libglvnd. GL and EGL then come from different drivers →
`EGL_BAD_MATCH`. It was carried in four separate places until 2026-08-09.

## Why a wrapper and not an alias

A `zsh` alias only covers the interactive shell. sioyek is launched from five
places, four of which never see it:

| launcher                                      | how it invokes sioyek                           |
| --------------------------------------------- | ----------------------------------------------- |
| interactive shell                             | `sioyek` from `PATH`                            |
| [yazi](yazi.md) `view_pdf` opener             | `sioyek %s1` from `PATH`                        |
| [kanata](kanata.md) apps-layer `z`            | `switchApp.sh sioyek '$HOME/.local/bin/sioyek'` |
| nvim vimtex (`vimtex_view_method = "sioyek"`) | `sioyek` from `PATH`                            |
| `xdg-open` (nvim mini.files `<leader>o`)      | `~/.local/share/applications/sioyek.desktop`    |

⚠️ **The kanata row used bare `sioyek` until 2026-08-15** — same bug class as
the alias: `(cmd zsh -lc ...)` is a non-interactive login shell, so `.zshrc`
(where `~/.local/bin` gets prepended to `PATH`) never sources, and `sioyek`
resolved to the unwrapped `/usr/bin/sioyek` instead. The wrapper never ran,
so the `z` key hit the EGL_BAD_MATCH bug below on every launch even though
the wrapper existed. See [kanata](kanata.md) for the full trace. Fixed by
hardcoding the wrapper's path in `config.kbd` rather than relying on `PATH`.

So `dots apply` writes a wrapper next to the existing `sudo` one:

```bash
exec env -u LIBGL_ALWAYS_SOFTWARE QT_QPA_PLATFORM=xcb /usr/bin/sioyek "$@"
```

`-u LIBGL_ALWAYS_SOFTWARE` is defensive: it neutralises the old variable if any
stale launcher outside this repo still exports it. Absolute `/usr/bin/sioyek`
avoids the wrapper recursing into itself.

⚠️ **Gotcha**: the `.desktop` entry calls the wrapper by **absolute path**
(`/home/shafed/.local/bin/sioyek`), not by name. The systemd user session's
`PATH` does not include `~/.local/bin`, so a bare `Exec=sioyek` would silently
resolve to `/usr/bin/sioyek` and bypass the wrapper. Check with
`systemctl --user show-environment | grep PATH` before assuming otherwise.

⚠️ **Gotcha**: that `.desktop` file and `~/.config/mimeapps.list` are **not in
this repo** — the fix won't survive a fresh machine. Also note the two disagree:
`mimeapps.list` maps `application/pdf` to zathura, but
`xdg-mime query default application/pdf` actually answers `sioyek.desktop`.

## Debugging: the zombie instance

sioyek is single-instance — a second launch hands the file to the running one
over a local socket and exits (~0.07 s). When the GL failure hits, **the process
does not die**: it stays alive with no window. Every later launch then forwards
into that zombie and silently does nothing, so the _original_ error scrolls past
only once and never reappears.

Symptom: `pgrep sioyek` shows a process, `hyprctl clients` shows no `sioyek`
window. Fix: `pkill -x sioyek` before re-testing, and use
`sioyek --new-instance` to surface real errors instead of forwarding.

## Laptop caveat (not applied)

The wrapper deliberately does **not** set `QT_SCALE_FACTOR`. On the desktop
(`DP-1`, `scale 1.00`) none is needed. On the laptop panel (`scale 1.6` with
`force_zero_scaling = true`) XWayland keeps the buffer at 1x, so sioyek will
render small — it needs `QT_SCALE_FACTOR=1.6` there, exactly like Happ; see the
HiDPI section of [hypr](hypr.md). Hardcoding 1.6 in a wrapper shared by both
machines would over-scale the desktop, so this is left until the laptop actually
needs it.
