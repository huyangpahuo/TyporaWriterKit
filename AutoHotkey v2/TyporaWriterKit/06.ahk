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
global ListFieldControls := Map()  

; 核心受保护属性
global ProtectedFields := ["Title", "Date", "Tags", "Categories", "Cover"]
global FullBgPath := ""

; 设置界面变量
global LBFields := 0, DDLPreColors := 0, EdtHexInput := 0, EdtColorName := 0, ColorPreview := 0
global EdtBgPathDisp := 0, SliOp := 0, SliW := 0, EdtW := 0, SliH := 0, EdtH := 0
global BtnDelColor := 0 

; 颜色工具变量
global CT_Gui := 0, CT_CustomGui := 0, HelpGui := 0, CT_CustomHex := "FF0000"

; 默认预设颜色表
global DefaultPresets := Map(
    "极简白", "FFFFFF", "夜间黑", "202020", "护眼绿", "C7EDCC", "少女粉", "FFF0F5",
    "天空蓝", "E0F7FA", "高级灰", "F5F5F5", "深海蓝", "1A237E", "暗夜紫", "2D1B4E",
    "薄荷绿", "E0F2F1", "柠檬黄", "FFFDE7", "日落橙", "FFCCBC", "樱花红", "FFCDD2",
    "薰衣草", "E1BEE7", "极客黑", "121212", "深空灰", "37474F", "茶色", "D7CCC8",
    "青柠", "F0F4C3", "琥珀", "FFECB3", "紫罗兰", "F3E5F5", "冰川蓝", "B3E5FC"
)
global RuntimeColors := DefaultPresets.Clone()

InitConfig()
LoadCustomColors() 

; =========================
; 托盘菜单
; =========================
A_TrayMenu.Delete()
A_TrayMenu.Add("显示主窗口", (*) => ShowMainGui())
A_TrayMenu.Add("全局设置", (*) => ShowSettingsGui())
A_TrayMenu.Add("颜色工具", (*) => ShowColorTool())
A_TrayMenu.Add()
A_TrayMenu.Add("重启", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())

ShowMainGui()

; =========================
; 快捷键
; =========================
#HotIf WinActive("ahk_exe Typora.exe")
^!i:: ShowMainGui()    
^!c:: ShowColorTool()  
#HotIf
F4:: ShowMainGui()     

