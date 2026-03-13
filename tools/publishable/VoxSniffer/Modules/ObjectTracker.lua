-- VoxSniffer ObjectTracker
-- Discovers GameObjects via mouseover and tooltip scanning
-- Captures chests, herbs, mining nodes, doors, levers, quest objects
-- Uses UPDATE_MOUSEOVER_UNIT + GameTooltip scanning for GO identification

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint
local EB = NS.EventBus

local MODULE_NAME = C.MODULE.OBJECT_TRACKER
local tracker = {}
NS.RegisterModule(MODULE_NAME, tracker)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")

-- Dedup recently seen objects
local seenObjects = {}  -- [entityKey] = GetTime()
local DEDUP_AGE = 30    -- seconds before re-recording

-- ============================================================
-- GameObject detection
-- ============================================================

local function OnMouseoverChanged()
    local guid = UnitGUID("mouseover")
    if not guid then return end

    -- Only track GameObjects
    local guidType = guid:match("^(%a+)-")
    if guidType ~= "GameObject" then return end

    local entityKey = GU.EntityKey(guid)
    if not entityKey then return end

    -- Dedup check (don't mark until record confirmed)
    local now = GetTime()
    if seenObjects[entityKey] and (now - seenObjects[entityKey]) < DEDUP_AGE then
        return
    end

    local goEntry = GU.GetGameObjectEntry(guid)
    local name = GU.SafeString(UnitName("mouseover"))

    -- Get position
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    -- Try to get tooltip info (GameObjects don't support C_TooltipInfo.GetUnit,
    -- so we read from the GameTooltip frame which auto-populates on mouseover)
    local tooltipData = nil
    if GameTooltip and GameTooltip:IsShown() then
        tooltipData = {}
        for i = 1, GameTooltip:NumLines() do
            local leftLine = _G["GameTooltipTextLeft" .. i]
            if leftLine then
                local text = leftLine:GetText()
                if text and text ~= "" then
                    local r, g, b = leftLine:GetTextColor()
                    tooltipData[#tooltipData + 1] = {
                        text = text,
                        color = { r = r, g = g, b = b },
                    }
                end
            end
        end
        if #tooltipData == 0 then tooltipData = nil end
    end

    local payload = {
        goEntry = goEntry,
        name = name,
        guid = guid,
        mapId = mapId,
        position = pos,
        tooltipLines = tooltipData,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.OBJECT_SEEN, entityKey, payload, {
        source_module = MODULE_NAME,
        fingerprint = FP.Compute({ go = goEntry or 0, name = name or "" }),
    })
    if not envelope then return end

    seenObjects[entityKey] = now
    buffer:Push(envelope)
    Log.Debug(MODULE_NAME, format("GameObject: %s [%s] entry=%s",
        name or "?", entityKey, tostring(goEntry)))
end

-- ============================================================
-- Vignette scanning (SilverDragon pattern)
-- Detects special objects/rares via the minimap vignette system
-- ============================================================

local seenVignettes = {}  -- [vignetteGUID] = true

local function ScanVignettes()
    if not C_VignetteInfo or not C_VignetteInfo.GetVignettes then return end

    local ok, vignettes = pcall(C_VignetteInfo.GetVignettes)
    if not ok or not vignettes then return end

    for _, vignetteGUID in ipairs(vignettes) do
        if not seenVignettes[vignetteGUID] then
            local vInfo = C_VignetteInfo.GetVignetteInfo(vignetteGUID)
            if vInfo then
                -- Get position
                local mapId = C_Map.GetBestMapForUnit("player")
                local pos = nil
                if mapId then
                    local p = C_Map.GetPlayerMapPosition(mapId, "player")
                    if p then pos = { x = p.x, y = p.y } end
                end

                -- Vignette position on map
                local vignettePos = nil
                if vInfo.vignetteGUID and C_VignetteInfo.GetVignettePosition then
                    local vp = C_VignetteInfo.GetVignettePosition(vignetteGUID, mapId)
                    if vp then vignettePos = { x = vp.x, y = vp.y } end
                end

                local payload = {
                    vignetteGUID = vignetteGUID,
                    name = vInfo.name,
                    vignetteID = vInfo.vignetteID,
                    objectGUID = vInfo.objectGUID,
                    type = vInfo.type,  -- 0=normal, 1=PvPBounty, 2=Torghast, 3=Vignette, 4=TreasureStar, 5=Stacking
                    isDead = vInfo.isDead,
                    onWorldMap = vInfo.onWorldMap,
                    onMinimap = vInfo.onMinimap,
                    isUnique = vInfo.isUnique,
                    inFogOfWar = vInfo.inFogOfWar,
                    atlasName = vInfo.atlasName,
                    hasTooltip = vInfo.hasTooltip,
                    mapId = mapId,
                    playerPosition = pos,
                    vignettePosition = vignettePos,
                }

                -- If vignette has an objectGUID, parse it
                if vInfo.objectGUID then
                    local objEntityKey = GU.EntityKey(vInfo.objectGUID)
                    local npcId = GU.GetNpcId(vInfo.objectGUID)
                    local goEntry = GU.GetGameObjectEntry(vInfo.objectGUID)
                    payload.entityKey = objEntityKey
                    payload.npcId = npcId
                    payload.goEntry = goEntry
                end

                local entityKey = payload.entityKey or ("VIG:" .. (vInfo.vignetteID or vignetteGUID))

                local envelope = NS.MakeEnvelope(C.OBS_TYPE.OBJECT_SEEN, entityKey, payload, {
                    source_module = MODULE_NAME,
                    fingerprint = FP.Compute({ vig = vInfo.vignetteID or 0, name = vInfo.name or "" }),
                })
                if envelope then
                    seenVignettes[vignetteGUID] = true
                    buffer:Push(envelope)
                    Log.Debug(MODULE_NAME, format("Vignette: %s (type %d) %s",
                        vInfo.name or "?", vInfo.type or -1, vInfo.isDead and "[DEAD]" or ""))
                end
            end
        end
    end
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        OnMouseoverChanged()
    elseif event == "VIGNETTE_MINIMAP_UPDATED" or event == "VIGNETTES_UPDATED" then
        ScanVignettes()
    end
end)

