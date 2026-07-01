# Wiki log

Append-only журнал операций над wiki. Новое — снизу. Префиксы для парсинга:
`INIT` · `INGEST` · `UPDATE` · `LINT` · `DECISION`.

- 2026-07-01 INIT — создан скелет wiki: index, CONVENTIONS, log, компонентные
  (kanata, scripts, hypr, kitty, nvim, zsh, waybar, yazi) и сквозные (keymap,
  sessions, theming, decisions, bootstrap) страницы-заглушки. Добавлен корневой
  CLAUDE.md с правилами ingest/update/lint.
- 2026-07-01 DECISION — удалено Windows/WSL-легаси (autohotkey, glazewm, wezterm,
  start.bat; glazewm/WSL-алиасы и winuser в zshrc; TERMCMD→kitty). См. decisions.md.
- 2026-07-01 UPDATE — наполнены kanata.md, keymap.md, sessions.md (keymap-домен): opposite-hand HRM (-release, neutral/timeout hold), chords-тайминги 35/80 и trade-off rolls-vs-mod-combos, symbol US-xkb-wrap, kitty-send взамен tmux prefix, apps force-English, numplain2; сквозная граница kanata↔hypr(Super)↔kitty(C-S-) + таблица конфликтов; миграция tmux→kitty sessions, nvim-edit-handler/obsidian, зафиксировано что daily-notes.sh уже нативно-kitty (tmux только в устаревшем комментарии).
- 2026-07-01 UPDATE — наполнена scripts.md (scripts-домен): fzf-пикеры (долгоживущий QAT-toggle, brotab-фокус вкладки, ws-роутинг мимо YouTube-ws, leading-debounce подсказок), training logbook (mood via YAML frontmatter, эволюция поиска fuzzy→ranked→debounce, nvim-edit-links, xlsx cell-colors→mood) и прочее (daily-notes нативно-kitty, symlayout-watch↔kanata).
- 2026-07-01 UPDATE — наполнены hypr.md, kitty.md, waybar.md, yazi.md, theming.md (desktop-домен): минимализм hypr + ленивый запуск браузера, kitty.conf ~3000 строк = дамп дефолтов (дан grep для реальных ~40), pass_keys/get_layout, waybar-модули (mediaplayer/power вне репо), yazi-плагины (clipboard пуст), тема статична — gruvbox dark продублирован вручную, darkman-заготовка пуста, hyprsunset только гамма.
- 2026-07-01 UPDATE — наполнены zsh.md, nvim.md, bootstrap.md, decisions.md (shell/editor-домен): oh-my-zsh + встроенный bootstrap плагинов, LazyVim + logbook-интеграция, таблица симлинков, decisions с trade-offs (tmux→kitty, kanata-движок, симлинки-vs-stow). Находки для чистки: мёртвый im-select.exe (/mnt/c/...), sync-vi/sv в несуществующий путь, легаси-симлинки tmux/wezterm, два секрета в git (OPENROUTER_API_KEY, TODOIST_API_TOKEN).
- 2026-07-01 LINT — координатор: все внутренние ссылки резолвятся, заглушек не осталось; index обновлён (🌱→🚧, статус, легенда) и исправлена строка theming (динамического light/dark нет).
- 2026-07-01 UPDATE — чистка: удалены секреты и мёртвые строки в zshrc (im-select/mnt-c, sync-vi/sv, дубль PATH), сняты легаси-симлинки ~/.config/{tmux,wezterm}.
- 2026-07-01 UPDATE — все внутренние ссылки wiki переведены на [[wikilinks]] (кроме внешней ../CLAUDE.md).
- 2026-07-01 DECISION — основные инструкции агента перенесены в AGENTS.md (кросс-агентный стандарт, читается и Codex); CLAUDE.md сведён к указателю на него + Claude-специфика.
