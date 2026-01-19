#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

; =========================
; 全局变量
; =========================
global ColorGui
global CustomGui
global CustomHex := "FF0000"


; =========================
; 仅在 Typora 生效
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!c::ShowColorGui()
#HotIf


; =========================
; 预设颜色点击
; =========================
ApplyColorFromText(ctrl, *)
{
    ColorGui.Hide()
    WinActivate "ahk_exe Typora.exe"
    Sleep 40
    AddFontColor(ctrl.Tag)
}


; =========================
; 主颜色窗口
; =========================
ShowColorGui()
{
    global ColorGui

    if IsSet(ColorGui)
    {
        ColorGui.Show()
        return
    }

    ColorGui := Gui("+AlwaysOnTop +Resize", "字体颜色")
    ColorGui.SetFont("s9")
    ColorGui.AddText("w260 Center", "点击颜色，为选中文本设置字体颜色")

    colors := [
        ["DarkOrange","焦橙色"], ["Red","红色"], ["LightSkyBlue","天蓝"],
        ["Turquoise","绿松石"], ["MediumVioletRed","紫红"], ["Teal","蓝绿色"],
        ["Gold","金黄色"], ["DimGray","灰黑色"], ["DeepPink","亮粉色"],
        ["DodgerBlue","亮蓝"], ["LimeGreen","鲜绿"], ["OrangeRed","橙红"],
        ["SlateBlue","岩蓝"], ["Chocolate","巧克力"], ["Crimson","深红"],
        ["SeaGreen","海绿"], ["SteelBlue","钢蓝"], ["Black","纯黑"]
    ]

    ColorHex := Map(
        "DarkOrange","FF8C00","Red","FF0000","LightSkyBlue","87CEFA",
        "Turquoise","40E0D0","MediumVioletRed","C71585","Teal","008080",
        "Gold","FFD700","DimGray","696969","DeepPink","FF1493",
        "DodgerBlue","1E90FF","LimeGreen","32CD32","OrangeRed","FF4500",
        "SlateBlue","6A5ACD","Chocolate","D2691E","Crimson","DC143C",
        "SeaGreen","2E8B57","SteelBlue","4682B4","Black","000000"
    )

    colW := 120, rowH := 28, startY := 40

    Loop colors.Length
    {
        c := colors[A_Index][1]
        n := colors[A_Index][2]

        col := (A_Index <= 9) ? 0 : 1
        row := Mod(A_Index - 1, 9)

        x := col * (colW + 10)
        y := startY + row * (rowH + 6)

        t := ColorGui.AddText(
            "x" x " y" y " w" colW " h" rowH
            " Center Border Background" ColorHex[c],
            n
        )

        t.SetFont(c="Black"||c="Crimson"||c="SlateBlue" ? "cWhite":"cBlack")
        t.Tag := c
        t.OnEvent("Click", ApplyColorFromText)
    }

    btn := ColorGui.AddButton("xm y+10 w260", "自定义颜色")
    btn.OnEvent("Click", (*) => ShowCustomColorGui())

    ColorGui.Show("w280 h360")
}


; =========================
; 自定义颜色窗口
; =========================
ShowCustomColorGui()
{
    global CustomGui, CustomHex, ColorGui

    if IsSet(CustomGui)
    {
        CustomGui.Show()
        return
    }

    ; ★ 关键：+Resize 让窗口可拉伸
    CustomGui := Gui("+AlwaysOnTop +Resize", "自定义颜色")
    CustomGui.SetFont("s9")

    CustomGui.AddText("xm", "HEX（不带 #）：")
    HexEdit := CustomGui.AddEdit("xm w120", CustomHex)

    CustomGui.AddText("x+20 yp", "RGB：")
    R := CustomGui.AddEdit("x+5 yp w40", "255")
    G := CustomGui.AddEdit("x+5 yp w40", "0")
    B := CustomGui.AddEdit("x+5 yp w40", "0")

    Preview := CustomGui.AddText(
        "xm y+10 w260 h40 Center Border Background" CustomHex,
        "颜色预览"
    )

    CustomGui.AddText("xm y+6 Center", "点击选择该颜色")

    ; 输入变化 → 自动同步（不强制）
    R.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    G.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    B.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    HexEdit.OnEvent("Change", (*) => UpdateFromHex(HexEdit, Preview))

    ; ===== 新增：刷新预览按钮 =====
    refresh := CustomGui.AddButton("xm y+10 w260", "刷新预览")
    refresh.OnEvent(
        "Click",
        (*) => RefreshPreview(R, G, B, HexEdit, Preview)
    )

    apply := CustomGui.AddButton("xm y+6 w260", "使用该颜色")
    apply.OnEvent("Click", (*) => ApplyCustomColor())

    back := CustomGui.AddButton("xm y+6 w260", "返回")
    back.OnEvent("Click", (*) => (CustomGui.Hide(), ColorGui.Show()))

    CustomGui.Show("w300 h360")
}


; =========================
; RGB → HEX
; =========================
UpdateFromRGB(R, G, B, HexEdit, Preview)
{
    global CustomHex

    r := Clamp(R.Value)
    g := Clamp(G.Value)
    b := Clamp(B.Value)

    CustomHex := Format("{:02X}{:02X}{:02X}", r, g, b)
    HexEdit.Value := CustomHex
    Preview.Opt("Background" CustomHex)
}


; =========================
; HEX → 预览
; =========================
UpdateFromHex(HexEdit, Preview)
{
    global CustomHex

    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
    {
        CustomHex := HexEdit.Value
        Preview.Opt("Background" CustomHex)
    }
}


; =========================
; 应用自定义颜色
; =========================
ApplyCustomColor()
{
    global CustomGui, CustomHex
    CustomGui.Hide()
    WinActivate "ahk_exe Typora.exe"
    Sleep 40
    AddFontColor("#" CustomHex)
}


; =========================
; Clamp（防空值）
; =========================
Clamp(v)
{
    if (v = "" || !IsNumber(v))
        return 0

    v := Integer(v)
    return v < 0 ? 0 : v > 255 ? 255 : v
}


; =========================
; Typora 加颜色
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

    Sleep 30
    A_Clipboard := ClipSaved
}

; =========================
; 刷新颜色
; =========================


RefreshPreview(R, G, B, HexEdit, Preview)
{
    global CustomHex, CustomGui

    ; 优先使用合法 HEX
    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
    {
        CustomHex := HexEdit.Value
    }
    else
    {
        r := Clamp(R.Value)
        g := Clamp(G.Value)
        b := Clamp(B.Value)

        CustomHex := Format("{:02X}{:02X}{:02X}", r, g, b)
        HexEdit.Value := CustomHex
    }

    ; 先隐藏再显示，保证预览刷新
    CustomGui.Hide()
    Preview.Opt("Background" CustomHex)
    CustomGui.Show()
}
