#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SendMode "Input"

; =========================
; 全局变量与配置文件路径
; =========================
global MetaGui := 0
global SettingsGui := 0
global IniFile := A_ScriptDir "\TyporaMetaSettings.ini"

; 初始化默认配置
if !FileExist(IniFile) {
    try {
        IniWrite("", IniFile, "Defaults", "Title")
        IniWrite("MyTag", IniFile, "Defaults", "Tags")
        IniWrite("MyCategory", IniFile, "Defaults", "Categories")
        IniWrite("/images/default.png", IniFile, "Defaults", "Cover")
    } catch as err {
        MsgBox "无法写入配置文件: " err.Message
    }
}

; =========================
; 托盘菜单
; =========================
A_TrayMenu.Delete()
A_TrayMenu.Add("打开插入窗口 (测试)", (*) => ShowMetaGui())
A_TrayMenu.Add("默认设置", (*) => ShowSettingsGui())
A_TrayMenu.Add()
A_TrayMenu.Add("重启脚本", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())

TrayTip "Typora YAML 脚本已启动`n按 Ctrl+Alt+I 呼出界面", "准备就绪", "Iconi"

; =========================
; 快捷键
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!i:: ShowMetaGui()
#HotIf

F4:: ShowMetaGui() ; 全局测试键

; =========================
; 主插入窗口
; =========================
ShowMetaGui()
{
    global MetaGui, IniFile

    if IsObject(MetaGui)
    {
        MetaGui.Show()
        return
    }

    MetaGui := Gui("+AlwaysOnTop", "插入 YAML Front Matter")
    MetaGui.SetFont("s10", "Microsoft YaHei") ; 设置默认大字体

    ; 读取默认配置
    defTitle := IniRead(IniFile, "Defaults", "Title", "")
    defTags := IniRead(IniFile, "Defaults", "Tags", "")
    defCats := IniRead(IniFile, "Defaults", "Categories", "")
    defCover := IniRead(IniFile, "Defaults", "Cover", "")
    
    currTime := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; ===== 界面布局 =====
    MetaGui.Add("Text", "xm w80 Right", "Title (标题):")
    edtTitle := MetaGui.Add("Edit", "x+10 w300", defTitle)

    MetaGui.Add("Text", "xm w80 Right", "Date (时间):")
    edtDate := MetaGui.Add("Edit", "x+10 w300", currTime) 

    MetaGui.Add("Text", "xm w80 Right", "Tags (标签):")
    
    ; --- 修正处开始 ---
    ; 在 v2 中，要改变某一行文字的字体/颜色，必须先 SetFont，添加完控件后再 SetFont 恢复
    MetaGui.SetFont("s8 cGray") 
    MetaGui.Add("Text", "x+10 w300", "多个标签用逗号或换行分隔")
    MetaGui.SetFont("s10 cDefault") ; 恢复默认字体
    ; --- 修正处结束 ---

    edtTags := MetaGui.Add("Edit", "xm+90 y+2 w300 r3", defTags)

    MetaGui.Add("Text", "xm w80 Right", "Categories`n(分类):")
    edtCats := MetaGui.Add("Edit", "x+10 w300 r3", defCats)

    MetaGui.Add("Text", "xm w80 Right", "Cover (封面):")
    edtCover := MetaGui.Add("Edit", "x+10 w300", defCover)

    ; ===== 按钮 =====
    btnSet := MetaGui.Add("Button", "xm w100", "⚙️ 默认设置")
    btnInsert := MetaGui.Add("Button", "x+190 w100 Default", "插入") 

    btnSet.OnEvent("Click", (*) => ShowSettingsGui())
    btnInsert.OnEvent("Click", (*) => InsertYaml(edtTitle.Value, edtDate.Value, edtTags.Value, edtCats.Value, edtCover.Value))
    
    MetaGui.OnEvent("Close", (*) => (MetaGui.Destroy(), MetaGui := 0))
    MetaGui.Show()
}

