# Wiki log

Append-only журнал операций над wiki. Новое — снизу. Префиксы для парсинга:
`INIT` · `INGEST` · `UPDATE` · `LINT` · `DECISION`.

- 2026-07-01 INIT — создан скелет wiki: index, CONVENTIONS, log, компонентные
  (kanata, scripts, hypr, kitty, nvim, zsh, waybar, yazi) и сквозные (keymap,
  sessions, theming, decisions, bootstrap) страницы-заглушки. Добавлен корневой
  CLAUDE.md с правилами ingest/update/lint.
- 2026-07-01 DECISION — удалено Windows/WSL-легаси (autohotkey, glazewm, wezterm,
  start.bat; glazewm/WSL-алиасы и winuser в zshrc; TERMCMD→kitty). См. decisions.md.
