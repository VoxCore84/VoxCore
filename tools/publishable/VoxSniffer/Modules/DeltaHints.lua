-- VoxSniffer DeltaHints
-- Live comparison of observed data against a loaded "hotset" baseline
-- OFF by default — requires baseline data to be loaded into VoxSnifferDB.hotset
-- When active, flags differences between observed and expected NPC data

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local EB = NS.EventBus
local Sched = NS.Scheduler

local MODULE_NAME = C.MODULE.DELTA_HINTS
local hints = {}
NS.RegisterModule(MODULE_NAME, hints)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- Hotset: loaded from VoxSnifferDB.hotset (populated by Python pipeline)
-- Format: { creatures = { [npcId] = { name, level, faction, ... }, ... } }
local hotset = nil

-- Track reported deltas to avoid spam
local reportedDeltas = {}  -- [deltaKey] = GetTime()
local REPORT_COOLDOWN = 300  -- 5 minutes between re-reporting same delta

-- ============================================================
-- Hotset loading
-- ============================================================

local function LoadHotset()
    if not VoxSnifferDB or not VoxSnifferDB.hotset then
        return false
    end
    hotset = VoxSnifferDB.hotset
    local creatureCount = 0
    if hotset.creatures then
        for _ in pairs(hotset.creatures) do creatureCount = creatureCount + 1 end
    end
    Log.Info(MODULE_NAME, format("Loaded hotset: %d creatures", creatureCount))
    return creatureCount > 0
end

-- ============================================================
-- Delta detection
-- ============================================================

local function CheckCreatureDelta(npcId, observed)
    if not hotset or not hotset.creatures then return end
    if not npcId then return end

    local expected = hotset.creatures[npcId]
    if not expected then
        -- NPC not in baseline — this IS a delta (new/unknown creature)
        local deltaKey = format("new_creature:%d", npcId)
        local now = GetTime()
        if reportedDeltas[deltaKey] and (now - reportedDeltas[deltaKey]) < REPORT_COOLDOWN then
            return
        end

        local payload = {
            deltaType = "new_creature",
            npcId = npcId,
            observedName = observed.name,
            observedLevel = observed.level,
            observedClassification = observed.classification,
        }

        local envelope = NS.MakeEnvelope(C.OBS_TYPE.DELTA_HINT, format("C:%d", npcId), payload, {
            source_module = MODULE_NAME,
        })
        if not envelope then return end
        reportedDeltas[deltaKey] = now
        buffer:Push(envelope)
        Log.Info(MODULE_NAME, format("DELTA: New creature %d (%s) not in baseline",
            npcId, observed.name or "?"))
        return
    end

    -- Compare fields
    local deltas = {}

    if expected.name and observed.name and expected.name ~= observed.name then
        deltas[#deltas + 1] = {
            field = "name",
            expected = expected.name,
            observed = observed.name,
        }
    end

    if expected.level and observed.level and expected.level ~= observed.level then
        deltas[#deltas + 1] = {
            field = "level",
            expected = expected.level,
            observed = observed.level,
        }
    end

    if expected.classification and observed.classification
        and expected.classification ~= observed.classification then
        deltas[#deltas + 1] = {
            field = "classification",
            expected = expected.classification,
            observed = observed.classification,
        }
    end

    if expected.creatureType and observed.creatureType
        and expected.creatureType ~= observed.creatureType then
        deltas[#deltas + 1] = {
            field = "creatureType",
            expected = expected.creatureType,
            observed = observed.creatureType,
        }
    end

    if #deltas == 0 then return end

    local deltaKey = format("creature_diff:%d", npcId)
    local now = GetTime()
    if reportedDeltas[deltaKey] and (now - reportedDeltas[deltaKey]) < REPORT_COOLDOWN then
        return
    end

    local payload = {
        deltaType = "creature_diff",
        npcId = npcId,
        unitName = observed.name,
        deltas = deltas,
        deltaCount = #deltas,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.DELTA_HINT, format("C:%d", npcId), payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end
    reportedDeltas[deltaKey] = now
    buffer:Push(envelope)
    Log.Info(MODULE_NAME, format("DELTA: Creature %d (%s) — %d field differences",
        npcId, observed.name or "?", #deltas))
end

-- ============================================================
-- EventBus subscriber — listens for unit observations from UnitScanner
-- ============================================================

local function OnUnitSeen(data)
    if not hotset then return end
    if not data or not data.p then return end

    local payload = data.p
    local npcId = payload.npcId
    if npcId then
        CheckCreatureDelta(npcId, payload)
    end
end

-- ============================================================
-- Periodic cooldown sweep
-- ============================================================

local function SweepCooldowns()
    local cutoff = GetTime() - REPORT_COOLDOWN * 2
    for k, t in pairs(reportedDeltas) do
        if t < cutoff then reportedDeltas[k] = nil end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

local ebHandle = nil

function hints.ResetState()
    wipe(reportedDeltas)
    -- Reload hotset from DB (nil-ing it breaks delta detection until next Enable)
    LoadHotset()
end

function hints.Enable()
    -- Idempotent: unsubscribe existing handle before re-subscribing
    if ebHandle then
        EB.Unsubscribe(ebHandle)
        ebHandle = nil
    end

    if not LoadHotset() then
        Log.Warn(MODULE_NAME, "No hotset loaded — DeltaHints will not detect differences")
        Log.Warn(MODULE_NAME, "Use Python pipeline to populate VoxSnifferDB.hotset")
    end

    -- Subscribe to unit observations via EventBus
    ebHandle = EB.Subscribe("UNIT_OBSERVED", OnUnitSeen)

    Sched.Register(MODULE_NAME .. "_sweep", SweepCooldowns, 60)
    Log.Debug(MODULE_NAME, "Enabled — comparing observations against baseline hotset")
end

function hints.Disable()
    if ebHandle then
        EB.Unsubscribe(ebHandle)
        ebHandle = nil
    end
    Sched.Unregister(MODULE_NAME .. "_sweep")
    hotset = nil
    Log.Info(MODULE_NAME, "Disabled")
end

function hints.GetStats()
    local stats = buffer:GetStats()
    stats.hotsetLoaded = hotset ~= nil
    stats.hotsetCreatures = 0
    if hotset and hotset.creatures then
        for _ in pairs(hotset.creatures) do stats.hotsetCreatures = stats.hotsetCreatures + 1 end
    end
    stats.reportedDeltas = 0
    for _ in pairs(reportedDeltas) do stats.reportedDeltas = stats.reportedDeltas + 1 end
    return stats
end

-- Expose reload function for slash commands
function hints.ReloadHotset()
    LoadHotset()
end