; =========================
; 默认设置窗口
; =========================
ShowSettingsGui()
{
    global SettingsGui, IniFile, MetaGui

    if IsObject(MetaGui)
        MetaGui.Hide()

    if IsObject(SettingsGui)
    {
        SettingsGui.Show()
        return
    }

    SettingsGui := Gui("+AlwaysOnTop", "配置默认值")
    SettingsGui.SetFont("s9", "Microsoft YaHei")
    
    SettingsGui.Add("Text", "xm", "此处设置将保存到 Ini 文件，下次自动加载。")

    savedTitle := IniRead(IniFile, "Defaults", "Title", "")
    savedTags := IniRead(IniFile, "Defaults", "Tags", "")
    savedCats := IniRead(IniFile, "Defaults", "Categories", "")
    savedCover := IniRead(IniFile, "Defaults", "Cover", "")

    SettingsGui.Add("Text", "xm y+10 w60", "默认标题:")
    sTitle := SettingsGui.Add("Edit", "x+10 w250", savedTitle)

    SettingsGui.Add("Text", "xm w60", "默认标签:")
    sTags := SettingsGui.Add("Edit", "x+10 w250 r3", savedTags)

    SettingsGui.Add("Text", "xm w60", "默认分类:")
    sCats := SettingsGui.Add("Edit", "x+10 w250 r3", savedCats)

    SettingsGui.Add("Text", "xm w60", "默认封面:")
    sCover := SettingsGui.Add("Edit", "x+10 w250", savedCover)

    btnSave := SettingsGui.Add("Button", "xm y+15 w150", "保存设置")
    btnCancel := SettingsGui.Add("Button", "x+20 w150", "取消")

    btnSave.OnEvent("Click", (*) => SaveSettings(sTitle.Value, sTags.Value, sCats.Value, sCover.Value))
    btnCancel.OnEvent("Click", (*) => (SettingsGui.Destroy(), SettingsGui := 0, IsObject(MetaGui) ? MetaGui.Show() : ""))
    SettingsGui.OnEvent("Close", (*) => (SettingsGui.Destroy(), SettingsGui := 0, IsObject(MetaGui) ? MetaGui.Show() : ""))

    SettingsGui.Show()
}

; =========================
; 逻辑处理函数
; =========================

SaveSettings(title, tags, cats, cover)
{
    global IniFile, SettingsGui, MetaGui
    IniWrite(title, IniFile, "Defaults", "Title")
    IniWrite(tags, IniFile, "Defaults", "Tags")
    IniWrite(cats, IniFile, "Defaults", "Categories")
    IniWrite(cover, IniFile, "Defaults", "Cover")
    
    MsgBox("默认设置已保存！", "提示", "Iconi")
    SettingsGui.Destroy()
    SettingsGui := 0
    if IsObject(MetaGui) {
        MetaGui.Destroy()
        MetaGui := 0
        ShowMetaGui()
    }
}

FormatYamlList(text)
{
    if (Trim(text) = "")
        return ""
    text := StrReplace(text, "，", ",")
    text := StrReplace(text, ",", "`n")
    
    result := ""
    Loop Parse, text, "`n", "`r"
    {
        line := Trim(A_LoopField)
        if (line != "")
            result .= "`n- " line
    }
    return result
}

InsertYaml(title, dateStr, tags, cats, cover)
{
    global MetaGui
    
    formattedTags := FormatYamlList(tags)
    formattedCats := FormatYamlList(cats)

    finalStr := "---`n"
    finalStr .= "title: " title "`n"
    finalStr .= "date: " dateStr "`n"
    
    if (formattedTags != "")
        finalStr .= "tags:" formattedTags "`n"
    else
        finalStr .= "tags: []`n"

    if (formattedCats != "")
        finalStr .= "categories:" formattedCats "`n"
    else
        finalStr .= "categories: []`n"

    finalStr .= "cover: " cover "`n"
    finalStr .= "---`n"

    MetaGui.Destroy()
    MetaGui := 0

    if !WinActive("ahk_exe Typora.exe")
    {
        MsgBox("不在 Typora 窗口中，内容已复制到剪贴板。")
        A_Clipboard := finalStr
        return
    }

    PasteToTypora(finalStr)
}

PasteToTypora(str)
{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := str
    if !ClipWait(1)
    {
        MsgBox("剪贴板操作失败")
        return
    }
    
    Send "^v"
    Sleep 200
    
    A_Clipboard := ClipSaved
}