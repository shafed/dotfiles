#Requires AutoHotkey v2.0+
#SingleInstance Force
SendMode("Input")
SetWorkingDir(A_ScriptDir)

; =============================================================================
;  KOMOREBI
; =============================================================================
Komorebic(cmd) {
    RunWait(format("komorebic.exe {}", cmd), , "Hide")
}

!q::Komorebic("close")
!m::Komorebic("minimize")

; Focus windows
!h::Komorebic("focus left")
!j::Komorebic("focus down")
!k::Komorebic("focus up")
!l::Komorebic("focus right")

!+sc01A::Komorebic("cycle-focus previous")
!+sc01B::Komorebic("cycle-focus next")

; Move windows
!+h::Komorebic("move left")
!+j::Komorebic("move down")
!+k::Komorebic("move up")
!+l::Komorebic("move right")

; Stack windows
!Left::Komorebic("stack left")
!Down::Komorebic("stack down")
!Up::Komorebic("stack up")
!Right::Komorebic("stack right")
!;::Komorebic("unstack")
!sc01A::Komorebic("cycle-stack previous")
!sc01B::Komorebic("cycle-stack next")

; Resize
!=::Komorebic("resize-axis horizontal increase")
!-::Komorebic("resize-axis horizontal decrease")
!+=::Komorebic("resize-axis vertical increase")
!+_::Komorebic("resize-axis vertical decrease")

; Manipulate windows
!+t::Komorebic("toggle-float")
!f::Komorebic("toggle-monocle")

; Window manager options
!+r::Komorebic("retile")
!p::Komorebic("toggle-pause")

; Layouts
;!x::Komorebic("flip-layout horizontal")
;!y::Komorebic("flip-layout vertical")

; Workspaces
!1::Komorebic("focus-workspace 0")
!2::Komorebic("focus-workspace 1")
!3::Komorebic("focus-workspace 2")
!4::Komorebic("focus-workspace 3")
!5::Komorebic("focus-workspace 4")
!6::Komorebic("focus-workspace 5")
!7::Komorebic("focus-workspace 6")
!8::Komorebic("focus-workspace 7")

; Move windows across workspaces
!+1::Komorebic("move-to-workspace 0")
!+2::Komorebic("move-to-workspace 1")
!+3::Komorebic("move-to-workspace 2")
!+4::Komorebic("move-to-workspace 3")
!+5::Komorebic("move-to-workspace 4")
!+6::Komorebic("move-to-workspace 5")
!+7::Komorebic("move-to-workspace 6")
!+8::Komorebic("move-to-workspace 7")

; =============================================================================
;  ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
; =============================================================================
browser := "zen.exe"
obsidian_path := "/mnt/c/ObsidianSync/"

; Пути к приложениям
exeHiddify := "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Hiddify.lnk"
winHiddify := "ahk_exe Hiddify.exe"

; Соотношения центра кнопки Hiddify относительно клиентской области
btnRatioX := 0.5813    ; 1115/1918 (из измерений)
btnRatioY := 0.5536    ;  506/914  (из измерений)

; Флаг для отслеживания обработки Alt+S+C
global altSCProcessing := false

; =============================================================================
;  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
; =============================================================================

/**
 * Переключает видимость окна: открывает/активирует или закрывает
 * @param winCriteria - критерий поиска окна
 * @param runTarget - путь к программе для запуска (опционально)
 * @param waitMs - время ожидания появления окна в мс
 */
ToggleClose(winCriteria, runTarget := "", waitMs := 10000) {
    hwnd := WinExist(winCriteria)
    
    ; Если окно не существует - запускаем программу
    if !hwnd {
        if (runTarget != "") {
            Run(runTarget)
            if WinWait(winCriteria, , waitMs)
                WinActivate(winCriteria)
        }
        return
    }
    
    ; Если окно активно - закрываем его
    if WinActive("ahk_id " hwnd) {
        WinClose("ahk_id " hwnd)
        return
    }
    
    ; Иначе - активируем окно
    WinActivate("ahk_id " hwnd)
}

/**
 * Открывает Hiddify VPN если не запущен
 */
OpenHiddify() {
    global exeHiddify, winHiddify
    if !WinExist(winHiddify)
        Run(exeHiddify)
    if WinWait(winHiddify,, 10)
        WinActivate(winHiddify)
}

/**
 * Подключается к VPN через клик по кнопке и закрывает окно
 */
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
    WinActivate(winHiddify)  ; Обязательно для корректной работы клиентских координат
    Sleep 100
    Click(cx, cy)

    ; Закрываем окно после подключения
    Sleep 100
    if WinExist(winHiddify)
        WinClose(winHiddify)
}