-- Periodic dedup sweep + vignette check
local function OnTick()
    if not NS.IsCaptureActive() then return end

    -- Sweep stale dedup entries
    local cutoff = GetTime() - DEDUP_AGE
    for k, t in pairs(seenObjects) do
        if t < cutoff then seenObjects[k] = nil end
    end

    -- Periodic vignette scan
    ScanVignettes()
end

-- ============================================================
-- Module interface
-- ============================================================

function tracker.ResetState()
    wipe(seenObjects)
    wipe(seenVignettes)
end

function tracker.Enable()
    eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    pcall(function() eventFrame:RegisterEvent("VIGNETTE_MINIMAP_UPDATED") end)
    pcall(function() eventFrame:RegisterEvent("VIGNETTES_UPDATED") end)

    NS.Scheduler.Register(MODULE_NAME, OnTick, 5)  -- 5s sweep cycle
    Log.Debug(MODULE_NAME, "Enabled — tracking GameObjects + vignettes")
end

function tracker.Disable()
    eventFrame:UnregisterAllEvents()
    NS.Scheduler.Unregister(MODULE_NAME)
    Log.Info(MODULE_NAME, "Disabled")
end

function tracker.GetStats()
    local stats = buffer:GetStats()
    stats.trackedObjects = 0
    for _ in pairs(seenObjects) do stats.trackedObjects = stats.trackedObjects + 1 end
    stats.seenVignettes = 0
    for _ in pairs(seenVignettes) do stats.seenVignettes = stats.seenVignettes + 1 end
    return stats
end
