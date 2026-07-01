# CLAUDE.md

Основные инструкции для этого репозитория — в [`AGENTS.md`](AGENTS.md) (общий
файл для всех AI-агентов: Claude Code, Codex и т.п.). **Прочитай его.** Ключевое:
перед работой над конфигом читай `wiki/index.md` и поддерживай wiki
(ingest/update/lint).

Claude-специфичное:

- Не добавляй `Co-Authored-By: Claude` в git-коммиты.
- Точечные настройки прав Claude Code — в локальных `.claude/` внутри `kanata/`,
  `scripts/`, `nvim/lua/config/`.
