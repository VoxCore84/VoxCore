-- VoxSniffer CombatEnricher
-- Captures combat context snapshots: unit health/power at key moments,
-- spell cast start/stop/interrupt, phase transitions during encounters
-- Supplements CombatCapture with richer behavioral data for NPC AI analysis

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.COMBAT_ENRICHER
local enricher = {}
NS.RegisterModule(MODULE_NAME, enricher)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")

-- Track units in combat for context snapshots
local combatUnits = {}  -- [guid] = { name, npcId, entityKey, lastSnapshot }
local SNAPSHOT_INTERVAL = 2  -- seconds between health snapshots per unit

-- ============================================================
-- Unit tracking helpers
-- ============================================================

local function IsNpcUnit(unit)
    if not UnitExists(unit) then return false end
    if UnitIsPlayer(unit) then return false end
    local guid = UnitGUID(unit)
    if not guid then return false end
    local guidType = guid:match("^(%a+)-")
    return guidType == "Creature" or guidType == "Vehicle"
end

local function TrackUnit(unit)
    if not IsNpcUnit(unit) then return end
    local guid = UnitGUID(unit)
    if not guid then return end
    if combatUnits[guid] then return end

    combatUnits[guid] = {
        name = GU.SafeString(UnitName(unit)),
        npcId = GU.GetNpcId(guid),
        entityKey = GU.EntityKey(guid),
        lastSnapshot = 0,
    }
end

-- ============================================================
-- Context snapshot (health/power at a point in time)
-- ============================================================

local function SnapshotUnit(unit, trigger)
    if not UnitExists(unit) then return end
    local guid = UnitGUID(unit)
    if not guid then return end

    local tracked = combatUnits[guid]
    if not tracked then return end

    local now = GetTime()
    if trigger == "tick" and (now - tracked.lastSnapshot) < SNAPSHOT_INTERVAL then
        return
    end
    tracked.lastSnapshot = now

    local health = GU.SafeNumber(UnitHealth(unit))
    local maxHealth = GU.SafeNumber(UnitHealthMax(unit))
    local power = GU.SafeNumber(UnitPower(unit))
    local maxPower = GU.SafeNumber(UnitPowerMax(unit))
    local powerType = GU.SafeNumber(UnitPowerType(unit))

    local payload = {
        trigger = trigger,
        npcId = tracked.npcId,
        unitName = tracked.name,
        guid = guid,
        health = health,
        maxHealth = maxHealth,
        healthPct = maxHealth and maxHealth > 0 and health and math.floor(health / maxHealth * 100) or nil,
        power = power,
        maxPower = maxPower,
        powerType = powerType,
    }

    -- Add cast info if casting
    if UnitCastingInfo then
        local ok, castName, _, _, _, _, _, castSpellID = pcall(UnitCastingInfo, unit)
        if ok and castName then
            payload.castName = castName
            payload.castSpellID = castSpellID
        end
    end

    if UnitChannelInfo then
        local ok, chanName, _, _, _, _, _, _, chanSpellID = pcall(UnitChannelInfo, unit)
        if ok and chanName then
            payload.chanName = chanName
            payload.chanSpellID = chanSpellID
        end
    end

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.COMBAT_CONTEXT, tracked.entityKey, payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    buffer:Push(envelope)
end

-- ============================================================
-- Cast tracking events
-- ============================================================

local function OnSpellcastEvent(unit, trigger, castGUID, spellID)
    if not unit then return end
    if not IsNpcUnit(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    TrackUnit(unit)

    local tracked = combatUnits[guid]
    if not tracked then return end

    local health = GU.SafeNumber(UnitHealth(unit))
    local maxHealth = GU.SafeNumber(UnitHealthMax(unit))

    local payload = {
        trigger = trigger,
        npcId = tracked.npcId,
        unitName = tracked.name,
        guid = guid,
        spellID = spellID,
        castGUID = castGUID,
        healthPct = maxHealth and maxHealth > 0 and health and math.floor(health / maxHealth * 100) or nil,
    }

    -- Get spell name
    if spellID and GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then payload.spellName = name end
    end

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.COMBAT_CONTEXT, tracked.entityKey, payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    buffer:Push(envelope)
    Log.Verbose(MODULE_NAME, format("[%s] %s: spell %s (%d) at %d%% HP",
        trigger, tracked.name or "?", payload.spellName or "?", spellID or 0, payload.healthPct or 0))
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_START" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "cast_start", castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_STOP" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "cast_stop", castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "cast_succeeded", castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "cast_interrupted", castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "channel_start", castGUID, spellID)

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit, castGUID, spellID = ...
        OnSpellcastEvent(unit, "channel_stop", castGUID, spellID)

    elseif event == "UNIT_HEALTH" then
        local unit = ...
        if unit and IsNpcUnit(unit) then
            TrackUnit(unit)
            SnapshotUnit(unit, "health_change")
        end

    elseif event == "UNIT_TARGET" then
        -- NPC changed target — useful for threat/aggro analysis
        local unit = ...
        if unit and IsNpcUnit(unit) then
            TrackUnit(unit)
            local guid = UnitGUID(unit)
            local tracked = guid and combatUnits[guid]
            if tracked then
                local targetUnit = unit .. "target"
                local targetName = UnitExists(targetUnit) and UnitName(targetUnit) or nil
                local targetGUID = UnitExists(targetUnit) and UnitGUID(targetUnit) or nil

                local payload = {
                    trigger = "target_change",
                    npcId = tracked.npcId,
                    unitName = tracked.name,
                    guid = guid,
                    targetName = targetName,
                    targetGUID = targetGUID,
                    targetIsPlayer = targetGUID and UnitIsPlayer(targetUnit) or nil,
                }

                local envelope = NS.MakeEnvelope(C.OBS_TYPE.COMBAT_CONTEXT, tracked.entityKey, payload, {
                    source_module = MODULE_NAME,
                })
                if envelope then
                    buffer:Push(envelope)
                end
            end
        end
    end
end)

-- ============================================================
-- Periodic combat unit cleanup
-- ============================================================

local function SweepCombatUnits()
    -- Remove units that no longer exist or are dead
    for guid, tracked in pairs(combatUnits) do
        -- We can't easily check if a GUID's unit still exists without iterating,
        -- so just prune entries older than 60 seconds since last snapshot
        if (GetTime() - tracked.lastSnapshot) > 60 then
            combatUnits[guid] = nil
        end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function enricher.ResetState()
    wipe(combatUnits)
end

function enricher.Enable()
    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_HEALTH")
    eventFrame:RegisterEvent("UNIT_TARGET")

    NS.Scheduler.Register(MODULE_NAME .. "_sweep", SweepCombatUnits, 30)

    Log.Debug(MODULE_NAME, "Enabled — enriching combat data with cast/health/target context")
end

function enricher.Disable()
    eventFrame:UnregisterAllEvents()
    NS.Scheduler.Unregister(MODULE_NAME .. "_sweep")
    wipe(combatUnits)
    Log.Info(MODULE_NAME, "Disabled")
end

function enricher.GetStats()
    local stats = buffer:GetStats()
    stats.trackedCombatUnits = 0
    for _ in pairs(combatUnits) do stats.trackedCombatUnits = stats.trackedCombatUnits + 1 end
    return stats
end