; =============================================================================
;  ГОРЯЧИЕ КЛАВИШИ: УПРАВЛЕНИЕ ПРИЛОЖЕНИЯМИ
; =============================================================================

; -----------------------------------------------------------------------------
; Alt+B / Shift+Alt+B - Hiddify VPN
; -----------------------------------------------------------------------------
Alt & SC030:: {  ; SC030 = клавиша B
    if GetKeyState("Shift")
        ConnectAndClose()      ; Shift+Alt+B - подключить и закрыть
    else
        ToggleClose(winHiddify, exeHiddify)  ; Alt+B - открыть/закрыть окно
}

; -----------------------------------------------------------------------------
; Alt+Shift+D - WhatsApp
; -----------------------------------------------------------------------------
!+d:: {
    Run("explorer.exe shell:AppsFolder\5319275A.WhatsAppDesktop_cv1g1gvanyjgm!App")
    if !WinExist("ahk_exe ApplicationFrameHost.exe") {
        WinWait("ahk_exe ApplicationFrameHost.exe")
        Komorebic("move-to-workspace 4")
    }
    Komorebic("focus-workspace 4")
}

; -----------------------------------------------------------------------------
; Простые горячие клавиши для приложений
; -----------------------------------------------------------------------------



; Alt+Shift+T - DeepL
!t:: {
    Run("C:\\Program Files\\Zero Install\\0install-win.exe run --no-wait https://appdownload.deepl.com/windows/0install/deepl.xml")  
    Komorebic("focus-workspace 5")
}
!r:: Run("rundll32 shell32.dll,#61")                                   ; Alt+R - Диалог запуска
!e:: Run("explorer")                                                   ; Alt+E - Проводник


!+s:: Run(EnvGet("USERPROFILE") "\AppData\Local\Programs\Perplexity\Perplexity.exe") ; Alt+Shift+S - Perplexity

; =============================================================================
;  ГОРЯЧИЕ КЛАВИШИ: СЛОЖНЫЕ КОМБИНАЦИИ
; =============================================================================

; -----------------------------------------------------------------------------
; Alt+S - Браузерный хаб
; -----------------------------------------------------------------------------
!s:: {
    global altSCProcessing
    deadline := A_TickCount + 600
    key1 := ""

    ; Первый уровень: какие клавиши ждём после Alt+S
    vkToKey1 := Map(
        "vk4F", "o",   ; O → блок курсов MIREA
        "vk43", "c",   ; C → ChatGPT / Claude
        "vk4C", "l",   ; L → lmarena
        "vk47", "g"    ; G → gmail
    )

    ; Ждём первую клавишу
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

    ; Обработка веток
    if (key1 = "o") {
        ; Alt+S+O → курсы MIREA (второй уровень)
        deadline2 := A_TickCount + 1000
        key2 := ""
        
        vkToKey2 := Map(
            "vk50", "p",  ; P
            "vk4D", "m",  ; M
            "vk4C", "l",  ; L
            "vk44", "d",  ; D
            "vk48", "h",  ; H
            "vk43", "c"   ; C
        )
        
        keyToUrl2 := Map(
            "p", "https://online-edu.mirea.ru/course/view.php?id=16159",
            "m", "https://online-edu.mirea.ru/course/view.php?id=13880",
            "l", "https://online-edu.mirea.ru/course/view.php?id=13878",
            "d", "https://online-edu.mirea.ru/course/view.php?id=13383",
            "h", "https://online-edu.mirea.ru/course/view.php?id=13488",
            "c", "https://online-edu.mirea.ru/course/view.php?id=14297"
        )

        ; Ждём вторую клавишу
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
            Run(browser " --new-window " keyToUrl2[key2])
        else
            Run(browser " --new-window https://online-edu.mirea.ru/")
    }
    else if (key1 = "c") {
        ; Alt+S+C → ChatGPT, Alt+S+C+C → Claude
        altSCProcessing := true  ; Устанавливаем флаг
        deadline2 := A_TickCount + 600
        
        if (KeyWait("vk43", "D T0.6")) {  ; Ждём ещё одно C
            Run(browser " --new-window https://claude.ai/")
        } else {
            Run(browser " --new-window https://chatgpt.com/")
        }
        
        ; Сбрасываем флаг через небольшую задержку
        SetTimer(() => altSCProcessing := false, -100)
    }
    else if (key1 = "l") {
        ; Alt+S+L → Lmarena
        Run(browser " --new-window https://lmarena.ai/")
    }
    else if (key1 = "g") {
        ; Alt+S+G → Gmail
        Run(browser " --new-window https://mail.google.com/mail/u/0/#inbox")
    }
    else {
        ; Просто Alt+S → браузер
        Run(browser)
    }

    Sleep 700
    Send("!f")
}

