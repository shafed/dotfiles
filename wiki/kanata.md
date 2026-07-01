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

🚧 Частично наполнено. Самая продуманная и хрупкая часть keymap. См. также
сквозную [[keymap]] и [[sessions]].

## Opposite-hand HRM (home-row mods)

Home-row mods по схеме **AGCS** (Alt-GUI-Ctrl-Shift от мизинца к указательному,
зеркально: `a/;`=Alt, `s/l`=Super, `d/k`=Ctrl, `f/j`=Shift). Реализованы через
`tap-hold-opposite-hand-release` (kanata PR #1955) поверх `defhands` — hold
срабатывает, **только если следующая клавиша на другой руке**. Это убрало
misfire вроде `sh → Super+h` без ручных списков «typing keys», которые
приходилось вести раньше.

Почему именно `-release`-вариант: решение принимается по **отпусканию**
прерывающей клавиши. Если при быстром ролле/биграмме вторая клавиша поднимается
раньше HRM-клавиши — обе резолвятся в буквы. Это и есть главный киллер
кросс-хэнд-misfire.

Настройки внутри `hrm`-шаблона:
- `(neutral hold)` + `neutral-keys` (цифры, spc/tab/ret/bspc/esc) — эти клавиши
  вне `defhands`, но должны **сохранять** hold, чтобы работали Super+2, Ctrl+Space,
  Shift+Tab, Ctrl+Enter.
- `(timeout hold)` — если прерывающую клавишу **удержали** дольше таймаута (и
  `-release` не сработал), форсим hold. Так получаются комбо `hold j (Shift) +
  hold v (C-v) → C-S-v`.
- ⚠️ Gotcha: same-hand по умолчанию `tap`. Одноручные mod-комбо (например `d+f`
  как Ctrl+Shift **на одной левой руке**) через HRM больше **не работают** — их
  надо брать через разные руки. Одноручный Ctrl+Shift вынесен в отдельный chord
  (см. ниже).

## Chords (chords-v2) и тайминги

`concurrent-tap-hold yes` + `defchordsv2`. Ключевые тайминги:
- `mod-chord-time 35` — очень узкое окно для одноручных mod-chords (`d+f`, `j+k`,
  `s+f`, `k+l`…): обе клавиши должны лечь почти одновременно, чтобы
  последовательный ролл вроде `fd` **не** триггерил Ctrl+Shift.
- `chords-v2-min-idle 80` — после любого не-chord-нажатия chords пропускаются
  80 мс. Итог: одноручный mod-chord срабатывает почти мгновенно после короткой
  паузы, но не посреди быстрого набора.
- `all-released` в большинстве chords держит модификаторы, пока не поднимутся обе
  клавиши, — можно добавить третью (напр. `C-S-tab`).

⚠️ Gotcha (rolls vs. mod-combos): это фундаментальный trade-off. Слишком широкое
окно ловит ложные mod-комбо на роллах; слишком узкое — не даёт нажать комбо
намеренно. Значения 35/80 подобраны эмпирически; менять осторожно.

Что живёт на chords: `d+f`=tap Esc / hold C-S, `j+k`=tap Enter / hold C-S,
`s+f`=Super+Shift, `w+e`=Tab, `k+l`=numplain, `j+k+l`=numplain2 (shifted числа),
`s+d`=symbols, `s+d+f`=symbols2, `j+l`=movews, `lsft+rsft`=выход в base.

## Символьные слои + xkb US-wrap

Символы (`symbols`, `symbols2`) держат `S-...`-keycodes на правой руке (левая
удерживает вход). ⚠️ Проблема: на RU-раскладке `S-2` даёт `"`, а не `@`. Решение
— на входе в слой переключаем **xkb-устройство kanata на US** (index 0), на
выходе восстанавливаем прежний индекс. Так `S-...` выдаёт одинаковые символы на
US и RU.

Механика: алиасы `sym-enter`/`sym-enter2` оборачивают `layer-while-held` в
`(on-press tap-vkey sym-us)` / `(on-release tap-vkey sym-restore)`. Vkeys дёргают
[`../scripts/symlayout-watch.sh`](../scripts/symlayout-watch.sh) `enter`/`leave`
напрямую (без TCP-сервера; POSIX-порт старого Python — на ~13 мс быстрее на вызов).
Скрипт хранит прежний индекс в `/tmp/symlayout-watch-$UID-kanata.layout` и
guard'ит двойной enter.

Раскладка символов **frequency-ordered**: горячие символы на сильном home row —
`()` на `j k`, `@` на `h`, `|` на `l`, `` ` `` на `y`. `symbols2` — эскалация:
добавив указательный `f`, попадаешь в редкие `! # * & % < >`. Символы не
дублируются между слоями (короткий = горячий chord).

## kitty-send (замена tmux prefix)

`deftemplate kitty-send` заменил старую tmux-prefix-схему (`C-s`). Теперь kanata
**фокусит kitty** (`@aterm` → [`switchApp.sh`](../kanata/switchApp.sh) focus-or-launch),
ждёт `aterm-settle 250` мс на осадку фокуса, затем шлёт `C-S-`-хоткей (kitty
`kitty_mod = C-S-`), который драйвит нативные сессии. См. [[sessions]].
⚠️ Gotcha: без задержки хоткей уходит до того, как kitty получил фокус, — сессия
не переключается.

## apps-слой + force-English

Hold большого пальца (`lalt`/`ralt`, tap=bspc/switch-lang) даёт слой `apps` —
лаунчер приложений/сессий/pickers. Сам `apps`-слой раскладку **не меняет**:
`apps-enter` — это просто `layer-while-held apps`.

Force-English делают **действия**, а не вход в слой: picker/session-экшены
начинаются с `(on-press tap-vkey apps-us)` → `symlayout-watch.sh app` (жёстко
xkb US index 0). Так fzf-pickers (bookmarks/youtube/apps/search) и rofimoji
всегда стартуют на английской раскладке независимо от текущего языка. Плоский
hold/release apps-клавиши без действия безвреден.

## Shifted number layer (numplain2)

`numplain` — плоские цифры на левой руке (home row 1-5, top row 6-0), вход через
chord `k+l`. `numplain2` — те же позиции, но `S-...` (символы над цифрами:
`! @ # $ % ...`), вход через более длинный chord `j+k+l`. Зачем отдельный слой:
позволяет печатать shifted-символы цифрового ряда без ухода в символьные слои и
без реального Shift, сохраняя мышечную память позиций цифр.

⚠️ Gotcha таймингов в целом: press-decided layer-holds на частых буквах (`n`, `e`,
`r`, `w`) мгновенны, но `буква + биграмма` может misfire — это осознанный
компромисс за скорость входа в слои.
