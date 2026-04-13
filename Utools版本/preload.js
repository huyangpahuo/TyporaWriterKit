const { clipboard } = require("electron");
const { exec } = require("child_process");
const fs = require("fs");
const path = require("path");

var configDir = path.join(require("os").homedir(), "Documents", "TyporaSuite");
var configFile = path.join(configDir, "utools-config.json");

if (!fs.existsSync(configDir)) {
  fs.mkdirSync(configDir, { recursive: true });
}

function loadConfig() {
  try {
    if (fs.existsSync(configFile)) {
      return JSON.parse(fs.readFileSync(configFile, "utf-8"));
    }
  } catch (e) {}
  return null;
}

function saveConfig(config) {
  try {
    fs.writeFileSync(configFile, JSON.stringify(config, null, 2), "utf-8");
    return true;
  } catch (e) {
    return false;
  }
}

function getCurrentDateTime() {
  var now = new Date();
  var y = now.getFullYear();
  var m = String(now.getMonth() + 1).padStart(2, "0");
  var d = String(now.getDate()).padStart(2, "0");
  var h = String(now.getHours()).padStart(2, "0");
  var min = String(now.getMinutes()).padStart(2, "0");
  var s = String(now.getSeconds()).padStart(2, "0");
  return y + "-" + m + "-" + d + " " + h + ":" + min + ":" + s;
}

function isTyporaRunning() {
  return new Promise(function (resolve) {
    var platform = process.platform;
    var cmd;
    if (platform === "win32") {
      cmd = 'tasklist /FI "IMAGENAME eq Typora.exe" /NH';
    } else if (platform === "darwin") {
      cmd = "pgrep -x Typora";
    } else {
      cmd = "pgrep -x typora";
    }
    exec(cmd, function (error, stdout) {
      if (platform === "win32") {
        resolve(stdout.toLowerCase().indexOf("typora.exe") !== -1);
      } else {
        resolve(!error && stdout.trim().length > 0);
      }
    });
  });
}

window.services = {
  copyToClipboard: function (text) {
    clipboard.writeText(text);
  },
  readClipboard: function () {
    return clipboard.readText();
  },
  loadConfig: loadConfig,
  saveConfig: saveConfig,
  getCurrentDateTime: getCurrentDateTime,
  isTyporaRunning: isTyporaRunning,
};