; ==============================================================================
; PART 1: 主界面 (完全重构布局算法)
; ==============================================================================
ShowMainGui()
{
    global MainGui, IniFile, FieldControls, ListFieldControls
    
    ; 严谨的对象检查
    if IsObject(MainGui) 
    {
        try 
        {
            MainGui.Show()
            return
        }
        catch
        {
            MainGui := 0
        }
    }

    ; === 读取配置 ===
    bgColor := IniRead(IniFile, "Appearance", "BgColor", "FFFFFF")
    bgPath := IniRead(IniFile, "Appearance", "Background", "")
    opacity := IniRead(IniFile, "Appearance", "Opacity", 255)
    winW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    winH := IniRead(IniFile, "Appearance", "WinHeight", 680) ; 稍微加高以防内容溢出

    txtColor := "Black" 
    if (bgPath == "")
    {
        txtColor := IsDarkColor(bgColor) ? "White" : "Black"
    }

    ; === 创建窗口 ===
    MainGui := Gui("+MinimizeBox", "Typora 终极助手")
    MainGui.SetFont("s10 c" txtColor, "Microsoft YaHei UI")
    
    if (bgPath != "")
    {
        MainGui.BackColor := "White"
    }
    else
    {
        MainGui.BackColor := bgColor
    }
    
    MainGui.MarginX := 20, MainGui.MarginY := 20

    ; === 背景图 ===
    if (bgPath != "" && FileExist(bgPath)) 
    {
        try 
        {
            MainGui.Add("Picture", "x0 y0 w" winW " h" winH " +0x4000000", bgPath)
        }
    }

    ; === 动态字段构建 (流式布局) ===
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "Title|Date|Tags|Categories|Cover")
    fields := StrSplit(fieldListStr, "|")
    FieldControls := Map()
    ListFieldControls := Map()
    
    ; 布局参数
    labelW := 80
    inputX := labelW + 35 ; 标签右侧起始位置 (20margin + 80label + 15gap)
    inputW := winW - inputX - 30 ; 留右边距
    if (inputW < 150) 
    {
        inputW := 150
    }
    
    currentY := 25

    for index, fieldName in fields 
    {
        if (fieldName = "") 
        {
            continue
        }
        
        ; 1. 绘制标签 (Title:)
        MainGui.SetFont("s10 w600 c" txtColor)
        MainGui.Add("Text", "x20 y" currentY " w" labelW " Right +BackgroundTrans", fieldName . ":")
        
        ; 恢复输入框字体
        MainGui.SetFont("s10 w400 cBlack")
        
        ; 2. 绘制输入控件
        if (fieldName = "Tags" || fieldName = "Categories") 
        {
            ; === 列表模式 ===
            defValRaw := IniRead(IniFile, "DefaultValues", fieldName, "")
            defArr := StrSplit(StrReplace(defValRaw, "`n", ","), ",")
            
            ; 列表框
            lb := MainGui.Add("ListBox", "x" inputX " y" currentY " w" inputW " h80", defArr)
            ListFieldControls[fieldName] := lb
            
            ; 辅助操作区 (位于列表正下方)
            opY := currentY + 85
            smallInputW := inputW - 70 
            
            addInput := MainGui.Add("Edit", "x" inputX " y" opY " w" smallInputW, "")
            btnAddItem := MainGui.Add("Button", "x+5 yp-1 w30 h26", "+")
            btnDelItem := MainGui.Add("Button", "x+5 yp w30 h26", "-")
            
            btnAddItem.OnEvent("Click", AddToList.Bind(lb, addInput))
            btnDelItem.OnEvent("Click", DelFromList.Bind(lb))
            
            ; 增加高度: 列表高80 + 间隙5 + 按钮高26 + 下个控件间距15
            currentY += 126
        } 
        else 
        {
            ; === 普通单行模式 ===
            defVal := IniRead(IniFile, "DefaultValues", fieldName, "")
            if (fieldName = "Date")
            {
                defVal := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            }
            
            ctl := MainGui.Add("Edit", "x" inputX " y" currentY " w" inputW " v" fieldName, defVal)
            FieldControls[fieldName] := ctl
            
            ; 增加高度: 控件高约26 + 间距14
            currentY += 40
        }
    }

    ; === 底部按钮区域 (固定在下方，不跟随 currentY 浮动，或者基于 currentY) ===
    ; 为了防止列表太多超出屏幕，最好基于 currentY
    
    currentY += 15
    btnW := (winW - 60) / 2
    
    MainGui.SetFont("s10 c" txtColor) 
    
    ; 第一排
    btnSet := MainGui.Add("Button", "x20 y" currentY " w" btnW, "⚙️ 设置")
    btnIns := MainGui.Add("Button", "x+20 yp w" btnW " Default", "插入 YAML")
    
    ; 第二排
    currentY += 45
    btnHelp := MainGui.Add("Button", "x20 y" currentY " w" btnW, "📖 使用说明")
    btnColorTool := MainGui.Add("Button", "x+20 yp w" btnW, "🎨 MD字体颜色")

    ; === 事件绑定 ===
    btnSet.OnEvent("Click", (*) => ShowSettingsGui())
    btnIns.OnEvent("Click", (*) => DoInsert(fields))
    btnHelp.OnEvent("Click", (*) => ShowHelpGui())
    btnColorTool.OnEvent("Click", (*) => ShowColorTool())

    MainGui.OnEvent("Close", (*) => ExitApp()) 
    
    MainGui.Show("w" winW " h" winH)
    
    if (opacity < 255)
    {
        try WinSetTransparent(opacity, MainGui.Hwnd)
    }
}

; ==============================================================================
; PART 2: 辅助功能
; ==============================================================================
AddToList(lbObj, editObj, *)
{
    txt := Trim(editObj.Value)
    if (txt != "")
    {
        lbObj.Add([txt])
        editObj.Value := "" 
        items := ControlGetItems(lbObj.Hwnd)
        if (items.Length > 0)
        {
            lbObj.Choose(items.Length) 
        }
    }
}

