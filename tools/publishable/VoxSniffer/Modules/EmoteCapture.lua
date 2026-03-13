-- VoxSniffer EmoteCapture
-- Capture NPC speech: SAY, YELL, EMOTE, WHISPER, PARTY, RAID_BOSS_EMOTE/WHISPER
-- Borrows broadcast text sanitization from Datamine (replace player name/class)

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local GU = NS.GuidUtils
local EB = NS.EventBus

local MODULE_NAME = C.MODULE.EMOTE_CAPTURE
local capture = {}
NS.RegisterModule(MODULE_NAME, capture)

local buffer = NS.RingBuffer.New(C.RING_BUFFER_CAP)
NS.FlushManager.RegisterBuffer(MODULE_NAME, buffer)

-- Player info for text sanitization
local playerName, playerClass

-- Dedup recent texts to avoid spam
local recentTexts = {}  -- [hash] = GetTime()
local DEDUP_WINDOW = 5  -- seconds

local eventFrame = CreateFrame("Frame")

-- ============================================================
-- Text sanitization (Datamine pattern)
-- ============================================================

local function SanitizeText(text)
    if not text or text == "" then return text end

    -- Replace player name and class with placeholders
    -- Escape Lua pattern magic characters in names (e.g. "Al-Rashid", "Dot.Com")
    if playerName and playerName ~= "" then
        local escaped = playerName:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        text = text:gsub(escaped, "$PLAYER_NAME$")
    end
    if playerClass and playerClass ~= "" then
        local escaped = playerClass:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
        text = text:gsub(escaped, "$PLAYER_CLASS$")
    end

    return text
end

-- Simple hash for dedup
local function TextHash(senderGuid, text, eventType)
    return (senderGuid or "") .. "|" .. (text or "") .. "|" .. (eventType or "")
end

-- ============================================================
-- Event handler
-- ============================================================

local EVENT_MAP = {
    CHAT_MSG_MONSTER_SAY     = "say",
    CHAT_MSG_MONSTER_YELL    = "yell",
    CHAT_MSG_MONSTER_EMOTE   = "emote",
    CHAT_MSG_MONSTER_WHISPER = "whisper",
    CHAT_MSG_MONSTER_PARTY   = "party",
    CHAT_MSG_RAID_BOSS_EMOTE   = "raid_boss_emote",
    CHAT_MSG_RAID_BOSS_WHISPER = "raid_boss_whisper",
}

local function OnChatEvent(event, text, senderName, languageName, _, _, _, _, _, _, _, _, senderGUID)
    if not text or text == "" then return end

    local emoteType = EVENT_MAP[event]
    if not emoteType then return end

    -- Dedup check
    local hash = TextHash(senderGUID, text, emoteType)
    local now = GetTime()
    if recentTexts[hash] and (now - recentTexts[hash]) < DEDUP_WINDOW then
        return
    end

    -- Entity identification
    local entityKey = nil
    local npcId = nil
    if senderGUID then
        entityKey = GU.EntityKey(senderGUID)
        npcId = GU.GetNpcId(senderGUID)
    end

    local sanitizedText = SanitizeText(text)

    local payload = {
        text = sanitizedText,
        rawText = (sanitizedText ~= text) and text or nil, -- only store raw if different
        emoteType = emoteType,
        senderName = senderName,
        senderGUID = senderGUID,
        npcId = npcId,
        language = languageName,
    }

    local envelope = NS.MakeEnvelope(C.OBS_TYPE.EMOTE_TEXT, entityKey, payload, {
        source_module = MODULE_NAME,
    })
    if not envelope then return end

    recentTexts[hash] = now
    buffer:Push(envelope)
    Log.Debug(MODULE_NAME, format("[%s] %s: %s", emoteType, senderName or "?", (sanitizedText or ""):sub(1, 60)))
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    OnChatEvent(event, ...)
end)

-- Periodic sweep of dedup cache
local function SweepDedup()
    local cutoff = GetTime() - DEDUP_WINDOW * 2
    for k, t in pairs(recentTexts) do
        if t < cutoff then recentTexts[k] = nil end
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function capture.ResetState()
    wipe(recentTexts)
end

function capture.Enable()
    -- Cache player info for sanitization
    playerName = UnitName("player") or ""
    local _, classToken = UnitClass("player")
    -- Get localized class name for text replacement
    local classInfo = C_CreatureInfo and C_CreatureInfo.GetClassInfo
    if classInfo then
        local info = classInfo(select(3, UnitClass("player")))
        playerClass = info and info.className or ""
    else
        playerClass = UnitClass("player") or ""
    end

    for event in pairs(EVENT_MAP) do
        eventFrame:RegisterEvent(event)
    end

    -- Sweep dedup cache periodically via scheduler
    NS.Scheduler.Register(MODULE_NAME .. "_sweep", SweepDedup, 30)

    Log.Debug(MODULE_NAME, "Enabled — capturing 7 NPC speech event types")
end

function capture.Disable()
    eventFrame:UnregisterAllEvents()
    NS.Scheduler.Unregister(MODULE_NAME .. "_sweep")
    Log.Info(MODULE_NAME, "Disabled")
end

function capture.GetStats()
    return buffer:GetStats()
end
