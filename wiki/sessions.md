---
title: sessions
type: topic
updated: 2026-07-01
covers:
  - kitty/sessions
  - kitty/scripts
  - scripts/nvim-edit-handler.sh
  - scripts/daily-notes.sh
---

# sessions — нативные kitty-сессии

🚧 Частично наполнено. См. [[kanata]] (как драйвятся) и [[keymap]].

## Миграция tmux → kitty native sessions

Раньше сессии/панели держал tmux (prefix `C-s`). Перешли на **нативные
kitty-сессии** (`goto_session`, session-файлы в
[`../kitty/sessions/`](../kitty/sessions/)). Почему:

- один слой меньше — не нужен tmux поверх kitty; управление (сплиты, вкладки,
  скроллбэк в nvim) уже есть в kitty.
- kitty-нативность: `tab_bar_filter session:~ or session:^$` показывает только
  вкладки текущей сессии; `goto_session` создаёт-или-переключает по имени файла.
- session-файл декларативен: `layout`, `cd`, `launch --title ...`, `focus`.

Trade-off: часть tmux-удобств (persistence раскладки, «reopen last session»)
пришлось воспроизводить руками. Например daily-note-сессия эмулирует старое
«нажать s на стартовом экране» через `require("persistence").load()` в nvim.

## Как kanata драйвит сессии

kanata из слоя `apps` шлёт `C-S-`-хоткеи (`kitty_mod = ctrl+shift`) через
`deftemplate kitty-send` (фокус kitty → задержка `aterm-settle` → хоткей). См.
[[kanata]]. Маппинг (kitty.conf, секция «Session & navigation»):

- `apps+h → C-S-a` = home, `apps+t → C-S-2` = todos, `apps+w → C-S-w` = downloads,
  `apps+o → C-S-o` = obsidian, `apps+p → C-S-c` = projects, `apps+d → C-S-d` = dotfiles.
- `apps+b → A-tab` = last session (`goto_session -1`).
- `apps+e → C-S-f` = zoxide-picker, `apps+c → C-S-s` = list-sessions-picker,
  `apps+r → C-S-1` = daily note.

## kitty-zoxide-session

[`../kitty/scripts/kitty-zoxide-session.sh`](../kitty/scripts/kitty-zoxide-session.sh)
(`C-S-f`, overlay) — переключение/создание сессии по каталогу через zoxide.
Поддерживает `--named <name>` для адресного вызова (используется nvim-edit-handler).

## obsidian-сессия и training logbook

Сессия `obsidian` ([`../kitty/sessions/obsidian.kitty-session`](../kitty/sessions/obsidian.kitty-session))
запускает nvim в `~/obsidian` после `git pull`, восстанавливая раскладку через
persistence.

Логбук тренировок открывает файлы через ссылки `nvim-edit://<path>`, которые
ловит [`../scripts/nvim-edit-handler.sh`](../scripts/nvim-edit-handler.sh) (см.
[[scripts]]). Он:
1. находит основной (не floating) kitty-сокет,
2. переключается/создаёт сессию `obsidian` через `kitty-zoxide-session.sh --named obsidian`,
3. открывает файл новой вкладкой в **уже запущенном** nvim этой сессии — сначала
   через `--server <sock> --remote-tab`, иначе fallback на `send-text` `:tabedit`.

⚠️ Gotcha: nvim-сокет ищется перебором PID вокруг pid nvim (`delta 0,1,-1,2,...`),
т.к. точный `nvim.<pid>.0` не всегда совпадает с pid форграунд-процесса. Хрупкое
место — если nvim не поднял `--listen`-сокет, срабатывает send-text fallback.

## daily-notes.sh — статус (tmux уже НЕ используется)

⚠️ Факт на 2026-07-01: shebang-**комментарий** в
[`../scripts/daily-notes.sh`](../scripts/daily-notes.sh) всё ещё говорит «tmux
session», но код tmux **не использует**. Скрипт генерирует временный
kitty-session-файл в `~/.cache/kitty-sessions/daily-<note>.kitty-session` и
вызывает `kitten @ action goto_session`. Одна kitty-сессия на день, nvim с
`persistence.load()`. Комментарий устарел — можно поправить при случае, поведение
уже нативно-kitty.

## Сплиты и layout

Сплиты: `C-S--` = hsplit, `C-S-\` = vsplit (`launch --location=... --cwd=current`).
`C-h/j/k/l` — контекстная навигация split/window через `pass_keys.py` (в nvim/fzf
проброс, иначе перемещение между окнами kitty).

⚠️ Gotcha (`tab.layout`): tab-title и session-фильтр завязаны на
`session_name`/`tab.active_wd`; session-файлы задают `layout` (обычно `tall`) явно
на первой строке. Прежний `M-t`-toggle сплита в текущем kitty.conf отсутствует —
сплиты теперь через `C-S--` / `C-S-\`.
