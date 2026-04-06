#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SendMode "Input"

; ==============================================================================
; 全局变量声明 (YAML主程序) - 配置路径持久化
; ==============================================================================
global ConfigDir := A_MyDocuments "\TyporaSuite"
if !DirExist(ConfigDir)
{
    try DirCreate(ConfigDir)
}
global IniFile := ConfigDir "\TyporaSettings.ini"

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

; 主界面预设颜色表
global DefaultPresets := Map(
    "极简白", "FFFFFF", "夜间黑", "202020", "护眼绿", "C7EDCC", "少女粉", "FFF0F5",
    "天空蓝", "E0F7FA", "高级灰", "F5F5F5", "深海蓝", "1A237E", "暗夜紫", "2D1B4E",
    "薄荷绿", "E0F2F1", "柠檬黄", "FFFDE7", "日落橙", "FFCCBC", "樱花红", "FFCDD2",
    "薰衣草", "E1BEE7", "极客黑", "121212", "深空灰", "37474F", "茶色", "D7CCC8",
    "青柠", "F0F4C3", "琥珀", "FFECB3", "紫罗兰", "F3E5F5", "冰川蓝", "B3E5FC"
)
global RuntimeColors := DefaultPresets.Clone()

; =========================
; 全局变量声明 (颜色工具 & 帮助)
; =========================
global CT_Gui := 0       ; 颜色主窗口
global CT_CustomGui := 0 ; 自定义颜色窗口
global MainHelpGui := 0  ; YAML主说明书
global ColorHelpGui := 0 ; 颜色工具说明书
global CT_CustomHex := "FF0000"
global CT_ContextMenu := 0

; 颜色工具的默认 18 色 (中文名 + HEX)
global CT_DefaultColors := [
    ["焦橙色", "FF8C00"], ["红色", "FF0000"], ["天蓝", "87CEFA"],
    ["绿松石", "40E0D0"], ["紫红", "C71585"], ["蓝绿色", "008080"],
    ["金黄色", "FFD700"], ["灰黑色", "696969"], ["亮粉色", "FF1493"],
    ["亮蓝", "1E90FF"], ["鲜绿", "32CD32"], ["橙红", "FF4500"],
    ["岩蓝", "6A5ACD"], ["巧克力", "D2691E"], ["深红", "DC143C"],
    ["海绿", "2E8B57"], ["钢蓝", "4682B4"], ["纯黑", "000000"]
]
; 运行时颜色列表 (从INI加载)
global CT_RuntimeList := []

