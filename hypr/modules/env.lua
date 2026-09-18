hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Force Qt apps onto native Wayland: under XWayland fractional scale (1.6)
-- just upscales the 1x buffer, so Qt apps render pixelated.
hl.env("QT_QPA_PLATFORM", "wayland")
-- Java/Swing assumes a reparenting WM; without this, Swing windows (e.g.
-- Scilab's GUI) render as blank panes on Hyprland.
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
