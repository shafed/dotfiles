hl.config({
  input = {
    kb_layout = "us,ru",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",

    follow_mouse = 1,

    sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.3,
    },
  },
})

-- See https://wiki.hypr.land/Configuring/Basics/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
