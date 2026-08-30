hl.config({
  cursor = {
    -- Hardware workaround: removing this makes the cursor invisible/corrupted.
    no_hardware_cursors = true,
  },

  -- XWayland can't do fractional scaling on the 1.6x laptop panel. Keep the
  -- buffer at 1x and let individual X11 toolkits scale themselves instead.
  xwayland = {
    force_zero_scaling = true,
  },
})
