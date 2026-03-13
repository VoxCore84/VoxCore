-- VoxSniffer CombatCapture
-- COMBAT_LOG_EVENT_UNFILTERED dispatch via token table (Details! pattern)
-- Captures spell casts, damage, healing, aura applications from NPCs
-- Only records NPC-involved events (skips pure player-vs-player)

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.COMBAT_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- ============================================================
-- GUID type checks
-- ============================================================

local NPC_GUID_TYPES = {
    Creature = true,
    Vehicle = true,
}

local PET_GUID_TYPE = "Pet"

local function IsNpcGuid(guid)
    if not guid or guid == "" then return false end
    local guidType = guid:match("^(%a+)-")
    return guidType and NPC_GUID_TYPES[guidType] or false
end

local function IsPetGuid(guid)
    if not guid or guid == "" then return false end
    local guidType = guid:match("^(%a+)-")
    return guidType == PET_GUID_TYPE
end

-- ============================================================
-- Token dispatch table (Details! pattern — O(1) lookup)
-- ============================================================

local tokenHandlers = {}

-- Helper: record a combat observation
local function RecordCombat(subEvent, sourceGUID, sourceName, destGUID, destName, payload)
    -- At least one side must be an NPC (creature/vehicle)
    local sourceIsNpc = IsNpcGuid(sourceGUID)
    local destIsNpc = IsNpcGuid(destGUID)
    local sourceIsPet = IsPetGuid(sourceGUID)
    local destIsPet = IsPetGuid(destGUID)

    -- Require at least one real NPC; pet-only events are tagged but not primary
    if not sourceIsNpc and not destIsNpc then
        -- Allow pet events through but tag them
        if not sourceIsPet and not destIsPet then return end
    end

    -- Use the NPC as the entity key (prefer NPC over pet)
    local entityKey, npcId
    if sourceIsNpc then
        entityKey = GU.EntityKey(sourceGUID)
        npcId = GU.GetNpcId(sourceGUID)
    elseif destIsNpc then
        entityKey = GU.EntityKey(destGUID)
        npcId = GU.GetNpcId(destGUID)
    elseif sourceIsPet then
        entityKey = GU.EntityKey(sourceGUID)
        npcId = GU.GetNpcId(sourceGUID)
    else
        entityKey = GU.EntityKey(destGUID)
        npcId = GU.GetNpcId(destGUID)
    end
    if not entityKey then return end

    payload.subEvent = subEvent
    payload.sourceGUID = sourceGUID
    payload.sourceName = sourceName
    payload.destGUID = destGUID
    payload.destName = destName
    payload.sourceIsNpc = sourceIsNpc
    payload.destIsNpc = destIsNpc
    payload.sourceIsPet = sourceIsPet
    payload.destIsPet = destIsPet
    payload.npcId = npcId

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.COMBAT_EVENT, entityKey, payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    buffer:Push(envelope)
end

-- ============================================================
-- Spell events
-- ============================================================

local function HandleSpellEvent(subEvent, ts, sourceGUID, sourceName, sf, sr, destGUID, destName, df, dr,
                                 spellId, spellName, spellSchool, ...)
    local payload = {
        spellId = spellId,
        spellName = spellName,
        spellSchool = spellSchool,
    }

    -- Damage suffix
    if subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
        local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...
        payload.amount = amount
        payload.overkill = overkill
        payload.critical = critical
        payload.absorbed = absorbed

    -- Heal suffix
    elseif subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
        local amount, overhealing, absorbed, critical = ...
        payload.amount = amount
        payload.overhealing = overhealing
        payload.critical = critical

    -- Miss suffix
    elseif subEvent == "SPELL_MISSED" or subEvent == "SPELL_PERIODIC_MISSED" then
        local missType, isOffHand, amountMissed, critical = ...
        payload.missType = missType
        payload.amountMissed = amountMissed

    -- Energize
    elseif subEvent == "SPELL_ENERGIZE" or subEvent == "SPELL_PERIODIC_ENERGIZE" then
        local amount, overEnergize, powerType = ...
        payload.amount = amount
        payload.powerType = powerType

    -- Interrupt
    elseif subEvent == "SPELL_INTERRUPT" then
        local extraSpellId, extraSpellName, extraSchool = ...
        payload.extraSpellId = extraSpellId
        payload.extraSpellName = extraSpellName

    -- Dispel / Stolen
    elseif subEvent == "SPELL_DISPEL" or subEvent == "SPELL_STOLEN" then
        local extraSpellId, extraSpellName, extraSchool, auraType = ...
        payload.extraSpellId = extraSpellId
        payload.extraSpellName = extraSpellName
        payload.auraType = auraType

    -- Summon
    elseif subEvent == "SPELL_SUMMON" then
        -- No extra args beyond spell info
    end

    RecordCombat(subEvent, sourceGUID, sourceName, destGUID, destName, payload)
end

