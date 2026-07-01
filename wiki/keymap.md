---
title: keymap
type: topic
updated: 2026-07-01
covers:
  - kanata/config.kbd
  - hypr/hyprland.conf
  - kitty/kitty.conf
---

# keymap — сквозная карта клавиш

🚧 Частично наполнено. Единая точка правды по хоткеям — чтобы слои не
конфликтовали и не забывались. См. компонентные [[kanata]],
[[hypr]], [[kitty]].

## Три уровня и граница между ними

1. **kanata** (`process-unmapped-keys (all-except lctl ralt)`) — перехватывает
   почти всю физическую клавиатуру, делает HRM, chords, слои, символы. Модифицирует
   потоки на уровне **до** оконного менеджера.
2. **hypr** — ловит только `Super`-биндинги (`$mainMod`). kanata Super не трогает
   (кроме `numws`/`movews`, где Super **вшит в keycode** и уходит в hypr как
   Super+цифра).
3. **kitty** — ловит `C-S-` (`kitty_mod = ctrl+shift`) для сессий/сплитов.

Ключевая развязка: **kanata шлёт `C-S-`-хоткеи в kitty** (через `kitty-send`,
после фокуса kitty), а **hypr слушает `Super`**. Пересечения нет, потому что
kitty ловит C-S-комбо только когда сфокусирован, а hypr — Super глобально.

## Слои kanata (что где)

- **base** — буквы + HRM (AGCS) + функциональные thumb/letter-holds.
- **normal** — «безопасный» слой (буквы как есть, `lsft`=switch-lang), вход через
  hold Enter; возврат в base из base через Enter-hold / `lsft+rsft`.
- **apps** (hold thumb) — лаунчер: приложения, kitty-сессии (`kitty-send C-S-*`),
  fzf-pickers, killactive (`q`), браузер-подслой (`s` hold → `browser`).
- **browser** (из apps, hold `s`) — прямые URL (gmail, perplexity, chatgpt, claude…).
- **symbols / symbols2** (hold `e`/`r` или chords `s+d` / `s+d+f`) — программерские
  символы на правой руке; xkb форсится в US (см. [[kanata]]).
- **navi** (hold `w` или toggle через caps-hold) — стрелки/навигация на правой
  руке, mods свободны на левой.
- **numplain / numplain2** (chords `k+l` / `j+k+l`) — цифры и shifted-символы
  цифрового ряда на левой руке.
- **numws / movews** (из apps hold `l`, либо chord `j+l`) — `Super+цифра` /
  `Super+Shift+цифра` на левой руке → hypr workspaces / move-to-workspace.

## Потенциальные конфликты и как разведены

| Клавиши | Кто владеет | Развязка |
|---|---|---|
| `h j k l` | kanata HRM (base) / navi / hypr Super | HRM только на hold с opposite-hand; hypr `Super+hjkl`=movefocus, kanata Super не трогает |
| цифры `1-0` | numplain (левая рука) / hypr `Super+N` | numplain даёт **плоские** цифры; workspace-переключение только через numws (Super вшит) |
| `C-tab` / `C-S-tab` | navi (browser tabs) / kitty | в navi это `@j/k-navi` (fork на alt); kitty ловит `C-S-*` только сфокусированным |
| Ctrl+Shift одноручный | HRM больше НЕ даёт (same-hand=tap) | вынесен в chords `d+f` / `j+k` (hold) |
| `w+e` | ролл букв vs. chord Tab | `mod-chord-time 35` + `chords-v2-min-idle 80` разводят ролл и намеренный chord |

## RU/US и force-English

Две логики форсирования US-раскладки, обе через
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh) на xkb-устройстве
`kanata`:

- **symbol-слои** (`enter`/`leave`): переключить на US на время удержания слоя и
  восстановить прежний индекс — чтобы `S-...`-keycodes давали одинаковые символы
  на RU и US.
- **apps-действия** (`app`): жёстко US index 0 при запуске picker/session-экшена —
  чтобы fzf/rofimoji стартовали на английском.

Переключение языка в обычной работе: tap `ralt` (`@sw` → `hyprctl
switchxkblayout kanata next`), либо `lsft` в слое `normal`.
