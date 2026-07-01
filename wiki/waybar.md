---
title: waybar
type: component
updated: 2026-07-01
covers:
  - waybar/config.jsonc
  - waybar/style.css
---

# waybar

🚧 Статус-бар для Hyprland. Цвета — [[theming]].

## Компоновка и модули

Бар сверху, высота 30. Раскладка:

- **left**: `hyprland/workspaces` (иконки, `all-outputs`), `hyprland/mode`,
  `hyprland/scratchpad`, `custom/media`.
- **center**: `hyprland/window` (заголовок активного окна).
- **right**: `mpd`, `pulseaudio`, `network`, `power-profiles-daemon`, `backlight`,
  `hyprland/language` (индикатор раскладки), `battery` + `battery#bat2`, `clock`,
  `tray`, `custom/power`.

⚠️ Gotcha: часть модулей закомментирована в `modules-right` (`idle_inhibitor`,
`cpu`, `memory`, `temperature`, `keyboard-state`) — их конфиги в файле остаются,
но в баре они не показываются. Не удивляйся «мёртвым» блокам конфига.

## Кастомные модули (скрипты/меню)

- **`custom/media`** — `exec: $HOME/.config/waybar/mediaplayer.py` (JSON,
  playerctl/MPRIS). ⚠️ Скрипт `mediaplayer.py` НЕ лежит в этом репо (ожидается в
  `~/.config/waybar/`); в dotfiles только `config.jsonc` и `style.css`.
- **`custom/power`** — кнопка `⏻` с меню на клик (`menu-file:
  power_menu.xml`, тоже вне репо): shutdown/reboot/suspend/hibernate.
- **`hyprland/language`** — показывает раскладку, которую переключает kanata
  (см. [[keymap]]); waybar только отображает состояние.

## style.css — gruvbox

Цвета заданы через `@define-color gb_*` (полная gruvbox-палитра: bg `#282828`,
fg `#d4be98`, акценты red/green/yellow/orange/blue/purple/aqua). Бар полупрозрачный
(`rgba(40,40,40,0.88)`). Это локальная копия палитры (не общий источник) — тот же
приём, что в kitty/nvim; единый гайд по цветам — [[theming]].
