#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SendMode "Input"

; =========================
; 全局变量声明
; =========================
global IniFile := A_ScriptDir "\TyporaSettings.ini"
global MainGui := 0, SettingsGui := 0
global MainBgPic := 0
global FieldControls := Map()

; 设置界面控件句柄
global LBFields := 0, EdtBg := 0, SliOp := 0, SliW := 0, EdtW := 0, SliH := 0, EdtH := 0
global ColorPreviewBlock := 0 ; 颜色预览色块
global CurrentFontColor := "000000" ; 当前字体颜色(Hex)

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

; 启动立即显示
ShowMainGui()

; =========================
; 快捷键
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!i:: ShowMainGui()
#HotIf
F4:: ShowMainGui()

; =========================
; 主界面函数
; =========================
ShowMainGui()
{
    global MainGui, IniFile, MainBgPic, FieldControls, CurrentFontColor
    
    if IsObject(MainGui) 
    {
        MainGui.Show()
        return
    }

    ; === 读取并校验颜色 ===
    savedColor := IniRead(IniFile, "Appearance", "FontColor", "000000")
    ; 校验是否为合法的 Hex 颜色 (6位 0-9A-F)
    if !RegExMatch(savedColor, "^[0-9A-Fa-f]{6}$")
    {
        savedColor := "000000" ; 如果是旧版本的 "Gold" 等非法值，重置为黑
    }
    CurrentFontColor := savedColor

    bgPath := IniRead(IniFile, "Appearance", "Background", "")
    opacity := IniRead(IniFile, "Appearance", "Opacity", 255) 
    winW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    winH := IniRead(IniFile, "Appearance", "WinHeight", 500)

    ; === 创建窗口 ===
    MainGui := Gui("+MinimizeBox +Owner", "YAML Generator")
    ; 直接使用 hex 颜色
    MainGui.SetFont("s10 c" CurrentFontColor, "Microsoft YaHei UI")
    MainGui.BackColor := "White"
    MainGui.MarginX := 20, MainGui.MarginY := 20

    ; === 1. 背景图层 ===
    if (bgPath != "" && FileExist(bgPath)) 
    {
        MainBgPic := MainGui.Add("Picture", "x0 y0 w" winW " h" winH " +0x4000000", bgPath)
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

    currentY := 20

    for index, fieldName in fields 
    {
        if (fieldName = "") 
        {
            continue
        }
        
        ; 标签
        MainGui.SetFont("s10 c" CurrentFontColor " w600")
        MainGui.Add("Text", "x20 y" currentY " w80 Right +BackgroundTrans", fieldName . ":")
        
        defVal := IniRead(IniFile, "DefaultValues", fieldName, "")
        if (fieldName = "Date")
        {
            defVal := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        }
            
        MainGui.SetFont("s10 cBlack w400") ; 输入框文字始终保持黑色以便阅读
        
        ; 输入框
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
    currentY += 15
    btnW := (winW - 60) / 2
    
    MainGui.SetFont("s10 c" CurrentFontColor)
    btnSet := MainGui.Add("Button", "x20 y" currentY " w" btnW, "⚙️ 设置")
    btnIns := MainGui.Add("Button", "x+20 yp w" btnW " Default", "插入 YAML")

    btnSet.OnEvent("Click", (*) => ShowSettingsGui())
    btnIns.OnEvent("Click", (*) => DoInsert(fields))

    ; === 4. 显示与透明度 ===
    MainGui.OnEvent("Close", (*) => ExitApp()) 
    
    MainGui.Show("w" winW " h" winH)
    
    if (opacity < 255)
    {
        try WinSetTransparent(opacity, MainGui.Hwnd)
    }
}

; =========================
; 设置界面
; =========================
ShowSettingsGui()
{
    global SettingsGui, MainGui, IniFile
    global LBFields, EdtBg, SliOp, SliW, EdtW, SliH, EdtH, ColorPreviewBlock, CurrentFontColor

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

    ; --- 左栏: 属性列表 ---
    SettingsGui.Add("GroupBox", "x10 y10 w200 h430", "属性排序")
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "")
    fieldArr := StrSplit(fieldListStr, "|")
    LBFields := SettingsGui.Add("ListBox", "xp+10 yp+25 w180 h390", fieldArr)

    ; --- 中栏: 属性操作按钮 ---
    SettingsGui.Add("GroupBox", "x220 y10 w130 h180", "属性操作")
    btnAdd := SettingsGui.Add("Button", "xp+10 yp+25 w110 h30", "➕ 新增")
    btnDel := SettingsGui.Add("Button", "xp y+5 w110 h30", "➖ 删除")
    
    ; 重命名按钮 (原默认值按钮)
    btnRen := SettingsGui.Add("Button", "xp y+5 w110 h30", "✏️ 重命名")
    
    ; 额外的默认值按钮 (为了功能完整性，做小一点)
    btnDef := SettingsGui.Add("Button", "xp y+5 w110 h20", "设定默认值")

    btnUp  := SettingsGui.Add("Button", "xp y+10 w50 h30", "▲")
    btnDown:= SettingsGui.Add("Button", "x+10 yp w50 h30", "▼")

    ; --- 右栏: 外观与尺寸 ---
    SettingsGui.Add("GroupBox", "x220 y200 w320 h240", "外观与尺寸")

    ; 背景图
    SettingsGui.Add("Text", "xp+10 yp+25", "背景图片:")
    EdtBg := SettingsGui.Add("Edit", "x+10 w200 ReadOnly", IniRead(IniFile, "Appearance", "Background", ""))
    btnBrowse := SettingsGui.Add("Button", "x+5 w40 h24", "...")

    ; 透明度
    SettingsGui.Add("Text", "x230 y+15", "透明度:")
    SliOp := SettingsGui.Add("Slider", "x+10 w180 Range50-255 ToolTip", IniRead(IniFile, "Appearance", "Opacity", 255))

    ; 字体颜色 (调色盘)
    SettingsGui.Add("Text", "x230 y+15", "字体色:")
    
    ; 颜色预览块
    ColorPreviewBlock := SettingsGui.Add("Text", "x+10 w25 h20 +Border", "")
    ColorPreviewBlock.Opt("+Background" CurrentFontColor) ; 设置初始颜色
    
    btnPickColor := SettingsGui.Add("Button", "x+10 yp w140 h24", "🎨 选择颜色 (调色盘)")

    ; 窗口尺寸
    currW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    currH := IniRead(IniFile, "Appearance", "WinHeight", 500)

    SettingsGui.Add("Text", "x230 y+20", "窗口宽度:")
    SliW := SettingsGui.Add("Slider", "x+10 w140 Range300-800", currW)
    EdtW := SettingsGui.Add("Edit", "x+10 yp w50 Number", currW)

    SettingsGui.Add("Text", "x230 y+15", "窗口高度:")
    SliH := SettingsGui.Add("Slider", "x+10 w140 Range300-900", currH)
    EdtH := SettingsGui.Add("Edit", "x+10 yp w50 Number", currH)
    
    btnResetSize := SettingsGui.Add("Button", "x450 yp-20 w60 h40", "重置`n大小")

    ; --- 底部: 保存 ---
    btnSave := SettingsGui.Add("Button", "x10 y+40 w530 h40", "保存全部设置并重启界面")

    ; === 事件绑定 ===
    btnAdd.OnEvent("Click", (*) => CustomInputBox("新增属性", "请输入属性名(英文):", DoAddField))
    btnDel.OnEvent("Click", DelField)
    btnRen.OnEvent("Click", RenameField)   ; 重命名
    btnDef.OnEvent("Click", EditDefaultValue) ; 编辑默认值
    
    btnUp.OnEvent("Click", (*) => MoveField(-1))
    btnDown.OnEvent("Click", (*) => MoveField(1))
    
    btnBrowse.OnEvent("Click", BrowseBg)
    btnPickColor.OnEvent("Click", PickColor) ; 调色盘
    btnResetSize.OnEvent("Click", ResetWindowSize)
    btnSave.OnEvent("Click", SaveAllSettings)
    
    SliW.OnEvent("Change", (*) => EdtW.Value := SliW.Value)
    EdtW.OnEvent("Change", (*) => SliW.Value := EdtW.Value)
    SliH.OnEvent("Change", (*) => EdtH.Value := SliH.Value)
    EdtH.OnEvent("Change", (*) => SliH.Value := EdtH.Value)

    SettingsGui.OnEvent("Close", CloseSettings)
    SettingsGui.Show("w550 h500")
}

CloseSettings(*) 
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
; 辅助功能与逻辑
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

; 调色盘逻辑
PickColor(*)
{
    global CurrentFontColor, ColorPreviewBlock
    
    ; 弹出 Windows 颜色选择器
    ; 注意：V2 没有内置 Color 窗口，这里使用 DllCall 调用系统 comdlg32
    ; 为了简化，我们使用一个简单的 InputBox 让用户输入 Hex，
    ; 或者更好的方法：使用 FileSelect 的替代品？不，还是 DllCall 靠谱。
    
    ; 简易方案：调用系统的 ChooseColor
    cc := Buffer(36, 0)
    NumPut("UInt", 36, cc, 0)
    
    if DllCall("comdlg32\ChooseColor", "Ptr", cc.Ptr)
    {
        rgbResult := NumGet(cc, 12, "UInt")
        ; Windows 返回的是 BGR，我们需要 RGB
        r := (rgbResult & 0xFF)
        g := ((rgbResult >> 8) & 0xFF)
        b := ((rgbResult >> 16) & 0xFF)
        
        hexColor := Format("{:02X}{:02X}{:02X}", r, g, b)
        CurrentFontColor := hexColor
        ColorPreviewBlock.Opt("+Background" hexColor)
        ColorPreviewBlock.Redraw()
    }
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

; 重命名逻辑
RenameField(*)
{
    global LBFields, IniFile
    if (!LBFields.Value) 
    {
        MsgBox "请先选中一个属性"
        return
    }
    oldName := LBFields.Text
    
    CustomInputBox("重命名属性", "将 [" oldName "] 重命名为:", DoRename, oldName)
}

DoRename(newName)
{
    global LBFields, IniFile
    if (newName = "") 
        return
        
    idx := LBFields.Value
    oldName := LBFields.Text
    
    ; 更新列表显示
    LBFields.Delete(idx)
    LBFields.Insert(idx, [newName])
    LBFields.Choose(idx)
    
    ; 迁移默认值配置
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
    if (LBFields.Value)
    {
        LBFields.Delete(LBFields.Value)
    }
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
        
    ; 交换
    temp := items[idx]
    items[idx] := items[newIdx]
    items[newIdx] := temp
    
    ; 彻底刷新列表
    LBFields.Delete()
    LBFields.Add(items)
    LBFields.Choose(newIdx)
}

BrowseBg(*) 
{
    global EdtBg
    s := FileSelect(3,, "选择背景图片", "Images (*.jpg; *.png)")
    if s 
    {
        EdtBg.Value := s
    }
}

ResetWindowSize(*) 
{
    global SliW, EdtW, SliH, EdtH
    SliW.Value := 450
    EdtW.Value := 450
    SliH.Value := 500
    EdtH.Value := 500
}

SaveAllSettings(*) 
{
    global SettingsGui, MainGui, IniFile
    global LBFields, EdtBg, SliOp, CurrentFontColor, SliW, SliH
    
    ; 保存字段结构
    items := ControlGetItems(LBFields.Hwnd)
    s := ""
    for i in items 
    {
        s .= i "|"
    }
    IniWrite(RTrim(s, "|"), IniFile, "Structure", "Fields")
    
    ; 保存外观
    IniWrite(EdtBg.Value, IniFile, "Appearance", "Background")
    IniWrite(SliOp.Value, IniFile, "Appearance", "Opacity")
    
    ; 保存当前选择的颜色
    IniWrite(CurrentFontColor, IniFile, "Appearance", "FontColor")
    
    ; 保存尺寸
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
    global FieldControls, MainGui
    
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
    
    TrayTip "YAML 已生成并复制", "Typora 助手", "Iconi"
    
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
        IniWrite("500", IniFile, "Appearance", "WinHeight")
        IniWrite("000000", IniFile, "Appearance", "FontColor")
    }
}