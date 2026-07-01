---
title: hypr
type: component
updated: 2026-07-01
covers:
  - hypr/hyprland.conf
  - hypr/hypridle.conf
  - hypr/hyprlock.conf
  - hypr/hyprsunset.conf
---

# hypr

🚧 Компоновщик (Wayland). Полная карта клавиш — в [[keymap]], цвета/тема — в
[[theming]], терминал/сессии — в [[kitty]] и [[sessions]].

## Ключевые решения

- **Layout dwindle, gaps и rounding = 0, анимаций почти нет.** Осознанно минималистичный
  тайлинг без визуальных излишеств: `gaps_in/out = 0`, `rounding = 0`,
  `animations { enabled = no }` (кроме служебных кривых, оставленных дефолтом).
  Границы окон — gruvbox-градиент (`col.active_border = d8a657 → a9b665`), в тон
  теме.
- **`no_hardware_cursors = true`** — обход бага с невидимым/битым курсором на этом
  железе (комментарий `fix bag with cursor` в конфиге). `no_warps` — курсор не
  прыгает при смене фокуса.
- **`kb_layout = us,ru`, но переключение раскладки ведёт kanata, а не Hyprland.**
  Запущен `hyprland-per-window-layout` (per-window раскладка). ⚠️ Gotcha:
  символьные слои kanata форсят US xkb — детали в [[kanata]]/[[keymap]],
  здесь только регистрируются две раскладки.

## Autostart (exec-once)

Порядок и состав `exec-once` — это «что такое рабочая сессия»:
`kitty` (нативные сессии, без tmux — см. [[kitty]]/[[sessions]]),
`waybar & hyprpaper`, `kanata` (клавиатурный движок — критичен, без него нет
слоёв), `hyprland-per-window-layout`, `hypridle`, `hyprsunset`, `stretchly`
(напоминания о перерывах). ⚠️ Gotcha: браузер НЕ в autostart —
`exec-once = browser` был удалён (коммит `75f46cf`); Firefox поднимается лениво
через `workspace = 2, on-created-empty:firefox` при первом заходе на 2-й воркспейс.

## Нетривиальные биндинги (только «почему»)

Общая карта — в [[keymap]]. Здесь только неочевидное:

- `SUPER, Q` (killactive) **закомментирован** в hyprland.conf — killactive повешен
  через kanata apps-слой (Q под большим пальцем), см. [[keymap]].
- `SUPER, M` — умный выход: `hyprshutdown` если есть, иначе `hyprctl dispatch exit`.
- `SUPER, home` — `systemctl suspend && hyprlock` (ручной сон+лок).
- `SUPER, V` — `copyq toggle` (менеджер буфера; окно CopyQ ловится windowrule во float).
- `Ctrl-h/j/k/l` навигации по окнам здесь НЕТ — они живут в kitty через `pass_keys.py`
  (контекстно: nvim/fzf получают их первыми), см. [[kitty]].

## Правила окон

- `suppress-maximize-events` для всех классов — приложения не «максимизируются» сами.
- Телеграм → воркспейс 5, kitty → воркспейс 1 (стабильное размещение).
- `hyprland-run`/CopyQ — во float с фиксированной позицией.

## idle / lock / suspend

- **hypridle**: единственный активный listener — `timeout = 1800` (30 мин) →
  `systemctl suspend`. Промежуточные листенеры (диммирование, dpms off, ранний
  lock) закомментированы осознанно. `before_sleep_cmd = loginctl lock-session`
  гарантирует лок ДО сна; `after_sleep_cmd = dpms on` — чтобы экран будился с
  первого нажатия.
- **hyprlock**: фон — блюренный скриншот; поля/акценты в gruvbox-градиентах в тон
  границам окон. Виджет раскладки кликабелен (`hyprctl switchxkblayout all next`).
  Пароль/цвета жёстко заданы — тема тут не переключается.

## Permissions / env

Блок `permissions` (screencopy для grim/portal) закомментирован — работает на
дефолтных правах. Env-переменные — только размеры курсора (`XCURSOR_SIZE`,
`HYPRCURSOR_SIZE = 24`).

## hyprsunset

Ночная цветовая температура, см. [[theming]]: день (7:30) — `identity`
(без сдвига), ночь (20:00) — `temperature = 6000, gamma = 0.7`. ⚠️ Gotcha: это
НЕ переключатель light/dark темы приложений — только гамма/температура экрана;
тема приложений задаётся статически (gruvbox dark везде).
