---
title: zsh
type: component
updated: 2026-07-01
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# zsh

🚧 База oh-my-zsh + ручной автоустановки плагинов. Основной файл — `../zsh/zshrc`
(симлинк `~/.zshrc → ~/dotfiles/zsh/zshrc`, см. [[bootstrap]]).

## Почему так устроено

- **oh-my-zsh, тема `gruvbox-material`** — единый gruvbox во всех инструментах
  (kitty/nvim/fzf), см. [[theming]]. Цвета `zsh-syntax-highlighting`,
  `LS_COLORS`, `FZF_DEFAULT_OPTS`, `BAT_THEME`, `LESS_TERMCAP_*` захардкожены
  gruvbox-material dark medium прямо в zshrc, чтобы совпадать с kitty-темой.
- **Плагины автоустанавливаются** (`zsh-autosuggestions`,
  `zsh-syntax-highlighting`, `zsh-vi-mode`): при отсутствии `$ZSH` или плагина
  zshrc клонирует их сам. Причина — на новой машине нет install-скрипта
  ([[bootstrap]]), поэтому bootstrap встроен в сам конфиг.
- **`bindkey -v` + zsh-vi-mode**: vi-режим в шелле; `gh`/`gl` перебиндены на
  начало/конец строки, чтобы совпадать с nvim-мышечной памятью.
- **Alt-t (`kitty_other_window`)** зеркалит nvim `<M-t>`: прыжок в соседнее kitty
  окно + `goto_layout stack`. `KITTY_WINDOW_DIRECTION="right"` обязан совпадать с
  `vim.g.tmux_pane_direction` в nvim. См. [[kitty]], [[sessions]].
- **Alt-e (`_aichat_zsh`)** — прогоняет текущий буфер через `aichat -r %shell%`
  и подставляет команду.

## Функции

- `y()` — обёртка над yazi: пишет cwd во временный файл и `cd` в него при выходе
  (навигация файловым менеджером меняет каталог шелла).
- `kitty_other_window()` — см. выше, интеграция с kitty-сплитами.

## Env и алиасы

- `EDITOR`/`VISUAL=nvim`, `BROWSER=firefox`, `TERMCMD=kitty` (после удаления
  Windows, см. [[decisions]]).
- nvim: `vi`=nvim, `vif`/`vip` — открыть конфиг/plugins; `neobean`/`nb` —
  альтернативный `NVIM_APPNAME` (см. [[nvim]]).
- прочее: `y`=yazi, `ta`/`tl`=taskwarrior, `ai`=aichat, `pulldeez`=git pull
  dotfiles + resource, `cdd`=`z -`.
- `cd` переопределён на **zoxide** (`zoxide init zsh --cmd cd`).

⚠️ Gotcha: zoxide-init обязан идти **последним** в zshrc. OMZ ставит свои
chpwd-хуки, из-за чего `zoxide doctor` даёт ложное «initialized too early» —
глушится через `_ZO_DOCTOR=0`.

## Грабли для чистки

✅ исправлено 2026-07-01: **мёртвые алиасы `sync-vi`/`sv`** (`cp -r ~/.config/nvim/
~/dotfiles/.config/`) удалены. Каталог `~/dotfiles/.config/` не существовал, а nvim
теперь сам симлинк `~/.config/nvim → ~/dotfiles/nvim` ([[bootstrap]]).

✅ исправлено 2026-07-01: **im-select машинерия удалена** —
`IM_SELECT_CMD="/mnt/c/windows/im-select.exe"` (остаток WSL) вместе с `set_im`/
`get_im`/`zle-im-keymap-select` и её регистрацией. Раскладкой в этой системе
занимается kanata ([[keymap]]), zsh-механизм был лишним.

✅ исправлено 2026-07-01: **секреты удалены** из `../zsh/zshrc` —
`OPENROUTER_API_KEY` и `TODOIST_API_TOKEN` (строки экспорта вычищены). Ключи
остаются в git-истории, поэтому их всё равно стоит **ротировать**. Примечание:
`TODOIST_API_TOKEN` больше не экспортируется, так что todoist-интеграция,
завязанная на него, перестанет работать без внешнего источника токена.

✅ исправлено 2026-07-01: **дубль `export PATH="$HOME/.local/bin:$PATH"`** убран —
осталась одна строка.