-- Register all spell-prefix tokens
local SPELL_TOKENS = {
    "SPELL_CAST_START", "SPELL_CAST_SUCCESS", "SPELL_CAST_FAILED",
    "SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE",
    "SPELL_HEAL", "SPELL_PERIODIC_HEAL",
    "SPELL_MISSED", "SPELL_PERIODIC_MISSED",
    "SPELL_ENERGIZE", "SPELL_PERIODIC_ENERGIZE",
    "SPELL_INTERRUPT", "SPELL_DISPEL", "SPELL_STOLEN",
    "SPELL_SUMMON",
    "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED",
    "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED_DOSE",
    "SPELL_AURA_REFRESH",
}

for _, token in ipairs(SPELL_TOKENS) do
    tokenHandlers[token] = HandleSpellEvent
end

-- ============================================================
-- Aura events (special handling for stacks)
-- ============================================================

local function HandleAuraEvent(subEvent, ts, sourceGUID, sourceName, sf, sr, destGUID, destName, df, dr,
                                spellId, spellName, spellSchool, auraType, amount)
    local payload = {
        spellId = spellId,
        spellName = spellName,
        spellSchool = spellSchool,
        auraType = auraType,
        stacks = amount,
    }
    RecordCombat(subEvent, sourceGUID, sourceName, destGUID, destName, payload)
end

-- Override aura tokens with the aura-specific handler
tokenHandlers["SPELL_AURA_APPLIED"] = HandleAuraEvent
tokenHandlers["SPELL_AURA_REMOVED"] = HandleAuraEvent
tokenHandlers["SPELL_AURA_APPLIED_DOSE"] = HandleAuraEvent
tokenHandlers["SPELL_AURA_REMOVED_DOSE"] = HandleAuraEvent
tokenHandlers["SPELL_AURA_REFRESH"] = HandleAuraEvent

-- ============================================================
-- Swing events
-- ============================================================

local function HandleSwingEvent(subEvent, ts, sourceGUID, sourceName, sf, sr, destGUID, destName, df, dr, ...)
    local payload = {}
    if subEvent == "SWING_DAMAGE" then
        local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing = ...
        payload.amount = amount
        payload.overkill = overkill
        payload.critical = critical
    elseif subEvent == "SWING_MISSED" then
        local missType, isOffHand, amountMissed = ...
        payload.missType = missType
    end
    RecordCombat(subEvent, sourceGUID, sourceName, destGUID, destName, payload)
end

tokenHandlers["SWING_DAMAGE"] = HandleSwingEvent
tokenHandlers["SWING_MISSED"] = HandleSwingEvent

-- ============================================================
-- Unit death / destroy
-- ============================================================

local function HandleUnitDied(subEvent, ts, sourceGUID, sourceName, sf, sr, destGUID, destName, df, dr)
    RecordCombat(subEvent, sourceGUID or "", sourceName or "", destGUID, destName, {})
end

tokenHandlers["UNIT_DIED"] = HandleUnitDied
tokenHandlers["UNIT_DESTROYED"] = HandleUnitDied

-- ============================================================
-- Range events (same shape as spell events)
-- ============================================================
tokenHandlers["RANGE_DAMAGE"] = HandleSpellEvent
tokenHandlers["RANGE_MISSED"] = HandleSpellEvent

-- ============================================================
-- Environmental damage
-- ============================================================

local function HandleEnvDamage(subEvent, ts, sourceGUID, sourceName, sf, sr, destGUID, destName, df, dr,
                                envType, amount, overkill, school, resisted, blocked, absorbed, critical)
    local payload = {
        envType = envType,
        amount = amount,
        overkill = overkill,
        critical = critical,
    }
    RecordCombat(subEvent, sourceGUID or "", sourceName or "", destGUID, destName, payload)
end

tokenHandlers["ENVIRONMENTAL_DAMAGE"] = HandleEnvDamage

-- ============================================================
-- Main CLEU dispatcher
-- ============================================================

local function OnCombatLogEvent()
    -- Single CombatLogGetCurrentEventInfo call; varargs capture suffix
    local ts, subEvent, hideCaster,
        sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags,
        ... = CombatLogGetCurrentEventInfo()

    local handler = tokenHandlers[subEvent]
    if handler then
        handler(subEvent, ts,
            sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
            destGUID, destName, destFlags, destRaidFlags,
            ...)
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    end
end)

-- ============================================================
-- Module interface
-- ============================================================

local cleuEnabled = false

function capture.ResetState()
    -- No module-local dedup state to clear; buffer drain handled by FlushManager
end

function capture.Enable()
    cleuEnabled = true
    -- Register CLEU from a clean execution context via C_Timer.After
    -- Direct registration during module Enable() inherits taint from earlier
    -- module calls (UnitHealth etc.), causing ADDON_ACTION_FORBIDDEN.
    C_Timer.After(0, function()
        if not cleuEnabled then return end  -- guard against Disable() before timer fires
        eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        Log.Info(MODULE_NAME, format("CLEU registered — %d tokens dispatched via lookup table", #SPELL_TOKENS + 6))
    end)
    Log.Debug(MODULE_NAME, "Enabled — CLEU registration deferred to clean context")
end

function capture.Disable()
    cleuEnabled = false
    eventFrame:UnregisterAllEvents()
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
