-- VoxSniffer VendorCapture
-- Full vendor inventory snapshot on MERCHANT_SHOW
-- Borrows cost extraction from Datamine + hook pattern from Journalator

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint
local EB = NS.EventBus

local MODULE_NAME = C.MODULE.VENDOR_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")
local moduleEnabled = false

-- ============================================================
-- Vendor data extraction
-- ============================================================

local function CaptureVendorInventory(snapshotGuid)
    -- Identify the NPC
    local npcGuid = snapshotGuid or UnitGUID("npc")
    if not npcGuid then return end

    -- If a snapshot was provided, verify the same NPC is still present
    if snapshotGuid then
        local currentGuid = UnitGUID("npc")
        if currentGuid ~= snapshotGuid then return end
    end

    local entityKey = GU.EntityKey(npcGuid)
    local npcId = GU.GetNpcId(npcGuid)
    local npcName = GU.SafeString(UnitName("npc"))

    -- Get item count
    local numItems = GetMerchantNumItems and GetMerchantNumItems() or 0
    if numItems == 0 then return end

    -- Get NPC position
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    -- Capture each item
    local items = {}
    for i = 1, numItems do
        local item = nil

        -- Try modern API first
        if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
            local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
            if ok and info then
                item = {
                    slot = i,
                    name = info.name,
                    price = info.price,
                    stackCount = info.stackCount,
                    numAvailable = info.numAvailable,
                    isPurchasable = info.isPurchasable,
                    isUsable = info.isUsable,
                    hasExtendedCost = info.hasExtendedCost,
                    currencyID = info.currencyID,
                    isQuestItem = info.isQuestStartItem,
                }
            end
        end

        -- Fallback to classic API
        if not item and GetMerchantItemInfo then
            local ok, name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost = pcall(GetMerchantItemInfo, i)
            if ok and name then
                item = {
                    slot = i,
                    name = name,
                    price = price,
                    stackCount = stackCount,
                    numAvailable = numAvailable,
                    isPurchasable = isPurchasable,
                    isUsable = isUsable,
                    hasExtendedCost = hasExtendedCost,
                }
            end
        end

        if item then
            -- Get item link for item ID
            if GetMerchantItemLink then
                local ok, link = pcall(GetMerchantItemLink, i)
                if ok and link then
                    item.itemLink = link
                    local itemId = link:match("item:(%d+)")
                    item.itemId = tonumber(itemId)
                end
            end

            -- Get extended cost details (currency costs)
            if item.hasExtendedCost and GetMerchantItemCostInfo then
                local ok, numCosts = pcall(GetMerchantItemCostInfo, i)
                if ok and numCosts and numCosts > 0 then
                    item.costs = {}
                    for j = 1, numCosts do
                        local cOk, cTexture, cCount, cLink, cCurrencyName = pcall(GetMerchantItemCostItem, i, j)
                        if cOk then
                            local costEntry = {
                                count = cCount,
                                name = cCurrencyName,
                            }
                            if cLink then
                                local costItemId = cLink:match("item:(%d+)")
                                costEntry.itemId = tonumber(costItemId)
                                local currId = cLink:match("currency:(%d+)")
                                costEntry.currencyId = tonumber(currId)
                            end
                            item.costs[j] = costEntry
                        end
                    end
                end
            end

            items[#items + 1] = item
        end
    end

    if #items == 0 then return end

    -- Build a content-aware fingerprint from item IDs, prices, and costs
    local fpParts = {}
    for _, itm in ipairs(items) do
        fpParts[#fpParts + 1] = format("%s:%s:%s",
            tostring(itm.itemId or itm.name or itm.slot),
            tostring(itm.price or 0),
            tostring(itm.stackCount or 1))
    end
    table.sort(fpParts)
    local vendorFP = FP.Compute({ npc = npcId or 0, items = table.concat(fpParts, ",") })
    local cache = VoxSnifferDB and VoxSnifferDB.local_cache and VoxSnifferDB.local_cache.seen_vendors
    if cache and cache[npcId or 0] == vendorFP then
        Log.Debug(MODULE_NAME, format("Vendor %s unchanged, skipping", npcName or "?"))
        return
    end

    local payload = {
        npcId = npcId,
        npcName = npcName,
        npcGuid = npcGuid,
        itemCount = #items,
        items = items,
        mapId = mapId,
        position = pos,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.VENDOR_SNAPSHOT, entityKey, payload, {
        source_module = MODULE_NAME,
        fingerprint = vendorFP,
    })
    if not envelope then return end

    if cache then
        cache[npcId or 0] = vendorFP
    end
    buffer:Push(envelope)
    Log.Info(MODULE_NAME, format("Captured vendor: %s (%d items)", npcName or "?", #items))
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "MERCHANT_SHOW" then
        local npcGuid = UnitGUID("npc")
        C_Timer.After(0.2, function()
            if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureVendorInventory(npcGuid) end
        end)

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.Merchant then
            local npcGuid = UnitGUID("npc")
            C_Timer.After(0.2, function()
                if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureVendorInventory(npcGuid) end
            end)
        end
    end
end)

-- ============================================================
-- Module interface
-- ============================================================

function capture.ResetState()
    -- Persistent dedup cache lives in VoxSnifferDB.local_cache.seen_vendors
end

function capture.Enable()
    moduleEnabled = true
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    -- Modern 12.x interaction event
    pcall(function() eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW") end)

    Log.Debug(MODULE_NAME, "Enabled — captures vendor inventory on interaction")
end

function capture.Disable()
    moduleEnabled = false
    eventFrame:UnregisterAllEvents()
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
