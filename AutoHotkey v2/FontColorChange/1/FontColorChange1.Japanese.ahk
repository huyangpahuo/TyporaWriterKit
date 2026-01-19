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

    ; 如果窗口已存在，直接显示
    if IsSet(ColorGui)
    {
        ColorGui.Show()
        return
    }

    ; 创建窗口
    ColorGui := Gui("+AlwaysOnTop", "フォントの色")
    ColorGui.AddText("w260 Center", "色をクリックして、選択したテキストのフォント色を設定します")

    ; 颜色表（键 = HTML 颜色，值 = 中文名）
    colors := Map(
        "DarkOrange", "濃いオレンジ",
        "Red", "赤",
        "LightSkyBlue", "空色",
        "Turquoise", "ターコイズブルー",
        "MediumVioletRed", "紫の赤",
        "Teal", "青緑",
        "Gold", "金色",
        "DimGray", "暗いグレー",
        "DeepPink", "濃いピンク"
    )

    ; 为每种颜色创建按钮
    for color, name in colors
    {
        btn := ColorGui.AddButton("w120", name)
        btn.Tag := color                  ; 把颜色存到按钮 Tag
        btn.OnEvent("Click", ApplyColor)  ; 绑定点击事件
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

    ; 关闭窗口，避免抢焦点
    ColorGui.Hide()

    ; 确保 Typora 获得焦点
    WinActivate "ahk_exe Typora.exe"
    Sleep 50

    ; 应用颜色
    AddFontColor(color)
}


; =========================
; 给选中文本加 <font color="">
; 核心：只用剪贴板，不 Send 字符
; =========================
AddFontColor(color)
{
    ; 备份原剪贴板
    ClipSaved := ClipboardAll()

    ; 复制选区
    A_Clipboard := ""
    Send "^c"
    ClipWait 0.5

    if (A_Clipboard != "")
    {
        ; 有选中文本：构造完整 HTML
        html := "<font color='" color "'>" A_Clipboard "</font>"
        A_Clipboard := html
        Send "^v"
    }
    else
    {
        ; 没选中文本：插入空标签
        A_Clipboard := "<font color='" color "'></font>"
        Send "^v"
        Send "{Left 7}"   ; 光标移到标签中间
    }

    ; 恢复剪贴板
    Sleep 50
    A_Clipboard := ClipSaved
}
