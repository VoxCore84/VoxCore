-- VoxSniffer — Universal Client-Side Data Vacuum for TrinityCore
-- Bootstrap: initializes core systems, registers events, provides slash commands
--
-- Phase 1: Skeleton + session infrastructure + core systems
-- Capture modules loaded in Phase 2+

local ADDON_NAME, NS = ...

local C = NS.Constants
local Log = NS.Log
local Cfg = NS.Config
local SM = NS.SessionManager
local FM = NS.FlushManager
local Schema = NS.Schema
local Sched = NS.Scheduler
local EB = NS.EventBus
local GU = NS.GuidUtils

-- ============================================================
-- Module registry
-- ============================================================

NS.modules = {}  -- [moduleName] = { Enable, Disable, GetStats, ... }

function NS.RegisterModule(name, module)
    NS.modules[name] = module
    Log.Debug("Core", "Module registered: " .. name)
end

function NS.GetModule(name)
    return NS.modules[name]
end

-- ============================================================
-- Main frame
-- ============================================================

local frame = CreateFrame("Frame", "VoxSnifferFrame")
local initialized = false

-- ============================================================
-- Capture gate — single source of truth for "should we record?"
-- ============================================================

function NS.IsCaptureActive()
    return SM.IsActive()
end

-- ============================================================
-- Cached player context (updated on a low-frequency tick)
-- Avoids repeated C_Map lookups on every MakeEnvelope call
-- ============================================================

local cachedMapId = 0
local cachedPos = nil
local cachedZone = ""

local function RefreshPlayerContext()
    cachedMapId = C_Map.GetBestMapForUnit("player") or 0
    cachedPos = nil
    if cachedMapId ~= 0 then
        local p = C_Map.GetPlayerMapPosition(cachedMapId, "player")
        if p then cachedPos = { x = p.x, y = p.y } end
    end
    cachedZone = GetRealZoneText() or ""
end

-- ============================================================
-- Observation envelope builder
-- ============================================================

function NS.MakeEnvelope(obsType, entityKey, payload, extra)
    -- Session gate: no envelopes without an active session
    if not SM.IsActive() then return nil end

    return {
        t = obsType,
        ek = entityKey,
        sid = SM.GetId(),
        map = cachedMapId,
        zone = cachedZone,
        pos = cachedPos,
        ts = GetTime(),
        epoch = time(),
        src = extra and extra.source_module or nil,
        fp = extra and extra.fingerprint or nil,
        p = payload,
    }
end

-- ============================================================
-- Module lifecycle hooks
-- Called on session start/stop/reset to clear per-module runtime state
-- ============================================================

function NS.ResetAllModuleState()
    for name, mod in pairs(NS.modules) do
        if mod.ResetState then
            mod.ResetState()
            Log.Debug("Core", "Reset runtime state: " .. name)
        end
    end
end

-- ============================================================
-- Status output
-- ============================================================

