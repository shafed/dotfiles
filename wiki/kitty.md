---
title: kitty
type: component
updated: 2026-07-01
covers:
  - kitty/
---

# kitty

🌱 Заглушка. См. [sessions](sessions.md) и [theming](theming.md).

## О чём написать

- [ ] ⚠️ `kitty.conf` ~3000 строк, но в основном закомментированные дефолты
      (`kitten themes` дамп). Описать, что из этого реально кастомизировано,
      чтобы агент не читал всё.
- [ ] Нативные сессии (`sessions/`) — миграция с tmux, см.
      [sessions](sessions.md).
- [ ] `quick-access-terminal-{center,right}.conf` — QAT-панели для пикеров.
- [ ] `get_layout.py` / `pass_keys.py` — что делают и зачем (kanata-интеграция).
- [ ] `current-theme.conf` + gruvbox, см. [theming](theming.md).
