---
title: scripts
type: component
updated: 2026-07-01
covers:
  - scripts/
---

# scripts

🚧 Самая живая и сложная часть репо. Три блока: fzf-пикеры, training logbook,
прочее.

## fzf-пикеры (общий `lib.sh`)

Все пикеры (`apps.sh`, `bookmarks.sh`, `search.sh`, `youtube.sh`) — это
fzf-loop'ы, живущие внутри **долгоживущей** kitty quick-access панели (QAT). Их
общий движок — `lib.sh`, который **sourced, а не executed**: он не запускается
как программа, а подключается через `source lib.sh` и потому обязан быть
безопасным под `set -euo pipefail`.

**Почему панель долгоживущая, а не запуск на каждый хоткей.** Панель
single-instance (`--instance-group`), поэтому повторная посылка той же launch-
команды kitty не плодит второй терминал, а **переключает видимость** уже
запущенного (`toggle_qat`). Пикер-процесс остаётся жить между показами
(`run_picker` — вечный `while`), так что открытие мгновенное — fzf не
cold-start'ится заново. Esc в fzf трактуется как «спрятать и перевзвестись», а не
«выйти».

Ключевое в `lib.sh`:
- `launch_qat` / `toggle_qat` — показ/скрытие панели через remote-control сокет
  **главного** kitty (`main_kitty_socket` фильтрует `/tmp/kitty-*` по имени
  процесса, чтобы случайно не таргетить другой плавающий терминал).
- `switch_to_english` — форсит раскладку `us` (индекс 0 в `us,ru`) через
  `hyprctl switchxkblayout`, чтобы fzf-запросы печатались латиницей даже при
  активной русской. Вызывается в `launch_qat` на **каждый** показ, потому что при
  toggle собственный `switch_to_english` пикера (он только на cold-start) не
  срабатывает.
- `FZF_DEFAULT_OPTS` захардкожен под gruvbox: QAT бежит под bash и не наследует
  интерактивный zsh-конфиг fzf.
- Firefox-хелперы (`firefox_window_off_workspace`, `open_in_new_firefox_window`,
  `move_firefox_when_up`) — общая логика доставки вкладок мимо YouTube-воркспейса.

⚠️ Gotcha: все запуски внешних процессов идут с `</dev/null` и `disown`. QAT
держит панель открытой, пока какой-либо процесс держит её tty
(`close_on_child_death=no`), и Firefox, привязанный к этому tty, был бы убит при
force-close панели.

⚠️ Gotcha (cold-start Firefox): на настоящем холодном старте окно появляется
несколько секунд (процесс + профиль + первый кадр), поэтому `move_firefox_when_up`
поллит ~12с, иначе вкладка откроется не на том воркспейсе.

### apps.sh — запуск приложений

Фаззи-поиск `.desktop`-записей из XDG-каталогов, запуск выбранного. Enter
**фокусит уже открытое окно** приложения (матч по WM-классу через `hyprctl`),
Alt+Enter — всегда новый инстанс (Shift+Enter в fzf недоступен — терминал не шлёт
отдельный код).

Решения:
- Кэш `~/.cache/apps-fzf/apps.tsv` пересобирается только когда mtime app-dir'а
  изменился (добавлен/удалён `.desktop`) — дёшево, ловит новые приложения без
  ручного `-r`.
- Usage-tally хранится **отдельно** от каталога, чтобы порядок «по частоте
  запуска» переживал пересборку. Пустой запрос показывает «recent/most-used»,
  ввод переключает на полный каталог (fzf `change:reload`).
- Запуск через распарсенный `Exec=`, **не** `gtk-launch`: `gtk-launch`/`gio
  launch` молча no-op'ят на `DBusActivatable=true` с невалидным для D-Bus id
  (напр. хешированный Flatpak-id Telegram) и возвращают 0.
- Матч окна фаззи (нормализация классов, суффиксное сравнение): `StartupWMClass`
  регулярно не совпадает с живым классом окна (кейс Telegram). `Telegram` вынесен
  из empty-query recent-списка, чтобы не засорять.