DelFromList(lbObj, *)
{
    idx := lbObj.Value
    if (idx > 0)
    {
        lbObj.Delete(idx)
    }
}

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
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) < 128
}

; ==============================================================================
; PART 3: 设置界面
; ==============================================================================
ShowSettingsGui()
{
    global SettingsGui, MainGui, IniFile
    global LBFields, DDLPreColors, EdtHexInput, EdtColorName, ColorPreview
    global EdtBgPathDisp, FullBgPath, SliOp, SliW, EdtW, SliH, EdtH
    global RuntimeColors, DefaultPresets, BtnDelColor

    if IsObject(SettingsGui) 
    {
        SettingsGui.Show()
        return
    }

    if IsObject(MainGui)
    {
        MainGui.Hide()
    }

    currBgColor := IniRead(IniFile, "Appearance", "BgColor", "FFFFFF")
    currTxtColor := IsDarkColor(currBgColor) ? "White" : "Black"

    SettingsGui := Gui("+AlwaysOnTop", "全局配置")
    SettingsGui.SetFont("s9 c" currTxtColor, "Microsoft YaHei UI")
    SettingsGui.BackColor := currBgColor

    Tabs := SettingsGui.Add("Tab3", "x10 y10 w500 h440", ["属性管理", "外观样式"])

    ; Tab 1
    Tabs.UseTab("属性管理")
    SettingsGui.Add("Text", "x30 y50 w300", "属性列表 (上限10个):")
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "")
    fieldArr := StrSplit(fieldListStr, "|")
    SettingsGui.SetFont("cBlack")
    LBFields := SettingsGui.Add("ListBox", "x30 y70 w200 h340", fieldArr)
    SettingsGui.SetFont("c" currTxtColor)

    btnAdd := SettingsGui.Add("Button", "x250 y70 w110 h30", "➕ 新增属性")
    btnDel := SettingsGui.Add("Button", "xp y+10 w110 h30", "➖ 删除属性")
    btnRen := SettingsGui.Add("Button", "xp y+10 w110 h30", "✏️ 重命名")
    btnDef := SettingsGui.Add("Button", "xp y+10 w110 h30", "📝 默认值")
    SettingsGui.Add("Text", "xp y+20 w110 h2 0x10") 
    btnUp  := SettingsGui.Add("Button", "xp y+20 w50 h30", "▲")
    btnDown:= SettingsGui.Add("Button", "x+10 yp w50 h30", "▼")

    ; Tab 2
    Tabs.UseTab("外观样式")
    SettingsGui.Add("GroupBox", "x30 y50 w460 h150", "窗口主题颜色")
    SettingsGui.Add("Text", "x50 y80", "预设风格:")
    colorNames := []
    for name, hex in RuntimeColors
    {
        colorNames.Push(name)
    }
    SettingsGui.SetFont("cBlack")
    DDLPreColors := SettingsGui.Add("DropDownList", "x+10 yp-3 w120 Sort", colorNames)
    SettingsGui.SetFont("c" currTxtColor)
    BtnDelColor := SettingsGui.Add("Button", "x+10 yp-1 w80 h24 Disabled", "删除此颜色")

    SettingsGui.Add("Text", "x50 y+20", "HEX:")
    SettingsGui.SetFont("cBlack")
    EdtHexInput := SettingsGui.Add("Edit", "x+5 yp-3 w60 Limit6", currBgColor)
    SettingsGui.SetFont("c" currTxtColor)
    SettingsGui.Add("Text", "x+10 yp+3", "名称:")
    SettingsGui.SetFont("cBlack")
    EdtColorName := SettingsGui.Add("Edit", "x+5 yp-3 w70 Limit6", "自定义")
    SettingsGui.SetFont("c" currTxtColor)
    ColorPreview := SettingsGui.Add("Text", "x+10 yp-1 w30 h24 +Border", "")
    ColorPreview.Opt("+Background" currBgColor)
    btnRefresh := SettingsGui.Add("Button", "x50 y+15 w90 h26", "刷新预览")
    btnAddColor := SettingsGui.Add("Button", "x+10 yp w90 h26", "确定添加")

    SettingsGui.Add("GroupBox", "x30 y210 w460 h110", "背景与透明度")
    SettingsGui.Add("Text", "x50 y240", "背景图片:")
    FullBgPath := IniRead(IniFile, "Appearance", "Background", "")
    dispPath := ShortenPath(FullBgPath, 35)
    SettingsGui.SetFont("cBlack")
    EdtBgPathDisp := SettingsGui.Add("Edit", "x+10 yp-3 w270 ReadOnly", dispPath)
    SettingsGui.SetFont("c" currTxtColor)
    btnBrowse := SettingsGui.Add("Button", "x+5 yp-1 w40 h24", "...")
    btnClearBg := SettingsGui.Add("Button", "x+5 yp w40 h24", "清除")
    SettingsGui.Add("Text", "x50 y+20", "窗口透明度:")
    SliOp := SettingsGui.Add("Slider", "x+10 yp w200 Range50-255 ToolTip", IniRead(IniFile, "Appearance", "Opacity", 255))

    SettingsGui.Add("GroupBox", "x30 y330 w460 h70", "窗口尺寸")
    currW := IniRead(IniFile, "Appearance", "WinWidth", 450)
    currH := IniRead(IniFile, "Appearance", "WinHeight", 650)
    SettingsGui.Add("Text", "x50 y355", "宽:")
    SliW := SettingsGui.Add("Slider", "x+5 yp w130 Range350-800", currW)
    EdtW := SettingsGui.Add("Edit", "x+5 yp-3 w40 Number", currW)
    SettingsGui.Add("Text", "x+20 yp+3", "高:")
    SliH := SettingsGui.Add("Slider", "x+5 yp w130 Range400-900", currH)
    EdtH := SettingsGui.Add("Edit", "x+5 yp-3 w40 Number", currH)
    Tabs.UseTab()

    btnCancel := SettingsGui.Add("Button", "x20 y460 w150 h40", "❌ 取消")
    btnSave := SettingsGui.Add("Button", "x350 yp w150 h40 Default", "✅ 保存并重启")

    btnAdd.OnEvent("Click", (*) => CustomInputBox("新增属性", "请输入属性名(英文):", DoAddField))
    btnDel.OnEvent("Click", DelField)
    btnRen.OnEvent("Click", RenameField)   
    btnDef.OnEvent("Click", EditDefaultValue) 
    btnUp.OnEvent("Click", (*) => MoveField(-1))
    btnDown.OnEvent("Click", (*) => MoveField(1))
    DDLPreColors.OnEvent("Change", SelectPresetColor)
    btnRefresh.OnEvent("Click", RefreshColorPreview)
    btnAddColor.OnEvent("Click", AddCustomColor)
    BtnDelColor.OnEvent("Click", DeleteCustomColor)
    btnBrowse.OnEvent("Click", BrowseBg)
    btnClearBg.OnEvent("Click", ClearBg)
    SliW.OnEvent("Change", (*) => EdtW.Value := SliW.Value)
    EdtW.OnEvent("Change", (*) => SliW.Value := EdtW.Value)
    SliH.OnEvent("Change", (*) => EdtH.Value := SliH.Value)
    EdtH.OnEvent("Change", (*) => SliH.Value := EdtH.Value)
    btnSave.OnEvent("Click", SaveAllSettings)
    btnCancel.OnEvent("Click", CancelSettings)

    SettingsGui.OnEvent("Close", CancelSettings)
    SettingsGui.Show("w520 h515")
}

