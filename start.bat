@echo off
setlocal enabledelayedexpansion

::GlazeWM
start "" "C:\Program Files\glzr.io\GlazeWM\glazewm.exe"

::Hotkeys
start "" "C:\Program Files\AutoHotkey\Hotkeys.ahk"

::Hiddify
start "" "C:\Program Files\Hiddify\Hiddify.exe"

:: Syncthing
start "" "C:\Program Files\Syncthing\syncthing.exe" --no-console --no-browser

::dual-key-remap
start "" "C:\Program Files\dual-key-remap-v0.8\dual-key-remap.exe"

::Razer
start "" "C:\Program Files\Razer\RazerAppEngine\RazerAppEngine.exe" --url-params=apps=synapse,chroma-app --launch-force-hidden=synapse,chroma-app --autoStart=1

:: TickTick
start "" "C:\Program Files (x86)\TickTick\TickTick.exe" -hide

::Reverso
start "" "%USERPROFILE%\AppData\Local\Reverso\Reverso\Reverso.exe" -minimized

::Auto Dark Mode
start "" "%USERPROFILE%\AppData\Local\Programs\AutoDarkMode\adm-app\AutoDarkModeSvc.exe"

::Stretchly
start "" "C:\Program Files\Stretchly\Stretchly.exe"

::Lightshot
start "" "C:\Program Files (x86)\Skillbrains\lightshot\Lightshot.exe"
