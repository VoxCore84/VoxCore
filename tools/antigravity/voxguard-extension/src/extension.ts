import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { execFile } from 'child_process';

// Paths (matching the Python toolkit)
const HOME = process.env.USERPROFILE || 'C:\\Users\\atayl';
const SETTINGS_JSON = path.join(HOME, 'AppData', 'Roaming', 'Antigravity', 'User', 'settings.json');
const ARGV_JSON = path.join(HOME, '.antigravity', 'argv.json');
const BUNDLED_EXT_DIR = path.join(HOME, 'AppData', 'Local', 'Programs', 'Antigravity', 'resources', 'app', 'extensions');
const BASELINE_FILE = path.join(HOME, 'VoxCore', 'tools', 'antigravity', 'otto_baseline.json');
const PYTHON = 'C:\\Python314\\python.exe';
const OPTIMIZER = path.join(HOME, 'VoxCore', 'tools', 'antigravity', 'optimize_antigravity.py');
const REDISABLER = path.join(HOME, 'VoxCore', 'tools', 'antigravity', 'redisable_extensions.py');

interface Baseline {
    settings_critical: Record<string, any>;
    argv_critical: Record<string, any>;
    argv_js_flags_required: string[];
    disabled_extensions: string[];
}

interface CheckResult {
    name: string;
    status: 'OK' | 'WARN' | 'ERROR';
    detail: string;
}

