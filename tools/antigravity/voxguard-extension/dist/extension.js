"use strict";
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/extension.ts
var extension_exports = {};
__export(extension_exports, {
  activate: () => activate,
  deactivate: () => deactivate
});
module.exports = __toCommonJS(extension_exports);
var vscode = __toESM(require("vscode"));
var fs = __toESM(require("fs"));
var path = __toESM(require("path"));
var import_child_process = require("child_process");
var HOME = process.env.USERPROFILE || "C:\\Users\\atayl";
var SETTINGS_JSON = path.join(HOME, "AppData", "Roaming", "Antigravity", "User", "settings.json");
var ARGV_JSON = path.join(HOME, ".antigravity", "argv.json");
var BUNDLED_EXT_DIR = path.join(HOME, "AppData", "Local", "Programs", "Antigravity", "resources", "app", "extensions");
var BASELINE_FILE = path.join(HOME, "VoxCore", "tools", "antigravity", "otto_baseline.json");
var PYTHON = "C:\\Python314\\python.exe";
var OPTIMIZER = path.join(HOME, "VoxCore", "tools", "antigravity", "optimize_antigravity.py");
var REDISABLER = path.join(HOME, "VoxCore", "tools", "antigravity", "redisable_extensions.py");
var statusBarItem;
var outputChannel;
var checkInterval;
function activate(context) {
  outputChannel = vscode.window.createOutputChannel("VoxGuard");
  statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 1e3);
  statusBarItem.command = "voxguard.showReport";
  statusBarItem.show();
  context.subscriptions.push(statusBarItem);
  context.subscriptions.push(
    vscode.commands.registerCommand("voxguard.checkHealth", () => runHealthCheck()),
    vscode.commands.registerCommand("voxguard.fixAll", () => runFixAll()),
    vscode.commands.registerCommand("voxguard.showReport", () => {
      outputChannel.show();
      runHealthCheck();
    })
  );
  context.subscriptions.push(
    vscode.workspace.onDidChangeConfiguration((e) => {
      const criticalKeys = [
        "telemetry.telemetryLevel",
        "extensions.autoUpdate",
        "editor.minimap.enabled",
        "workbench.enableExperiments"
      ];
      for (const key of criticalKeys) {
        if (e.affectsConfiguration(key)) {
          outputChannel.appendLine(`[VoxGuard] Settings change detected: ${key}`);
          runHealthCheck();
          return;
        }
      }
    })
  );
  runHealthCheck();
  checkInterval = setInterval(() => runHealthCheck(), 30 * 60 * 1e3);
  context.subscriptions.push({ dispose: () => {
    if (checkInterval)
      clearInterval(checkInterval);
  } });
  outputChannel.appendLine("[VoxGuard] Activated \u2014 monitoring optimization health");
}
function deactivate() {
  if (checkInterval)
    clearInterval(checkInterval);
}
function loadBaseline() {
  try {
    const raw = fs.readFileSync(BASELINE_FILE, "utf-8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}
async function runHealthCheck() {
  const baseline = loadBaseline();
  if (!baseline) {
    updateStatusBar("error", "Baseline not found");
    outputChannel.appendLine("[VoxGuard] ERROR: otto_baseline.json not found");
    return;
  }
  const results = [];
  const timestamp = (/* @__PURE__ */ new Date()).toLocaleTimeString();
  try {
    const settingsRaw = fs.readFileSync(SETTINGS_JSON, "utf-8");
    const settings = JSON.parse(settingsRaw);
    let settingsOk = true;
    for (const [key, expected] of Object.entries(baseline.settings_critical)) {
      const actual = getNestedValue(settings, key);
      if (JSON.stringify(actual) !== JSON.stringify(expected)) {
        results.push({ name: `Setting: ${key}`, status: "WARN", detail: `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}` });
        settingsOk = false;
      }
    }
    if (settingsOk) {
      results.push({ name: "Settings", status: "OK", detail: `${Object.keys(baseline.settings_critical).length} critical keys verified` });
    }
  } catch (err) {
    results.push({ name: "Settings", status: "ERROR", detail: `Cannot read: ${err}` });
  }
  try {
    const argvRaw = fs.readFileSync(ARGV_JSON, "utf-8");
    const argv = JSON.parse(argvRaw);
    let argvOk = true;
    for (const [key, expected] of Object.entries(baseline.argv_critical)) {
      if (JSON.stringify(argv[key]) !== JSON.stringify(expected)) {
        results.push({ name: `argv: ${key}`, status: "WARN", detail: `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(argv[key])}` });
        argvOk = false;
      }
    }
    const jsFlags = argv["js-flags"] || "";
    for (const flag of baseline.argv_js_flags_required) {
      if (!jsFlags.includes(flag)) {
        results.push({ name: `argv: js-flags`, status: "WARN", detail: `Missing flag: ${flag}` });
        argvOk = false;
      }
    }
    if (argvOk) {
      results.push({ name: "argv.json", status: "OK", detail: "All critical flags verified" });
    }
  } catch (err) {
    results.push({ name: "argv.json", status: "ERROR", detail: `Cannot read: ${err}` });
  }
  try {
    const entries = fs.readdirSync(BUNDLED_EXT_DIR);
    let reenabledCount = 0;
    const reenabled = [];
    for (const ext of baseline.disabled_extensions) {
      if (entries.includes(ext) && !entries.includes(ext + ".disabled")) {
        reenabledCount++;
        reenabled.push(ext);
      }
    }
    if (reenabledCount > 0) {
      results.push({ name: "Bundled Extensions", status: "ERROR", detail: `${reenabledCount} re-enabled: ${reenabled.slice(0, 5).join(", ")}${reenabledCount > 5 ? "..." : ""}` });
    } else {
      results.push({ name: "Bundled Extensions", status: "OK", detail: `${baseline.disabled_extensions.length} extensions still disabled` });
    }
  } catch (err) {
    results.push({ name: "Bundled Extensions", status: "ERROR", detail: `Cannot scan: ${err}` });
  }
  const errorCount = results.filter((r) => r.status === "ERROR").length;
  const warnCount = results.filter((r) => r.status === "WARN").length;
  const okCount = results.filter((r) => r.status === "OK").length;
  const total = results.length;
  let overall;
  if (errorCount > 0)
    overall = "critical";
  else if (warnCount > 0)
    overall = "degraded";
  else
    overall = "healthy";
  updateStatusBar(
    overall === "healthy" ? "ok" : overall === "degraded" ? "warn" : "error",
    `${okCount}/${total} OK`
  );
  outputChannel.appendLine("");
  outputChannel.appendLine(`=== VoxGuard Health Check [${timestamp}] ===`);
  outputChannel.appendLine(`Status: ${overall.toUpperCase()} (${okCount} OK, ${warnCount} WARN, ${errorCount} ERROR)`);
  outputChannel.appendLine("");
  for (const r of results) {
    const icon = r.status === "OK" ? "[OK]" : r.status === "WARN" ? "[!!]" : "[ER]";
    outputChannel.appendLine(`  ${icon} ${r.name}: ${r.detail}`);
  }
  outputChannel.appendLine("");
  if (overall === "critical") {
    const action = await vscode.window.showWarningMessage(
      `VoxGuard: ${errorCount} optimization regression(s) detected`,
      "Fix All",
      "Show Report"
    );
    if (action === "Fix All")
      runFixAll();
    else if (action === "Show Report")
      outputChannel.show();
  }
}
function updateStatusBar(status, text) {
  if (status === "ok") {
    statusBarItem.text = "$(check) OTTO";
    statusBarItem.tooltip = `VoxGuard: All optimizations healthy (${text})`;
    statusBarItem.backgroundColor = void 0;
  } else if (status === "warn") {
    statusBarItem.text = "$(warning) OTTO";
    statusBarItem.tooltip = `VoxGuard: Minor issues (${text})`;
    statusBarItem.backgroundColor = new vscode.ThemeColor("statusBarItem.warningBackground");
  } else {
    statusBarItem.text = "$(error) OTTO";
    statusBarItem.tooltip = `VoxGuard: Regressions detected! (${text})`;
    statusBarItem.backgroundColor = new vscode.ThemeColor("statusBarItem.errorBackground");
  }
}
async function runFixAll() {
  outputChannel.appendLine("[VoxGuard] Running auto-fix...");
  try {
    const result = await runPython(OPTIMIZER, ["--fix"]);
    outputChannel.appendLine(result);
  } catch (err) {
    outputChannel.appendLine(`[VoxGuard] Optimizer error: ${err}`);
  }
  try {
    const result = await runPython(REDISABLER, []);
    outputChannel.appendLine(result);
  } catch (err) {
    outputChannel.appendLine(`[VoxGuard] Redisabler error: ${err}`);
  }
  outputChannel.appendLine("[VoxGuard] Re-checking health...");
  await runHealthCheck();
  vscode.window.showInformationMessage("VoxGuard: Fix complete \u2014 see output for details");
}
function runPython(script, args) {
  return new Promise((resolve, reject) => {
    (0, import_child_process.execFile)(PYTHON, [script, ...args], { timeout: 3e4 }, (error, stdout, stderr) => {
      if (error) {
        reject(`${error.message}
${stderr}`);
      } else {
        resolve(stdout + (stderr ? `
${stderr}` : ""));
      }
    });
  });
}
function getNestedValue(obj, key) {
  const parts = key.split(".");
  let current = obj;
  for (const part of parts) {
    if (current === void 0 || current === null)
      return void 0;
    current = current[part];
  }
  return current;
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  activate,
  deactivate
});
