local wezterm = require 'wezterm'
local prev_layout = "us"

wezterm.on('window-focus-changed', function(window, pane)
    if window:is_focused() then
        -- Сохраняем текущую раскладку (например, 'ru')
        local success, stdout, _ = wezterm.run_child_process({"xkb-switch", "-p"})
        if success then prev_layout = stdout:gsub("%s+", "") end
        
        -- Переключаем на английский (us)
        wezterm.run_child_process({"xkb-switch", "-s", "us"})
    else
        -- Возвращаем предыдущую при потере фокуса
        wezterm.run_child_process({"xkb-switch", "-s", prev_layout})
    end
end)

return {
    -- --- Среда ---
    set_environment_variables = {
        TERM = "xterm-256color",
    },

    -- Tmux
    default_prog = { 'tmux', 'new-session', '-A', '-s', 'main' },

    -- --- Оболочка: сразу Debian + zsh как login-shell ---

    -- --- Шрифт ---
    font = wezterm.font_with_fallback({
        { family = "JetBrainsMonoNerdFontMono", weight = "Regular" }, -- твой основной
        "Noto Color Emoji",                            -- эмодзи
        "DejaVu Sans",                                 -- редкие символы
    }),
    harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' },
    font_size = 12.0,

    -- --- Цвета ---
    colors = {
        foreground = "#dfbf8e",
        background = "#282828",
        ansi = {
            "#665c54", "#ea6962", "#a9b665", "#e78a4e",
            "#7daea3", "#d3869b", "#89b482", "#dfbf8e",
        },
        brights = {
            "#928374", "#ea6962", "#a9b665", "#e3a84e",
            "#7daea3", "#d3869b", "#89b482", "#dfbf8e",
        },
    },

    -- --- Окно ---
    hide_tab_bar_if_only_one_tab = true,
    window_close_confirmation = "NeverPrompt",
    window_decorations = "RESIZE",
    max_fps = 120
}
