-- VoxSniffer Logging
-- Debug output with module tags and severity levels

local _, NS = ...
NS.Log = {}
local Log = NS.Log
local C = NS.Constants

local debugEnabled = false
local verboseEnabled = false

function Log.SetDebug(enabled)
    debugEnabled = enabled
end

function Log.SetVerbose(enabled)
    verboseEnabled = enabled
end

function Log.IsDebug()
    return debugEnabled
end

local function Output(level, module, msg)
    print(format("%s[VoxSniffer %s]%s %s: %s", C.COLOR, level, C.CLOSE, module or "Core", msg))
end

function Log.Info(module, msg)
    Output("INFO", module, msg)
end

function Log.Warn(module, msg)
    Output("WARN", module, msg)
end

function Log.Error(module, msg)
    Output("ERROR", module, msg)
end

function Log.Debug(module, msg)
    if debugEnabled then
        Output("DBG", module, msg)
    end
end

function Log.Verbose(module, msg)
    if verboseEnabled then
        Output("VERB", module, msg)
    end
end