local function PrintStatus()
    local session = SM.GetSession()
    local db = VoxSnifferDB

    print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Status:")

    if session then
        print(format("  Session: #%d %s— %s on %s",
            session.session_id,
            session.label ~= "" and ("\"" .. session.label .. "\" ") or "",
            session.character, session.realm))
        print(format("  Running: %s | Observations: %d | Chunks: %d",
            date("%H:%M:%S", session.start_time),
            session.observation_count, session.chunk_count))
    else
        print("  Session: |cffff4444INACTIVE|r — use /vs start")
    end

    if db then
        print(format("  DB: schema v%d | %d sessions | %d chunks | %d total obs",
            db.schema_version,
            db.stats.total_sessions or 0,
            db.stats.total_chunks or 0,
            db.stats.total_observations or 0))
    end

    -- Flush stats
    local fStats = FM.GetStats()
    print(format("  Buffers: %d pending | %d flushed this session", fStats.pendingCount, fStats.totalFlushed))

    -- Module status
    local cfg = Cfg.Get()
    local enabledList, disabledList = {}, {}
    for name, enabled in pairs(cfg.modules) do
        if enabled then
            enabledList[#enabledList + 1] = name
        else
            disabledList[#disabledList + 1] = name
        end
    end
    table.sort(enabledList)
    table.sort(disabledList)

    if #enabledList > 0 then
        print("  Modules ON: |cff00ff00" .. table.concat(enabledList, ", ") .. "|r")
    end
    if #disabledList > 0 then
        print("  Modules OFF: |cffff4444" .. table.concat(disabledList, ", ") .. "|r")
    end

    -- Scheduler info
    local sched = Sched.GetRegistered()
    local schedCount = 0
    for _ in pairs(sched) do schedCount = schedCount + 1 end
    if schedCount > 0 then
        print(format("  Scheduler: %d registered callbacks", schedCount))
    end
end

-- ============================================================
-- Module enable/disable
-- ============================================================

local function SetModuleState(name, enabled)
    -- Find the module (case-insensitive search)
    local matchedName = nil
    for modName in pairs(C.MODULE) do
        if C.MODULE[modName]:lower() == name:lower() then
            matchedName = C.MODULE[modName]
            break
        end
    end

    if not matchedName then
        -- Try direct match
        for _, modName in pairs(C.MODULE) do
            if modName:lower() == name:lower() then
                matchedName = modName
                break
            end
        end
    end

    if not matchedName then
        Log.Warn("Core", "Unknown module: " .. name)
        return
    end

    Cfg.SetModuleEnabled(matchedName, enabled)
    local mod = NS.modules[matchedName]
    if mod then
        if enabled and mod.Enable then
            mod.Enable()
        elseif not enabled and mod.Disable then
            mod.Disable()
        end
    end

    Sched.SetEnabled(matchedName, enabled)

    local state = enabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"
    print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " " .. matchedName .. ": " .. state)
end

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_VOXSNIFFER1 = "/vs"
SLASH_VOXSNIFFER2 = "/voxsniffer"
SlashCmdList["VOXSNIFFER"] = function(msg)
    local args = {}
    for word in (msg or ""):gmatch("%S+") do
        args[#args + 1] = word:lower()
    end
    local cmd = args[1] or ""

    if cmd == "start" then
        local label = ""
        if #args > 1 then
            label = table.concat(args, " ", 2)
        end
        if SM.Start(label) then
            NS.ResetAllModuleState()
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording started.")
        end

    elseif cmd == "stop" then
        FM.FlushAll("session_stop")
        if SM.Stop() then
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording stopped.")
        end

    elseif cmd == "status" then
        PrintStatus()

    elseif cmd == "flush" then
        if not SM.IsActive() then
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " No active session. Nothing buffered.")
        else
            local count = FM.FlushAll("manual")
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. format(" Flushed %d records.", count))
        end

    elseif cmd == "module" or cmd == "mod" then
        local modName = args[2]
        local state = args[3]
        if not modName then
            Log.Warn("Core", "Usage: /vs module <name> on|off")
        elseif state == "on" or state == "enable" then
            SetModuleState(modName, true)
        elseif state == "off" or state == "disable" then
            SetModuleState(modName, false)
        else
            -- Toggle
            local cfg = Cfg.Get()
            for _, mName in pairs(C.MODULE) do
                if mName:lower() == modName then
                    local current = cfg.modules[mName] ~= false
                    SetModuleState(modName, not current)
                    return
                end
            end
            Log.Warn("Core", "Unknown module: " .. modName .. ". Use /vs module <name> on|off")
        end

    elseif cmd == "label" then
        if #args > 1 then
            SM.SetLabel(table.concat(args, " ", 2))
        else
            SM.SetLabel("")
        end

    elseif cmd == "debug" then
        local cfg = Cfg.Get()
        Cfg.SetDebug(not cfg.debugMode)
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Debug " .. (Cfg.Get().debugMode and "|cff00ff00ON|r" or "OFF"))

    elseif cmd == "verbose" then
        local cfg = Cfg.Get()
        Cfg.SetVerbose(not cfg.verboseMode)
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Verbose " .. (Cfg.Get().verboseMode and "|cff00ff00ON|r" or "OFF"))

    elseif cmd == "reset" then
        StaticPopup_Show("VOXSNIFFER_RESET")

    else
        -- No args or unknown command — open the control panel
        if NS.TogglePanel then
            NS.TogglePanel()
        else
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " v" .. C.VERSION .. " — /vs start | stop | status | flush | module | debug | verbose | reset")
        end
    end