let statusBarItem: vscode.StatusBarItem;
let outputChannel: vscode.OutputChannel;
let checkInterval: NodeJS.Timeout | undefined;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('VoxGuard');

    // Status bar item (left side, high priority)
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 1000);
    statusBarItem.command = 'voxguard.showReport';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('voxguard.checkHealth', () => runHealthCheck()),
        vscode.commands.registerCommand('voxguard.fixAll', () => runFixAll()),
        vscode.commands.registerCommand('voxguard.showReport', () => {
            outputChannel.show();
            runHealthCheck();
        })
    );

    // Watch for settings changes
    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration(e => {
            // Check if any critical setting changed
            const criticalKeys = [
                'telemetry.telemetryLevel', 'extensions.autoUpdate',
                'editor.minimap.enabled', 'workbench.enableExperiments'
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

    // Initial health check
    runHealthCheck();

    // Periodic check every 30 minutes
    checkInterval = setInterval(() => runHealthCheck(), 30 * 60 * 1000);
    context.subscriptions.push({ dispose: () => { if (checkInterval) clearInterval(checkInterval); } });

    outputChannel.appendLine('[VoxGuard] Activated — monitoring optimization health');
}

export function deactivate() {
    if (checkInterval) clearInterval(checkInterval);
}

// Load baseline from otto_baseline.json
function loadBaseline(): Baseline | null {
    try {
        const raw = fs.readFileSync(BASELINE_FILE, 'utf-8');
        return JSON.parse(raw);
    } catch {
        return null;
    }
}

// Run health check — compares current state against baseline
async function runHealthCheck(): Promise<void> {
    const baseline = loadBaseline();
    if (!baseline) {
        updateStatusBar('error', 'Baseline not found');
        outputChannel.appendLine('[VoxGuard] ERROR: otto_baseline.json not found');
        return;
    }

    const results: CheckResult[] = [];
    const timestamp = new Date().toLocaleTimeString();

    // 1. Check settings.json critical keys
    try {
        const settingsRaw = fs.readFileSync(SETTINGS_JSON, 'utf-8');
        const settings = JSON.parse(settingsRaw);
        let settingsOk = true;
        for (const [key, expected] of Object.entries(baseline.settings_critical)) {
            const actual = getNestedValue(settings, key);
            if (JSON.stringify(actual) !== JSON.stringify(expected)) {
                results.push({ name: `Setting: ${key}`, status: 'WARN', detail: `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}` });
                settingsOk = false;
            }
        }
        if (settingsOk) {
            results.push({ name: 'Settings', status: 'OK', detail: `${Object.keys(baseline.settings_critical).length} critical keys verified` });
        }
    } catch (err) {
        results.push({ name: 'Settings', status: 'ERROR', detail: `Cannot read: ${err}` });
    }

    // 2. Check argv.json
    try {
        const argvRaw = fs.readFileSync(ARGV_JSON, 'utf-8');
        const argv = JSON.parse(argvRaw);
        let argvOk = true;
        for (const [key, expected] of Object.entries(baseline.argv_critical)) {
            if (JSON.stringify(argv[key]) !== JSON.stringify(expected)) {
                results.push({ name: `argv: ${key}`, status: 'WARN', detail: `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(argv[key])}` });
                argvOk = false;
            }
        }
        // Check js-flags
        const jsFlags = argv['js-flags'] || '';
        for (const flag of baseline.argv_js_flags_required) {
            if (!jsFlags.includes(flag)) {
                results.push({ name: `argv: js-flags`, status: 'WARN', detail: `Missing flag: ${flag}` });
                argvOk = false;
            }
        }
        if (argvOk) {
            results.push({ name: 'argv.json', status: 'OK', detail: 'All critical flags verified' });
        }
    } catch (err) {
        results.push({ name: 'argv.json', status: 'ERROR', detail: `Cannot read: ${err}` });
    }

    // 3. Check disabled extensions
    try {
        const entries = fs.readdirSync(BUNDLED_EXT_DIR);
        let reenabledCount = 0;
        const reenabled: string[] = [];
        for (const ext of baseline.disabled_extensions) {
            // Extension should exist as ext.disabled, NOT as ext
            if (entries.includes(ext) && !entries.includes(ext + '.disabled')) {
                // It's been re-enabled (exists without .disabled)
                reenabledCount++;
                reenabled.push(ext);
            }
        }
        if (reenabledCount > 0) {
            results.push({ name: 'Bundled Extensions', status: 'ERROR', detail: `${reenabledCount} re-enabled: ${reenabled.slice(0, 5).join(', ')}${reenabledCount > 5 ? '...' : ''}` });
        } else {
            results.push({ name: 'Bundled Extensions', status: 'OK', detail: `${baseline.disabled_extensions.length} extensions still disabled` });
        }
    } catch (err) {
        results.push({ name: 'Bundled Extensions', status: 'ERROR', detail: `Cannot scan: ${err}` });
    }

    // Compute overall status
    const errorCount = results.filter(r => r.status === 'ERROR').length;
    const warnCount = results.filter(r => r.status === 'WARN').length;
    const okCount = results.filter(r => r.status === 'OK').length;
    const total = results.length;

    let overall: 'healthy' | 'degraded' | 'critical';
    if (errorCount > 0) overall = 'critical';
    else if (warnCount > 0) overall = 'degraded';
    else overall = 'healthy';

    // Update UI
    updateStatusBar(overall === 'healthy' ? 'ok' : overall === 'degraded' ? 'warn' : 'error',
        `${okCount}/${total} OK`);

    // Write to output channel
    outputChannel.appendLine('');
    outputChannel.appendLine(`=== VoxGuard Health Check [${timestamp}] ===`);
    outputChannel.appendLine(`Status: ${overall.toUpperCase()} (${okCount} OK, ${warnCount} WARN, ${errorCount} ERROR)`);
    outputChannel.appendLine('');
    for (const r of results) {
        const icon = r.status === 'OK' ? '[OK]' : r.status === 'WARN' ? '[!!]' : '[ER]';
        outputChannel.appendLine(`  ${icon} ${r.name}: ${r.detail}`);
    }
    outputChannel.appendLine('');

    // Show notification if critical
    if (overall === 'critical') {
        const action = await vscode.window.showWarningMessage(
            `VoxGuard: ${errorCount} optimization regression(s) detected`,
            'Fix All', 'Show Report'
        );
        if (action === 'Fix All') runFixAll();
        else if (action === 'Show Report') outputChannel.show();
    }
}

function updateStatusBar(status: 'ok' | 'warn' | 'error', text: string) {
    if (status === 'ok') {
        statusBarItem.text = '$(check) OTTO';
        statusBarItem.tooltip = `VoxGuard: All optimizations healthy (${text})`;
        statusBarItem.backgroundColor = undefined;
    } else if (status === 'warn') {
        statusBarItem.text = '$(warning) OTTO';
        statusBarItem.tooltip = `VoxGuard: Minor issues (${text})`;
        statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    } else {
        statusBarItem.text = '$(error) OTTO';
        statusBarItem.tooltip = `VoxGuard: Regressions detected! (${text})`;
        statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
    }
}

// Run fix via Python scripts
async function runFixAll(): Promise<void> {
    outputChannel.appendLine('[VoxGuard] Running auto-fix...');

    // Run optimizer with --fix
    try {
        const result = await runPython(OPTIMIZER, ['--fix']);
        outputChannel.appendLine(result);
    } catch (err) {
        outputChannel.appendLine(`[VoxGuard] Optimizer error: ${err}`);
    }

    // Run extension re-disabler
    try {
        const result = await runPython(REDISABLER, []);
        outputChannel.appendLine(result);
    } catch (err) {
        outputChannel.appendLine(`[VoxGuard] Redisabler error: ${err}`);
    }

    // Re-check
    outputChannel.appendLine('[VoxGuard] Re-checking health...');
    await runHealthCheck();

    vscode.window.showInformationMessage('VoxGuard: Fix complete — see output for details');
}

function runPython(script: string, args: string[]): Promise<string> {
    return new Promise((resolve, reject) => {
        execFile(PYTHON, [script, ...args], { timeout: 30000 }, (error, stdout, stderr) => {
            if (error) {
                reject(`${error.message}\n${stderr}`);
            } else {
                resolve(stdout + (stderr ? `\n${stderr}` : ''));
            }
        });
    });
}

// Helper to get nested object values by dotted key
function getNestedValue(obj: any, key: string): any {
    const parts = key.split('.');
    let current = obj;
    for (const part of parts) {
        if (current === undefined || current === null) return undefined;
        current = current[part];
    }
    return current;
}
