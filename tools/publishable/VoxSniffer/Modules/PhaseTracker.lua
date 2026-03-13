-- VoxSniffer PhaseTracker
-- Detects phase/terrain swap evidence by tracking visibility changes
-- When NPCs appear/disappear near the player without dying, that's phase evidence
-- Also tracks SCENARIO_UPDATE, AREA_POIS_UPDATED, and phase-related events

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.PHASE_TRACKER
local tracker = {}
NS.RegisterModule(MODULE_NAME, tracker)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")

-- Track nameplate appearances/disappearances for phase inference
local knownUnits = {}  -- [guid] = { name, npcId, entityKey, firstSeen, lastSeen, mapId }
local PHASE_WINDOW = 3  -- seconds — if NPC vanishes within this window, could be phase change

-- ============================================================
-- Phase evidence recording
-- ============================================================

local function RecordPhaseEvidence(trigger, data)
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    data.trigger = trigger
    data.mapId = mapId
    data.position = pos

    local entityKey = data.entityKey or format("PHASE:%d:%s", mapId or 0, trigger)

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.PHASE_EVIDENCE, entityKey, data, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    buffer:Push(envelope)
    Log.Debug(MODULE_NAME, format("Phase evidence: %s (map %d)", trigger, mapId or 0))
end

-- ============================================================
-- Nameplate-based phase detection
-- When an NPC's nameplate disappears without UNIT_DIED, it may have phased out
-- ============================================================

local function OnNameplateAdded(unit)
    if not unit then return end
    if not UnitExists(unit) then return end
    if UnitIsPlayer(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local guidType = guid:match("^(%a+)-")
    if guidType ~= "Creature" and guidType ~= "Vehicle" then return end

    local now = GetTime()
    local entityKey = GU.EntityKey(guid)
    local npcId = GU.GetNpcId(guid)
    local name = GU.SafeString(UnitName(unit))
    local mapId = C_Map.GetBestMapForUnit("player")

    local prev = knownUnits[guid]
    if prev and prev.removed and (now - prev.removed) < PHASE_WINDOW then
        -- NPC reappeared quickly — possible phase flicker
        RecordPhaseEvidence("unit_reappeared", {
            npcId = npcId,
            unitName = name,
            entityKey = entityKey,
            guid = guid,
            gapSeconds = now - prev.removed,
        })
    end

    knownUnits[guid] = {
        name = name,
        npcId = npcId,
        entityKey = entityKey,
        firstSeen = prev and prev.firstSeen or now,
        lastSeen = now,
        mapId = mapId,
        removed = nil,
    }
end

local function OnNameplateRemoved(unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    if not guid then return end

    local tracked = knownUnits[guid]
    if not tracked then return end

    -- Mark removal time (don't delete yet — check for reappearance)
    tracked.removed = GetTime()
    tracked.lastSeen = GetTime()
end

-- ============================================================
-- Zone/scenario/phase events
-- ============================================================

local lastZoneText = nil
local lastSubZoneText = nil

local function OnZoneChanged()
    local zoneText = GetZoneText and GetZoneText() or nil
    local subZoneText = GetSubZoneText and GetSubZoneText() or nil

    if zoneText ~= lastZoneText or subZoneText ~= lastSubZoneText then
        RecordPhaseEvidence("zone_changed", {
            fromZone = lastZoneText,
            fromSubZone = lastSubZoneText,
            toZone = zoneText,
            toSubZone = subZoneText,
        })
        lastZoneText = zoneText
        lastSubZoneText = subZoneText
    end
end

local function OnScenarioUpdate()
    if not C_Scenario or not C_Scenario.GetInfo then return end

    local ok, scenarioName, currentStage, numStages, flags, _, _, _, _, textDescription = pcall(C_Scenario.GetInfo)
    if not ok then return end

    if scenarioName and scenarioName ~= "" then
        RecordPhaseEvidence("scenario_update", {
            scenarioName = scenarioName,
            currentStage = currentStage,
            numStages = numStages,
            description = textDescription,
        })
    end
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        OnNameplateAdded(...)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        OnNameplateRemoved(...)

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS"
        or event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChanged()

    elseif event == "SCENARIO_UPDATE" or event == "SCENARIO_CRITERIA_UPDATE" then
        OnScenarioUpdate()

    elseif event == "AREA_POIS_UPDATED" then
        RecordPhaseEvidence("area_pois_updated", {})

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        RecordPhaseEvidence("entering_world", {
            isInitialLogin = isInitialLogin,
            isReloadingUi = isReloadingUi,
            zone = GetZoneText and GetZoneText() or nil,
            subZone = GetSubZoneText and GetSubZoneText() or nil,
        })
        lastZoneText = GetZoneText and GetZoneText()
        lastSubZoneText = GetSubZoneText and GetSubZoneText()
    end
end)

-- ============================================================
-- Periodic cleanup
-- ============================================================

local function SweepTrackedUnits()
    local cutoff = GetTime() - 120  -- 2 minutes
    for guid, data in pairs(knownUnits) do
        if data.lastSeen < cutoff then
            knownUnits[guid] = nil
        end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function tracker.ResetState()
    wipe(knownUnits)
    lastZoneText = GetZoneText and GetZoneText() or nil
    lastSubZoneText = GetSubZoneText and GetSubZoneText() or nil

    -- Re-enumerate currently visible nameplates to rebuild baseline
    -- so phase detection works for NPCs already on screen at session start
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            local now = GetTime()
            for _, plate in ipairs(plates) do
                local unit = plate and plate.namePlateUnitToken
                if unit and UnitExists(unit) and not UnitIsPlayer(unit) then
                    local guid = UnitGUID(unit)
                    if guid then
                        local guidType = guid:match("^(%a+)-")
                        if guidType == "Creature" or guidType == "Vehicle" then
                            local mapId = C_Map.GetBestMapForUnit("player")
                            knownUnits[guid] = {
                                name = GU.SafeString(UnitName(unit)),
                                npcId = GU.GetNpcId(guid),
                                entityKey = GU.EntityKey(guid),
                                firstSeen = now,
                                lastSeen = now,
                                mapId = mapId,
                                removed = nil,
                            }
                        end
                    end
                end
            end
        end
    end
end

function tracker.Enable()
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    pcall(function() eventFrame:RegisterEvent("SCENARIO_UPDATE") end)
    pcall(function() eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE") end)
    pcall(function() eventFrame:RegisterEvent("AREA_POIS_UPDATED") end)

    NS.Scheduler.Register(MODULE_NAME .. "_sweep", SweepTrackedUnits, 30)

    lastZoneText = GetZoneText and GetZoneText()
    lastSubZoneText = GetSubZoneText and GetSubZoneText()

    Log.Debug(MODULE_NAME, "Enabled — tracking phase/visibility/zone transitions")
end

function tracker.Disable()
    eventFrame:UnregisterAllEvents()
    NS.Scheduler.Unregister(MODULE_NAME .. "_sweep")
    wipe(knownUnits)
    Log.Info(MODULE_NAME, "Disabled")
end

function tracker.GetStats()
    local stats = buffer:GetStats()
    stats.trackedUnits = 0
    for _ in pairs(knownUnits) do stats.trackedUnits = stats.trackedUnits + 1 end
    return stats
end
