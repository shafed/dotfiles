---
title: kitty
type: component
updated: 2026-07-01
covers:
  - kitty/
---

# kitty

🚧 Терминал и мультиплексор (нативные сессии вместо tmux). Сессии подробно —
[[sessions]]; цвета — [[theming]].

## ⚠️ Gotcha: kitty.conf ~3000 строк, но кастомизация — единицы строк

`kitty/kitty.conf` — это дамп `kitten themes` со ВСЕМИ дефолтами в комментариях.
НЕ читай его целиком. Реальные (раскомментированные) настройки достаются так:

```sh
grep -vE '^\s*#' kitty/kitty.conf | grep -vE '^\s*$'
```

Всё содержательное сводится к:

- **Шрифт/курсор**: JetBrains Mono 14, `cursor_blink_interval 0`, `cursor_trail 1`
  (след курсора).
- **Скролл/мышь**: `wheel_scroll_multiplier 3.0`, `copy_on_select yes`,
  `mouse_hide_wait -1` (курсор не прячется).
- **Внешний вид**: `hide_window_decorations yes`, `tab_bar_style powerline`,
  `include current-theme.conf` (gruvbox, см. ниже), границы в тон теме.
- **Remote control**: `allow_remote_control yes` + `listen_on unix:/tmp/kitty-{kitty_pid}`
  — включён РАДИ пикеров сессий и QAT-панелей (общаются через `kitten @`).
- **Сессии**: `startup_session .../home.kitty-session` (kitty стартует БЕЗ tmux,
  коммит `65d18e9`), `tab_bar_filter session:~ ...`, шаблон заголовка вкладки
  показывает имя сессии. Всё про сессии — в [[sessions]].
- **`kitty_mod+i`** — открыть scrollback в nvim-пейджере (yank из истории панели).

## `pass_keys.py` — контекстная навигация Ctrl-h/j/k/l

`map ctrl+h/j/k/l → kitten pass_keys.py`. ⚠️ Ключевая идея: **одни и те же клавиши
служат и навигацией по окнам kitty, и внутри дочерней программы**. Киттен смотрит
на foreground-процесс окна: если это `nvim` ИЛИ `fzf` (дефолтный regex
`n?vim|fzf`) — клавиша прокидывается внутрь (nvim-сплиты, движение по списку fzf),
иначе — `boss.active_tab.neighboring_window(direction)` двигает фокус между окнами
kitty. Regex переопределяется 4-м аргументом в биндинге. Это заменяет
Hyprland-навигацию по окнам внутри терминала (коммит `24b289d`).

## `get_layout.py` — имя текущего layout

Крошечный кастомный киттен (`handle_result` возвращает `active_tab.current_layout.name`,
`no_ui`). Используется скриптами/сессиями, чтобы узнать текущую раскладку панелей
kitty из-под `kitten @`. Не путать с раскладкой клавиатуры (той ведает kanata).

## QAT-панели (quick-access-terminal)

Выпадающие панели-оверлеи для fzf-пикеров ([[scripts]]: bookmarks/youtube):

- `quick-access-terminal-center.conf` — центрированная (`edge center-sized`,
  22×90, `background_opacity 0.85`), с полным дублированием gruvbox-палитры через
  `kitty_override` и `tab_bar_style=hidden`.
- `quick-access-terminal-right.conf` — прижата к правому краю, без прозрачности,
  таб-бар скрыт. ⚠️ Gotcha: `<M-t>` внутри переключает геометрию/скрывает таб-бар
  плавающей панели (коммиты `4c315a0`/`b0cad6e`).

## current-theme.conf

Gruvbox Material Dark Medium (`background #282828` в тон nvim — коммит `e5557fc`).
Подробнее и почему именно этот источник цветов — [[theming]].
