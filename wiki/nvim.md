---
title: nvim
type: component
updated: 2026-07-01
covers:
  - nvim/
---

# nvim

🚧 Конфиг на базе **LazyVim**; кастомизация поверх в `../nvim/lua/`. Симлинк
`~/.config/nvim → ~/dotfiles/nvim` ([[bootstrap]]).

## Почему так устроено

- **LazyVim как база** (`lazyvim.json`, `lazy-lock.json`): не собираем конфиг с
  нуля, а берём готовый дистрибутив и переопределяем точечно в
  `lua/plugins/*.lua`. Включённые extras: `luasnip`, `dap.core`, `mini-files`,
  `lang.python`.
- Своё в `lua/plugins/` (auto-save, hardtime, render-markdown, bullets, vimtex,
  img-clip, blink, snacks и др.) — переопределяют/добавляют плагины поверх LazyVim.
- **`gruvbox-material`** как colorscheme — единый gruvbox во всех инструментах,
  см. [[theming]]. В `colorscheme.lua` дополнительно перекрашены
  markdown-хайлайты (bold=оранжевый, italic=зелёный).
- Логика клавиш вынесена в `lua/utils/` (folding, kitty, tasks, obsidian, gcal),
  чтобы `keymaps.lua` не разбухал.

## Интеграция с training logbook

nvim — редакторская часть тренировочного логбука; генерация и просмотр — в
[[scripts]], вызов из редактора — в [[sessions]].

- `<leader>lp` (`obsidian.save_training_note`) — сохраняет буфер как
  `~/obsidian/periodic/training/YYYY-MM-DD-<h1>.md` (H1 переписывается в slug,
  чтобы имя файла = заголовок) и **сразу дёргает** `~/dotfiles/scripts/generate_logbook.py`
  для регенерации `logbook.html`.
- Отдельный keymap открывает `logbook.html` через `xdg-open`.
- `obsidian.push_with_cooldown()` — авто commit+push vault `~/obsidian` (кулдаун
  час), чтобы правки заметок бэкапились без ручных коммитов.
- `nvim-edit-handler.sh` в [[scripts]] — обратная связка: логбук
  открывает заметку на редактирование в nvim.

⚠️ Gotcha: `harper_ls` (грамматика) **выключен на training-заметках** —
`excludePatterns` содержит `~/obsidian/periodic/training/**/*.md` и `Day [123].md`.
Причина: тренировочные заметки — таблицы/сокращения, harper захлёбывается ложными
срабатываниями. Коммит `ef70575` («recursive disable harper in training»).

## LSP / прочие исключения

- `marksman` выключен в пользу **`markdown_oxide`** (daily-notes, code lens,
  `:Daily` для открытия заметок естественным языком).
- `harper_ls` включён только для `markdown`/`typst`, `isolateEnglish=true`,
  игнор ссылок и `[[wikilinks]]`.

## neobean

Алиасы `neobean`/`nb` в [[zsh]] запускают nvim с
`NVIM_APPNAME=linkarzu/dotfiles-latest/neovim/neobean` — отдельный сторонний
конфиг (linkarzu) параллельно основному, не мешая ему. TODO: подтвердить, что
этот `NVIM_APPNAME`-каталог реально установлен на машине (в репо его нет).

## Снипеты и spell

- `snippets/` — luasnip-снипеты, много под LaTeX (`tex/*.lua`, `bib.lua`).
- Есть `;date` snippet — вставка текущей даты в ISO-формате (коммит `2e4f335`).
- `spell/` — пользовательские словари EN+RU.
