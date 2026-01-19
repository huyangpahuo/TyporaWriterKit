#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SendMode "Input"

; =========================
; 全局变量声明
; =========================
global IniFile := A_ScriptDir "\TyporaSettings.ini"
global MainGui := 0, SettingsGui := 0
global FieldControls := Map()

; 设置界面控件句柄 (需要跨函数访问)
global LBFields := 0
global DDLPreColors := 0, EdtHexColor := 0, ColorPreview := 0
global EdtBgPath := 0, SliOp := 0
global SliW := 0, EdtW := 0, SliH := 0, EdtH := 0

; 预设颜色表 (名称 -> Hex)
global ColorPresets := Map(
    "极简白", "FFFFFF",
    "夜间黑", "202020",
    "护眼绿", "C7EDCC",
    "少女粉", "FFF0F5",
    "天空蓝", "E0F7FA",
    "高级灰", "F5F5F5",
    "深海蓝", "1A237E",
    "暗夜紫", "2D1B4E"
)

; 确保初始化配置
InitConfig()

; =========================
; 托盘菜单
; =========================
A_TrayMenu.Delete()
A_TrayMenu.Add("显示窗口", (*) => ShowMainGui())
A_TrayMenu.Add("全局设置", (*) => ShowSettingsGui())
A_TrayMenu.Add()
A_TrayMenu.Add("重启", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())

; 启动显示
ShowMainGui()

; =========================
; 快捷键
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!i:: ShowMainGui()
#HotIf
F4:: ShowMainGui()

; =========================
; 主界面 (单窗口稳定版)
; =========================
ShowMainGui()
{
    global MainGui, IniFile, FieldControls
    
    if IsObject(MainGui) 
    {
        MainGui.Show()
        return
    }

    ; === 读取配置 ===
    bgColor := IniRead(IniFile, "Appearance", "BgColor", "FFFFFF")
    bgPath := IniRead(IniFile, "Appearance", "Background", "")
    opacity := IniRead(IniFile, "Appearance", "Opacity", 255)
    winW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    winH := IniRead(IniFile, "Appearance", "WinHeight", 550)

    ; 自动判断文字颜色
    txtColor := IsDarkColor(bgColor) ? "White" : "Black"

    ; === 创建窗口 ===
    MainGui := Gui("+MinimizeBox", "YAML Generator")
    MainGui.SetFont("s10 c" txtColor, "Microsoft YaHei UI")
    MainGui.BackColor := bgColor
    MainGui.MarginX := 20, MainGui.MarginY := 20

    ; === 1. 背景图 (底层) ===
    if (bgPath != "" && FileExist(bgPath)) 
    {
        try 
        {
            MainGui.Add("Picture", "x0 y0 w" winW " h" winH " +0x4000000", bgPath)
        }
    }

    ; === 2. 动态字段构建 ===
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "Title|Date|Tags|Categories|Cover")
    fields := StrSplit(fieldListStr, "|")
    FieldControls := Map()
    
    ctlW := winW - 130 
    if (ctlW < 100) 
    {
        ctlW := 100
    }
    currentY := 25

    for index, fieldName in fields 
    {
        if (fieldName = "") 
        {
            continue
        }
        
        ; 标签
        MainGui.SetFont("s10 w600 c" txtColor)
        MainGui.Add("Text", "x20 y" currentY " w80 Right +BackgroundTrans", fieldName . ":")
        
        defVal := IniRead(IniFile, "DefaultValues", fieldName, "")
        if (fieldName = "Date")
        {
            defVal := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        }
            
        ; 输入框
        MainGui.SetFont("s10 w400 cBlack")
        
        if (fieldName = "Tags" || fieldName = "Categories") 
        {
            ctl := MainGui.Add("Edit", "x+10 yp w" ctlW " r2 v" fieldName, defVal)
            currentY += 50
        } 
        else 
        {
            ctl := MainGui.Add("Edit", "x+10 yp w" ctlW " v" fieldName, defVal)
            currentY += 35
        }
        FieldControls[fieldName] := ctl
    }

    ; === 3. 底部按钮 ===
    currentY += 20
    btnW := (winW - 60) / 2
    
    MainGui.SetFont("s10 c" txtColor) 
    
    btnSet := MainGui.Add("Button", "x20 y" currentY " w" btnW, "⚙️ 设置")
    btnIns := MainGui.Add("Button", "x+20 yp w" btnW " Default", "插入 YAML")

    btnSet.OnEvent("Click", (*) => ShowSettingsGui())
    btnIns.OnEvent("Click", (*) => DoInsert(fields))

    ; === 4. 窗口显示与透明度 ===
    MainGui.OnEvent("Close", (*) => ExitApp()) 
    
    MainGui.Show("w" winW " h" winH)
    
    if (opacity < 255)
    {
        try WinSetTransparent(opacity, MainGui.Hwnd)
    }
}

