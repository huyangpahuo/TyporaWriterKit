(function () {
  "use strict";

  var config = null;
  var currentEditingField = null;
  var typoraOnline = false;

  var defaultColors = [
    { name: "焦橙色", hex: "FF8C00" },
    { name: "红色", hex: "FF0000" },
    { name: "天蓝", hex: "87CEFA" },
    { name: "绿松石", hex: "40E0D0" },
    { name: "紫红", hex: "C71585" },
    { name: "蓝绿色", hex: "008080" },
    { name: "金黄色", hex: "FFD700" },
    { name: "灰黑色", hex: "696969" },
    { name: "亮粉色", hex: "FF1493" },
    { name: "亮蓝", hex: "1E90FF" },
    { name: "鲜绿", hex: "32CD32" },
    { name: "橙红", hex: "FF4500" },
    { name: "岩蓝", hex: "6A5ACD" },
    { name: "巧克力", hex: "D2691E" },
    { name: "深红", hex: "DC143C" },
    { name: "海绿", hex: "2E8B57" },
    { name: "钢蓝", hex: "4682B4" },
    { name: "纯黑", hex: "000000" },
  ];

  var themeColors = [
    { name: "经典蓝", hex: "007bff" },
    { name: "翠绿", hex: "28a745" },
    { name: "活力橙", hex: "fd7e14" },
    { name: "玫瑰红", hex: "e83e8c" },
    { name: "深紫", hex: "6f42c1" },
    { name: "青色", hex: "17a2b8" },
    { name: "珊瑚", hex: "ff6b6b" },
    { name: "薄荷绿", hex: "20c997" },
    { name: "琥珀", hex: "ffc107" },
    { name: "石板蓝", hex: "6c757d" },
    { name: "深海蓝", hex: "1A237E" },
    { name: "暗夜紫", hex: "4a148c" },
    { name: "森林绿", hex: "2E7D32" },
    { name: "酒红", hex: "880E4F" },
    { name: "巧克力", hex: "5D4037" },
    { name: "钢铁灰", hex: "455a64" },
    { name: "天际蓝", hex: "0288D1" },
    { name: "落日橙", hex: "EF6C00" },
    { name: "樱花粉", hex: "EC407A" },
    { name: "极客黑", hex: "263238" },
  ];

  var protectedFields = ["Title", "Date", "Tags", "Categories", "Cover"];

  document.addEventListener("DOMContentLoaded", init);

  function init() {
    loadConfig();
    setupTabs();
    renderYAMLForm();
    renderColorGrid();
    renderFieldList();
    renderThemeColorGrid();
    setupEventListeners();
    applyTheme();
    checkTyporaStatus();
    setInterval(checkTyporaStatus, 5000);
  }

  function checkTyporaStatus() {
    var dot = document.getElementById("status-dot");
    var text = document.getElementById("status-text");
    if (!dot || !text) return;

    if (window.services && window.services.isTyporaRunning) {
      window.services
        .isTyporaRunning()
        .then(function (running) {
          typoraOnline = running;
          if (running) {
            dot.classList.add("online");
            text.textContent = "Typora 运行中";
          } else {
            dot.classList.remove("online");
            text.textContent = "Typora 未运行";
          }
        })
        .catch(function () {
          dot.classList.remove("online");
          text.textContent = "检测失败";
        });
    } else {
      text.textContent = "测试模式";
    }
  }

  function loadConfig() {
    var loaded = null;
    if (window.services && window.services.loadConfig) {
      loaded = window.services.loadConfig();
    }
    if (!loaded) {
      var saved = localStorage.getItem("typora-suite-config");
      if (saved) {
        try {
          loaded = JSON.parse(saved);
        } catch (e) {}
      }
    }
    config = loaded || getDefaultConfig();
    if (!config.defaultValues) config.defaultValues = {};
    if (!config.appearance) config.appearance = { themeColor: "007bff" };
    if (!config.colors)
      config.colors = JSON.parse(JSON.stringify(defaultColors));
    if (!config.fields)
      config.fields = ["Title", "Date", "Tags", "Categories", "Cover"];
  }

  function saveConfig() {
    if (window.services && window.services.saveConfig) {
      window.services.saveConfig(config);
    }
    localStorage.setItem("typora-suite-config", JSON.stringify(config));
  }

  function getDefaultConfig() {
    return {
      fields: ["Title", "Date", "Tags", "Categories", "Cover"],
      defaultValues: { Title: "", Tags: [], Categories: [], Cover: "" },
      colors: JSON.parse(JSON.stringify(defaultColors)),
      appearance: { themeColor: "007bff" },
    };
  }

  function setupTabs() {
    var tabs = document.querySelectorAll(".tab-btn");
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].addEventListener("click", function () {
        var allTabs = document.querySelectorAll(".tab-btn");
        var allPanels = document.querySelectorAll(".panel");
        for (var j = 0; j < allTabs.length; j++)
          allTabs[j].classList.remove("active");
        for (var k = 0; k < allPanels.length; k++)
          allPanels[k].classList.remove("active");
        this.classList.add("active");
        document
          .getElementById(this.dataset.tab + "-panel")
          .classList.add("active");
      });
    }
  }

  function renderYAMLForm() {
    var container = document.getElementById("yaml-form");
    if (!container) return;
    container.innerHTML = "";

    for (var i = 0; i < config.fields.length; i++) {
      var fieldName = config.fields[i];
      var group = document.createElement("div");
      group.className = "form-group";

      var label = document.createElement("label");
      label.textContent = fieldName + ":";
      group.appendChild(label);

      if (fieldName === "Tags" || fieldName === "Categories") {
        group.appendChild(createListField(fieldName));
      } else {
        var input = document.createElement("input");
        input.type = "text";
        input.id = "field-" + fieldName;
        if (fieldName === "Date") {
          input.value = getCurrentDateTime();
        } else {
          input.value = config.defaultValues[fieldName] || "";
        }
        group.appendChild(input);
      }
      container.appendChild(group);
    }
  }

  function createListField(fieldName) {
    var wrapper = document.createElement("div");
    wrapper.className = "list-field";

    var itemsEl = document.createElement("div");
    itemsEl.className = "list-items";
    itemsEl.id = "list-" + fieldName;

    var items = config.defaultValues[fieldName] || [];
    if (typeof items === "string") {
      var temp = [];
      var parts = items.split(",");
      for (var x = 0; x < parts.length; x++) {
        var s = parts[x].trim();
        if (s) temp.push(s);
      }
      items = temp;
    }

    for (var j = 0; j < items.length; j++) {
      addListItem(itemsEl, items[j]);
    }

    var inputRow = document.createElement("div");
    inputRow.className = "list-input-row";

    var input = document.createElement("input");
    input.type = "text";
    input.placeholder = "输入后添加";

    var btn = document.createElement("button");
    btn.className = "btn btn-primary btn-small";
    btn.textContent = "+";

    btn.addEventListener("click", function () {
      var v = input.value.trim();
      if (v) {
        addListItem(itemsEl, v);
        input.value = "";
      }
    });

    input.addEventListener("keypress", function (e) {
      if (e.key === "Enter") {
        var v = input.value.trim();
        if (v) {
          addListItem(itemsEl, v);
          input.value = "";
        }
      }
    });

    inputRow.appendChild(input);
    inputRow.appendChild(btn);
    wrapper.appendChild(itemsEl);
    wrapper.appendChild(inputRow);
    return wrapper;
  }

  function addListItem(container, text) {
    var item = document.createElement("span");
    item.className = "list-item";
    item.innerHTML = escapeHtml(text) + '<span class="remove-btn">×</span>';
    item.querySelector(".remove-btn").addEventListener("click", function () {
      item.remove();
    });
    container.appendChild(item);
  }

  function generateYAML() {
    var yaml = "---\n";
    for (var i = 0; i < config.fields.length; i++) {
      var field = config.fields[i];
      var key = field.toLowerCase();

      if (field === "Tags" || field === "Categories") {
        var container = document.getElementById("list-" + field);
        var items = container ? container.querySelectorAll(".list-item") : [];
        if (items.length > 0) {
          yaml += key + ":\n";
          for (var j = 0; j < items.length; j++) {
            var txt = items[j].textContent.replace("×", "").trim();
            yaml += "  - " + txt + "\n";
          }
        } else {
          yaml += key + ": []\n";
        }
      } else {
        var input = document.getElementById("field-" + field);
        var val = input ? input.value : "";
        yaml += key + ": " + val + "\n";
      }
    }
    yaml += "---\n";
    return yaml;
  }

  function copyYAML() {
    var yaml = generateYAML();
    copyToClipboard(yaml);
    showToast("📋 已复制到剪贴板", "success");
  }

  function renderColorGrid() {
    var grid = document.getElementById("color-grid");
    if (!grid) return;
    grid.innerHTML = "";

    for (var i = 0; i < config.colors.length; i++) {
      var color = config.colors[i];
      var block = document.createElement("div");
      block.className = "color-block";

      if (isDarkColor(color.hex)) {
        block.classList.add("light-text");
      } else {
        block.classList.add("dark-text");
      }

      block.style.backgroundColor = "#" + color.hex;
      block.textContent = color.name;
      block.setAttribute("data-hex", color.hex);
      block.setAttribute("data-index", i);

      block.addEventListener("click", function () {
        var hex = this.getAttribute("data-hex");
        var name = this.textContent;
        copyColorCode(hex, name);
      });

      block.addEventListener("contextmenu", function (e) {
        e.preventDefault();
        var hex = this.getAttribute("data-hex");
        var idx = parseInt(this.getAttribute("data-index"));
        var name = this.textContent;
        showColorMenu(e.pageX, e.pageY, { hex: hex, name: name }, idx);
      });

      grid.appendChild(block);
    }
  }

  function copyColorCode(hex, name) {
    var code = "<font color='#" + hex + "'></font>";
    copyToClipboard(code);
    showToast("📋 " + name + " 已复制", "success");
  }

  function showColorMenu(x, y, color, index) {
    removeContextMenu();

    var menu = document.createElement("div");
    menu.className = "context-menu";
    menu.style.left = Math.min(x, window.innerWidth - 140) + "px";
    menu.style.top = Math.min(y, window.innerHeight - 90) + "px";

    var copyItem = document.createElement("div");
    copyItem.className = "context-menu-item";
    copyItem.textContent = "📋 复制 #" + color.hex;
    copyItem.addEventListener("click", function () {
      copyToClipboard("#" + color.hex);
      showToast("已复制");
      menu.remove();
    });

    var divider = document.createElement("div");
    divider.className = "context-menu-divider";

    var deleteItem = document.createElement("div");
    deleteItem.className = "context-menu-item danger";
    deleteItem.textContent = "🗑️ 删除";
    deleteItem.addEventListener("click", function () {
      config.colors.splice(index, 1);
      saveConfig();
      renderColorGrid();
      showToast("已删除");
      menu.remove();
    });

    menu.appendChild(copyItem);
    menu.appendChild(divider);
    menu.appendChild(deleteItem);
    document.body.appendChild(menu);

    setTimeout(function () {
      document.addEventListener("click", function handler() {
        if (menu.parentNode) menu.remove();
        document.removeEventListener("click", handler);
      });
    }, 10);
  }

  function updateColorPreview() {
    var hexInput = document.getElementById("custom-hex");
    var preview = document.getElementById("color-preview");
    if (!hexInput || !preview) return;
    var hex = hexInput.value.replace("#", "");
    if (/^[0-9A-Fa-f]{6}$/.test(hex)) {
      preview.style.backgroundColor = "#" + hex;
    }
  }

  function updateHexFromRGB() {
    var rEl = document.getElementById("custom-r");
    var gEl = document.getElementById("custom-g");
    var bEl = document.getElementById("custom-b");
    var hexEl = document.getElementById("custom-hex");
    if (!rEl || !gEl || !bEl || !hexEl) return;

    var r = Math.min(255, Math.max(0, parseInt(rEl.value) || 0));
    var g = Math.min(255, Math.max(0, parseInt(gEl.value) || 0));
    var b = Math.min(255, Math.max(0, parseInt(bEl.value) || 0));

    var rH = r.toString(16);
    if (rH.length === 1) rH = "0" + rH;
    var gH = g.toString(16);
    if (gH.length === 1) gH = "0" + gH;
    var bH = b.toString(16);
    if (bH.length === 1) bH = "0" + bH;

    hexEl.value = (rH + gH + bH).toUpperCase();
    updateColorPreview();
  }

  function addCustomColor() {
    var hexEl = document.getElementById("custom-hex");
    var nameEl = document.getElementById("custom-name");
    if (!hexEl || !nameEl) return;

    var hex = hexEl.value.replace("#", "").toUpperCase();
    var name = nameEl.value.trim() || "自定义";

    if (!/^[0-9A-Fa-f]{6}$/.test(hex)) {
      showToast("HEX 无效", "error");
      return;
    }
    if (config.colors.length >= 18) {
      showToast("已达上限", "error");
      return;
    }

    for (var i = 0; i < config.colors.length; i++) {
      if (config.colors[i].hex.toUpperCase() === hex) {
        showToast("已存在", "error");
        return;
      }
    }

    config.colors.push({ name: name, hex: hex });
    saveConfig();
    renderColorGrid();
    showToast("已添加 " + name, "success");
  }

  function useCustomColor() {
    var hexEl = document.getElementById("custom-hex");
    if (!hexEl) return;
    var hex = hexEl.value.replace("#", "").toUpperCase();
    if (/^[0-9A-Fa-f]{6}$/.test(hex)) {
      copyColorCode(hex, "自定义");
    } else {
      showToast("HEX 无效", "error");
    }
  }

  function restoreDefaultColors() {
    if (confirm("恢复默认颜色？")) {
      config.colors = JSON.parse(JSON.stringify(defaultColors));
      saveConfig();
      renderColorGrid();
      showToast("已恢复", "success");
    }
  }

  function renderFieldList() {
    var container = document.getElementById("field-list");
    if (!container) return;
    container.innerHTML = "";

    for (var i = 0; i < config.fields.length; i++) {
      var field = config.fields[i];
      var item = document.createElement("div");
      item.className = "field-item";
      item.setAttribute("data-field", field);
      item.setAttribute("data-index", i);

      var nameWrapper = document.createElement("div");
      var nameSpan = document.createElement("span");
      nameSpan.className = "field-name";
      nameSpan.textContent = field;
      nameWrapper.appendChild(nameSpan);

      var defaultVal = config.defaultValues[field];
      if (
        defaultVal &&
        (Array.isArray(defaultVal) ? defaultVal.length : defaultVal)
      ) {
        var defaultSpan = document.createElement("span");
        defaultSpan.className = "field-default";
        var preview = "";
        if (Array.isArray(defaultVal)) {
          preview = defaultVal.slice(0, 2).join(", ");
          if (defaultVal.length > 2) preview += "...";
        } else {
          preview = String(defaultVal).substring(0, 10);
          if (String(defaultVal).length > 10) preview += "...";
        }
        defaultSpan.textContent = "(" + preview + ")";
        nameWrapper.appendChild(defaultSpan);
      }

      var actions = document.createElement("div");
      actions.className = "field-actions";

      if (i > 0) {
        var upBtn = document.createElement("button");
        upBtn.textContent = "▲";
        upBtn.setAttribute("data-index", i);
        upBtn.addEventListener("click", function (e) {
          e.stopPropagation();
          moveField(parseInt(this.getAttribute("data-index")), -1);
        });
        actions.appendChild(upBtn);
      }

      if (i < config.fields.length - 1) {
        var downBtn = document.createElement("button");
        downBtn.textContent = "▼";
        downBtn.setAttribute("data-index", i);
        downBtn.addEventListener("click", function (e) {
          e.stopPropagation();
          moveField(parseInt(this.getAttribute("data-index")), 1);
        });
        actions.appendChild(downBtn);
      }

      if (protectedFields.indexOf(field) === -1) {
        var delBtn = document.createElement("button");
        delBtn.textContent = "🗑️";
        delBtn.style.color = "var(--danger-color)";
        delBtn.setAttribute("data-field", field);
        delBtn.setAttribute("data-index", i);
        delBtn.addEventListener("click", function (e) {
          e.stopPropagation();
          var f = this.getAttribute("data-field");
          var idx = parseInt(this.getAttribute("data-index"));
          if (confirm('删除 "' + f + '"？')) {
            config.fields.splice(idx, 1);
            delete config.defaultValues[f];
            saveConfig();
            renderFieldList();
            renderYAMLForm();
          }
        });
        actions.appendChild(delBtn);
      }

      item.appendChild(nameWrapper);
      item.appendChild(actions);

      item.addEventListener("contextmenu", function (e) {
        e.preventDefault();
        var f = this.getAttribute("data-field");
        var idx = parseInt(this.getAttribute("data-index"));
        showFieldMenu(e.pageX, e.pageY, f, idx);
      });

      container.appendChild(item);
    }
  }

  function showFieldMenu(x, y, field, index) {
    removeContextMenu();

    var menu = document.createElement("div");
    menu.className = "context-menu";
    menu.style.left = Math.min(x, window.innerWidth - 140) + "px";
    menu.style.top = Math.min(y, window.innerHeight - 100) + "px";

    var editItem = document.createElement("div");
    editItem.className = "context-menu-item";
    editItem.textContent = "✏️ 编辑默认值";
    editItem.addEventListener("click", function () {
      menu.remove();
      showDefaultValueModal(field);
    });
    menu.appendChild(editItem);

    if (protectedFields.indexOf(field) === -1) {
      var divider = document.createElement("div");
      divider.className = "context-menu-divider";
      menu.appendChild(divider);

      var deleteItem = document.createElement("div");
      deleteItem.className = "context-menu-item danger";
      deleteItem.textContent = "🗑️ 删除";
      deleteItem.addEventListener("click", function () {
        menu.remove();
        if (confirm('删除 "' + field + '"？')) {
          config.fields.splice(index, 1);
          delete config.defaultValues[field];
          saveConfig();
          renderFieldList();
          renderYAMLForm();
        }
      });
      menu.appendChild(deleteItem);
    }

    document.body.appendChild(menu);

    setTimeout(function () {
      document.addEventListener("click", function handler() {
        if (menu.parentNode) menu.remove();
        document.removeEventListener("click", handler);
      });
    }, 10);
  }

  function showDefaultValueModal(field) {
    currentEditingField = field;
    var overlay = document.getElementById("modal-overlay");
    var fieldNameEl = document.getElementById("modal-field-name");
    var inputEl = document.getElementById("modal-default-input");

    if (!overlay || !fieldNameEl || !inputEl) return;

    fieldNameEl.innerHTML = "属性: <strong>" + field + "</strong>";

    var val = config.defaultValues[field];
    if (val === undefined || val === null) val = "";
    if (Array.isArray(val)) {
      inputEl.value = val.join(", ");
    } else {
      inputEl.value = String(val);
    }

    overlay.classList.remove("hidden");
    overlay.style.display = "flex";
    setTimeout(function () {
      inputEl.focus();
    }, 100);
  }

  function saveDefaultValue() {
    if (!currentEditingField) return;
    var inputEl = document.getElementById("modal-default-input");
    if (!inputEl) return;

    var value = inputEl.value.trim();

    if (
      currentEditingField === "Tags" ||
      currentEditingField === "Categories"
    ) {
      if (value === "") {
        value = [];
      } else {
        var arr = value.split(",");
        var result = [];
        for (var i = 0; i < arr.length; i++) {
          var s = arr[i].trim();
          if (s) result.push(s);
        }
        value = result;
      }
    }

    config.defaultValues[currentEditingField] = value;
    saveConfig();
    closeModal();
    renderFieldList();
    renderYAMLForm();
    showToast("已保存", "success");
    currentEditingField = null;
  }

  function closeModal() {
    var overlay = document.getElementById("modal-overlay");
    if (overlay) {
      overlay.classList.add("hidden");
      overlay.style.display = "none";
    }
    currentEditingField = null;
  }

  function closeHelpModal() {
    var overlay = document.getElementById("help-modal-overlay");
    if (overlay) {
      overlay.classList.add("hidden");
      overlay.style.display = "none";
    }
  }

  function moveField(index, direction) {
    var newIndex = index + direction;
    if (newIndex >= 0 && newIndex < config.fields.length) {
      var temp = config.fields[index];
      config.fields[index] = config.fields[newIndex];
      config.fields[newIndex] = temp;
      saveConfig();
      renderFieldList();
    }
  }

  function addField() {
    var input = document.getElementById("new-field-name");
    if (!input) return;
    var name = input.value.trim();
    if (!name) {
      showToast("请输入名称", "error");
      return;
    }
    if (config.fields.length >= 10) {
      showToast("已达上限", "error");
      return;
    }
    if (config.fields.indexOf(name) !== -1) {
      showToast("已存在", "error");
      return;
    }
    config.fields.push(name);
    config.defaultValues[name] = "";
    input.value = "";
    saveConfig();
    renderFieldList();
    renderYAMLForm();
    showToast("已添加", "success");
  }

  function renderThemeColorGrid() {
    var grid = document.getElementById("theme-color-grid");
    if (!grid) return;
    grid.innerHTML = "";

    for (var i = 0; i < themeColors.length; i++) {
      var color = themeColors[i];
      var item = document.createElement("div");
      item.className = "theme-color-item";

      if (isDarkColor(color.hex)) {
        item.classList.add("light-check");
      } else {
        item.classList.add("dark-check");
      }

      item.style.backgroundColor = "#" + color.hex;
      item.title = color.name;
      item.setAttribute("data-hex", color.hex);

      if (config.appearance.themeColor === color.hex) {
        item.classList.add("active");
      }

      item.addEventListener("click", function () {
        var all = document.querySelectorAll(".theme-color-item");
        for (var j = 0; j < all.length; j++) all[j].classList.remove("active");
        this.classList.add("active");
        config.appearance.themeColor = this.getAttribute("data-hex");
      });

      grid.appendChild(item);
    }
  }

  function saveSettings() {
    saveConfig();
    applyTheme();
    showToast("已保存", "success");
  }

  function resetSettings() {
    if (confirm("重置所有设置？")) {
      config = getDefaultConfig();
      saveConfig();
      renderYAMLForm();
      renderColorGrid();
      renderFieldList();
      renderThemeColorGrid();
      applyTheme();
      showToast("已重置", "success");
    }
  }

  function showYAMLHelp() {
    var content = '<div class="help-content">';
    content += "<h4>📝 基本使用</h4>";
    content += "<ul>";
    content += "<li>填写文章属性（标题、标签等）</li>";
    content += "<li>Tags 和 Categories 点击 <code>+</code> 添加多个</li>";
    content += "<li>点击【复制到剪贴板】</li>";
    content += "<li>在 Typora 中 <code>Ctrl+V</code> 粘贴</li>";
    content += "</ul>";
    content += "<h4>⚙️ 自定义属性</h4>";
    content += "<ul>";
    content += "<li>在【设置】中添加/删除/排序属性</li>";
    content += "<li><strong>右键属性</strong> 可编辑默认值</li>";
    content += "<li>Date 字段自动填充当前时间</li>";
    content += "<li>最多支持 10 个属性</li>";
    content += "</ul>";
    content += '<div class="tip">💡 设置默认值后，每次打开自动填充</div>';
    content += "<h4>📋 生成示例</h4>";
    content +=
      "<pre>---\ntitle: 文章标题\ndate: 2024-03-09 12:00:00\ntags:\n  - 标签1\n  - 标签2\ncategories:\n  - 分类1\ncover: /img/cover.jpg\n---</pre>";
    content += "<h4>🔒 受保护属性</h4>";
    content +=
      "<p>Title、Date、Tags、Categories、Cover 为核心属性，不可删除。</p>";
    content += "</div>";
    showHelpModal("YAML 生成器说明", content);
  }

  function showColorHelp() {
    var content = '<div class="help-content">';
    content += "<h4>🎨 基本使用</h4>";
    content += "<ul>";
    content += "<li>点击色块，复制颜色代码到剪贴板</li>";
    content += "<li>在 Typora 中将文字放入标签内</li>";
    content +=
      "<li>示例：<code>&lt;font color='#FF0000'&gt;红色文字&lt;/font&gt;</code></li>";
    content += "</ul>";
    content += "<h4>📝 使用步骤</h4>";
    content += "<ol>";
    content += "<li>点击想要的颜色</li>";
    content += "<li>在 Typora 中 <code>Ctrl+V</code> 粘贴</li>";
    content += "<li>在标签中间输入文字</li>";
    content += "</ol>";
    content += "<h4>🎯 自定义颜色</h4>";
    content += "<ul>";
    content += "<li>输入 HEX 值（如 FF5500）</li>";
    content += "<li>或输入 RGB 值（0-255）自动转换</li>";
    content += "<li>填写颜色名称（可选）</li>";
    content += "<li>点击【添加】保存到色板</li>";
    content += "<li>点击【复制】直接使用</li>";
    content += "</ul>";
    content += '<div class="tip">💡 最多保存 18 个颜色</div>';
    content += "<h4>🗑️ 管理颜色</h4>";
    content += "<ul>";
    content += "<li><strong>右键色块</strong> 可删除颜色或复制 HEX</li>";
    content += "<li>点击【恢复默认】重置为默认 18 色</li>";
    content += "</ul>";
    content += "<h4>💡 小技巧</h4>";
    content += "<ul>";
    content += "<li>深色背景用浅色文字</li>";
    content += "<li>浅色背景用深色文字</li>";
    content += "<li>常用颜色建议添加到色板</li>";
    content += "</ul>";
    content += "</div>";
    showHelpModal("字体颜色说明", content);
  }

  function showHelpModal(title, content) {
    var overlay = document.getElementById("help-modal-overlay");
    var titleEl = document.getElementById("help-modal-title");
    var contentEl = document.getElementById("help-content");
    if (!overlay || !titleEl || !contentEl) return;
    titleEl.textContent = title;
    contentEl.innerHTML = content;
    overlay.classList.remove("hidden");
    overlay.style.display = "flex";
  }

  function setupEventListeners() {
    var btnCopy = document.getElementById("btn-copy");
    if (btnCopy) btnCopy.addEventListener("click", copyYAML);

    var btnPreview = document.getElementById("btn-preview");
    if (btnPreview) {
      btnPreview.addEventListener("click", function () {
        var box = document.getElementById("yaml-preview");
        var output = document.getElementById("yaml-output");
        if (box && output) {
          output.textContent = generateYAML();
          box.classList.toggle("hidden");
        }
      });
    }

    var btnYamlHelp = document.getElementById("btn-yaml-help");
    if (btnYamlHelp) btnYamlHelp.addEventListener("click", showYAMLHelp);

    var btnRefreshPreview = document.getElementById("btn-refresh-preview");
    if (btnRefreshPreview)
      btnRefreshPreview.addEventListener("click", updateColorPreview);

    var btnAddColor = document.getElementById("btn-add-color");
    if (btnAddColor) btnAddColor.addEventListener("click", addCustomColor);

    var btnUseColor = document.getElementById("btn-use-color");
    if (btnUseColor) btnUseColor.addEventListener("click", useCustomColor);

    var btnRestoreColors = document.getElementById("btn-restore-colors");
    if (btnRestoreColors)
      btnRestoreColors.addEventListener("click", restoreDefaultColors);

    var btnColorHelp = document.getElementById("btn-color-help");
    if (btnColorHelp) btnColorHelp.addEventListener("click", showColorHelp);

    var rgbIds = ["custom-r", "custom-g", "custom-b"];
    for (var i = 0; i < rgbIds.length; i++) {
      var el = document.getElementById(rgbIds[i]);
      if (el) el.addEventListener("input", updateHexFromRGB);
    }

    var customHex = document.getElementById("custom-hex");
    if (customHex) customHex.addEventListener("input", updateColorPreview);

    var btnAddField = document.getElementById("btn-add-field");
    if (btnAddField) btnAddField.addEventListener("click", addField);

    var newFieldName = document.getElementById("new-field-name");
    if (newFieldName) {
      newFieldName.addEventListener("keypress", function (e) {
        if (e.key === "Enter") addField();
      });
    }

    var btnSaveSettings = document.getElementById("btn-save-settings");
    if (btnSaveSettings)
      btnSaveSettings.addEventListener("click", saveSettings);

    var btnResetSettings = document.getElementById("btn-reset-settings");
    if (btnResetSettings)
      btnResetSettings.addEventListener("click", resetSettings);

    var refreshStatus = document.getElementById("refresh-status");
    if (refreshStatus)
      refreshStatus.addEventListener("click", checkTyporaStatus);

    var modalClose = document.getElementById("modal-close");
    if (modalClose) modalClose.addEventListener("click", closeModal);

    var modalCancel = document.getElementById("modal-cancel");
    if (modalCancel) modalCancel.addEventListener("click", closeModal);

    var modalSave = document.getElementById("modal-save");
    if (modalSave) modalSave.addEventListener("click", saveDefaultValue);

    var modalOverlay = document.getElementById("modal-overlay");
    if (modalOverlay) {
      modalOverlay.addEventListener("click", function (e) {
        if (e.target === modalOverlay) closeModal();
      });
    }

    var helpModalClose = document.getElementById("help-modal-close");
    if (helpModalClose)
      helpModalClose.addEventListener("click", closeHelpModal);

    var helpModalOk = document.getElementById("help-modal-ok");
    if (helpModalOk) helpModalOk.addEventListener("click", closeHelpModal);

    var helpModalOverlay = document.getElementById("help-modal-overlay");
    if (helpModalOverlay) {
      helpModalOverlay.addEventListener("click", function (e) {
        if (e.target === helpModalOverlay) closeHelpModal();
      });
    }

    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape") {
        closeModal();
        closeHelpModal();
        removeContextMenu();
      }
    });
  }

  function isDarkColor(hex) {
    hex = hex.replace("#", "");
    var r = parseInt(hex.substr(0, 2), 16);
    var g = parseInt(hex.substr(2, 2), 16);
    var b = parseInt(hex.substr(4, 2), 16);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b < 128;
  }

  function getCurrentDateTime() {
    if (window.services && window.services.getCurrentDateTime) {
      return window.services.getCurrentDateTime();
    }
    var now = new Date();
    var y = now.getFullYear();
    var m = String(now.getMonth() + 1).padStart(2, "0");
    var d = String(now.getDate()).padStart(2, "0");
    var h = String(now.getHours()).padStart(2, "0");
    var min = String(now.getMinutes()).padStart(2, "0");
    var s = String(now.getSeconds()).padStart(2, "0");
    return y + "-" + m + "-" + d + " " + h + ":" + min + ":" + s;
  }

  function copyToClipboard(text) {
    if (window.services && window.services.copyToClipboard) {
      window.services.copyToClipboard(text);
      return;
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text);
      return;
    }
    var textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.left = "-9999px";
    document.body.appendChild(textarea);
    textarea.select();
    document.execCommand("copy");
    document.body.removeChild(textarea);
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  function showToast(message, type) {
    var toast = document.getElementById("toast");
    if (!toast) return;
    toast.textContent = message;
    toast.className = "toast";
    if (type) toast.classList.add(type);
    setTimeout(function () {
      toast.classList.add("hidden");
    }, 2000);
  }

  function removeContextMenu() {
    var existing = document.querySelector(".context-menu");
    if (existing && existing.parentNode) existing.remove();
  }

  function applyTheme() {
    var themeColor = config.appearance.themeColor || "007bff";
    document.documentElement.style.setProperty(
      "--theme-accent",
      "#" + themeColor,
    );

    var r = parseInt(themeColor.substr(0, 2), 16);
    var g = parseInt(themeColor.substr(2, 2), 16);
    var b = parseInt(themeColor.substr(4, 2), 16);

    document.documentElement.style.setProperty(
      "--theme-bg",
      "rgba(" + r + "," + g + "," + b + ",0.03)",
    );
    document.documentElement.style.setProperty(
      "--theme-bg-light",
      "rgba(" + r + "," + g + "," + b + ",0.08)",
    );
    document.documentElement.style.setProperty(
      "--theme-border",
      "rgba(" + r + "," + g + "," + b + ",0.2)",
    );
  }
})();
