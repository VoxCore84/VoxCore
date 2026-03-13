-- VoxSniffer MovementTracker
-- Samples NPC positions over time to infer patrol waypoints
-- OFF by default (high volume) — enable with /vs module movementtracker on
-- Tracks nameplated NPCs + target/focus, records position when movement detected

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local Sched = NS.Scheduler

local MODULE_NAME = C.MODULE.MOVEMENT_TRACKER
local tracker = {}
NS.RegisterModule(MODULE_NAME, tracker)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- Track last known position per NPC to detect movement
local unitPositions = {}  -- [guid] = { x, y, mapId, time, name, npcId, entityKey }
local MIN_MOVE_DIST = 0.001  -- minimum normalized coord change to record (avoids idle jitter)
local PRUNE_AGE = 120  -- seconds before pruning stale entries

-- Units to track
local TRACK_UNITS = { "target", "focus" }

-- Active nameplates
local activeNameplates = {}

local eventFrame = CreateFrame("Frame")

-- ============================================================
-- Position helpers
-- ============================================================

local function GetUnitMapPosition(unit)
    local mapId = C_Map.GetBestMapForUnit(unit)
    if not mapId then return nil, nil, nil end

    local pos = C_Map.GetPlayerMapPosition(mapId, unit)
    if not pos then
        -- For NPCs, try using unit position directly
        -- C_Map.GetPlayerMapPosition only works for "player" on most maps
        -- We can try the world position approach
        return nil, nil, mapId
    end

    return pos.x, pos.y, mapId
end

-- For NPCs we need a different approach since GetPlayerMapPosition
-- only works reliably for "player". We use position relative to player.
local function EstimateUnitPosition(unit)
    -- Get player's map position as anchor
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then return nil, nil, nil end

    local playerPos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not playerPos then return nil, nil, nil end

    -- We can't get exact NPC map coords without C_Map support for that unit
    -- But we CAN detect movement by comparing player-relative distance over time
    -- Use UnitPosition for world coords (works in instances, may be restricted in open world)
    if UnitPosition then
        local ok, y, x, z, instanceId = pcall(UnitPosition, unit)
        if ok and y and x then
            return x, y, mapId  -- world coords, not map-normalized
        end
    end

    return nil, nil, mapId
end

local function DistSq(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return dx * dx + dy * dy
end

-- ============================================================
-- Movement sampling
-- ============================================================

local function SampleUnit(unit, source)
    if not NS.IsCaptureActive() then return end
    if not UnitExists(unit) then return end
    if UnitIsPlayer(unit) then return end
    if UnitIsDead(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local guidType = guid:match("^(%a+)-")
    if guidType ~= "Creature" and guidType ~= "Vehicle" then return end

    local x, y, mapId = EstimateUnitPosition(unit)
    if not x or not y then return end

    local now = GetTime()
    local prev = unitPositions[guid]

    if prev then
        -- Check if unit has moved enough to record
        local distSq = DistSq(x, y, prev.x, prev.y)
        if distSq < MIN_MOVE_DIST * MIN_MOVE_DIST then
            return  -- hasn't moved enough
        end

        -- Record waypoint
        local entityKey = prev.entityKey
        local payload = {
            npcId = prev.npcId,
            unitName = prev.name,
            guid = guid,
            fromX = prev.x,
            fromY = prev.y,
            toX = x,
            toY = y,
            mapId = mapId,
            elapsed = now - prev.time,
            distance = math.sqrt(distSq),
            source = source,
        }

        local envelope = NS.MakeEnvelope(C.OBS_TYPE.MOVEMENT_SAMPLE, entityKey, payload, {
            source_module = MODULE_NAME,
        })
        if not envelope then return end

        buffer:Push(envelope)
        Log.Verbose(MODULE_NAME, format("Move: %s [%.4f,%.4f]->[%.4f,%.4f] (%.2fs)",
            prev.name or "?", prev.x, prev.y, x, y, payload.elapsed))
    end

    -- Update position
    unitPositions[guid] = {
        x = x,
        y = y,
        mapId = mapId,
        time = now,
        name = prev and prev.name or GU.SafeString(UnitName(unit)),
        npcId = prev and prev.npcId or GU.GetNpcId(guid),
        entityKey = prev and prev.entityKey or GU.EntityKey(guid),
    }
end

-- ============================================================
-- Tick handler
-- ============================================================

local sweepTimer = 0

local function OnTick()
    if not NS.IsCaptureActive() then return end

    -- Track explicit units
    for _, unit in ipairs(TRACK_UNITS) do
        if UnitExists(unit) then
            SampleUnit(unit, "tick_" .. unit)
        end
    end

    -- Track nameplated NPCs
    for unit in pairs(activeNameplates) do
        if UnitExists(unit) then
            SampleUnit(unit, "nameplate")
        end
    end

    -- Prune stale entries
    sweepTimer = sweepTimer + NS.Config.GetTickRate(MODULE_NAME)
    if sweepTimer >= 30 then
        sweepTimer = 0
        local cutoff = GetTime() - PRUNE_AGE
        for guid, data in pairs(unitPositions) do
            if data.time < cutoff then
                unitPositions[guid] = nil
            end
        end
    end
end

-- ============================================================
-- Nameplate tracking
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if unit then activeNameplates[unit] = true end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        if unit then activeNameplates[unit] = nil end
    end
end)

-- ============================================================
-- Module interface
-- ============================================================

function tracker.ResetState()
    wipe(unitPositions)
    sweepTimer = 0
end

function tracker.Enable()
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    Sched.Register(MODULE_NAME, OnTick, NS.Config.GetTickRate(MODULE_NAME))
    Log.Debug(MODULE_NAME, "Enabled — sampling NPC movement at 1Hz (high volume)")
end

function tracker.Disable()
    eventFrame:UnregisterAllEvents()
    Sched.Unregister(MODULE_NAME)
    wipe(unitPositions)
    wipe(activeNameplates)
    Log.Info(MODULE_NAME, "Disabled")
end

function tracker.GetStats()
    local stats = buffer:GetStats()
    stats.trackedUnits = 0
    for _ in pairs(unitPositions) do stats.trackedUnits = stats.trackedUnits + 1 end
    return stats
end