; 简单的颜色深浅判断算法
IsDarkColor(hexColor)
{
    ifStr := "0x" . hexColor
    if !IsInteger(ifStr)
    {
        return false
    }
    r := (ifStr >> 16) & 0xFF
    g := (ifStr >> 8) & 0xFF
    b := ifStr & 0xFF
    ; 亮度公式
    luma := 0.2126 * r + 0.7152 * g + 0.0722 * b
    return (luma < 128)
}

; =========================
; 设置界面 (Tab 分页布局)
; =========================
ShowSettingsGui()
{
    global SettingsGui, MainGui, IniFile
    global LBFields, DDLPreColors, EdtHexColor, ColorPreview
    global EdtBgPath, SliOp, SliW, EdtW, SliH, EdtH

    if IsObject(SettingsGui) 
    {
        SettingsGui.Show()
        return
    }

    if IsObject(MainGui)
    {
        MainGui.Hide()
    }

    SettingsGui := Gui("+AlwaysOnTop", "全局配置")
    SettingsGui.SetFont("s9", "Microsoft YaHei UI")
    SettingsGui.BackColor := "White"

    ; === 使用 Tab 控件优化布局 ===
    Tabs := SettingsGui.Add("Tab3", "x10 y10 w480 h380", ["属性管理", "外观样式"])

    ; =========================
    ; Tab 1: 属性管理
    ; =========================
    Tabs.UseTab("属性管理")
    
    SettingsGui.Add("Text", "x30 y50 w200", "当前属性列表 (可排序):")
    
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "")
    fieldArr := StrSplit(fieldListStr, "|")
    LBFields := SettingsGui.Add("ListBox", "x30 y70 w200 h280", fieldArr)

    ; 右侧操作按钮
    btnAdd := SettingsGui.Add("Button", "x250 y70 w110 h30", "➕ 新增属性")
    btnDel := SettingsGui.Add("Button", "xp y+10 w110 h30", "➖ 删除属性")
    btnRen := SettingsGui.Add("Button", "xp y+10 w110 h30", "✏️ 重命名")
    btnDef := SettingsGui.Add("Button", "xp y+10 w110 h30", "📝 默认值")

    SettingsGui.Add("Text", "xp y+20 w110 h2 0x10") ; 分隔线

    btnUp  := SettingsGui.Add("Button", "xp y+20 w50 h30", "▲")
    btnDown:= SettingsGui.Add("Button", "x+10 yp w50 h30", "▼")

    ; =========================
    ; Tab 2: 外观样式
    ; =========================
    Tabs.UseTab("外观样式")

    ; --- 颜色设置 ---
    SettingsGui.Add("GroupBox", "x30 y50 w440 h100", "窗口主题颜色")
    
    SettingsGui.Add("Text", "x50 y80", "预设风格:")
    preColors := ["极简白", "夜间黑", "护眼绿", "少女粉", "天空蓝", "高级灰", "深海蓝", "暗夜紫"]
    DDLPreColors := SettingsGui.Add("DropDownList", "x+10 yp-3 w120 Choose1", preColors)
    
    SettingsGui.Add("Text", "x50 y+20", "HEX代码:")
    EdtHexColor := SettingsGui.Add("Edit", "x+10 yp-3 w80 Limit6", "FFFFFF")
    ColorPreview := SettingsGui.Add("Text", "x+20 yp-1 w60 h24 +Border", "")
    
    ; 颜色同步逻辑
    DDLPreColors.OnEvent("Change", SelectPresetColor)
    EdtHexColor.OnEvent("Change", UpdateColorPreview)

    ; --- 背景图与透明度 ---
    SettingsGui.Add("GroupBox", "x30 y160 w440 h120", "背景与透明度")
    
    SettingsGui.Add("Text", "x50 y190", "背景图片:")
    EdtBgPath := SettingsGui.Add("Edit", "x+10 yp-3 w250 ReadOnly", IniRead(IniFile, "Appearance", "Background", ""))
    btnBrowse := SettingsGui.Add("Button", "x+5 yp-1 w40 h24", "...")
    btnClearBg := SettingsGui.Add("Button", "x+5 yp w40 h24", "清除")

    SettingsGui.Add("Text", "x50 y+20", "窗口透明度:")
    SliOp := SettingsGui.Add("Slider", "x+10 yp w200 Range50-255 ToolTip", IniRead(IniFile, "Appearance", "Opacity", 255))
    SettingsGui.Add("Text", "x+10 yp cGray", "(255=不透明)")

    ; --- 尺寸设置 ---
    SettingsGui.Add("GroupBox", "x30 y290 w440 h80", "窗口尺寸")
    
    currW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    currH := IniRead(IniFile, "Appearance", "WinHeight", 550)

    SettingsGui.Add("Text", "x50 y315", "宽度:")
    SliW := SettingsGui.Add("Slider", "x+10 yp w120 Range350-800", currW)
    EdtW := SettingsGui.Add("Edit", "x+10 yp-3 w50 Number", currW)
    
    SettingsGui.Add("Text", "x+30 yp+3", "高度:")
    SliH := SettingsGui.Add("Slider", "x+10 yp w120 Range400-900", currH)
    EdtH := SettingsGui.Add("Edit", "x+10 yp-3 w50 Number", currH)

    ; 结束 Tab
    Tabs.UseTab()

    ; === 底部按钮 (Tab 之外) ===
    btnCancel := SettingsGui.Add("Button", "x20 y405 w150 h40", "❌ 取消")
    btnSave := SettingsGui.Add("Button", "x330 yp w150 h40 Default", "✅ 保存并重启")

    ; === 事件绑定 ===
    btnAdd.OnEvent("Click", (*) => CustomInputBox("新增属性", "请输入属性名(英文):", DoAddField))
    btnDel.OnEvent("Click", DelField)
    btnRen.OnEvent("Click", RenameField)   
    btnDef.OnEvent("Click", EditDefaultValue) 
    
    btnUp.OnEvent("Click", (*) => MoveField(-1))
    btnDown.OnEvent("Click", (*) => MoveField(1))
    
    btnBrowse.OnEvent("Click", BrowseBg)
    btnClearBg.OnEvent("Click", ClearBg)
    
    SliW.OnEvent("Change", (*) => EdtW.Value := SliW.Value)
    EdtW.OnEvent("Change", (*) => SliW.Value := EdtW.Value)
    SliH.OnEvent("Change", (*) => EdtH.Value := SliH.Value)
    EdtH.OnEvent("Change", (*) => SliH.Value := EdtH.Value)
    
    btnSave.OnEvent("Click", SaveAllSettings)
    btnCancel.OnEvent("Click", CancelSettings)

    ; 初始化颜色显示
    currHex := IniRead(IniFile, "Appearance", "BgColor", "FFFFFF")
    EdtHexColor.Value := currHex
    UpdateColorPreview()

    SettingsGui.OnEvent("Close", CancelSettings)
    SettingsGui.Show("w500 h460")
}