; 确保初始化配置
InitConfig()
LoadCustomColors()
LoadColorToolData()

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
; PART 1: YAML 生成器主界面
; ==============================================================================
ShowMainGui()
{
    global MainGui, IniFile, FieldControls, ListFieldControls

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
    winH_Config := IniRead(IniFile, "Appearance", "WinHeight", 650)

    txtColor := "Black"
    ; 只要没有背景图，就应用背景色逻辑
    if (bgPath == "")
    {
        txtColor := IsDarkColor(bgColor) ? "White" : "Black"
    }

    ; === 创建窗口 ===
    MainGui := Gui("+MinimizeBox -MaximizeBox -Resize", "Typora 小助手(Huyangahuo & Gemini3 pro)")
    MainGui.SetFont("s10 c" txtColor, "Microsoft YaHei UI")

    if (bgPath != "")
    {
        MainGui.BackColor := "White" ; 有图时底色设为白，防止边缘杂色
    }
    else
    {
        MainGui.BackColor := bgColor ; 无图时使用用户设定的背景色
    }

    MainGui.MarginX := 20, MainGui.MarginY := 20

    ; === 背景图 ===
    if (bgPath != "" && FileExist(bgPath))
    {
        try
        {
            MainGui.Add("Picture", "x0 y0 w" winW " h" winH_Config " +0x4000000", bgPath)
        }
    }

    ; === 动态字段构建 ===
    fieldListStr := IniRead(IniFile, "Structure", "Fields", "Title|Date|Tags|Categories|Cover")
    fields := StrSplit(fieldListStr, "|")
    FieldControls := Map()
    ListFieldControls := Map()

    ; --- 布局核心参数 ---
    topMargin := 20
    sideMargin := 20
    labelW := 70
    gapX := 10
    inputX := sideMargin + labelW + gapX
    inputW := winW - inputX - sideMargin

    if (inputW < 150)
    {
        inputW := 150
    }

    currentY := topMargin + 25

    ; GroupBox 容器
    gbStart := MainGui.Add("GroupBox", "x" sideMargin " y" topMargin " w" (winW - sideMargin * 2) " h500", " 文章属性 ")

    gbInnerY := topMargin + 30

    for index, fieldName in fields
    {
        if (fieldName = "")
        {
            continue
        }

        ; 1. 标签
        MainGui.SetFont("s10 w600 c" txtColor)
        MainGui.Add("Text", "x" (sideMargin + 10) " y" gbInnerY " w" labelW " Right +BackgroundTrans", fieldName . ":")

        MainGui.SetFont("s10 w400 cBlack")

        ; 2. 输入控件
        if (fieldName = "Tags" || fieldName = "Categories")
        {
            ; --- 列表模式 ---
            defValRaw := IniRead(IniFile, "DefaultValues", fieldName, "")
            defArr := StrSplit(StrReplace(defValRaw, "`n", ","), ",")

            ; 列表框
            lb := MainGui.Add("ListBox", "x" inputX " y" gbInnerY " w" (inputW - 10) " h80", defArr)
            ListFieldControls[fieldName] := lb

            ; 操作行
            opY := gbInnerY + 85
            smallInputW := inputW - 80

            addInput := MainGui.Add("Edit", "x" inputX " y" opY " w" smallInputW, "")
            btnAddItem := MainGui.Add("Button", "x+5 yp-1 w30 h26", "+")
            btnDelItem := MainGui.Add("Button", "x+5 yp w30 h26", "-")

            btnAddItem.OnEvent("Click", AddToList.Bind(lb, addInput))
            btnDelItem.OnEvent("Click", DelFromList.Bind(lb))

            gbInnerY += 125
        }
        else
        {
            ; --- 单行模式 ---
            defVal := IniRead(IniFile, "DefaultValues", fieldName, "")
            if (fieldName = "Date")
            {
                defVal := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
            }

            ctl := MainGui.Add("Edit", "x" inputX " y" gbInnerY " w" (inputW - 10) " v" fieldName, defVal)
            FieldControls[fieldName] := ctl

            gbInnerY += 40
        }
    }

    ; 调整 GroupBox 高度
    gbHeight := gbInnerY - topMargin + 10
    gbStart.Move(, , , gbHeight)

    ; === 底部按钮区域 ===
    btnStartY := topMargin + gbHeight + 20
    btnW := (winW - 60) / 2

    MainGui.SetFont("s10 c" txtColor)

    ; 第一排按钮
    btnSet := MainGui.Add("Button", "x20 y" btnStartY " w" btnW " h35", "⚙️ 设置")
    btnIns := MainGui.Add("Button", "x+20 yp w" btnW " h35 Default", "插入 YAML")

    ; 第二排按钮
    btnStartY += 45
    btnHelp := MainGui.Add("Button", "x20 y" btnStartY " w" btnW " h35", "📖 使用说明")
    btnColorTool := MainGui.Add("Button", "x+20 yp w" btnW " h35", "🎨 MD字体颜色")

    ; 计算最终窗口高度
    finalWinH := btnStartY + 55

    ; === 事件绑定 ===
    btnSet.OnEvent("Click", (*) => ShowSettingsGui())
    btnIns.OnEvent("Click", (*) => DoInsert(fields))
    btnHelp.OnEvent("Click", (*) => ShowMainHelpGui())
    btnColorTool.OnEvent("Click", (*) => ShowColorTool())

    MainGui.OnEvent("Close", (*) => ExitApp())

    MainGui.Show("w" winW " h" finalWinH)

    if (opacity < 255)
    {
        try WinSetTransparent(opacity, MainGui.Hwnd)
    }
}

