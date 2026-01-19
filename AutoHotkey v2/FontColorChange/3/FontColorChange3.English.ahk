#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

; =========================
; 全局 GUI 对象
; =========================
global ColorGui


; =========================
; 点击彩色块后的处理（提前定义，避免 #Warn）
; =========================
ApplyColorFromText(ctrl, *)
{
    global ColorGui

    ColorGui.Hide()                      ; 隐藏窗口，避免抢焦点
    WinActivate "ahk_exe Typora.exe"     ; 激活 Typora
    Sleep 50

    AddFontColor(ctrl.Tag)               ; 应用颜色
}


; =========================
; 仅在 Typora 激活时生效
; Ctrl + Alt + C 打开颜色窗口
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!c::ShowColorGui()
#HotIf


; =========================
; 显示 / 创建颜色选择窗口
; =========================
ShowColorGui()
{
    global ColorGui

    if IsSet(ColorGui)
    {
        ColorGui.Show()
        return
    }

    ; 带滚动条的窗口
    ColorGui := Gui("+AlwaysOnTop +Resize", "Font Color")
    ColorGui.SetFont("s9")

    ColorGui.AddText("w260 Center", "Click a color to set the font color of selected text")

    ; 颜色列表（18 种）
    colors := [
        ["DarkOrange","DarkOrange"], ["Red","Red"], ["LightSkyBlue","LightSkyBlue"],
        ["Turquoise","Turquoise"], ["MediumVioletRed","MediumVioletRed"], ["Teal","Teal"],
        ["Gold","Gold"], ["DimGray","DimGray"], ["DeepPink","DeepPink"],

        ["DodgerBlue","DodgerBlue"], ["LimeGreen","LimeGreen"], ["OrangeRed","OrangeRed"],
        ["SlateBlue","SlateBlue"], ["Chocolate","Chocolate"], ["Crimson","Crimson"],
        ["SeaGreen","SeaGreen"], ["SteelBlue","SteelBlue"], ["Black","Black"]
    ]

    ; HTML 颜色名 → HEX（给 GUI 用）
    ColorHex := Map(
        "DarkOrange","FF8C00","Red","FF0000","LightSkyBlue","87CEFA",
        "Turquoise","40E0D0","MediumVioletRed","C71585","Teal","008080",
        "Gold","FFD700","DimGray","696969","DeepPink","FF1493",
        "DodgerBlue","1E90FF","LimeGreen","32CD32","OrangeRed","FF4500",
        "SlateBlue","6A5ACD","Chocolate","D2691E","Crimson","DC143C",
        "SeaGreen","2E8B57","SteelBlue","4682B4","Black","000000"
    )

    ; === 两列布局参数 ===
    colWidth  := 120
    rowHeight := 28
    startY    := 40

    Loop colors.Length
    {
        color := colors[A_Index][1]
        name  := colors[A_Index][2]

        col := (A_Index <= 9) ? 0 : 1
        row := Mod(A_Index - 1, 9)

        x := col * (colWidth + 10)
        y := startY + row * (rowHeight + 6)

        ctrl := ColorGui.AddText(
            "x" x " y" y
            " w" colWidth " h" rowHeight
            " Center Border Background" ColorHex[color],
            name
        )

        ; 深色背景用白字
        if (color = "Black" || color = "Crimson" || color = "SlateBlue")
            ctrl.SetFont("cWhite")
        else
            ctrl.SetFont("cBlack")

        ctrl.Tag := color
        ctrl.OnEvent("Click", ApplyColorFromText)
    }

    ColorGui.Show("w280 h320")
}


; =========================
; 给选中文本加 <font color="">
; 中文输入法稳定版
; =========================
AddFontColor(color)
{
    ClipSaved := ClipboardAll()

    A_Clipboard := ""
    Send "^c"
    ClipWait 0.5

    if (A_Clipboard != "")
    {
        A_Clipboard := "<font color='" color "'>" A_Clipboard "</font>"
        Send "^v"
    }
    else
    {
        A_Clipboard := "<font color='" color "'></font>"
        Send "^v"
        Send "{Left 7}"
    }

    Sleep 50
    A_Clipboard := ClipSaved
}
