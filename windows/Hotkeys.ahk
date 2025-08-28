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
::вин::Windows
::обси::Obsidian
::obsi::Obsidian
::tg::Telegram
::тг::Telegram
:*::mail::shaparenko.fedor@gmail.com
:*::.mail::shaparenkofedor@gmail.com
:*::mmail::shaparenko.f.a@edu.mirea.ru