; ==============================================================================
; PART 2: 辅助功能 (列表, 颜色判断等)
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
        try
        {
            SettingsGui.Show()
            return
        }
        catch
        {
            SettingsGui := 0
        }
    }

    if IsObject(MainGui)
    {
        MainGui.Hide()
    }

    currBgColor := IniRead(IniFile, "Appearance", "BgColor", "FFFFFF")
    currTxtColor := IsDarkColor(currBgColor) ? "White" : "Black"

    ; 禁止改变大小
    SettingsGui := Gui("+AlwaysOnTop -MaximizeBox -Resize", "全局配置")
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
    btnUp := SettingsGui.Add("Button", "xp y+20 w50 h30", "▲")
    btnDown := SettingsGui.Add("Button", "x+10 yp w50 h30", "▼")

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

    ; 核心修复：每次打开设置时，从INI读取背景路径到全局变量
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
    
    ; === 核心修复：防止输入框为空时报错 ===
    ; 只有当输入框内容不为空时，才同步到 Slider
    SliW.OnEvent("Change", (*) => EdtW.Value := SliW.Value)
    EdtW.OnEvent("Change", (*) => (EdtW.Value != "" ? SliW.Value := EdtW.Value : ""))
    
    SliH.OnEvent("Change", (*) => EdtH.Value := SliH.Value)
    EdtH.OnEvent("Change", (*) => (EdtH.Value != "" ? SliH.Value := EdtH.Value : ""))
    
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
    customSection := IniRead(IniFile, "CustomColors", , "")
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
        return SubStr(name, 1, maxLen - 3) "..."
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
    s := FileSelect(3, , "选择背景图片", "Images (*.jpg; *.png)")
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
    ; 262144 = MB_TOPMOST (强制置顶)
    MsgBox(text, title, options " " ownOpt " 262144")
}

; === 核心修复: 智能判断父窗口的输入框 ===
CustomInputBox(title, prompt, callback, defaultVal := "")
{
    global SettingsGui, CT_CustomGui, MainGui

    ownerOpt := ""

    ; 优先级: 设置窗口 > 颜色自定义窗口 > 主窗口
    if (IsObject(SettingsGui) && SettingsGui != 0)
    {
        ownerOpt := "+Owner" SettingsGui.Hwnd
    }
    else if (IsObject(CT_CustomGui) && CT_CustomGui != 0)
    {
        ownerOpt := "+Owner" CT_CustomGui.Hwnd
    }
    else if (IsObject(MainGui) && MainGui != 0)
    {
        ownerOpt := "+Owner" MainGui.Hwnd
    }

    ; 无论父窗口是谁，都加上置顶属性
    InputGui := Gui(ownerOpt " +AlwaysOnTop -MaximizeBox -Resize", title)
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
        if (MainGui != 0)
            MainGui.Destroy()
        MainGui := 0
    }
    ShowMainGui()
}