; -----------------------------------------------------------------------------
; Alt+O - nvim в корне Obsidian
; -----------------------------------------------------------------------------
*!o:: {
    ; Проверяем, не является ли это частью комбинации Alt+S+O
    if (A_PriorKey = "s" && A_TimeSincePriorHotkey < 700) {
        return
    }
    
    ; Сначала ищем без скрытых окон (только на текущем рабочем столе)
    DetectHiddenWindows(false)
    
    if WinExist("NVIM-OBSIDIAN") {
        ; Окно на текущем рабочем столе - просто активируем
        WinActivate()
        WinShow()
        return
    } else {
        ; Теперь ищем на всех рабочих столах
        DetectHiddenWindows(true)
        
        if WinExist("NVIM-OBSIDIAN") {
            ; Окно существует на другом рабочем столе
            ; Форсируем переключение
            winId := WinGetID("NVIM-OBSIDIAN")
            WinMinimize()  ; Сначала минимизируем
            WinRestore()   ; Затем восстанавливаем
            WinActivate()  ; И активируем - это заставит Windows переключить рабочий стол
            return
        } else {
            ; Окна нет вообще - создаём новое
            Run('alacritty.exe --title "NVIM-OBSIDIAN" --command wsl.exe -d Debian -e nvim ' 
                . obsidian_path)
            Komorebic("focus-workspace 1")
        }
        
        DetectHiddenWindows(false)
    }
}



; -----------------------------------------------------------------------------
; Alt+G - TickTick
; -----------------------------------------------------------------------------
*!g:: {
    ; Проверяем, не является ли это частью комбинации Alt+S+G
    if (A_PriorKey = "s" && A_TimeSincePriorHotkey < 700) {
        return
    }
    Run("C:\Program Files (x86)\TickTick\TickTick.exe")  ; Alt+G - TickTick
    Komorebic("focus-workspace 0")
    Sleep 600 ; Нажимаем Alt+F, чтобы перерисовать окно
    Send("!f")
    Sleep 50
    Send("!f")
}

