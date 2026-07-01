---
title: zsh
type: component
updated: 2026-07-01
covers:
  - zsh/zshrc
  - zsh/zprofile
---

# zsh

🌱 Заглушка.

## О чём написать

- [ ] oh-my-zsh база; что подключено.
- [ ] Функции: `y()` (yazi cd), `set_im`/`get_im` (im-select), `_aichat_zsh`.
- [ ] Алиасы: nvim (`vi`/`vif`/`vip`/`neobean`), yazi, task (`ta`), aichat (`ai`).
- [ ] env: EDITOR/VISUAL=nvim, BROWSER=firefox, TERMCMD=kitty, PATH-добавки.
- [ ] ⚠️ Мёртвые алиасы после чистки Windows: `sync-vi`/`sv` копируют в
      несуществующий `~/dotfiles/.config/` (nvim теперь симлинк) — вычистить.
- [ ] ⚠️ Секрет `OPENROUTER_API_KEY` захардкожен — вынести из репо, ротировать.
