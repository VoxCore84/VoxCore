-- VoxSniffer GossipCapture
-- Full gossip menu snapshot on GOSSIP_SHOW
-- Captures options, available quests, active quests, NPC text
-- Borrows interaction hook pattern from Journalator

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.GOSSIP_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")
local moduleEnabled = false

-- ============================================================
-- Gossip data extraction
-- ============================================================

local function CaptureGossipMenu(snapshotGuid)
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

    -- Get gossip text (NPC speech bubble text)
    local gossipText = nil
    if C_GossipInfo and C_GossipInfo.GetText then
        local ok, text = pcall(C_GossipInfo.GetText)
        if ok then gossipText = text end
    end

    -- Get gossip options
    local options = {}
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local ok, optionList = pcall(C_GossipInfo.GetOptions)
        if ok and optionList then
            for i, opt in ipairs(optionList) do
                options[i] = {
                    gossipOptionID = opt.gossipOptionID,
                    name = opt.name,
                    icon = opt.icon,
                    status = opt.status,
                    spellID = opt.spellID,
                    overrideIconID = opt.overrideIconID,
                    selectOptionWhenOnlyOption = opt.selectOptionWhenOnlyOption,
                    orderIndex = opt.orderIndex,
                    flags = opt.flags,
                }
            end
        end
    end

    -- Get available quests from this NPC
    local availableQuests = {}
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local ok, questList = pcall(C_GossipInfo.GetAvailableQuests)
        if ok and questList then
            for i, q in ipairs(questList) do
                availableQuests[i] = {
                    questID = q.questID,
                    title = q.title,
                    questLevel = q.questLevel,
                    isTrivial = q.isTrivial,
                    frequency = q.frequency,
                    repeatable = q.repeatable,
                    isComplete = q.isComplete,
                    isLegendary = q.isLegendary,
                    isIgnored = q.isIgnored,
                    isImportant = q.isImportant,
                }
            end
        end
    end

    -- Get active quests (in-progress, completable)
    local activeQuests = {}
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        local ok, questList = pcall(C_GossipInfo.GetActiveQuests)
        if ok and questList then
            for i, q in ipairs(questList) do
                activeQuests[i] = {
                    questID = q.questID,
                    title = q.title,
                    questLevel = q.questLevel,
                    isTrivial = q.isTrivial,
                    isComplete = q.isComplete,
                    isLegendary = q.isLegendary,
                    isIgnored = q.isIgnored,
                    isImportant = q.isImportant,
                }
            end
        end
    end

    -- Get NPC position
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    -- Skip if completely empty (NPC with no gossip content)
    if not gossipText and #options == 0 and #availableQuests == 0 and #activeQuests == 0 then
        return
    end

    -- Fingerprint for dedup — include option text/IDs, not just counts
    local optionSigs = {}
    for _, opt in ipairs(options) do
        optionSigs[#optionSigs + 1] = tostring(opt.gossipOptionID or opt.name or "")
    end
    local questSigs = {}
    for _, q in ipairs(availableQuests) do
        questSigs[#questSigs + 1] = tostring(q.questID or q.title or "")
    end
    local fpData = {
        npc = npcId or 0,
        opts = table.concat(optionSigs, ","),
        avail = table.concat(questSigs, ","),
        active = #activeQuests,
        text = gossipText and gossipText:sub(1, 80) or "",
    }
    local gossipFP = FP.Compute(fpData)

    -- Dedup against local cache
    local cache = VoxSnifferDB and VoxSnifferDB.local_cache and VoxSnifferDB.local_cache.seen_gossip
    if not cache and VoxSnifferDB and VoxSnifferDB.local_cache then
        VoxSnifferDB.local_cache.seen_gossip = {}
        cache = VoxSnifferDB.local_cache.seen_gossip
    end
    if cache and cache[npcId or 0] == gossipFP then
        Log.Debug(MODULE_NAME, format("Gossip for %s unchanged, skipping", npcName or "?"))
        return
    end

    local payload = {
        npcId = npcId,
        npcName = npcName,
        npcGuid = npcGuid,
        gossipText = gossipText,
        options = #options > 0 and options or nil,
        availableQuests = #availableQuests > 0 and availableQuests or nil,
        activeQuests = #activeQuests > 0 and activeQuests or nil,
        optionCount = #options,
        availableQuestCount = #availableQuests,
        activeQuestCount = #activeQuests,
        mapId = mapId,
        position = pos,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.GOSSIP_SNAPSHOT, entityKey, payload, {
        source_module = MODULE_NAME,
        fingerprint = gossipFP,
    })
    if not envelope then return end

    if cache then
        cache[npcId or 0] = gossipFP
    end
    buffer:Push(envelope)
    Log.Info(MODULE_NAME, format("Captured gossip: %s (%d opts, %d avail, %d active)",
        npcName or "?", #options, #availableQuests, #activeQuests))
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "GOSSIP_SHOW" then
        local npcGuid = UnitGUID("npc")
        C_Timer.After(0.1, function()
            if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureGossipMenu(npcGuid) end
        end)

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if interactionType == Enum.PlayerInteractionType.Gossip then
            local npcGuid = UnitGUID("npc")
            C_Timer.After(0.1, function()
                if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureGossipMenu(npcGuid) end
            end)
        end
    end
end)

-- ============================================================
-- Module interface
-- ============================================================

function capture.ResetState()
    -- Persistent dedup cache lives in VoxSnifferDB.local_cache.seen_gossip
    -- which gets wiped on full reset via Schema.CreateEmpty()
end

function capture.Enable()
    moduleEnabled = true
    eventFrame:RegisterEvent("GOSSIP_SHOW")
    -- Modern 12.x interaction event
    pcall(function() eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW") end)

    Log.Debug(MODULE_NAME, "Enabled — captures gossip menus on NPC interaction")
end

function capture.Disable()
    moduleEnabled = false
    eventFrame:UnregisterAllEvents()
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