; -----------------------------------------------------------------------------
; Alt+A - Терминальный хаб
; -----------------------------------------------------------------------------
!a:: {
    deadline := A_TickCount + 600
    tag := ""

    ; Ждём вторую клавишу
    vkToTag := Map(
        "vk44", "d"   ; D → todo.md
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

    if (tag = "d") {
    ; Сначала ищем без скрытых окон (только на текущем рабочем столе)
    DetectHiddenWindows(false)
    
    if WinExist("TODO-MD-WINDOW") {
        ; Окно на текущем рабочем столе - просто активируем
        WinActivate()
        WinShow()
        return
    } else {
        ; Теперь ищем на всех рабочих столах
        DetectHiddenWindows(true)
        
        if WinExist("TODO-MD-WINDOW") {
            ; Окно существует на другом рабочем столе
            ; Форсируем переключение
            winId := WinGetID("TODO-MD-WINDOW")
            WinMinimize()  ; Сначала минимизируем
            WinRestore()   ; Затем восстанавливаем
            WinActivate()  ; И активируем - это заставит Windows переключить рабочий стол
            return
        } else {
            ; Окна нет вообще - создаём новое
            Run('alacritty.exe --title "TODO-MD-WINDOW" --command wsl.exe -d Debian -e nvim ' 
                . obsidian_path . '/base/notes/todo.md')
        }
        
        DetectHiddenWindows(false)
    }
}
    else {
        ; Просто Alt+A → терминал
        Run('alacritty.exe')
    }
    Komorebic("focus-workspace 1")
    Sleep 300
    WinMaximize("ahk_exe alacritty.exe")
    Sleep 50
    WinRestore("ahk_exe alacritty.exe")
    Sleep 100
    WinActivate("ahk_exe alacritty.exe")
}

; -----------------------------------------------------------------------------
; Alt+D - Telegram
; -----------------------------------------------------------------------------
*!d:: {
    ; Проверяем, не является ли это частью комбинации Alt+A+D
    if (A_PriorKey = "a" && A_TimeSincePriorHotkey < 1000) {
        return
    }
    Run(EnvGet("USERPROFILE") "\AppData\Roaming\Telegram Desktop\Telegram.exe")
    if !WinExist("ahk_exe Telegram.exe") {
        WinWait("ahk_exe Telegram.exe")
        Komorebic("move-to-workspace 4")
    }
    Run("komorebic focus-workspace 4")
}


; -----------------------------------------------------------------------------
; Alt+C - VS Code
; -----------------------------------------------------------------------------
*!c:: {
    global altSCProcessing
    
    ; Проверяем, не является ли это частью комбинации Alt+S+C или Alt+S+C+C
    if (A_PriorKey = "s" && A_TimeSincePriorHotkey < 700) {
        return
    }
    
    ; Проверяем, не обрабатываем ли мы сейчас Alt+S+C+C
    if (altSCProcessing) {
        return
    }
    
    Run(EnvGet("USERPROFILE") "\AppData\Local\Programs\Microsoft VS Code\Code.exe")  ; Alt+C - VS Code
    Komorebic("focus-workspace 1")
}
; Alt+Shift+C - Cursor
!+c:: {
    Run(EnvGet("USERPROFILE") "\AppData\Local\Programs\cursor\Cursor.exe")
    Komorebic("focus-workspace 1")
}

; -----------------------------------------------------------------------------
; Alt+Y - YouTube хаб
; -----------------------------------------------------------------------------
!y:: {
    KeyWait("vk59")  ; Ждём отпускания Y, чтобы не поймать её как вторую
    
    deadline := A_TickCount + 600
    second := ""

    ; Ловим вторую клавишу (Y/H)
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

    ; Определяем URL
    url := (second = "y") ? "https://www.youtube.com/playlist?list=WL"
         : (second = "h") ? "https://www.youtube.com/feed/history"
         : "https://www.youtube.com/"

    ; Запускаем в браузере
    try
        Run('chrome.exe --new-window "' url '"')
    Komorebic("focus-workspace 3")
}

; -----------------------------------------------------------------------------
; Alt+X - OneDrive + файлы дней
; -----------------------------------------------------------------------------
!x:: {
    deadline := A_TickCount + 600
    key := ""

    ; Ждём вторую клавишу (1/2/3)
    while (A_TickCount < deadline && key = "") {
        Loop 3 {
            if GetKeyState(A_Index, "P") {
                key := A_Index
                KeyWait(A_Index)
                break
            }
        }
        Sleep 10
    }

    ; Открываем OneDrive
    url := "https://onedrive.live.com/personal/a96ef60ed3018334/_layouts/15/doc2.aspx?resid=d3018334-f60e-206e-80a9-730600000000&cid=a96ef60ed3018334&ct=1756228104602&wdOrigin=OFFICECOM-WEB.MAIN.EDGEWORTH&wdPreviousSessionSrc=HarmonyWeb&wdPreviousSession=f8e116b3-fb69-408d-b79a-fa81411fa7ce"
    Run(browser ' --new-window "' url '"')

    ; Если была цифра — запускаем nvim с файлом дня
    if (key != "") {
        Run("alacritty.exe --command wsl.exe -d Debian -e nvim " 
            . obsidian_path . "/base/notes/Day_" . key . ".md" " temp.md")
    }

    Komorebic("focus-workspace 1")
}

; =============================================================================
;  ТЕКСТОВЫЕ ЗАМЕНЫ
; =============================================================================

; Замена "--" на "— " (отключено в Telegram)
#HotIf !(WinActive("ahk_exe Telegram.exe") || WinActive("ahk_exe TelegramDesktop.exe"))
::--::— 
#HotIf

; "ёёё" → переключение на английский + вставка ```
:*:ёёё:: {
    ; Сменить язык ввода на English (US)
    DllCall("PostMessage", "ptr", WinExist("A"), "uint", 0x50, "ptr", 0, "ptr", 0x04090409)
    Send("{``}{``}{``}")
}

; Автозамены (отключены в терминале Alacritty)
#HotIf !WinActive("ahk_exe alacritty.exe")
::вин::Windows
::обси::Obsidian
::obsi::Obsidian
::tg::Telegram
::тг::Telegram
:*:;mail::shaparenko.fedor@gmail.com
:*:;.mail::shaparenkofedor@gmail.com
:*:;mmail::shaparenko.f.a@edu.mirea.ru
#HotIf

; =============================================================================
;  ПЕРЕНАЗНАЧЕНИЕ КЛАВИШ
; =============================================================================
RAlt::LAlt  ; Правый Alt работает как левый Alt

