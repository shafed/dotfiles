---
title: bootstrap
type: topic
updated: 2026-07-01
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# Bootstrap — развёртывание на новой машине

🌱 Заглушка. Наполнить.

Платформа: Arch Linux + Hyprland. Windows/WSL-часть удалена (см. [decisions](decisions.md)).

## Механизм деплоя

Установочного скрипта **нет**. Конфиги подключаются **ручными симлинками** из
`~/.config/<tool> → ~/dotfiles/<tool>`. Проверено на текущей машине:
`hypr`, `kitty`, `nvim`, `kanata`, `waybar`, `yazi` симлинкнуты в `~/.config/`;
`~/.zshrc → ~/dotfiles/zsh/zshrc`.

## TODO наполнить

- [ ] Точный список пакетов (pacman/AUR): hyprland, kanata, kitty, waybar, yazi,
      nvim, zsh, oh-my-zsh, fzf, yt-dlp, brotab, …
- [ ] Полный список симлинков (одной таблицей source → target).
- [ ] Порядок установки и зависимости между шагами.
- [ ] Что requires ручной настройки вне репо (Firefox-расширение brotab,
      systemd user-сервисы, im-select/xkb).
- [ ] Секреты: `OPENROUTER_API_KEY` сейчас захардкожен в zshrc — вынести из репо.

⚠️ Gotcha: рассмотреть `stow` или install-скрипт, если симлинков станет много —
сейчас отвергнуто в пользу простоты (см. [decisions](decisions.md)).
