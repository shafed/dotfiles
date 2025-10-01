#Requires AutoHotkey v2.0+
#SingleInstance Force
SendMode("Input")
SetWorkingDir(A_ScriptDir)

; ---------------------------------------------------------------------------
;  H E L P E R   F U N C T I O N S
; ---------------------------------------------------------------------------
ToggleClose(winCriteria, runTarget := "", waitMs := 10000) {
    hwnd := WinExist(winCriteria)
    if !hwnd {
        if (runTarget != "") {
            Run(runTarget)
            if WinWait(winCriteria, , waitMs)
                WinActivate(winCriteria)
        }
        return
    }
    if WinActive("ahk_id " hwnd) {
        WinClose("ahk_id " hwnd)
        return
    }
    WinActivate("ahk_id " hwnd)
}

; =============================================================================
;  H O Т K E Y S   (AltGr  +  <Key>)
; =============================================================================

; ---------------------------------------------------------------------------
;  Alt + B  /  Shift + Alt + B        – Hiddify VPN
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
;  Alt + B  /  Shift + Alt + B        – Hiddify VPN без привязки к размерам
; ---------------------------------------------------------------------------
; --- Универсальный клик по центру кнопки Hiddify ---
exeHiddify := "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Hiddify.lnk"
winHiddify := "ahk_exe Hiddify.exe"

; Соотношения центра кнопки относительно клиентской области (для любой ширины)
btnRatioX := 0.5813    ; из второго скрина: 1115/1918
btnRatioY := 0.5536    ; из второго скрина:  506/ 914

Alt & SC030::{          ; Alt + B
    if GetKeyState("Shift")
        ConnectAndClose()
    else
        ToggleClose(winHiddify, exeHiddify)
}

OpenHiddify() {
    global exeHiddify, winHiddify
    if !WinExist(winHiddify)
        Run(exeHiddify)
    if WinWait(winHiddify,, 10)
        WinActivate(winHiddify)
}

ConnectAndClose() {
    global winHiddify, btnRatioX, btnRatioY
    OpenHiddify()

    ; Получаем размеры клиентской области
    WinGetClientPos(&wx, &wy, &ww, &wh, winHiddify)

    ; Высчитываем точку для клика
    cx := Round(ww * btnRatioX)
    cy := Round(wh * btnRatioY)

    ; Кликаем по клиентской области окна
    CoordMode("Mouse", "Client")
    ; WinActivate обязательно, чтобы клик пошёл по клиентским координатам!
    WinActivate(winHiddify)
    Sleep 100
    Click(cx, cy)

    Sleep 100
    if WinExist(winHiddify)
        WinClose(winHiddify)
}


; =============================================================================
;  T E X T   R E P L A C E M E N T S
; =============================================================================

; ---------------------------------------------------------------------------
;  "--"  →  "— "   (disabled inside Telegram)
; ---------------------------------------------------------------------------
#HotIf !(WinActive("ahk_exe Telegram.exe") || WinActive("ahk_exe TelegramDesktop.exe"))
::--::— 
#HotIf

