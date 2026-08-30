hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Force Qt apps onto native Wayland: under XWayland fractional scale (1.6)
-- just upscales the 1x buffer, so Qt apps render pixelated.
hl.env("QT_QPA_PLATFORM", "wayland")