end

-- ============================================================
-- Reset dialog
-- ============================================================

StaticPopupDialogs["VOXSNIFFER_RESET"] = {
    text = "Reset ALL VoxSniffer data? This cannot be undone.",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        -- Stop active session first
        if SM.IsActive() then
            FM.FlushAll("session_stop")
            SM.Stop()
        end
        -- Drain all module buffers to prevent stale data leaking
        FM.DrainAll()
        -- Clear all module runtime state (dedup caches, tracking tables, etc.)
        NS.ResetAllModuleState()
        VoxSnifferDB = Schema.CreateEmpty()
        Cfg.Init(VoxSnifferDB.config)
        FM.Reset()
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " All data reset.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- ============================================================
-- Addon Compartment (minimap button)
-- ============================================================

function VoxSniffer_OnCompartmentClick(_, buttonName)
    if buttonName == "RightButton" then
        if SM.IsActive() then
            FM.FlushAll("session_stop")
            SM.Stop()
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording stopped.")
        else
            if SM.Start() then
                NS.ResetAllModuleState()
            end
            print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording started.")
        end
    else
        -- Left-click opens the control panel
        if NS.TogglePanel then
            NS.TogglePanel()
        else
            PrintStatus()
        end
    end
end

function VoxSniffer_OnCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("VoxSniffer", 0, 0.8, 1)

    local session = SM.GetSession()
    if session then
        GameTooltip:AddLine(format("Recording: session #%d", session.session_id), 0, 1, 0)
        GameTooltip:AddLine(format("%d observations | %d chunks", session.observation_count, session.chunk_count), 1, 1, 1)
    else
        GameTooltip:AddLine("Not recording", 0.6, 0.6, 0.6)
    end

    local pending = FM.GetPendingCount()
    if pending > 0 then
        GameTooltip:AddLine(format("%d pending flush", pending), 1, 0.8, 0)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00ff00Left-click|r Panel  |cff00ff00Right-click|r Start/Stop", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

function VoxSniffer_OnCompartmentLeave()
    GameTooltip:Hide()
end

-- ============================================================
-- Event handler + bootstrap
-- ============================================================

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        -- 1. Validate/migrate SavedVariables
        VoxSnifferDB = Schema.Validate(VoxSnifferDB)

        -- 2. Initialize config from saved state
        Cfg.Init(VoxSnifferDB.config)

        -- 3. Enable modules that have registered
        for name, mod in pairs(NS.modules) do
            if Cfg.IsModuleEnabled(name) and mod.Enable then
                mod.Enable()
            end
        end

        initialized = true

        -- 4. Initial context refresh
        RefreshPlayerContext()

        -- 5. Auto-start session if configured
        if Cfg.Get().autoStartSession then
            if SM.Start("auto") then
                NS.ResetAllModuleState()
            end
        end

        -- Summary
        local db = VoxSnifferDB
        -- Count enabled modules (don't spam a line per module)
        local enabledCount = 0
        for name in pairs(NS.modules) do
            if Cfg.IsModuleEnabled(name) then enabledCount = enabledCount + 1 end
        end
        print(format("%s[VoxSniffer]%s v%s loaded — %d modules active | %d sessions | %d observations stored. /vs to open panel.",
            C.COLOR, C.CLOSE, C.VERSION, enabledCount,
            db.stats.total_sessions or 0, db.stats.total_observations or 0))

    elseif event == "PLAYER_LOGOUT" then
        -- Flush everything before logout
        FM.FlushAll("logout")

        -- Save config
        if VoxSnifferDB then
            VoxSnifferDB.config = Cfg.Save()
        end

        -- Close session if active
        if SM.IsActive() then
            SM.Stop()
        end

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        SM.UpdateZone()
        RefreshPlayerContext()
    end
end)

local contextTimer = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if not initialized then return end
    Sched.OnUpdate(elapsed)
    FM.OnUpdate(elapsed)
    -- Refresh cached player context every 1s (not every frame)
    contextTimer = contextTimer + elapsed
    if contextTimer >= 1 then
        contextTimer = 0
        RefreshPlayerContext()
    end
end)

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
