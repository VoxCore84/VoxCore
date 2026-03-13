-- VoxSniffer QuestCapture
-- Captures quest data when quests are offered, accepted, or turned in
-- Uses QUEST_DETAIL, QUEST_ACCEPTED, QUEST_COMPLETE, QUEST_TURNED_IN
-- Borrows quest text extraction patterns from AllTheThings

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local FP = NS.Fingerprint

local MODULE_NAME = C.MODULE.QUEST_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

local eventFrame = CreateFrame("Frame")
local moduleEnabled = false

-- Track recently captured quest IDs to avoid duplicates
local recentQuests = {}  -- [questID] = GetTime()
local DEDUP_WINDOW = 10  -- seconds

-- ============================================================
-- Quest data extraction
-- ============================================================

local function GetQuestRewards()
    local rewards = {}

    -- Item rewards (choose one)
    local numChoices = GetNumQuestChoices and GetNumQuestChoices() or 0
    if numChoices > 0 then
        rewards.choices = {}
        for i = 1, numChoices do
            local ok, name, texture, count, quality, isUsable = pcall(GetQuestItemInfo, "choice", i)
            if ok and name then
                local entry = {
                    name = name,
                    count = count,
                    quality = quality,
                }
                local lok, link = pcall(GetQuestItemLink, "choice", i)
                if lok and link then
                    entry.itemLink = link
                    entry.itemId = tonumber(link:match("item:(%d+)"))
                end
                rewards.choices[i] = entry
            end
        end
    end

    -- Fixed item rewards
    local numRewards = GetNumQuestRewards and GetNumQuestRewards() or 0
    if numRewards > 0 then
        rewards.items = {}
        for i = 1, numRewards do
            local ok, name, texture, count, quality, isUsable = pcall(GetQuestItemInfo, "reward", i)
            if ok and name then
                local entry = {
                    name = name,
                    count = count,
                    quality = quality,
                }
                local lok, link = pcall(GetQuestItemLink, "reward", i)
                if lok and link then
                    entry.itemLink = link
                    entry.itemId = tonumber(link:match("item:(%d+)"))
                end
                rewards.items[i] = entry
            end
        end
    end

    -- Currency rewards
    if GetNumRewardCurrencies then
        local numCurrencies = GetNumRewardCurrencies() or 0
        if numCurrencies > 0 then
            rewards.currencies = {}
            for i = 1, numCurrencies do
                local ok, name, texture, count, quality = pcall(GetQuestCurrencyInfo, "reward", i)
                if ok and name then
                    rewards.currencies[i] = {
                        name = name,
                        count = count,
                    }
                end
            end
        end
    end

    -- Money reward
    local money = GetRewardMoney and GetRewardMoney() or 0
    if money > 0 then
        rewards.money = money
    end

    -- XP reward
    local xp = GetRewardXP and GetRewardXP() or 0
    if xp > 0 then
        rewards.xp = xp
    end

    return rewards
end

local function GetQuestObjectives(questID)
    local objectives = {}

    if C_QuestLog and C_QuestLog.GetNumQuestObjectives then
        local ok, numObj = pcall(C_QuestLog.GetNumQuestObjectives, questID)
        if ok and numObj then
            for i = 1, numObj do
                local ook, text, objectiveType, finished, fulfilled, required = pcall(GetQuestObjectiveInfo, questID, i, false)
                if ook and text then
                    objectives[i] = {
                        text = text,
                        type = objectiveType,
                        finished = finished,
                        fulfilled = fulfilled,
                        required = required,
                    }
                end
            end
        end
    end

    return #objectives > 0 and objectives or nil
end

