-- VoxSniffer AuraScanner
-- Periodic scan of auras (buffs/debuffs) on visible NPC units
-- Supplements CombatCapture with full aura snapshots (stacks, duration, source)
-- Borrows nameplate iteration from CreatureCodex's 5Hz aura scraper

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint
local Sched = NS.Scheduler

local MODULE_NAME = C.MODULE.AURA_SCANNER
local scanner = {}
NS.RegisterModule(MODULE_NAME, scanner)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- Track seen aura combos to avoid re-recording identical snapshots
local seenAuras = {}  -- [entityKey.."|"..spellId] = GetTime()
local DEDUP_AGE = 15  -- seconds before re-recording same aura on same unit

-- Units to scan each tick
local SCAN_UNITS = { "target", "focus", "mouseover", "softenemy" }
local BOSS_UNITS = {}
for i = 1, 8 do BOSS_UNITS[#BOSS_UNITS + 1] = "boss" .. i end

-- Active nameplates (maintained by UnitScanner events, but we track our own copy)
local activeNameplates = {}

local eventFrame = CreateFrame("Frame")

-- ============================================================
-- Aura extraction
-- ============================================================

local function ScanUnitAuras(unit, source)
    if not UnitExists(unit) then return end
    if UnitIsPlayer(unit) then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    local entityKey = GU.EntityKey(guid)
    if not entityKey then return end

    local npcId = GU.GetNpcId(guid)
    local unitName = GU.SafeString(UnitName(unit))
    local now = GetTime()

    -- Modern API: C_UnitAuras.GetAuraDataByIndex
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 80 do  -- cap at 80 to avoid infinite loop
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, i)
            if not aura then break end

            local dedupKey = entityKey .. "|" .. (aura.spellId or 0)
            if not seenAuras[dedupKey] or (now - seenAuras[dedupKey]) >= DEDUP_AGE then
                local payload = {
                    spellId = aura.spellId,
                    name = aura.name,
                    stacks = aura.applications or 0,
                    duration = aura.duration,
                    expirationTime = aura.expirationTime,
                    isHelpful = aura.isHelpful,
                    isHarmful = aura.isHarmful,
                    sourceUnit = aura.sourceUnit,
                    canApplyAura = aura.canApplyAura,
                    isBossAura = aura.isBossAura,
                    isFromPlayerOrPlayerPet = aura.isFromPlayerOrPlayerPet,
                    npcId = npcId,
                    unitName = unitName,
                    scanSource = source,
                }

                local envelope = NS.MakeEnvelope(C.OBS_TYPE.AURA_SEEN, entityKey, payload, {
                    source_module = MODULE_NAME,
                })
                if not envelope then return end

                seenAuras[dedupKey] = now
                buffer:Push(envelope)
                Log.Verbose(MODULE_NAME, format("Aura: %s on %s [%s] (%s)",
                    aura.name or "?", unitName or "?", entityKey, source))
            end
        end
        return
    end

    -- Fallback: UnitAura (deprecated but works on older clients)
    if UnitAura then
        for i = 1, 40 do
            local name, icon, count, dispelType, duration, expirationTime, source_unit,
                  isStealable, nameplateShowPersonal, spellId = UnitAura(unit, i, "HELPFUL")
            if not name then break end

            local dedupKey = entityKey .. "|" .. (spellId or 0)
            if not seenAuras[dedupKey] or (now - seenAuras[dedupKey]) >= DEDUP_AGE then
                local payload = {
                    spellId = spellId,
                    name = name,
                    stacks = count or 0,
                    duration = duration,
                    expirationTime = expirationTime,
                    isHelpful = true,
                    dispelType = dispelType,
                    sourceUnit = source_unit,
                    npcId = npcId,
                    unitName = unitName,
                    scanSource = source,
                }
                local envelope = NS.MakeEnvelope(C.OBS_TYPE.AURA_SEEN, entityKey, payload, {
                    source_module = MODULE_NAME,
                })
                if envelope then
                    seenAuras[dedupKey] = now
                    buffer:Push(envelope)
                end
            end
        end

        for i = 1, 40 do
            local name, icon, count, dispelType, duration, expirationTime, source_unit,
                  isStealable, nameplateShowPersonal, spellId = UnitAura(unit, i, "HARMFUL")
            if not name then break end

            local dedupKey = entityKey .. "|" .. (spellId or 0)
            if not seenAuras[dedupKey] or (now - seenAuras[dedupKey]) >= DEDUP_AGE then
                local payload = {
                    spellId = spellId,
                    name = name,
                    stacks = count or 0,
                    duration = duration,
                    expirationTime = expirationTime,
                    isHarmful = true,
                    dispelType = dispelType,
                    sourceUnit = source_unit,
                    npcId = npcId,
                    unitName = unitName,
                    scanSource = source,
                }
                local envelope = NS.MakeEnvelope(C.OBS_TYPE.AURA_SEEN, entityKey, payload, {
                    source_module = MODULE_NAME,
                })
                if envelope then
                    seenAuras[dedupKey] = now
                    buffer:Push(envelope)
                end
            end
        end
    end
end

-- ============================================================
-- Tick handler
-- ============================================================

local sweepTimer = 0

local function OnTick()
    if not NS.IsCaptureActive() then return end

    -- Scan explicit units
    for _, unit in ipairs(SCAN_UNITS) do
        if UnitExists(unit) then
            ScanUnitAuras(unit, "tick_" .. unit)
        end
    end

    -- Scan boss units
    for _, unit in ipairs(BOSS_UNITS) do
        if UnitExists(unit) then
            ScanUnitAuras(unit, "tick_boss")
        end
    end

    -- Scan active nameplates
    for unit in pairs(activeNameplates) do
        if UnitExists(unit) then
            ScanUnitAuras(unit, "nameplate")
        end
    end

    -- Periodic dedup sweep
    sweepTimer = sweepTimer + NS.Config.GetTickRate(MODULE_NAME)
    if sweepTimer >= 30 then
        sweepTimer = 0
        local cutoff = GetTime() - DEDUP_AGE
        for k, t in pairs(seenAuras) do
            if t < cutoff then seenAuras[k] = nil end
        end
    end
end

-- ============================================================
-- Nameplate tracking events
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

function scanner.ResetState()
    wipe(seenAuras)
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
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    Sched.Register(MODULE_NAME, OnTick, NS.Config.GetTickRate(MODULE_NAME))
    Log.Debug(MODULE_NAME, "Enabled — scanning auras on NPCs at 1Hz")
end

function scanner.Disable()
    eventFrame:UnregisterAllEvents()
    Sched.Unregister(MODULE_NAME)
    Log.Info(MODULE_NAME, "Disabled")
end

function scanner.GetStats()
    local stats = buffer:GetStats()
    stats.trackedAuras = 0
    for _ in pairs(seenAuras) do stats.trackedAuras = stats.trackedAuras + 1 end
    stats.activeNameplates = 0
    for _ in pairs(activeNameplates) do stats.activeNameplates = stats.activeNameplates + 1 end
    return stats
end