; 选中预设颜色时
SelectPresetColor(*)
{
    global DDLPreColors, EdtHexColor, ColorPresets
    choice := DDLPreColors.Text
    if ColorPresets.Has(choice)
    {
        EdtHexColor.Value := ColorPresets[choice]
        UpdateColorPreview()
    }
}

; 更新预览色块
UpdateColorPreview(*)
{
    global EdtHexColor, ColorPreview
    hex := EdtHexColor.Value
    if RegExMatch(hex, "^[0-9A-Fa-f]{6}$")
    {
        ColorPreview.Opt("+Background" hex)
        ColorPreview.Redraw()
    }
}

CancelSettings(*)
{
    global SettingsGui, MainGui
    SettingsGui.Destroy()
    SettingsGui := 0
    if IsObject(MainGui)
    {
        MainGui.Show()
    }
}

; =========================
; 辅助功能
; =========================
CustomInputBox(title, prompt, callback, defaultVal := "") 
{
    global SettingsGui
    InputGui := Gui("+Owner" SettingsGui.Hwnd " +AlwaysOnTop", title)
    InputGui.SetFont("s9", "Microsoft YaHei UI")
    InputGui.Add("Text", "xm w280", prompt)
    edt := InputGui.Add("Edit", "xm y+10 w280", defaultVal)
    btnOk := InputGui.Add("Button", "xm y+10 w80 Default", "确定")
    btnCancel := InputGui.Add("Button", "x+10 yp w80", "取消")
    
    btnOk.OnEvent("Click", (*) => (callback(edt.Value), InputGui.Destroy()))
    btnCancel.OnEvent("Click", (*) => InputGui.Destroy())
    InputGui.Show()
}