### bookmarks.sh — закладки (фокус существующей FF-вкладки)

Фаззи-поиск закладок, открытие в Firefox с **предпочтением уже открытой вкладки**
через **brotab** (`bt list` → `bt activate --focused`), а не дублированием.

⚠️ Gotcha (brotab): `bt` — опциональная зависимость (pipx), требует установленного
FF-расширения brotab. Без него — фолбэк на `xdg-open`. `bt activate --focused` на
Hyprland не поднимает окно сам, поэтому окно поднимается вручную —
`focus_firefox_for_title` находит окно по титулу вкладки (титул вкладки становится
титулом окна после активации), чтобы победила именно вкладка на YouTube-ws, а не
случайное другое FF-окно.

- Источники: свой `bookmarks.tsv`, приватный dotfiles-private, и авто-экспорт
  закладок FF (`export_firefox_bookmarks`). `places.sqlite` залочен, пока FF
  запущен, поэтому копируется во временную папку (+WAL/SHM) и читается оттуда.
- Новые вкладки **никогда** не открываются на YouTube-воркспейсе (ws4):
  `prepare_firefox_for_new_tab` выбирает стратегию `tab`/`newwindow`/`cold`.
- Recents-лог как в apps.sh: пустой запрос → недавно открытые.

### search.sh — веб-поиск (выделен из bookmarks.sh)

**Почему отдельно от bookmarks.sh** (коммит «split web search into search.sh»):
адресно-строчная половина «искать в вебе» вынесена в собственный независимый QAT
без bookmark-строк — bookmarks.sh теперь ищет только закладки. Печатаешь запрос →
живые Google-подсказки (`suggestqueries.google.com`) → Enter на подсказке или на
своём сыром запросе открывает поиск в FF (та же brotab-логика, что в bookmarks.sh).

⚠️ Gotcha (debounce): `suggest_rows` делает **leading** `sleep 0.18` перед curl'ом.
fzf убивает предыдущий reload-процесс на каждый keystroke, поэтому пауза означает,
что запрос уходит в сеть только при паузе в печати — не по запросу на символ.
fzf в режиме `--disabled` (список формируем сами) + `--print-query` (Enter на
сыром запросе).

### youtube.sh / youtube-qat.sh

`youtube.sh` — yt-dlp-пикер видео по каналу/плейлисту/поиску; превью — миниатюра
(kitty graphics, фолбэк chafa) + титул. `youtube-qat.sh` — тонкая обёртка,
запускающая `youtube.sh -s` как kitty-панель (bound на kanata apps-слой).

- Видео открываются на **ws4** (в отличие от bookmarks/search — ws2).
- `-H`/`-L` (история/watch-later) читают залогиненную сессию через
  `--cookies-from-browser firefox` (без OAuth).

⚠️ Gotcha (кэш/превью): превью **не** делает сетевых запросов на hover — всё из
уже построенного TSV; миниатюра качается один раз и кэшируется в
`~/.cache/youtube-fzf/thumbs`. Порядок фолбэка `hqdefault→mqdefault→default`
(hqdefault есть всегда). Превью-функция запускается как subprocess (ветка
`--preview`) и не зависит от остального скрипта.

## Training logbook

### generate_logbook.py

Генератор **одного самодостаточного** `logbook.html` из markdown-сессий
`~/obsidian/periodic/training/`. CSS+JS инлайнятся в HTML, данные упражнений
инъектятся как JSON (`__EXDATA__`). Структура: парсинг сессий/событий → минимальный
markdown→HTML → рендер → сборка страницы (`main`).

Ключевые решения (по git-эволюции):
- **Mood через YAML frontmatter** сессии (`mood: bad|mid|great`), а не inline-тег
  в теле — коммит «Add session-level mood via YAML frontmatter». Настроение —
  свойство всей сессии, поэтому живёт в шапке файла; парсится `MOOD_FM_RE`.
