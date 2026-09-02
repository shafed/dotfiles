hl.config({
  cursor = {
    -- 2 = auto: Hyprland now renders a correct hardware cursor here (verified
    -- 2026-09-02), so screenshots no longer need the software-cursor-then-
    -- toggle-to-hardware dance kanata/screenshot-*.sh used to do.
    no_hardware_cursors = 2,
  },

  -- XWayland can't do fractional scaling on the 1.6x laptop panel. Keep the
  -- buffer at 1x and let individual X11 toolkits scale themselves instead.
  xwayland = {
    force_zero_scaling = true,
  },
})