DoAddField(val) 
{
    global LBFields
    if (val = "") 
    {
        return
    }
    val := Trim(val)
    items := ControlGetItems(LBFields.Hwnd)
    for item in items 
    {
        if (item = val) 
        {
            MsgBox "属性已存在"
            return
        }
    }
    LBFields.Add([val])
}

RenameField(*)
{
    global LBFields, IniFile
    if (!LBFields.Value) 
    {
        MsgBox "请先选中一个属性"
        return
    }
    oldName := LBFields.Text
    if (oldName = "Date" || oldName = "date") 
    {
        MsgBox "Date 属性禁止重命名。", "禁止操作", "Icon!"
        return
    }
    CustomInputBox("重命名属性", "将 [" oldName "] 重命名为:", DoRename, oldName)
}

DoRename(newName)
{
    global LBFields, IniFile
    if (newName = "") 
    {
        return
    }
    idx := LBFields.Value
    oldName := LBFields.Text
    LBFields.Delete(idx)
    LBFields.Insert(idx, [newName])
    LBFields.Choose(idx)
    oldDef := IniRead(IniFile, "DefaultValues", oldName, "")
    if (oldDef != "") 
    {
        IniWrite(oldDef, IniFile, "DefaultValues", newName)
        IniDelete(IniFile, "DefaultValues", oldName)
    }
}

EditDefaultValue(*) 
{
    global LBFields, IniFile
    if (!LBFields.Value) 
    {
        MsgBox "请先选中一个属性"
        return
    }
    fName := LBFields.Text
    currDef := IniRead(IniFile, "DefaultValues", fName, "")
    CustomInputBox("设置默认值", "编辑 [" fName "] 的默认值:", FinishEditDefault, currDef)
}

FinishEditDefault(val) 
{
    global LBFields, IniFile
    fName := LBFields.Text
    IniWrite(val, IniFile, "DefaultValues", fName)
}

DelField(*) 
{
    global LBFields
    if (!LBFields.Value) 
    {
        return
    }
    fName := LBFields.Text
    if (fName = "Date" || fName = "date") 
    {
        MsgBox "Date 属性禁止删除。", "禁止操作", "Icon!"
        return
    }
    LBFields.Delete(LBFields.Value)
}

