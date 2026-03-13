-- VoxSniffer SessionManager
-- Start/stop recording sessions with metadata tracking
-- All observations are linked to the active session

local _, NS = ...
NS.SessionManager = {}
local SM = NS.SessionManager
local C = NS.Constants
local Log = NS.Log
local Schema = NS.Schema

local activeSession = nil   -- current session metadata table
local sessionId = nil       -- current session ID

function SM.Start(label)
    if activeSession then
        Log.Warn("Session", "Session already active (id=" .. sessionId .. "). Stop first.")
        return false
    end

    local db = VoxSnifferDB
    if not db then
        Log.Error("Session", "No database initialized!")
        return false
    end

    sessionId = Schema.NextSessionId(db)
    local now = time()

    activeSession = {
        session_id = sessionId,
        label = label or "",
        character = UnitName("player") or "Unknown",
        realm = GetRealmName() or "Unknown",
        class = select(2, UnitClass("player")) or "UNKNOWN",
        level = NS.GuidUtils.SafeNumber(UnitLevel("player")) or 0,
        client_build = select(2, GetBuildInfo()) or "0",
        interface_version = select(4, GetBuildInfo()) or 0,
        locale = GetLocale() or "enUS",
        map_id = C_Map.GetBestMapForUnit("player") or 0,
        zone_name = GetRealZoneText() or "Unknown",
        start_time = now,
        end_time = nil,
        observation_count = 0,
        chunk_count = 0,
        modules_enabled = {},
    }

    -- Record which modules are active
    local cfg = NS.Config.Get()
    for name, enabled in pairs(cfg.modules) do
        if enabled then
            activeSession.modules_enabled[name] = true
        end
    end

    db.sessions[sessionId] = activeSession
    db.stats.total_sessions = (db.stats.total_sessions or 0) + 1

    Log.Info("Session", format("Started session %d — %s on %s", sessionId, activeSession.character, activeSession.realm))
    NS.EventBus.Publish("SESSION_STARTED", { session_id = sessionId })
    return true
end

function SM.Stop()
    if not activeSession then
        Log.Warn("Session", "No active session to stop.")
        return false
    end

    activeSession.end_time = time()

    -- Trigger a final flush before closing
    NS.EventBus.Publish("SESSION_STOPPING", { session_id = sessionId })

    Log.Info("Session", format("Stopped session %d — %d observations in %d chunks",
        sessionId, activeSession.observation_count, activeSession.chunk_count))

    NS.EventBus.Publish("SESSION_STOPPED", { session_id = sessionId })

    activeSession = nil
    sessionId = nil
    return true
end

function SM.IsActive()
    return activeSession ~= nil
end

function SM.GetId()
    return sessionId
end

function SM.GetSession()
    return activeSession
end

function SM.SetLabel(label)
    if activeSession then
        activeSession.label = label or ""
        Log.Info("Session", "Label set: " .. (label or "(cleared)"))
    end
end

function SM.IncrementObservations(count)
    if activeSession then
        activeSession.observation_count = activeSession.observation_count + (count or 1)
    end
end

function SM.IncrementChunks()
    if activeSession then
        activeSession.chunk_count = activeSession.chunk_count + 1
    end
end

-- Update current zone metadata on the session
function SM.UpdateZone()
    if activeSession then
        activeSession.map_id = C_Map.GetBestMapForUnit("player") or activeSession.map_id
        activeSession.zone_name = GetRealZoneText() or activeSession.zone_name
    end
end
