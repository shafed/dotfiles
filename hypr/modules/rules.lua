local browser = "helium-browser"

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Workspace-Rules/

hl.window_rule({
  -- Ignore maximize requests from all apps. You'll probably like this.
  name = "suppress-maximize-events",
  match = { class = ".*" },

  suppress_event = "maximize",
})

hl.window_rule({
  -- Fix some dragging issues with XWayland
  name = "fix-xwayland-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },

  no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
  name = "move-hyprland-run",
  match = { class = "hyprland-run" },

  move = { 20, "monitor_h-120" },
  float = true,
})

hl.window_rule({
  name = "kitty to w1",
  match = { class = "kitty" },
  workspace = "1",
})

hl.window_rule({
  name = "telegram to w5",
  match = { class = "org.telegram.desktop" },
  workspace = "5",
})

hl.window_rule({
  name = "satty float almost-fullscreen",
  match = { class = "com.gabm.satty" },

  float = true,
  size = { "95%", "95%" },
  center = true,
})

hl.workspace_rule({ workspace = "2", on_created_empty = browser })
