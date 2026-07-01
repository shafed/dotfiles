---
title: scripts
type: component
updated: 2026-07-01
covers:
  - scripts/
---

# scripts

🌱 Заглушка. Самая живая и сложная часть репо — приоритет наполнения.

## fzf-пикеры (общий `lib.sh`)

`lib.sh` — общие хелперы, **sourced не executed**. Пикеры запускаются как
kitty-панели.

- [ ] `apps.sh` — запуск приложений.
- [ ] `bookmarks.sh` — поиск закладок; фокусит существующую FF-вкладку через brotab.
- [ ] `search.sh` — веб-поиск (выделен из bookmarks.sh).
- [ ] `youtube.sh` / `youtube-qat.sh` — yt-dlp/xdg-open/кэш-гочи.
- [ ] Что именно в `lib.sh` общее и почему пикеры на нём.

## Training logbook

- [ ] `generate_logbook.py` (~1000 строк) — HTML-генератор; fuzzy/ranked search,
      debounce, exercise history, mood via YAML frontmatter, note-links.
- [ ] `import_training_log_xlsx.py` — импорт истории из `Training_Log.xlsx`,
      включая цвета ячеек → mood-теги.
- [ ] `nvim-edit-handler.sh` — обработчик `nvim-edit://` ссылок из logbook: открывает
      файл в kitty "obsidian"-сессии как новую вкладку nvim.
- [ ] Связь с nvim-интеграцией (см. [nvim](nvim.md)) и obsidian-сессией
      (см. [sessions](sessions.md)).

## Прочее

- [ ] `daily-notes.sh` — today's note в per-day tmux-сессии (⚠️ ещё tmux? сверить с
      миграцией на kitty native, см. [sessions](sessions.md)).
- [ ] `symlayout-watch.sh` — force US xkb пока активны символьные слои kanata
      (см. [kanata](kanata.md)).