local function CaptureQuestDetail(trigger, snapshotQuestID, snapshotNpcGuid)
    -- Use snapshotted questID if provided, fall back to live API
    local questID = snapshotQuestID or (GetQuestID and GetQuestID() or nil)
    if not questID or questID == 0 then return end

    -- If a snapshot was provided, verify the quest frame still shows the same quest
    -- Abort if frame closed (ID=0) or showing a different quest
    if snapshotQuestID then
        local currentQuestID = GetQuestID and GetQuestID() or 0
        if currentQuestID ~= snapshotQuestID then return end
    end

    -- Dedup check (don't mark until record confirmed)
    local now = GetTime()
    if recentQuests[questID] and (now - recentQuests[questID]) < DEDUP_WINDOW then
        return
    end

    -- NPC offering the quest — use snapshot if provided
    local npcGuid = snapshotNpcGuid or UnitGUID("npc") or UnitGUID("questnpc")
    local entityKey = nil
    local npcId = nil
    local npcName = nil
    if npcGuid then
        entityKey = GU.EntityKey(npcGuid)
        npcId = GU.GetNpcId(npcGuid)
        npcName = GU.SafeString(UnitName("npc") or UnitName("questnpc"))
    end

    -- Quest text
    local title = GU.SafeString(GetTitleText and GetTitleText())
    local questText = GU.SafeString(GetQuestText and GetQuestText())
    local objectiveText = GU.SafeString(GetObjectiveText and GetObjectiveText())
    local progressText = GU.SafeString(GetProgressText and GetProgressText())
    local rewardText = GU.SafeString(GetRewardText and GetRewardText())

    -- Quest info
    local questInfo = {}
    if C_QuestLog then
        if C_QuestLog.IsQuestFlaggedCompleted then
            questInfo.isCompleted = C_QuestLog.IsQuestFlaggedCompleted(questID)
        end
        if C_QuestLog.IsLegendaryQuest then
            questInfo.isLegendary = C_QuestLog.IsLegendaryQuest(questID)
        end
    end

    -- Required items (quest requires you to bring items)
    local requiredItems = {}
    local numRequired = GetNumQuestItems and GetNumQuestItems() or 0
    for i = 1, numRequired do
        local ok, name, texture, count = pcall(GetQuestItemInfo, "required", i)
        if ok and name then
            local entry = { name = name, count = count }
            local lok, link = pcall(GetQuestItemLink, "required", i)
            if lok and link then
                entry.itemLink = link
                entry.itemId = tonumber(link:match("item:(%d+)"))
            end
            requiredItems[i] = entry
        end
    end

    -- Rewards
    local rewards = GetQuestRewards()

    -- Position
    local mapId = C_Map.GetBestMapForUnit("player")
    local pos = nil
    if mapId then
        local p = C_Map.GetPlayerMapPosition(mapId, "player")
        if p then pos = { x = p.x, y = p.y } end
    end

    local payload = {
        questID = questID,
        title = title,
        questText = questText,
        objectiveText = objectiveText,
        progressText = (trigger == "QUEST_COMPLETE") and progressText or nil,
        rewardText = (trigger == "QUEST_COMPLETE" or trigger == "QUEST_TURNED_IN") and rewardText or nil,
        trigger = trigger,
        npcId = npcId,
        npcName = npcName,
        npcGuid = npcGuid,
        rewards = next(rewards) and rewards or nil,
        requiredItems = #requiredItems > 0 and requiredItems or nil,
        objectives = GetQuestObjectives(questID),
        questInfo = next(questInfo) and questInfo or nil,
        mapId = mapId,
        position = pos,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.QUEST_SNAPSHOT, entityKey or ("Q:" .. questID), payload, {
        source_module = MODULE_NAME,
        fingerprint = FP.Compute({ quest = questID, trigger = trigger }),
    })
    if not envelope then return end

    recentQuests[questID] = GetTime()
    buffer:Push(envelope)
    Log.Info(MODULE_NAME, format("[%s] Quest %d: %s (from %s)",
        trigger, questID, title or "?", npcName or "?"))
end

-- ============================================================
-- Event handler
-- ============================================================

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "QUEST_DETAIL" then
        local questID = GetQuestID and GetQuestID() or nil
        local npcGuid = UnitGUID("npc") or UnitGUID("questnpc")
        C_Timer.After(0.1, function()
            if moduleEnabled and NS.IsCaptureActive() then CaptureQuestDetail("QUEST_DETAIL", questID, npcGuid) end
        end)

    elseif event == "QUEST_COMPLETE" then
        local questID = GetQuestID and GetQuestID() or nil
        local npcGuid = UnitGUID("npc") or UnitGUID("questnpc")
        C_Timer.After(0.1, function()
            if moduleEnabled and NS.IsCaptureActive() then CaptureQuestDetail("QUEST_COMPLETE", questID, npcGuid) end
        end)

    elseif event == "QUEST_ACCEPTED" then
        local questID = ...
        if questID then
            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or "?"
            local npcGuid = UnitGUID("npc") or UnitGUID("questnpc")
            local entityKey = npcGuid and GU.EntityKey(npcGuid) or ("Q:" .. questID)
            local npcId = npcGuid and GU.GetNpcId(npcGuid) or nil

            local payload = {
                questID = questID,
                title = title,
                trigger = "QUEST_ACCEPTED",
                npcId = npcId,
                npcName = npcGuid and GU.SafeString(UnitName("npc") or UnitName("questnpc")) or nil,
            }

            local envelope = NS.MakeEnvelope(C.OBS_TYPE.QUEST_SNAPSHOT, entityKey, payload, {
                source_module = MODULE_NAME,
                fingerprint = FP.Compute({ quest = questID, trigger = "accepted" }),
            })
            if envelope then
                recentQuests[questID] = GetTime()
                buffer:Push(envelope)
                Log.Debug(MODULE_NAME, format("Quest accepted: %d (%s)", questID, title))
            end
        end

    elseif event == "QUEST_TURNED_IN" then
        local questID, xpReward, moneyReward = ...
        if questID then
            local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or "?"

            local payload = {
                questID = questID,
                title = title,
                trigger = "QUEST_TURNED_IN",
                xpReward = xpReward,
                moneyReward = moneyReward,
            }

            local envelope = NS.MakeEnvelope(C.OBS_TYPE.QUEST_SNAPSHOT, "Q:" .. questID, payload, {
                source_module = MODULE_NAME,
                fingerprint = FP.Compute({ quest = questID, trigger = "turned_in" }),
            })
            if envelope then
                buffer:Push(envelope)
                Log.Debug(MODULE_NAME, format("Quest turned in: %d (%s)", questID, title))
            end
        end
    end
end)

-- Periodic dedup cache sweep
local function SweepDedup()
    local cutoff = GetTime() - DEDUP_WINDOW * 2
    for k, t in pairs(recentQuests) do
        if t < cutoff then recentQuests[k] = nil end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function capture.ResetState()
    wipe(recentQuests)
end

function capture.Enable()
    moduleEnabled = true
    eventFrame:RegisterEvent("QUEST_DETAIL")
    eventFrame:RegisterEvent("QUEST_COMPLETE")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:RegisterEvent("QUEST_TURNED_IN")

    NS.Scheduler.Register(MODULE_NAME .. "_sweep", SweepDedup, 30)

    Log.Debug(MODULE_NAME, "Enabled — captures quest offer/accept/turn-in data")
end

function capture.Disable()
    moduleEnabled = false
    eventFrame:UnregisterAllEvents()
    NS.Scheduler.Unregister(MODULE_NAME .. "_sweep")
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