MoveField(offset) 
{
    global LBFields
    idx := LBFields.Value
    if (idx = 0) 
    {
        return
    }
    items := ControlGetItems(LBFields.Hwnd)
    count := items.Length
    newIdx := idx + offset
    if (newIdx < 1 || newIdx > count) 
    {
        return
    }
    temp := items[idx]
    items[idx] := items[newIdx]
    items[newIdx] := temp
    LBFields.Delete()
    LBFields.Add(items)
    LBFields.Choose(newIdx)
}

BrowseBg(*) 
{
    global EdtBgPath
    s := FileSelect(3,, "选择背景图片", "Images (*.jpg; *.png)")
    if s 
    {
        EdtBgPath.Value := s
    }
}

ClearBg(*)
{
    global EdtBgPath
    EdtBgPath.Value := ""
}

SaveAllSettings(*) 
{
    global SettingsGui, MainGui, IniFile
    global LBFields, EdtBgPath, SliOp, EdtHexColor, SliW, SliH
    
    items := ControlGetItems(LBFields.Hwnd)
    s := ""
    for i in items 
    {
        s .= i "|"
    }
    IniWrite(RTrim(s, "|"), IniFile, "Structure", "Fields")
    
    IniWrite(EdtBgPath.Value, IniFile, "Appearance", "Background")
    IniWrite(SliOp.Value, IniFile, "Appearance", "Opacity")
    IniWrite(EdtHexColor.Value, IniFile, "Appearance", "BgColor")
    
    IniWrite(SliW.Value, IniFile, "Appearance", "WinWidth")
    IniWrite(SliH.Value, IniFile, "Appearance", "WinHeight")
    
    SettingsGui.Destroy()
    SettingsGui := 0
    
    if IsObject(MainGui) 
    {
        MainGui.Destroy()
        MainGui := 0
    }
    ShowMainGui() 
}

; =========================
; 插入逻辑
; =========================
DoInsert(fieldsOrder)
{
    global FieldControls
    
    finalStr := "---`n"
    for idx, fName in fieldsOrder 
    {
        if (fName = "") 
        {
            continue
        }
        val := FieldControls[fName].Value
        
        if (fName = "Tags" || fName = "Categories") 
        {
            val := StrReplace(StrReplace(val, "，", ","), ",", "`n")
            if Trim(val) != "" 
            {
                finalStr .= StrLower(fName) . ":`n"
                Loop Parse, val, "`n", "`r" 
                {
                    if Trim(A_LoopField) != ""
                    {
                        finalStr .= "- " Trim(A_LoopField) "`n"
                    }
                }
            } 
            else 
            {
                finalStr .= StrLower(fName) . ": []`n"
            }
        } 
        else 
        {
            finalStr .= StrLower(fName) . ": " . val . "`n"
        }
    }
    finalStr .= "---`n"
    
    A_Clipboard := finalStr
    TrayTip "YAML 已复制", "Typora 助手", "Iconi"
    
    if WinExist("ahk_exe Typora.exe") 
    {
        WinActivate "ahk_exe Typora.exe"
        if WinWaitActive("ahk_exe Typora.exe",, 1) 
        {
            Send "^v"
        }
    }
}

InitConfig() 
{
    if !FileExist(IniFile) 
    {
        IniWrite("Title|Date|Tags|Categories|Cover", IniFile, "Structure", "Fields")
        IniWrite("My Title", IniFile, "DefaultValues", "Title")
        IniWrite("AHK", IniFile, "DefaultValues", "Tags")
        IniWrite("450", IniFile, "Appearance", "WinWidth")
        IniWrite("550", IniFile, "Appearance", "WinHeight")
        IniWrite("FFFFFF", IniFile, "Appearance", "BgColor")
        IniWrite("255", IniFile, "Appearance", "Opacity")
    }
}