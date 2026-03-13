-- VoxSniffer UnitScanner
-- Passive unit discovery via nameplates, target, mouseover, soft-target, focus
-- Borrows 8-event pattern from Datamine + nameplate tracking from CreatureCodex

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint
local Sched = NS.Scheduler
local EB = NS.EventBus

local MODULE_NAME = C.MODULE.UNIT_SCANNER
local scanner = {}
NS.RegisterModule(MODULE_NAME, scanner)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- Dedup: don't re-record the same unit within this interval
local seenUnits = {}        -- [entityKey] = GetTime()
local DEDUP_AGE = 10        -- seconds before re-scanning same entity
local sweepTimer = 0

-- Active nameplate tracking (event-driven, not polled)
local activeNameplates = {} -- [unitToken] = true

-- All unit tokens to scan on each tick
local EXPLICIT_UNITS = { "target", "focus", "mouseover", "softenemy", "softfriend", "softinteract" }
local BOSS_UNITS = {}
for i = 1, 8 do BOSS_UNITS[#BOSS_UNITS + 1] = "boss" .. i end
local GROUP_TARGETS = {}
for i = 1, 4 do GROUP_TARGETS[#GROUP_TARGETS + 1] = "party" .. i .. "target" end
for i = 1, 40 do GROUP_TARGETS[#GROUP_TARGETS + 1] = "raid" .. i .. "target" end

-- ============================================================
-- Unit data extraction
-- ============================================================

local function ExtractUnitData(unit)
    if not UnitExists(unit) then return nil end
    if UnitIsPlayer(unit) then return nil end

    local guid = UnitGUID(unit)
    if not guid then return nil end

    local entityKey = GU.EntityKey(guid)
    if not entityKey then return nil end

    -- Dedup check (don't mark seen yet — that happens after successful envelope creation)
    local now = GetTime()
    if seenUnits[entityKey] and (now - seenUnits[entityKey]) < DEDUP_AGE then
        return nil
    end

    local name = GU.SafeString(UnitName(unit))
    local level = GU.SafeNumber(UnitLevel(unit))
    local classification = UnitClassification(unit) or "normal"
    local creatureType = UnitCreatureType(unit)
    local reaction = UnitReaction(unit, "player")
    local isFriend = UnitIsFriend(unit, "player")
    local health = GU.SafeNumber(UnitHealth(unit))
    local maxHealth = GU.SafeNumber(UnitHealthMax(unit))
    local power = GU.SafeNumber(UnitPower(unit))
    local maxPower = GU.SafeNumber(UnitPowerMax(unit))
    local powerType = GU.SafeNumber(UnitPowerType(unit))
    local sex = GU.SafeNumber(UnitSex(unit))
    local isDead = UnitIsDead(unit)

    -- Cast info
    local castName, _, _, _, _, _, castSpellID = nil, nil, nil, nil, nil, nil, nil
    local ok, cn, _, _, _, _, _, csid = pcall(UnitCastingInfo, unit)
    if ok then castName, castSpellID = cn, csid end

    local chanName, chanSpellID = nil, nil
    ok, cn, _, _, _, _, _, _, csid = pcall(UnitChannelInfo, unit)
    if ok then chanName, chanSpellID = cn, csid end

    -- NPC ID from GUID
    local npcId = GU.GetNpcId(guid)
    local goEntry = GU.GetGameObjectEntry(guid)

    local payload = {
        name = name,
        npcId = npcId,
        goEntry = goEntry,
        level = level,
        classification = classification,
        creatureType = creatureType,
        reaction = reaction,
        isFriend = isFriend,
        health = health,
        maxHealth = maxHealth,
        healthPct = health and maxHealth and maxHealth > 0 and math.floor(health / maxHealth * 100) or nil,
        power = power,
        maxPower = maxPower,
        powerType = powerType,
        sex = sex,
        isDead = isDead,
        castSpellID = GU.SafeNumber(castSpellID),
        castName = GU.SafeString(castName),
        chanSpellID = GU.SafeNumber(chanSpellID),
        chanName = GU.SafeString(chanName),
        guid = guid,
    }

    return entityKey, payload
end

local function RecordUnit(unit, source)
    local entityKey, payload = ExtractUnitData(unit)
    if not entityKey then return end

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.UNIT_SEEN, entityKey, payload, {
        source_module = MODULE_NAME,
        fingerprint = FP.Unit(entityKey, payload.name, payload.level, payload.classification),
    })
    if not envelope then return end
    envelope.unit_source = source

    buffer:Push(envelope)
    seenUnits[entityKey] = GetTime()
    EB.Publish("UNIT_OBSERVED", envelope)
    Log.Verbose(MODULE_NAME, format("Unit: %s [%s] %s", payload.name or "?", entityKey, source))
end

-- ============================================================
-- Event handlers (8-event passive capture from Datamine pattern)
-- ============================================================

local eventFrame = CreateFrame("Frame")

local function OnTargetChanged()
    RecordUnit("target", "target")
end

local function OnMouseover()
    RecordUnit("mouseover", "mouseover")
end

local function OnSoftEnemyChanged()
    RecordUnit("softenemy", "softenemy")
end

local function OnSoftFriendChanged()
    RecordUnit("softfriend", "softfriend")
end

local function OnSoftInteractChanged()
    RecordUnit("softinteract", "softinteract")
end

local function OnNameplateAdded(_, unit)
    if unit then
        activeNameplates[unit] = true
        RecordUnit(unit, "nameplate")
    end
end

local function OnNameplateRemoved(_, unit)
    if unit then
        activeNameplates[unit] = nil
    end
end

local function OnForbiddenNameplateAdded(_, unit)
    -- Can't read full data from forbidden nameplates but record what we can
    if unit then
        RecordUnit(unit, "forbidden_nameplate")
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_TARGET_CHANGED" then OnTargetChanged()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then OnMouseover()
    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then OnSoftEnemyChanged()
    elseif event == "PLAYER_SOFT_FRIEND_CHANGED" then OnSoftFriendChanged()
    elseif event == "PLAYER_SOFT_INTERACT_CHANGED" then OnSoftInteractChanged()
    elseif event == "NAME_PLATE_UNIT_ADDED" then OnNameplateAdded(nil, ...)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then OnNameplateRemoved(nil, ...)
    elseif event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then OnForbiddenNameplateAdded(nil, ...)
    end
end)

-- ============================================================
-- Periodic scan tick — catch boss units, group targets, focus
-- ============================================================

local function OnTick()
    if not NS.IsCaptureActive() then return end

    -- Explicit units
    for _, unit in ipairs(EXPLICIT_UNITS) do
        if UnitExists(unit) then
            RecordUnit(unit, "tick_" .. unit)
        end
    end

    -- Boss units
    for _, unit in ipairs(BOSS_UNITS) do
        if UnitExists(unit) then
            RecordUnit(unit, "tick_boss")
        end
    end

    -- Group targets (passive data from party/raid)
    for _, unit in ipairs(GROUP_TARGETS) do
        if UnitExists(unit) then
            RecordUnit(unit, "tick_group_target")
        end
    end

    -- Dedup sweep
    sweepTimer = sweepTimer + NS.Config.GetTickRate(MODULE_NAME)
    if sweepTimer >= 30 then
        sweepTimer = 0
        local cutoff = GetTime() - DEDUP_AGE
        for k, t in pairs(seenUnits) do
            if t < cutoff then seenUnits[k] = nil end
        end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function scanner.ResetState()
    wipe(seenUnits)
    wipe(activeNameplates)
    sweepTimer = 0

    -- Re-enumerate currently visible nameplates so we don't miss units
    -- already on screen when a session starts mid-gameplay
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local plates = C_NamePlate.GetNamePlates()
        if plates then
            for _, plate in ipairs(plates) do
                local unit = plate and plate.namePlateUnitToken
                if unit then
                    activeNameplates[unit] = true
                end
            end
        end
    end
end

function scanner.Enable()
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    -- Soft-target events (12.x)
    pcall(function() eventFrame:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED") end)
    pcall(function() eventFrame:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED") end)
    pcall(function() eventFrame:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED") end)
    pcall(function() eventFrame:RegisterEvent("FORBIDDEN_NAME_PLATE_UNIT_ADDED") end)

    Sched.Register(MODULE_NAME, OnTick, NS.Config.GetTickRate(MODULE_NAME))
    Log.Debug(MODULE_NAME, "Enabled — 8-event passive capture + periodic scan")
end

function scanner.Disable()
    eventFrame:UnregisterAllEvents()
    Sched.Unregister(MODULE_NAME)
    Log.Info(MODULE_NAME, "Disabled")
end

function scanner.GetStats()
    local stats = buffer:GetStats()
    stats.activeNameplates = 0
    for _ in pairs(activeNameplates) do stats.activeNameplates = stats.activeNameplates + 1 end
    stats.trackedEntities = 0
    for _ in pairs(seenUnits) do stats.trackedEntities = stats.trackedEntities + 1 end
    return stats
end
