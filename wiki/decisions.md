---
title: decisions
type: topic
updated: 2026-07-01
---

# decisions — крупные решения и отвергнутые альтернативы

🌱 Заглушка. Ключевая страница «почему так сделано». Каждая запись:
**решение → причина → отвергнутая альтернатива → дата**.

## Зафиксированные

### tmux → kitty native sessions
- Ушли с tmux prefix (C-s) на нативные сессии kitty; kanata шлёт C-S-хоткеи.
- [ ] Причина и trade-offs — наполнить. См. [sessions](sessions.md).

### kanata как единый keymap-движок
- Home-row mods, chords, слои и force-layout централизованы в kanata, а не
  размазаны по hypr/kitty.
- [ ] Причина — наполнить. См. [kanata](kanata.md), [keymap](keymap.md).

### Удаление Windows/WSL-легаси (2026-07-01)
- Удалены `autohotkey/`, `glazewm/`, `wezterm/`, `start.bat`; вычищены glazewm/WSL
  алиасы и `winuser`/`explorer.exe`/`powershell.exe` из zshrc; `TERMCMD` → kitty.
- Причина: машина теперь только Arch/Hyprland; Windows-часть больше не нужна.
- `awesome/` оставлен как устаревший, но пока не удалён (осознанно).

### Ручные симлинки вместо stow/install-скрипта
- Конфиги подключаются вручную симлинками `~/.config → ~/dotfiles`.
- [ ] Причина (простота?) и когда пересмотреть — наполнить. См. [bootstrap](bootstrap.md).