; ==============================================================================
; PART 4: 逻辑处理
; ==============================================================================
LoadCustomColors() 
{
    global RuntimeColors, IniFile
    customSection := IniRead(IniFile, "CustomColors",, "")
    Loop Parse, customSection, "`n", "`r" 
    {
        if (A_LoopField = "") 
        { 
            continue 
        }
        parts := StrSplit(A_LoopField, "=")
        if (parts.Length = 2) 
        { 
            RuntimeColors[parts[1]] := parts[2] 
        }
    }
}

SelectPresetColor(*) 
{
    global DDLPreColors, EdtHexInput, RuntimeColors, BtnDelColor, DefaultPresets, EdtColorName
    choice := DDLPreColors.Text
    if (choice != "" && RuntimeColors.Has(choice)) 
    {
        hex := RuntimeColors[choice]
        EdtHexInput.Value := hex
        EdtColorName.Value := choice
        RefreshColorPreview()
        if (DefaultPresets.Has(choice)) 
        {
            BtnDelColor.Enabled := false
            BtnDelColor.Text := "系统预设"
        } 
        else 
        {
            BtnDelColor.Enabled := true
            BtnDelColor.Text := "删除此颜色"
        }
    }
}

RefreshColorPreview(*) 
{
    global EdtHexInput, ColorPreview
    hex := EdtHexInput.Value
    if RegExMatch(hex, "^[0-9A-Fa-f]{6}$") 
    {
        ColorPreview.Opt("+Background" hex)
        ColorPreview.Redraw()
    }
}

