---
tags:
  - note/basic
aliases:
---

1. [Скачать последний релиз](https://github.com/sha5010/vim.xlam?utm_source=chatgpt.com) и переместить файл в %AppData%\Microsoft\AddIns
2. Нажать ПКМ -> свойства -> разблокировать
3. Открыть Параметры -> Надстройки -> Перейти... -> через Обзор найти файл и нажать ОК
4. Открыть VBA редактор через alt+f11
	1. Заменить и сохранить код из ThisWorkbook в VBAProject (vim.xlam)\Microsoft Excel Objects на следующий
```
#If Win64 Then
    Private Declare PtrSafe Function LoadKeyboardLayout Lib "user32" Alias "LoadKeyboardLayoutA" _
        (ByVal pwszKLID As String, ByVal Flags As Long) As LongPtr
    Private Declare PtrSafe Function ActivateKeyboardLayout Lib "user32" _
        (ByVal hkl As LongPtr, ByVal flags As Long) As LongPtr
    Private Declare PtrSafe Function GetKeyboardLayout Lib "user32" _
        (ByVal idThread As Long) As LongPtr
#Else
    Private Declare Function LoadKeyboardLayout Lib "user32" Alias "LoadKeyboardLayoutA" _
        (ByVal pwszKLID As String, ByVal Flags As Long) As Long
    Private Declare Function ActivateKeyboardLayout Lib "user32" _
        (ByVal hkl As Long, ByVal flags As Long) As Long
    Private Declare Function GetKeyboardLayout Lib "user32" _
        (ByVal idThread As Long) As Long
#End If

Private Sub Workbook_Open()
    Dim prevHKL As LongPtr
    Dim hUS As LongPtr

    ' 1) Save current keyboard layout of the active thread
    prevHKL = GetKeyboardLayout(0)

    ' 2) Temporarily activate ENG (US) layout so Application.OnKey will not fail
    hUS = LoadKeyboardLayout("00000409", &H1) ' KLF_ACTIVATE
    ActivateKeyboardLayout hUS, 0

    ' 3) Register all Vim hotkeys
    On Error Resume Next
    Call C_Core.StartVim
    On Error GoTo 0

    ' 4) Restore the original keyboard layout
    If prevHKL <> 0 Then
        ActivateKeyboardLayout prevHKL, 0
    End If
End Sub
```