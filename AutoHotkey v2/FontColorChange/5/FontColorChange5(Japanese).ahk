#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"

; =========================
; 全局变量
; =========================
global ColorGui := 0
global CustomGui := 0
global InfoGui   := 0
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

    if IsObject(ColorGui)
    {
        ColorGui.Show()
        return
    }

    ; 创建窗口
    ColorGui := Gui("+AlwaysOnTop +Resize", "フォントの色")
    ColorGui.SetFont("s9")

    ; ===== 顶部按钮 =====
    ; 按钮宽 120，中间间距 20
    infoBtn   := ColorGui.AddButton("xm w120", "使い方説明(必読)")
    customBtn := ColorGui.AddButton("x+20 yp w120", "カスタムカラー")

    infoBtn.OnEvent("Click", (*) => ShowInfoGui())
    customBtn.OnEvent("Click", (*) => ShowCustomColorGui())

    ; ===== 颜色定义 =====
    colors := [
        ["DarkOrange","焦橙色"], ["Red","赤色"], ["LightSkyBlue","空色"],
        ["Turquoise","ターコイズブルー"], ["MediumVioletRed","赤紫"], ["Teal","青緑"],
        ["Gold","金色"], ["DimGray","暗灰色"], ["DeepPink","濃いピンク"],
        ["DodgerBlue","ドジャーブルー"], ["LimeGreen","ライムグリーン"], ["OrangeRed","オレンジレッド"],
        ["SlateBlue","スレートブルー"], ["Chocolate","チョコレート色"], ["Crimson","深紅"],
        ["SeaGreen","シーグリーン"], ["SteelBlue","スチールブルー"], ["Black","黒"]
    ]

    ColorHex := Map(
        "DarkOrange","FF8C00","Red","FF0000","LightSkyBlue","87CEFA",
        "Turquoise","40E0D0","MediumVioletRed","C71585","Teal","008080",
        "Gold","FFD700","DimGray","696969","DeepPink","FF1493",
        "DodgerBlue","1E90FF","LimeGreen","32CD32","OrangeRed","FF4500",
        "SlateBlue","6A5ACD","Chocolate","D2691E","Crimson","DC143C",
        "SeaGreen","2E8B57","SteelBlue","4682B4","Black","000000"
    )

    ; ===== 布局参数 =====
    colW := 120   ; 色块宽度（与顶部按钮一致）
    rowH := 28    ; 色块高度
    gapY := 6     ; 上下间距
    startY := 45  ; 第一行颜色的起始Y坐标（稍微拉开一点点与按钮的距离，更好看）
    
    ; 这里的 gapX 必须等于顶部两个按钮的间距 (20)
    ; 计算右列的 X 偏移量：左边距(xm) + 按钮宽(120) + 间距(20) = 140
    
    Loop colors.Length
    {
        c := colors[A_Index][1]
        n := colors[A_Index][2]

        ; 计算行列 (0为左列, 1为右列)
        col := (A_Index <= 9) ? 0 : 1
        row := Mod(A_Index - 1, 9)

        ; >>> 核心修改：X坐标对齐逻辑 <<<
        ; 如果是左列(0)，位置就是 xm
        ; 如果是右列(1)，位置就是 xm+140 (即 xm + 宽度120 + 间距20)
        xPosStr := (col == 0) ? "xm" : "xm+140"
        
        ; 计算 Y 坐标
        yPos := startY + row * (rowH + gapY)

        ; 添加色块
        ; 0x200 保证垂直居中
        t := ColorGui.AddText(
            xPosStr " y" yPos " w" colW " h" rowH 
            " 0x200 Center Border Background" ColorHex[c], 
            n
        )

        t.SetFont(c="Black"||c="Crimson"||c="SlateBlue" ? "cWhite":"cBlack")
        t.Tag := c
        t.OnEvent("Click", ApplyColorFromText)
    }

    ; 自动调整高度，宽度稍微给点余量避免紧贴边缘，但内容是绝对居中的
    ColorGui.Show("w290 h370")
}