AddCustomColor(*) 
{
    global EdtHexInput, EdtColorName, RuntimeColors, DDLPreColors, IniFile
    hex := EdtHexInput.Value
    name := Trim(EdtColorName.Value)
    if !RegExMatch(hex, "^[0-9A-Fa-f]{6}$") 
    {
        SafeMsgBox("HEX 代码必须是 6 位颜色代码 (例如 FFFFFF)")
        return
    }
    if (StrLen(name) < 1 || StrLen(name) > 7) 
    {
        SafeMsgBox("颜色名称长度必须在 1 到 7 个字之间。")
        return
    }
    RuntimeColors[name] := hex
    IniWrite(hex, IniFile, "CustomColors", name)
    UpdateColorDDL(name)
    SafeMsgBox("颜色 [" name "] 已保存！")
}

DeleteCustomColor(*) 
{
    global DDLPreColors, RuntimeColors, IniFile, DefaultPresets
    choice := DDLPreColors.Text
    if (DefaultPresets.Has(choice)) 
    {
        SafeMsgBox("不可删除预设颜色。")
        return
    }
    if (choice != "") 
    {
        RuntimeColors.Delete(choice)
        IniDelete(IniFile, "CustomColors", choice)
        UpdateColorDDL()
        SafeMsgBox("已删除颜色 [" choice "]")
    }
}

UpdateColorDDL(selectItem := "") 
{
    global DDLPreColors, RuntimeColors
    items := []
    for k, v in RuntimeColors 
    { 
        items.Push(k) 
    }
    DDLPreColors.Delete()
    DDLPreColors.Add(items)
    if (selectItem != "") 
    {
        try 
        { 
            DDLPreColors.Choose(selectItem) 
        }
    } 
    else 
    { 
        DDLPreColors.Choose(1) 
    }
    SelectPresetColor()
}

DoAddField(val) 
{
    global LBFields
    items := ControlGetItems(LBFields.Hwnd)
    if (items.Length >= 10) 
    {
        SafeMsgBox("上限10个属性。", "提示", "Icon!")
        return
    }
    if (val = "") 
    { 
        return 
    }
    val := Trim(val)
    for item in items 
    {
        if (item = val) 
        {
            SafeMsgBox("属性已存在")
            return
        }
    }
    LBFields.Add([val])
}

