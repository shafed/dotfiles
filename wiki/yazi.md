---
title: yazi
type: component
updated: 2026-07-01
covers:
  - yazi/
---

# yazi

🚧 Файловый менеджер (TUI). Тема — [[theming]]; лончится из [[kitty]]/сессий.

## Плагины (какие реально подключены)

Зависимости зафиксированы в `package.toml` (pinned rev+hash через `ya pack`),
код лежит в `plugins/`. Активно используются (биндинги в `keymap.toml`):

- **relative-motions** — `1`–`9` как относительные motion'ы (vim-стиль прыжки по
  списку); настроен в `init.lua` (`relative_absolute`, `enter_mode = cache_or_first`).
- **smart-enter** — `l` и `<Enter>`: заходит в папку ИЛИ открывает файл (одна клавиша).
- **smart-paste** — `p`: вставка в наведённую папку без захода в неё.
- **jump-to-char** — `f`: прыжок к файлу по первой букве.
- **lazygit** — `g i`: открыть lazygit в текущем каталоге.
- **sudo** — префикс `R ...`: paste/rename/link/hardlink/create/remove/chmod от
  root (обёртки над операциями с повышением прав).
- **autosession** — `init.lua` вызывает `:setup()`; `<Esc>`-подобный
  `save-and-quit` в keymap. Сохраняет/восстанавливает состояние сессии yazi.
- **rich-preview** — превью markdown/json/csv/ipynb (примеры в `plugins/rich-preview.yazi/examples`).

⚠️ Gotcha: в `plugins/` есть **`clipboard.yazi` (пустая папка — не установлена)**
и `smart-enter`/`smart-paste`, но НЕ полагайся на наличие папки как на «включён» —
источник истины, что подключено, это `package.toml` + биндинги в `keymap.toml`.
`z`/`Z` (fzf/zoxide) — встроенные плагины yazi, не из этого списка.

## yazi.toml

Три колонки (`ratio [1,4,3]`), скрытые файлы по умолчанию выключены. Openers:
PDF — просмотр через `sioyek` (`LIBGL_ALWAYS_SOFTWARE=1` — обход GL-проблемы,
коммит `ae6cf4b`), аннотирование — `xournalpp`.

## Тема

`theme.toml`: и `dark`, и `light` → `gruvbox-dark` (flavor `bennyyip/gruvbox-dark`
в `flavors/`). ⚠️ Gotcha: yazi НЕ переключается на светлую тему — обе привязки
указывают на один тёмный flavor (осознанно, «всегда gruvbox dark»). См.
[[theming]].