; ---------------------------------------------------------------------------
;  "ёёё"  →  удаление + переключение на English (US)
; ---------------------------------------------------------------------------
:*:ёёё::
{
    ; Сменить язык ввода на English (United States)
    DllCall("PostMessage", "ptr", WinExist("A"), "uint", 0x50, "ptr", 0, "ptr", 0x04090409)
    ; Вставить ```
    Send("{``}{``}{``}")
}

RAlt::LAlt

#HotIf !WinActive("ahk_exe alacritty.exe")

::вин::Windows
::обси::Obsidian
::obsi::Obsidian
::tg::Telegram
::тг::Telegram
:*:;mail::shaparenko.fedor@gmail.com
:*:;.mail::shaparenkofedor@gmail.com
:*:;mmail::shaparenko.f.a@edu.mirea.ru

#HotIf  ; отключаем фильтр



!s:: {
    deadline := A_TickCount + 600
    key1 := ""

    ; первый уровень: какие клавиши ждём сразу после Alt+S
    vkToKey1 := Map(
        "vk4F","o",   ; O → блок курсов MIREA
        "vk43","c",   ; C → ChatGPT / Claude
        "vk4C","l",    ; L → lmarena
        "vk47","g"    ; E → gmail
    )

    while (A_TickCount < deadline && key1 = "") {
        for vk, tag in vkToKey1 {
            if GetKeyState(vk, "P") {
                key1 := tag
                KeyWait(vk)
                break
            }
        }
        Sleep 10
    }

    ; ===== ВЕТКИ =====
    if (key1 = "o") {
        ; Alt+S+O → курсы MIREA
        deadline2 := A_TickCount + 600
        key2 := ""
        vkToKey2 := Map(
            "vk50","p",
            "vk4D","m",
            "vk4C","l",
            "vk44","d",
            "vk48","h",
            "vk43","c"
        )
        keyToUrl2 := Map(
            "p","https://online-edu.mirea.ru/course/view.php?id=16159",
            "m","https://online-edu.mirea.ru/course/view.php?id=13880",
            "l","https://online-edu.mirea.ru/course/view.php?id=13878",
            "d","https://online-edu.mirea.ru/course/view.php?id=13383",
            "h","https://online-edu.mirea.ru/course/view.php?id=13488",
            "c","https://online-edu.mirea.ru/course/view.php?id=14297"
        )

        while (A_TickCount < deadline2 && key2 = "") {
            for vk, tag in vkToKey2 {
                if GetKeyState(vk, "P") {
                    key2 := tag
                    KeyWait(vk)
                    break
                }
            }
            Sleep 10
        }

        if (key2 != "" && keyToUrl2.Has(key2))
            Run("zen.exe --new-window " keyToUrl2[key2])
        else
            Run("zen.exe --new-window https://online-edu.mirea.ru/")
    }
    else if (key1 = "c") {
        ; Alt+S+C → ChatGPT, Alt+S+C+C → Claude
        deadline2 := A_TickCount + 600
        key2 := ""
        if (KeyWait("vk43", "D T0.6")) {  ; ждём ещё одно C
            Run("zen.exe --new-window https://claude.ai/")
        } else {
            Run("zen.exe --new-window https://chatgpt.com/")
        }
    }
    else if (key1 = "l") {
        ; Alt+S+L → Lmarena
        Run("zen.exe --new-window https://lmarena.ai/")
    }
    else if (key1 = "g") {
        ; Alt+S+E → Gmail
        Run("zen.exe --new-window https://mail.google.com/mail/u/0/#inbox")
    }
    else {
        ; просто Alt+S
        Run("zen.exe")
    }
}


; Alt+Shift+S: запуск Perplexity
!+s:: {
    Run(EnvGet("USERPROFILE") "\AppData\Local\Programs\Perplexity\Perplexity.exe")
    }


; ===================== Alt + A: хаб =====================
!a:: {
    deadline := A_TickCount + 600
    tag := ""

    ; ждём вторую клавишу
    vkToTag := Map(
        "vk4F","o",  ; O → nvim в корне Obsidian
        "vk4A","j",  ; J → (пример) просто nvim
        "vk54","t",  ; T → todo (если нужно, оставь)
        "vk44","d"   ; D → todo.md
    )

    while (A_TickCount < deadline && tag = "") {
        for vk, t in vkToTag {
            if GetKeyState(vk, "P") {
                tag := t
                KeyWait(vk)
                break
            }
        }
        Sleep 10
    }

    ; что запускать
    if (tag = "o")
        Run('alacritty.exe --title "NVIM-OBSIDIAN" --command wsl.exe -d Debian -e nvim /mnt/d/ObsidianSync/')
    else if (tag = "j")
        Run('alacritty.exe --command wsl.exe -d Debian -e nvim')
    else if (tag = "t")
        Run('alacritty.exe --title "NVIM-TODO" --command wsl.exe -d Debian -e nvim /mnt/d/ObsidianSync/base/notes/todo')
    else if (tag = "d") {
        ; Ищем окно с нашим уникальным заголовком
        if WinExist("TODO-MD-WINDOW") {
            WinActivate()
            WinShow()  ; Восстанавливаем, если свёрнуто
        } else {
            Run('alacritty.exe --title "TODO-MD-WINDOW" --command wsl.exe -d Debian -e nvim /mnt/d/ObsidianSync/base/notes/todo.md')
        }
    }
    else
        Run('alacritty.exe')  ; просто Alt+A
}

; ===================== Alt + D: Telegram =====================
; Используем * чтобы хоткей срабатывал даже если D уже была нажата
*!d:: {
    ; Проверяем историю нажатий - если A была нажата недавно, это Alt+A+D
    if (A_PriorKey = "a" && A_TimeSincePriorHotkey < 700) {
        ; Это часть комбинации Alt+A+D, не запускаем Telegram
        return
    }
    
    ; подставь свой путь, пример:
    tg := EnvGet("USERPROFILE") "\AppData\Roaming\Telegram Desktop\Telegram.exe"
    if FileExist(tg)
        Run('"' tg '"')
    else
        Run('Telegram.exe')  ; если в PATH
}

; ---------- Настройки ----------
g_AltYTimeout := 600  ; мс

; ---------- Хелперы ----------
FindChromePath() {
    static cached := ""
    if (cached != "")
        return cached
    for path in [
        EnvGet("ProgramFiles") "\Google\Chrome\Application\chrome.exe",
        EnvGet("ProgramFiles(x86)") "\Google\Chrome\Application\chrome.exe",
        EnvGet("LOCALAPPDATA") "\Google\Chrome\Application\chrome.exe",
        "chrome.exe"  ; если в PATH
    ] {
        if FileExist(path) {
            cached := path
            return cached
        }
    }
    return ""
}
RunChromeApp(url) {
    chrome := FindChromePath()
    if (chrome != "")
        Run('"' chrome '" --new-window --app=' url)
    else
        Run(url)  ; фоллбек: системный браузер
}

; Alt+Y: YouTube через Zen
; Alt+Y     → https://www.youtube.com/
; Alt+Y+Y   → https://www.youtube.com/playlist?list=WL
; Alt+Y+H   → https://www.youtube.com/feed/history
!y:: {
    ; важный шаг: дождаться отпускания исходной Y, чтобы не поймать её как вторую
    KeyWait("vk59")

    deadline := A_TickCount + 600
    second := ""

    ; ловим вторую клавишу (Y/H) по VK-кодам, независимо от раскладки
    while (A_TickCount < deadline && second = "") {
        if GetKeyState("vk59", "P") {      ; Y
            second := "y"
            KeyWait("vk59")
        } else if GetKeyState("vk48", "P") { ; H
            second := "h"
            KeyWait("vk48")
        }
        Sleep 10
    }

    url := (second = "y")
        ? "https://www.youtube.com/playlist?list=WL"
        : (second = "h")
            ? "https://www.youtube.com/feed/history"
            : "https://www.youtube.com/"

    ; запускаем в Zen в новом окне; если zen.exe не найден — fallback в системный браузер
    try
        Run("zen.exe --new-window " url)
    catch
        Run(url)
}


