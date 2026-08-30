-- fyne/GLFW apps (adrop) have no Wayland backend, so they stay on XWayland;
-- with force_zero_scaling they scale themselves via FYNE_SCALE.
hl.env("FYNE_SCALE", "1.6")