; =========================
; 提醒窗口（独立）
; =========================
ShowInfoGui()
{
    global InfoGui

    if IsObject(InfoGui)
    {
        InfoGui.Show()
        return
    }

    InfoGui := Gui("+AlwaysOnTop +Resize", "使い方")
    InfoGui.SetFont("s9")

    InfoGui.AddEdit(
        "xm ym w400 h260 ReadOnly -VScroll Wrap",
        "① 色をクリックして、Typoraで選択したテキストのフォント色を設定します`n`n"
        "② メインウィンドウを誤って閉じてしまった場合、Ctrl + Alt + C で再度開けます`n`n"
        "③ メインウィンドウとすべてのサブウィンドウは、枠をドラッグして自由にサイズ変更できます`n`n"
        "④ 現状では修正できない既知のバグがあり、文字が消えることがあります；Ctrl + Z で操作を取り消してください。すでに色が付いた文字の色を変更したい場合、直接的な方法はありません；Ctrl + Z で色を戻すか、文字を削除して再入力し、改めて色を選んでください"
    )

    InfoGui.Show("w420 h300")
}


; =========================
; 自定义颜色窗口
; =========================
ShowCustomColorGui()
{
    global CustomGui, CustomHex, ColorGui

    if IsObject(CustomGui)
    {
        CustomGui.Show()
        return
    }

    CustomGui := Gui("+AlwaysOnTop +Resize", "カスタムカラー")
    CustomGui.SetFont("s9")

    ; ===== HEX =====
    CustomGui.AddText("xm", "HEX(#なし)")
    HexEdit := CustomGui.AddEdit("xm w260", CustomHex)

    ; ===== RGB =====
    CustomGui.AddText("xm y+10", "RGB")
    R := CustomGui.AddEdit("xm w80", "255")
    G := CustomGui.AddEdit("x+10 yp w80", "0")
    B := CustomGui.AddEdit("x+10 yp w80", "0")

    ; ===== 预览 =====
    Preview := CustomGui.AddText(
        "xm y+10 w260 h40 0x200 Center Border Background" CustomHex,
        "色のプレビュー"
    )

    R.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    G.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    B.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    HexEdit.OnEvent("Change", (*) => UpdateFromHex(HexEdit, Preview))

    refresh := CustomGui.AddButton("xm y+10 w260", "プレビューを更新")
    refresh.OnEvent("Click", (*) => RefreshPreview(R, G, B, HexEdit, Preview))

    apply := CustomGui.AddButton("xm y+6 w260", "この色を使用")
    apply.OnEvent("Click", (*) => ApplyCustomColor())

    back := CustomGui.AddButton("xm y+6 w260", "戻る")
    back.OnEvent("Click", (*) => (CustomGui.Hide(), ColorGui.Show()))

    CustomGui.Show("w300 h360")
}


; =========================
; 颜色逻辑
; =========================
UpdateFromRGB(R, G, B, HexEdit, Preview)
{
    global CustomHex
    CustomHex := Format("{:02X}{:02X}{:02X}", Clamp(R.Value), Clamp(G.Value), Clamp(B.Value))
    HexEdit.Value := CustomHex
    Preview.Opt("Background" CustomHex)
}

UpdateFromHex(HexEdit, Preview)
{
    global CustomHex
    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
    {
        CustomHex := HexEdit.Value
        Preview.Opt("Background" CustomHex)
    }
}

ApplyCustomColor()
{
    global CustomHex
    WinActivate "ahk_exe Typora.exe"
    Sleep 40
    AddFontColor("#" CustomHex)
}

RefreshPreview(R, G, B, HexEdit, Preview)
{
    global CustomHex, CustomGui

    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
        CustomHex := HexEdit.Value
    else
        CustomHex := Format("{:02X}{:02X}{:02X}", Clamp(R.Value), Clamp(G.Value), Clamp(B.Value))

    CustomGui.Hide()
    Preview.Opt("Background" CustomHex)
    CustomGui.Show()
}

Clamp(v)
{
    if (v = "" || !IsNumber(v))
        return 0
    v := Integer(v)
    return v < 0 ? 0 : v > 255 ? 255 : v
}

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
; 启动即显示
; =========================
ShowColorGui()