local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local secondaryMod = "ALT"
local fileManager = "dolphin"
local home = os.getenv("HOME") or "~"
local shellCtl = home .. "/.config/quickshell/dots-shell"

-- Quickshell owns desktop-facing launchers, pickers, scratch and system panels.
-- The old terminal/fzf QAT scripts remain only as standalone fallbacks.
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(shellCtl .. " clipboard"))
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd(shellCtl .. " hotkeys"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(shellCtl .. " panel audio"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(shellCtl .. " panel network"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(shellCtl .. " panel bluetooth"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(shellCtl .. " panel power"))
hl.bind(mainMod .. " + SHIFT + I", hl.dsp.exec_cmd(shellCtl .. " panel agents"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd(shellCtl .. " panel updates"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd(shellCtl .. " panel notifications"))

hl.bind("SUPER + Home", hl.dsp.exec_cmd("systemctl suspend && hyprlock"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(shellCtl .. " scratch"))

hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("pkill -USR2 -x handy"))
-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
-- Routed through kitty-new-window.sh instead of a bare `exec terminal`: a
-- fresh kitty process has no source window to inherit a session from, so its
-- tabs come up permanently orphaned (see wiki/sessions.md). The script opens
-- a new OS window inside the already-running main kitty instead.
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("~/github/dotfiles/scripts/kitty-new-window.sh"))
-- hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(
  mainMod .. " + F5",
  hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + Y", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
-- hl.bind(mainMod .. " + T", hl.dsp.layout("togglesplit")) -- dwindle

-- Move focus with mainMod
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "d" }))

-- Move window
hl.bind(mainMod .. " + " .. secondaryMod .. " + H", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + " .. secondaryMod .. " + L", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + " .. secondaryMod .. " + K", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + " .. secondaryMod .. " + J", hl.dsp.window.swap({ direction = "d" }))

-- Resize window
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })

-- Switch workspaces with mainMod + [0-9]
-- Move active window to workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
  local key = i % 10 -- 10 maps to key 0
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Standard XF86 system keys are the single owner for volume/mute/brightness.
-- Kanata's apps-layer chords emit these keycodes instead of duplicating the
-- wpctl/brightnessctl commands.
hl.bind(
  "XF86AudioRaiseVolume",
  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86AudioLowerVolume",
  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86AudioMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
  { locked = true, repeating = true }
)

-- Mic mute has no kanata equivalent, but remains a normal XF86 binding.
hl.bind(
  "XF86AudioMicMute",
  hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
  { locked = true, repeating = true }
)

hl.bind(
  "XF86MonBrightnessUp",
  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),
  { locked = true, repeating = true }
)
hl.bind(
  "XF86MonBrightnessDown",
  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),
  { locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- OpenWhispr toggle. This is the single source of truth: the app also writes
-- hypr/openwhispr-binds.conf (hyprlang syntax), but that file is never loaded —
-- hyprland.conf (which source()s it) is not read when hyprland.lua exists — so
-- the app's rewrites have no effect. If OpenWhispr changes its bind, copy it
-- here by hand. (The stray file may reappear in the dir; ignore it.)
hl.bind(
  "CTRL + Super_L",
  hl.dsp.exec_cmd(
    "dbus-send --session --type=method_call --dest=com.openwhispr.App /com/openwhispr/App com.openwhispr.App.Toggle"
  )
)