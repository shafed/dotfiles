---
title: bootstrap
type: topic
updated: 2026-07-01
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# Bootstrap — развёртывание на новой машине

🚧 Платформа: Arch Linux + Hyprland. Windows/WSL-часть удалена (см.
[[decisions]]). Автозапуск сессии — `../zsh/zprofile`: на tty1 без
`$DISPLAY` делает `exec start-hyprland`.

## Механизм деплоя

Установочного скрипта **нет**. Конфиги подключаются **ручными симлинками**
`~/.config/<tool> → ~/dotfiles/<tool>` (плюс `~/.zshrc`). Причина выбора и
отвергнутый `stow` — см. [[decisions]].

Симлинки, подтверждённые на текущей машине (`ls -la ~/.config/`):

| target (~/.config/) | source (~/dotfiles/) |
| --- | --- |
| `hypr` | `hypr` |
| `kitty` | `kitty` |
| `nvim` | `nvim` |
| `kanata` | `kanata` |
| `waybar` | `waybar` |
| `yazi` | `yazi` |
| `darkman` | `darkman` |
| `lazygit` | `lazygit` |
| `sioyek` | `sioyek` |
| `zathura` | `zathura` |
| `systemd` | `systemd` |
| `xray` | `xray` |
| `~/.zshrc` | `zsh/zshrc` |

✅ исправлено 2026-07-01: легаси-симлинки `~/.config/tmux` и `~/.config/wezterm`
(оба указывали в dotfiles) сняты — переход на kitty native sessions завершён
(см. [[decisions]]). Каталоги `tmux/`/`wezterm/` в репозитории
не трогались.

## Пакеты

Подтверждаются конфигами репозитория (не выдумано): `hyprland`, `kanata`,
`kitty`, `waybar`, `yazi`, `neovim`, `zsh` + `oh-my-zsh` (автоустановка из
zshrc), `zoxide`, `fzf`, `darkman`, `lazygit`, `sioyek`, `zathura`, `xray`.
Из [[scripts]]/[[zsh]] видны также `yt-dlp`, `brotab`, `aichat`,
`taskwarrior`, `todoist`, `copyq`, `python` (generate_logbook.py).

TODO: точные имена пакетов pacman vs AUR и версии — не зафиксированы (проверять
при развёртывании).

## Ручная настройка вне репо (TODO уточнить)

- Firefox-расширение для `brotab` (bookmarks.sh фокусит вкладку), см.
  [[scripts]].
- systemd user-сервисы из `~/.config/systemd`.
- Раскладки: kanata (см. [[keymap]]). Старый `im-select` в [[zsh]]
  (Windows-путь) удалён 2026-07-01.
- oh-my-zsh и custom-плагины подтягиваются автоматически при первом запуске
  zshrc (install-скрипт не нужен).

✅ исправлено 2026-07-01: секреты (`OPENROUTER_API_KEY`, `TODOIST_API_TOKEN`)
удалены из `../zsh/zshrc`. Ключи остаются в git-истории — ротировать
(см. [[zsh]]).