; === 核心修复：更健壮的保存逻辑 ===
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

    ; 确保写入背景路径
    IniWrite(FullBgPath, IniFile, "Appearance", "Background")

    IniWrite(SliOp.Value, IniFile, "Appearance", "Opacity")

    ; 确保写入背景色 (如果为空，默认为白色)
    valBgColor := EdtHexInput.Value
    if (valBgColor = "")
        valBgColor := "FFFFFF"
    IniWrite(valBgColor, IniFile, "Appearance", "BgColor")

    IniWrite(SliW.Value, IniFile, "Appearance", "WinWidth")
    IniWrite(SliH.Value, IniFile, "Appearance", "WinHeight")

    SettingsGui.Destroy()
    SettingsGui := 0
    if IsObject(MainGui)
    {
        if (MainGui != 0)
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
        if WinWaitActive("ahk_exe Typora.exe", , 1)
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
; PART 5: 帮助 & 颜色工具 (增强版：修复报错+滚动条)
; ==============================================================================
ShowMainHelpGui()
{
    global MainHelpGui, MainGui
    if IsObject(MainHelpGui)
    {
        try
        {
            MainHelpGui.Show()
            return
        }
        catch
        {
            MainHelpGui := 0
        }
    }

    ; 禁止改变大小
    MainHelpGui := Gui("+AlwaysOnTop +Owner" MainGui.Hwnd " -MaximizeBox -Resize", "YAML 生成器说明")
    MainHelpGui.SetFont("s10", "Microsoft YaHei UI")
    MainHelpGui.BackColor := "White"

    ; +VScroll 允许垂直滚动
    MainHelpGui.AddEdit(
        "xm ym w400 h260 ReadOnly +VScroll +Wrap",
        "【YAML 生成器使用指南】`n`n"
        "1. 在下方输入框填写文章信息。`n"
        "2. Tags 和 Categories 支持添加多个，点击 + 号添加或点击 - 号删除。`n"
        "3. 点击【插入 YAML】自动生成并粘贴到 Typora。`n"
        "4. 点击【设置】可以自定义背景图、主题颜色、窗口大小和字段顺序。`n"
        "5. 快捷键：在typora中 使用 Ctrl+Alt+I 快速呼出或按 F4 快速打开。`n"
        "6. 存储的设置文件可以在这个Documents(文档)\TyporaSuite\TyporaSettings.ini 路径找到"
    )

    MainHelpGui.Show("w420 h280")
}

ShowColorHelpGui()
{
    global ColorHelpGui, CT_Gui
    if IsObject(ColorHelpGui)
    {
        try
        {
            ColorHelpGui.Show()
            return
        }
        catch
        {
            ColorHelpGui := 0
        }
    }

    ; 禁止改变大小
    ColorHelpGui := Gui("+AlwaysOnTop +Owner" CT_Gui.Hwnd " -MaximizeBox -Resize", "颜色工具说明")
    ColorHelpGui.SetFont("s10", "Microsoft YaHei UI")
    ColorHelpGui.BackColor := "White"

    ; +VScroll 允许垂直滚动
    ColorHelpGui.AddEdit(
        "xm ym w400 h260 ReadOnly +VScroll +Wrap",
        "【MD 字体颜色工具使用说明】`n`n"
        "1. 基本使用：`n"
        "   - 在 Typora 中选中文字。`n"
        "   - 点击色块即可应用颜色。`n"
        "   - 若未选中文字，将只会插入带颜色的空标签。`n`n"
        "2. 自定义颜色：`n"
        "   - 点击【自定义添加】可输入任意 HEX 颜色,程序会把 RGB 值自动转换为 Hex 值`n"
        "   - 支持保存到色板，最大支持 18 个颜色。`n`n"
        "3. 更多功能：`n"
        "   - 在任意色块上可以右键点击选择删除该颜色。`n"
        "   - 可以使用快捷键Ctrl + Alt + C快速打开最小化窗口`n`n"
        "4. 故障排除：`n"
        "   - 如果文字意外消失，请按 Ctrl+Z 撤销。`n"
        "   - 若要在已添加颜色字体上换颜色,只有先删除已有颜色代码，才能腾出位置添加新颜色。"
    )

    ColorHelpGui.Show("w420 h280")
}

; === 颜色工具数据处理 (核心新增逻辑) ===
LoadColorToolData()
{
    global CT_RuntimeList, IniFile, CT_DefaultColors
    ; 从 INI 读取
    rawStr := IniRead(IniFile, "ColorTool", "UserColors", "")

    CT_RuntimeList := []

    if (rawStr = "")
    {
        ; 首次运行或被清空，使用默认值
        CT_RuntimeList := CT_DefaultColors.Clone()
        SaveColorToolData() ; 回写默认值
    }
    else
    {
        ; 解析字符串 "Name:Hex|Name:Hex"
        Loop Parse, rawStr, "|"
        {
            if (A_LoopField == "")
                continue
            parts := StrSplit(A_LoopField, ":")
            if (parts.Length = 2)
                CT_RuntimeList.Push([parts[1], parts[2]])
        }

        ; 双重保险：如果读取为空数组（比如格式坏了），恢复默认
        if (CT_RuntimeList.Length == 0)
        {
            CT_RuntimeList := CT_DefaultColors.Clone()
            SaveColorToolData()
        }
    }
}

SaveColorToolData()
{
    global CT_RuntimeList, IniFile
    saveStr := ""
    for item in CT_RuntimeList
    {
        saveStr .= item[1] . ":" . item[2] . "|"
    }
    IniWrite(RTrim(saveStr, "|"), IniFile, "ColorTool", "UserColors")
}

RestoreDefaultColors(*)
{
    global CT_RuntimeList, CT_DefaultColors, CT_Gui

    ; 这里的 MsgBox 强制置顶
    result := MsgBox("确定要恢复默认的 18 种颜色吗？`n自定义的颜色将会丢失。", "恢复默认", "YesNo Icon? 262144")
    if (result == "Yes")
    {
        CT_RuntimeList := CT_DefaultColors.Clone()
        SaveColorToolData()

        if IsObject(CT_Gui)
        {
            CT_Gui.Destroy()
            CT_Gui := 0
        }
        ShowColorTool()
    }
}

; === 颜色工具主窗口 ===
ShowColorTool()
{
    global CT_Gui, MainGui, CT_RuntimeList

    if IsObject(CT_Gui)
    {
        try
        {
            CT_Gui.Show()
            return
        }
        catch
        {
            CT_Gui := 0
        }
    }

    ; 禁止改变大小
    CT_Gui := Gui("+AlwaysOnTop -MaximizeBox -Resize", "MD字体颜色工具")
    CT_Gui.SetFont("s9", "Microsoft YaHei UI")
    CT_Gui.BackColor := "White"

    ; 顶部功能区
    infoBtn := CT_Gui.AddButton("xm w80", "使用说明")
    customBtn := CT_Gui.AddButton("x+10 yp w90", "自定义添加")
    resetBtn := CT_Gui.AddButton("x+10 yp w80", "恢复默认")

    infoBtn.OnEvent("Click", (*) => ShowColorHelpGui())
    customBtn.OnEvent("Click", (*) => ShowCustomColorGui())
    resetBtn.OnEvent("Click", RestoreDefaultColors)

    colW := 120
    rowH := 28
    gapY := 6
    startY := 45

    ; 动态渲染色块
    Loop CT_RuntimeList.Length
    {
        if (A_Index > 18) ; 最多显示18个
            break

        cName := CT_RuntimeList[A_Index][1]
        cHex := CT_RuntimeList[A_Index][2]

        ; 0为左列, 1为右列
        col := (A_Index <= 9) ? 0 : 1
        row := Mod(A_Index - 1, 9)

        ; 左边是 xm，右边是 xm+140
        xPosStr := (col == 0) ? "xm" : "xm+140"
        yPos := startY + row * (rowH + gapY)

        ; 绘制色块
        t := CT_Gui.AddText(
            xPosStr " y" yPos " w" colW " h" rowH
            " 0x200 Center Border Background" cHex,
            cName
        )

        ; 文字颜色适配
        if IsDarkColor(cHex)
            t.SetFont("cWhite")
        else
            t.SetFont("cBlack")

        t.Tag := cHex
        t.OnEvent("Click", ApplyColorFromText)

        ; === 核心修复：直接绑定事件处理，不在这里 Bind 数据 ===
        ; 将具体的 HEX 和 Name 存入控件属性，点击时再提取
        t.ColorName := cName
        t.ColorHex := cHex
        t.OnEvent("ContextMenu", ShowColorContextMenu)
    }

    CT_Gui.Show("w290 h370")
}

; 核心修复：动态右键菜单
ShowColorContextMenu(ctrl, *)
{
    ; 动态创建一个菜单
    tempMenu := Menu()
    ; 绑定删除函数，传入该控件的 Hex 和 Name
    tempMenu.Add("删除 [" ctrl.ColorName "]", (*) => DeleteColorByHex(ctrl.ColorHex, ctrl.ColorName))
    tempMenu.Show()
}

DeleteColorByHex(targetHex, targetName)
{
    global CT_RuntimeList, CT_Gui

    foundIndex := 0
    for idx, item in CT_RuntimeList
    {
        if (item[2] == targetHex)
        {
            foundIndex := idx
            break
        }
    }

    if (foundIndex > 0)
    {
        CT_RuntimeList.RemoveAt(foundIndex)
        SaveColorToolData()
        SafeMsgBox("已删除颜色: " targetName)

        ; 刷新界面
        CT_Gui.Destroy()
        CT_Gui := 0
        ShowColorTool()
    }
    else
    {
        SafeMsgBox("删除失败：颜色未找到 (可能已更改)")
    }
}

ApplyColorFromText(ctrl, *)
{
    if WinExist("ahk_exe Typora.exe")
    {
        WinActivate "ahk_exe Typora.exe"
        WinWaitActive "ahk_exe Typora.exe", , 1
        AddFontColor("#" ctrl.Tag)
    }
}

; === 自定义颜色窗口 ===
ShowCustomColorGui()
{
    global CT_CustomGui, CT_CustomHex, CT_Gui

    if IsObject(CT_CustomGui)
    {
        try
        {
            CT_CustomGui.Show()
            return
        }
        catch
        {
            CT_CustomGui := 0
        }
    }

    CT_CustomGui := Gui("+AlwaysOnTop -MaximizeBox -Resize +Owner" CT_Gui.Hwnd, "自定义颜色")
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

    R.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    G.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    B.OnEvent("Change", (*) => UpdateFromRGB(R, G, B, HexEdit, Preview))
    HexEdit.OnEvent("Change", (*) => UpdateFromHex(HexEdit, Preview))

    refresh := CT_CustomGui.AddButton("xm y+10 w260", "刷新预览")
    refresh.OnEvent("Click", (*) => RefreshCustomPreview(R, G, B, HexEdit, Preview))

    ; 新增：添加到列表
    addBtn := CT_CustomGui.AddButton("xm y+6 w260", "添加到列表 (并保存)")
    addBtn.OnEvent("Click", (*) => AddColorToTool(HexEdit.Value))

    apply := CT_CustomGui.AddButton("xm y+6 w260", "仅使用该颜色")
    apply.OnEvent("Click", (*) => ApplyCustomColor(HexEdit.Value))

    ; 这里的 Back 按钮逻辑修改为销毁窗口，避免僵尸对象
    back := CT_CustomGui.AddButton("xm y+6 w260", "返回")
    back.OnEvent("Click", (*) => (CT_CustomGui.Destroy(), CT_CustomGui := 0))

    CT_CustomGui.Show("w300 h400")
}

; 核心新增：添加到色板逻辑
AddColorToTool(hex)
{
    global CT_RuntimeList, CT_Gui, CT_CustomGui

    if !RegExMatch(hex, "^[0-9A-Fa-f]{6}$")
    {
        SafeMsgBox("HEX 代码无效，无法添加。")
        return
    }

    if (CT_RuntimeList.Length >= 18)
    {
        SafeMsgBox("颜色数量已达上限 (18个)。`n请先右键删除一些现有颜色。")
        return
    }

    ; 查重
    for item in CT_RuntimeList
    {
        if (item[2] = hex)
        {
            SafeMsgBox("该颜色已存在！")
            return
        }
    }

    ; 弹出名称输入框 (置顶)
    CustomInputBox("颜色名称", "请为颜色命名 (建议4字以内):", DoAddColorConfirm, hex)
}

DoAddColorConfirm(name)
{
    global CT_RuntimeList, CT_CustomHex, CT_Gui

    if (name == "")
        name := "自定义"

    CT_RuntimeList.Push([name, CT_CustomHex])
    SaveColorToolData()

    SafeMsgBox("颜色 [" name "] 已添加！")

    ; 刷新主界面
    if IsObject(CT_Gui)
    {
        CT_Gui.Destroy()
        CT_Gui := 0
    }
    ShowColorTool()
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

RefreshCustomPreview(R, G, B, HexEdit, Preview)
{
    global CT_CustomHex, CT_CustomGui
    if RegExMatch(HexEdit.Value, "^[0-9A-Fa-f]{6}$")
    {
        CT_CustomHex := HexEdit.Value
    }
    else
    {
        CT_CustomHex := Format("{:02X}{:02X}{:02X}", Clamp(R.Value), Clamp(G.Value), Clamp(B.Value))
    }

    CT_CustomGui.Hide()
    try
    {
        Preview.Opt("+Background" CT_CustomHex)
    }
    CT_CustomGui.Show()
}

ApplyCustomColor(hex)
{
    if WinExist("ahk_exe Typora.exe")
    {
        WinActivate "ahk_exe Typora.exe"
        WinWaitActive "ahk_exe Typora.exe", , 1
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