RenameField(*) 
{
    global LBFields, IniFile, ProtectedFields
    if (!LBFields.Value) 
    {
        SafeMsgBox("请先选中属性")
        return
    }
    oldName := LBFields.Text
    if HasValue(ProtectedFields, oldName) 
    {
        SafeMsgBox("核心属性禁止重命名。", "禁止", "Icon!")
        return
    }
    CustomInputBox("重命名", "重命名 [" oldName "] 为:", DoRename, oldName)
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

DelField(*) 
{
    global LBFields, ProtectedFields
    if (!LBFields.Value) 
    { 
        return 
    }
    fName := LBFields.Text
    if HasValue(ProtectedFields, fName) 
    {
        SafeMsgBox("核心属性禁止删除。", "禁止", "Icon!")
        return
    }
    LBFields.Delete(LBFields.Value)
}

ShortenPath(path, maxLen) 
{
    if (StrLen(path) <= maxLen) 
    { 
        return path 
    }
    SplitPath(path, &name, &dir)
    if (StrLen(name) >= maxLen) 
    { 
        return SubStr(name, 1, maxLen-3) "..." 
    }
    drive := SubStr(path, 1, 3) 
    remain := maxLen - StrLen(drive) - StrLen(name) - 4 
    if (remain < 1) 
    { 
        return drive "..." name 
    }
    return drive "..." SubStr(dir, -remain) "\" name
}

BrowseBg(*) 
{
    global EdtBgPathDisp, FullBgPath
    s := FileSelect(3,, "选择背景图片", "Images (*.jpg; *.png)")
    if s 
    {
        FullBgPath := s
        EdtBgPathDisp.Value := ShortenPath(s, 35)
    }
}

ClearBg(*) 
{
    global EdtBgPathDisp, FullBgPath
    FullBgPath := ""
    EdtBgPathDisp.Value := ""
}

HasValue(arr, val) 
{
    for index, value in arr 
    {
        if (value = val) 
        { 
            return true 
        }
    }
    return false
}

SafeMsgBox(text, title := "助手", options := "") 
{
    global SettingsGui
    ownOpt := ""
    if IsObject(SettingsGui) 
    { 
        ownOpt := "Owner" SettingsGui.Hwnd 
    }
    MsgBox(text, title, options " " ownOpt " 262144") 
}

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

EditDefaultValue(*) 
{
    global LBFields, IniFile
    if (!LBFields.Value) 
    {
        SafeMsgBox("请先选中属性")
        return
    }
    fName := LBFields.Text
    currDef := IniRead(IniFile, "DefaultValues", fName, "")
    CustomInputBox("默认值", "编辑 [" fName "] 默认值:", FinishEditDefault, currDef)
}

FinishEditDefault(val) 
{
    global LBFields, IniFile
    fName := LBFields.Text
    IniWrite(val, IniFile, "DefaultValues", fName)
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

SaveAllSettings(*) 
{
    global SettingsGui, MainGui, IniFile
    global LBFields, FullBgPath, SliOp, EdtHexInput, SliW, SliH
    items := ControlGetItems(LBFields.Hwnd)
    s := ""
    for i in items 
    { 
        s .= i "|" 
    }
    IniWrite(RTrim(s, "|"), IniFile, "Structure", "Fields")
    IniWrite(FullBgPath, IniFile, "Appearance", "Background")
    IniWrite(SliOp.Value, IniFile, "Appearance", "Opacity")
    IniWrite(EdtHexInput.Value, IniFile, "Appearance", "BgColor")
    IniWrite(SliW.Value, IniFile, "Appearance", "WinWidth")
    IniWrite(SliH.Value, IniFile, "Appearance", "WinHeight")
    SettingsGui.Destroy()
    SettingsGui := 0
    
    ; 核心修复: 销毁并置空后重新创建
    if IsObject(MainGui) 
    { 
        MainGui.Destroy() 
        MainGui := 0
    }
    ShowMainGui() 
}

DoInsert(fieldsOrder) 
{
    global FieldControls, ListFieldControls
    finalStr := "---`n"
    for idx, fName in fieldsOrder 
    {
        if (fName = "") 
        { 
            continue 
        }
        if (ListFieldControls.Has(fName)) 
        {
            lb := ListFieldControls[fName]
            items := ControlGetItems(lb.Hwnd)
            if (items.Length > 0) 
            {
                finalStr .= StrLower(fName) . ":`n"
                for item in items 
                { 
                    finalStr .= "  - " item "`n" 
                }
            } 
            else 
            { 
                finalStr .= StrLower(fName) . ": []`n" 
            }
        } 
        else if (FieldControls.Has(fName)) 
        {
            val := FieldControls[fName].Value
            finalStr .= StrLower(fName) . ": " . val . "`n"
        }
    }
    finalStr .= "---`n"
    A_Clipboard := finalStr
    SafeMsgBox("已生成并复制到剪贴板！", "成功")
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
        IniWrite("AHK,Demo", IniFile, "DefaultValues", "Tags")
        IniWrite("450", IniFile, "Appearance", "WinWidth")
        IniWrite("650", IniFile, "Appearance", "WinHeight")
        IniWrite("FFFFFF", IniFile, "Appearance", "BgColor")
        IniWrite("255", IniFile, "Appearance", "Opacity")
    }
}

; ==============================================================================
; PART 5: 新增功能 - 帮助 & 颜色工具
; ==============================================================================
ShowHelpGui()
{
    global HelpGui, MainGui
    if IsObject(HelpGui) 
    {
        HelpGui.Show()
        return
    }
    
    ; 窗口置顶，隶属于 MainGui
    HelpGui := Gui("+AlwaysOnTop +Owner" MainGui.Hwnd, "使用说明")
    HelpGui.SetFont("s10", "Microsoft YaHei UI")
    HelpGui.BackColor := "White"
    
    HelpGui.AddEdit(
        "xm ym w400 h260 ReadOnly -VScroll Wrap",
        "红红火火恍恍惚惚哈哈哈哈哈哈哈哈哈哈哈哈`n`n"
        "① 点击颜色,在 Typora 中为选中文本设置字体颜色`n`n"
        "② 若不小心关闭主窗口,可使用 Ctrl + Alt + C 重新打开`n`n"
        "③ 主窗口与所有小窗口均支持自由拉伸`n`n"
        "④ 由于我的软件目前存在一个已知的暂时无法修复的Bug可能会导致文字消失,可使用 Ctrl + Z 撤回操作,以及如果你们想要将已经修改颜色的文字换一个颜色,对此我无能为力,你可以可使用 Ctrl + Z 撤回颜色或者删掉重新打字并再次选择颜色"
    )
    
    HelpGui.Show("w420 h280")
}

; === 颜色工具主窗口 ===
ShowColorTool()
{
    global CT_Gui, MainGui
    
    if IsObject(CT_Gui)
    {
        CT_Gui.Show()
        return
    }

    ; 使用白色背景，字体雅黑
    CT_Gui := Gui("+AlwaysOnTop +Resize", "MD字体颜色工具")
    CT_Gui.SetFont("s9", "Microsoft YaHei UI")
    CT_Gui.BackColor := "White"

    ; 顶部功能区
    infoBtn := CT_Gui.AddButton("xm w120", "使用说明")
    customBtn := CT_Gui.AddButton("x+20 yp w120", "自定义颜色")

    infoBtn.OnEvent("Click", (*) => ShowHelpGui())
    customBtn.OnEvent("Click", (*) => ShowCustomColorGui())

    ; 颜色数据
    colors := [
        ["DarkOrange", "焦橙色"], ["Red", "红色"], ["LightSkyBlue", "天蓝"],
        ["Turquoise", "绿松石"], ["MediumVioletRed", "紫红"], ["Teal", "蓝绿色"],
        ["Gold", "金黄色"], ["DimGray", "灰黑色"], ["DeepPink", "亮粉色"],
        ["DodgerBlue", "亮蓝"], ["LimeGreen", "鲜绿"], ["OrangeRed", "橙红"],
        ["SlateBlue", "岩蓝"], ["Chocolate", "巧克力"], ["Crimson", "深红"],
        ["SeaGreen", "海绿"], ["SteelBlue", "钢蓝"], ["Black", "纯黑"]
    ]

    ColorHex := Map(
        "DarkOrange", "FF8C00", "Red", "FF0000", "LightSkyBlue", "87CEFA",
        "Turquoise", "40E0D0", "MediumVioletRed", "C71585", "Teal", "008080",
        "Gold", "FFD700", "DimGray", "696969", "DeepPink", "FF1493",
        "DodgerBlue", "1E90FF", "LimeGreen", "32CD32", "OrangeRed", "FF4500",
        "SlateBlue", "6A5ACD", "Chocolate", "D2691E", "Crimson", "DC143C",
        "SeaGreen", "2E8B57", "SteelBlue", "4682B4", "Black", "000000"
    )

    colW := 120   
    rowH := 28    
    gapY := 6     
    startY := 45  

    Loop colors.Length
    {
        c := colors[A_Index][1]
        n := colors[A_Index][2]
        
        ; 0为左列, 1为右列
        col := (A_Index <= 9) ? 0 : 1
        row := Mod(A_Index - 1, 9)

        ; 左边是 xm，右边是 xm+140 (120按钮+20间距)
        xPosStr := (col == 0) ? "xm" : "xm+140"
        yPos := startY + row * (rowH + gapY)

        ; 绘制色块
        t := CT_Gui.AddText(
            xPosStr " y" yPos " w" colW " h" rowH
            " 0x200 Center Border Background" ColorHex[c],
            n
        )
        
        ; 自动适配文字颜色
        if (c = "Black" || c = "Crimson" || c = "SlateBlue" || c = "Teal" || c = "DimGray")
        {
            t.SetFont("cWhite")
        }
        else
        {
            t.SetFont("cBlack")
        }
            
        t.Tag := ColorHex[c] 
        t.OnEvent("Click", ApplyColorFromText)
    }

    CT_Gui.Show("w290 h370")
}

ApplyColorFromText(ctrl, *)
{
    if WinExist("ahk_exe Typora.exe")
    {
        WinActivate "ahk_exe Typora.exe"
        WinWaitActive "ahk_exe Typora.exe",, 1
        AddFontColor("#" ctrl.Tag)
    }
}

; === 自定义颜色窗口 ===
ShowCustomColorGui()
{
    global CT_CustomGui, CT_CustomHex, CT_Gui

    if IsObject(CT_CustomGui)
    {
        CT_CustomGui.Show()
        return
    }

    CT_CustomGui := Gui("+AlwaysOnTop +Resize +Owner" CT_Gui.Hwnd, "自定义颜色")
    CT_CustomGui.SetFont("s9", "Microsoft YaHei UI")
    CT_CustomGui.BackColor := "White"

    CT_CustomGui.AddText("xm", "HEX (不带 #):")
    HexEdit := CT_CustomGui.AddEdit("xm w260", CT_CustomHex)

    CT_CustomGui.AddText("xm y+10", "RGB:")
    R := CT_CustomGui.AddEdit("xm w80", "255")
    G := CT_CustomGui.AddEdit("x+10 yp w80", "0")
    B := CT_CustomGui.AddEdit("x+10 yp w80", "0")

    Preview := CT_CustomGui.AddText(
        "xm y+10 w260 h40 0x200 Center Border Background" CT_CustomHex,
        "预览"
    )

    ; 实时更新
    R.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    G.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    B.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    HexEdit.OnEvent("Change", (*) => UpdateFromHex(HexEdit, Preview))

    apply := CT_CustomGui.AddButton("xm y+10 w260", "应用该颜色")
    apply.OnEvent("Click", (*) => ApplyCustomColor(HexEdit.Value))

    CT_CustomGui.Show("w300 h240")
}

UpdateFromRGB(R, G, B, HexEdit, Preview)
{
    global CT_CustomHex
    CT_CustomHex := Format("{:02X}{:02X}{:02X}", Clamp(R.Value), Clamp(G.Value), Clamp(B.Value))
    HexEdit.Value := CT_CustomHex
    try 
    {
        Preview.Opt("+Background" CT_CustomHex)
    }
}

UpdateFromHex(HexEdit, Preview)
{
    global CT_CustomHex
    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
    {
        CT_CustomHex := HexEdit.Value
        try 
        {
            Preview.Opt("+Background" CT_CustomHex)
        }
    }
}

ApplyCustomColor(hex)
{
    if WinExist("ahk_exe Typora.exe")
    {
        WinActivate "ahk_exe Typora.exe"
        WinWaitActive "ahk_exe Typora.exe",, 1
        AddFontColor("#" hex)
    }
}

Clamp(v)
{
    if (v = "" || !IsNumber(v))
    {
        return 0
    }
    v := Integer(v)
    return v < 0 ? 0 : v > 255 ? 255 : v
}

AddFontColor(colorStr)
{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""

    Send "^c"
    if !ClipWait(0.5)
    {
        A_Clipboard := "<font color='" colorStr "'></font>"
        Send "^v"
        Send "{Left 7}" 
        Sleep 300
        A_Clipboard := ClipSaved
        return
    }

    if (A_Clipboard != "")
    {
        A_Clipboard := "<font color='" colorStr "'>" A_Clipboard "</font>"
        Send "^v"
        Sleep 300 
    }
    
    A_Clipboard := ClipSaved
}