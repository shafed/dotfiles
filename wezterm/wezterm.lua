local wezterm = require 'wezterm'

wezterm.on('window-focus-changed', function(window, pane)
    if os.getenv('XDG_SESSION_TYPE') == 'x11' then
        -- не ломает опции и порядок раскладок
        wezterm.run_child_process({ 'xkb-switch', '-s', 'us' })
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
        { family = "Hack Nerd Font", weight = "Regular" }, -- твой основной
        "Noto Color Emoji",                            -- эмодзи
        "DejaVu Sans",                                 -- редкие символы
    }),
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
    window_decorations = "RESIZE"
}
