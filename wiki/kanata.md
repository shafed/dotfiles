---
title: kanata
type: component
updated: 2026-07-01
covers:
  - kanata/config.kbd
  - kanata/switchApp.sh
  - scripts/symlayout-watch.sh
---

# kanata

🌱 Заглушка. Самая продуманная и хрупкая часть keymap — наполнить в первую очередь.
См. также сквозную [keymap](keymap.md) и [sessions](sessions.md).

## О чём написать

- **Opposite-hand HRM** (home-row mods, kanata PR #1955): hold срабатывает только
  если следующая клавиша на другой руке — почему это убрало misfire вроде
  `sh → Super+h` без ручных списков клавиш. `-release`-вариант и его логика.
- **Chords** (`chords-v2`, `mod-chord-time`, `chords-v2-min-idle`): почему такие
  тайминги; одноручные mod-chords (d+f, j+k) и trade-off с HRM.
- **Символьные слои + xkb US-wrap**: почему символы оборачиваются переключением на
  US-раскладку (чтобы S-… эмитил те же символы на RU/US). Связка с
  `../scripts/symlayout-watch.sh` (force US пока активен symbol-слой).
- **kitty-send** (`deftemplate kitty-send`): заменил старый tmux prefix (C-s) —
  kanata фокусит kitty и шлёт C-S-хоткей, который драйвит нативные сессии. См.
  [sessions](sessions.md).
- **apps-слой**: hold apps (ralt/lalt) форсит English; picker/session-действия
  форсят English при запуске.
- **shifted number layer** (последний коммит) — зачем.

⚠️ Gotcha: перечислить известные грабли таймингов (rolls vs. mod-combos).
