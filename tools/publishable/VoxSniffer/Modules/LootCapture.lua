-- VoxSniffer LootCapture
-- Captures loot window contents when looting mobs/containers/pickpocket
-- Uses LOOT_READY + GetLootSlotInfo/GetLootSlotLink for item data
-- Borrows loot source tracking from Journalator's vendor/loot hooks

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.LOOT_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")
local moduleEnabled = false

-- ============================================================
-- Loot data extraction
-- ============================================================

local function CaptureLootWindow(snapshotTargetGuid, snapshotTargetName)
    local numItems = GetNumLootItems and GetNumLootItems() or 0
    if numItems == 0 then return end

    -- Identify loot source
    local sourceGUIDs = {}
    local primarySource = nil

    for i = 1, numItems do
        if GetLootSourceInfo then
            local ok, sources = pcall(GetLootSourceInfo, i)
            if ok and sources then
                -- GetLootSourceInfo returns guid1, count1, guid2, count2, ...
                -- In modern API it may return a table
                if type(sources) == "string" then
                    -- Classic-style: returns GUID directly
                    sourceGUIDs[sources] = true
                    if not primarySource then primarySource = sources end
                end
            end
        end
    end

    -- Fallback: use snapshotted target from event time, then live target
    if not primarySource then
        if snapshotTargetGuid then
            primarySource = snapshotTargetGuid
        else
            local targetGuid = UnitGUID("target")
            if targetGuid and UnitIsDead("target") then
                primarySource = targetGuid
            end
        end
    end

    local entityKey = nil
    local npcId = nil
    if primarySource then
        entityKey = GU.EntityKey(primarySource)
        npcId = GU.GetNpcId(primarySource)
    end

    -- Get player position
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    -- Capture each loot slot
    local items = {}
    for i = 1, numItems do
        local slotData = nil

        -- Try modern API
        if C_LootInfo and C_LootInfo.GetLootSlot then
            local ok, info = pcall(C_LootInfo.GetLootSlot, i)
            if ok and info then
                slotData = {
                    slot = i,
                    name = info.item,
                    icon = info.icon,
                    quantity = info.quantity,
                    quality = info.quality,
                    locked = info.locked,
                    isQuestItem = info.isQuestItem,
                    questID = info.questID,
                    isActive = info.isActive,
                }
            end
        end

        -- Fallback to classic API
        if not slotData and GetLootSlotInfo then
            local ok, icon, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive = pcall(GetLootSlotInfo, i)
            if ok and name then
                slotData = {
                    slot = i,
                    name = name,
                    icon = icon,
                    quantity = quantity,
                    quality = quality,
                    locked = locked,
                    isQuestItem = isQuestItem,
                    questID = questID,
                    isActive = isActive,
                    currencyID = currencyID,
                }
            end
        end

        if slotData then
            -- Get item link for ID extraction
            if GetLootSlotLink then
                local ok, link = pcall(GetLootSlotLink, i)
                if ok and link then
                    slotData.itemLink = link
                    local itemId = link:match("item:(%d+)")
                    slotData.itemId = tonumber(itemId)
                end
            end

            -- Get loot slot type
            if GetLootSlotType then
                local ok, slotType = pcall(GetLootSlotType, i)
                if ok then slotData.slotType = slotType end
            end

            items[#items + 1] = slotData
        end
    end

    if #items == 0 then return end

    local payload = {
        sourceGUID = primarySource,
        npcId = npcId,
        sourceName = primarySource and (snapshotTargetName or GU.SafeString(UnitName("target"))) or nil,
        itemCount = #items,
        items = items,
        mapId = mapId,
        position = pos,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.LOOT_EVENT, entityKey or "UNKNOWN", payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    buffer:Push(envelope)
    Log.Info(MODULE_NAME, format("Captured loot: %d items from %s",
        #items, payload.sourceName or (npcId and ("NPC:" .. npcId) or "unknown")))
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        local targetGuid = UnitGUID("target")
        local targetName = UnitExists("target") and UnitName("target") or nil
        C_Timer.After(0.1, function()
            if moduleEnabled and NS.IsCaptureActive() then CaptureLootWindow(targetGuid, targetName) end
        end)
    end
end)

-- ============================================================
-- Module interface
-- ============================================================

function capture.ResetState()
    -- No module-local dedup state
end

function capture.Enable()
    moduleEnabled = true
    -- LOOT_READY is the modern event (fires when loot window is ready)
    pcall(function() eventFrame:RegisterEvent("LOOT_READY") end)
    -- LOOT_OPENED is the classic fallback
    eventFrame:RegisterEvent("LOOT_OPENED")

    Log.Debug(MODULE_NAME, "Enabled — captures loot window contents")
end

function capture.Disable()
    moduleEnabled = false
    eventFrame:UnregisterAllEvents()
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