- **Эволюция поиска**: fuzzy (`f49a39f`) → ranked (`832326c`, весовой `searchScore`:
  точное совпадение даты 10000, подстрока 8000, токены 150/25/5) → speed up
  (`f9594b3`) → debounce (`48314a5`). ⚠️ Gotcha: `input` дебаунсится на **220ms**
  (`scheduleSearch`), а подсветка совпадений (`highlight`, дорогой TreeWalker)
  отложена и ограничена топ-50 результатов (`scheduleHighlight`) — иначе печать
  лагает на большом фиде.
- **Разделённые даты в поиске** (`c26e2dc`): `2026 06` матчит `2026-06-*`.
- **Exercise history** (`ce289e2`): клик по имени упражнения → его история;
  список упражнений сортируется по последнему использованию, не алфавиту
  (`0a0133a`).
- **note-links / nvim-edit** (`fc30a5c`): в фиде и истории — ссылки
  `nvim-edit://<percent-encoded absolute path>`, открывающие исходный md-файл
  сессии. Обрабатывает их `nvim-edit-handler.sh` (см. ниже).

### import_training_log_xlsx.py

Единоразовый импорт истории из `Training_Log.xlsx` в md-сессии. **Без зависимостей**:
читает `.xlsx` как zip XML-частей (не openpyxl).

⚠️ Gotcha (цвета ячеек → mood): настроение восстанавливается из **fill-цвета**
notes-ячейки. Зелёный — базовый цвет и НЕ тегируется (иначе почти каждый workout
получил бы тег); только оранжевый→`mid` и красный→`bad` дают mood, который
пишется в frontmatter сессии (замыкается с `generate_logbook.py`). Резолвятся
только прямые `rgb`-заливки; theme/indexed игнорируются.

### nvim-edit-handler.sh — обработчик `nvim-edit://`

Обрабатывает `nvim-edit://`-ссылки из логбука (см. [[nvim]],
[[sessions]]). Открывает файл в kitty **obsidian**-сессии как новую
вкладку nvim.

Устройство (двухуровневый фолбэк, потому что kitty-сессия и nvim асинхронны):
1. Через `kitty-zoxide-session.sh --named obsidian` фокусит/создаёт obsidian-сессию
   в **главном** (не плавающем) kitty — не в транзиентных панелях вроде apps.sh.
2. Предпочитает `nvim --remote-tab` через nvim-сокет
   (`$XDG_RUNTIME_DIR/nvim.<pid>.0`, pid ищется с дельтой ±5, т.к. точный pid
   nvim нестабилен), при неудаче — фолбэк на `kitty send-text` (`:tabedit` в
   работающий nvim, или `nvim <file>` в голый shell).

### Связи

- `nvim-edit-handler.sh` ↔ kitty obsidian-сессия и её nvim (см. [[sessions]]).
- `generate_logbook.py` (генерит ссылки) ↔ `nvim-edit-handler.sh` (открывает их)
  ↔ `import_training_log_xlsx.py` (пишет mood во frontmatter, который читает
  генератор).

## Прочее

### daily-notes.sh

Открывает сегодняшнюю daily-note в nvim внутри **per-day kitty-сессии**
(`daily-<note>.kitty-session`), создавая заметку и её `год/месяц`-каталог при
первом обращении. Layout: `~/obsidian/periodic/<YYYY>/<MM-Mon>/<...>.md`.

⚠️ Заметка (устаревший комментарий): shebang и header ещё упоминают tmux, но
скрипт уже мигрирован на **kitty native sessions** (`kitten @ action
goto_session`); при первом входе делает `git -C ~/obsidian pull` и
`persistence.load()` вместо старого tmux-«s». См. [[sessions]].

### symlayout-watch.sh

Форсит раскладку `us`, пока активны символьные слои kanata. Вызывается
**напрямую действиями kanata** (`enter`/`leave`/`app`), без TCP-сервера. См.
[[kanata]].

- POSIX-sh порт старой Python-версии — на ~13ms быстрее за вызов (нет запуска
  интерпретатора), что важно, т.к. дёргается на каждом входе/выходе из слоя.
- `enter` запоминает текущий индекс раскладки в state-файле и переключает на `us`;
  `leave` восстанавливает сохранённый индекс. State-файл заодно защищает от
  двойного enter.
