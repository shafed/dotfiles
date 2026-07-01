---
title: theming
type: topic
updated: 2026-07-01
covers:
  - darkman/
  - hypr/hyprsunset.conf
  - kitty/current-theme.conf
---

# theming — gruvbox (dark везде)

🚧 Сквозная тема визуала. Компоненты: [[kitty]], [[waybar]],
[[yazi]], [[hypr]], nvim ([[nvim]]).

## Единый визуальный язык: Gruvbox Material Dark

Везде один и тот же палитр — **Gruvbox Material Dark Medium**, привязанный к
`background #282828` / `foreground #d4be98`. Опорная точка — nvim; kitty-фон
специально подогнан к нему (`e5557fc`: hard→medium `#282828`), терминальные цвета
выровнены под gruvbox material (`1a43177`, `81ce442`).

⚠️ Gotcha: **единого файла-источника цветов НЕТ.** Палитра продублирована по
компонентам вручную:

- `kitty/current-theme.conf` (+ дубль в `quick-access-terminal-center.conf` через
  `kitty_override`),
- `waybar/style.css` (`@define-color gb_*`),
- `yazi/flavors/gruvbox-dark.yazi` + `theme.toml`,
- nvim — свой плагин gruvbox-material,
- hyprland/hyprlock — hex-цвета границ/полей прямо в конфигах (`d8a657`, `a9b665`…).

Меняешь оттенок — правь во ВСЕХ этих местах, автоматической синхронизации нет.

## Light/dark: фактически всегда dark

- **yazi**: `theme.toml` — и `dark`, и `light` указывают на `gruvbox-dark`
  (переключения нет).
- **darkman**: установлен (`darkman/config.yaml`: `usegeoclue: false`, координаты
  Москвы `lat/lng` для расчёта заката), НО ⚠️ **`darkman/scripts/` пуст** — нет
  ни dark-mode.d, ни light-mode.d хуков, и darkman ни в чём в репо не упоминается
  и не в autostart Hyprland. То есть механизм переключения темы приложений
  де-факто НЕ подключён — задел на будущее, а не рабочий свитчер.

## hyprsunset — только гамма/температура экрана

`hypr/hyprsunset.conf` управляет цветовой температурой дисплея по времени (день
7:30 — `identity`; ночь 20:00 — `temperature 6000, gamma 0.7`), стартует из
`exec-once` в [[hypr]]. ⚠️ Не путать с переключением темы: hyprsunset НЕ
трогает цвета приложений и НЕ связан с darkman — это независимый ночной фильтр
поверх всего экрана.

## Итог для агента

Тема статична: gruvbox dark, заданный по копии в каждом компоненте. Динамического
light/dark-конвейера сейчас нет (darkman-заготовка пустая; hyprsunset — отдельная
гамма-коррекция).
