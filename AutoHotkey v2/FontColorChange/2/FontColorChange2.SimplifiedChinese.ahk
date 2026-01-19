#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

; =========================
; 全局 GUI 对象
; =========================
global ColorGui

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

    ColorGui := Gui("+AlwaysOnTop", "字体颜色")
    ColorGui.AddText("w260 Center", "点击颜色，为选中文本设置字体颜色")

    colors := Map(
        "DarkOrange",        "焦橙色",
        "Red",               "红色",
        "LightSkyBlue",      "天蓝",
        "Turquoise",         "绿松石",
        "MediumVioletRed",   "紫红",
        "Teal",              "蓝绿色",
        "Gold",              "金黄色",
        "DimGray",           "灰黑色",
        "DeepPink",          "亮粉色",

        "DodgerBlue",        "亮蓝",
        "LimeGreen",         "鲜绿",
        "OrangeRed",         "橙红",
        "SlateBlue",         "岩蓝",
        "Chocolate",         "巧克力",
        "Crimson",           "深红",
        "SeaGreen",          "海绿",
        "SteelBlue",         "钢蓝",
        "Black",             "纯黑"
    )

    ColorHex := Map(
        "DarkOrange", "FF8C00",
        "Red", "FF0000",
        "LightSkyBlue", "87CEFA",
        "Turquoise", "40E0D0",
        "MediumVioletRed", "C71585",
        "Teal", "008080",
        "Gold", "FFD700",
        "DimGray", "696969",
        "DeepPink", "FF1493",
        "DodgerBlue", "1E90FF",
        "LimeGreen", "32CD32",
        "OrangeRed", "FF4500",
        "SlateBlue", "6A5ACD",
        "Chocolate", "D2691E",
        "Crimson", "DC143C",
        "SeaGreen", "2E8B57",
        "SteelBlue", "4682B4",
        "Black", "000000"
    )

    for color, name in colors
    {
        btn := ColorGui.AddButton("w120 h28", name)
        btn.Tag := color

        ; ★ 关键修复：Background 只能用 HEX
        btn.Opt("Background" ColorHex[color])

        ; 深色背景用白字
        if (color = "Black" || color = "Crimson" || color = "SlateBlue")
            btn.SetFont("cWhite")
        else
            btn.SetFont("cBlack")

        btn.OnEvent("Click", ApplyColor)
    }

    ColorGui.Show()
}


; =========================
; 点击颜色按钮后的处理
; =========================
ApplyColor(btn, *)
{
    global ColorGui

    color := btn.Tag

    ; 隐藏窗口，避免抢焦点
    ColorGui.Hide()

    ; 激活 Typora
    WinActivate "ahk_exe Typora.exe"
    Sleep 50

    ; 应用颜色
    AddFontColor(color)
}


; =========================
; 给选中文本加 <font color="">
; 中文输入法稳定版
; =========================
AddFontColor(color)
{
    ; 备份剪贴板
    ClipSaved := ClipboardAll()

    ; 复制选区
    A_Clipboard := ""
    Send "^c"
    ClipWait 0.5

    if (A_Clipboard != "")
    {
        ; 有选中文本
        html := "<font color='" color "'>" A_Clipboard "</font>"
        A_Clipboard := html
        Send "^v"
    }
    else
    {
        ; 没选中文本
        A_Clipboard := "<font color='" color "'></font>"
        Send "^v"
        Send "{Left 7}"
    }

    ; 恢复剪贴板
    Sleep 50
    A_Clipboard := ClipSaved
}
