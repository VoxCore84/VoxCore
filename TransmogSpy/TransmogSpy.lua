-- TransmogSpy v2: Transmog Debug Logger
-- Comprehensive monitor for all transmog API calls, events, and state changes.
-- v2: displayType capture, IMA resolution, illusion tracking, active/viewed
--     outfit tracking, 12.x button paths, new commands (status/bridge/resolve/items)

local RED = "|cffff4444"
local GREEN = "|cff44ff44"
local YELLOW = "|cffffff44"
local CYAN = "|cff44ffff"
local WHITE = "|cffffffff"
local ORANGE = "|cffff8800"
local RESET = "|r"

-- SavedVariables
TransmogSpyDB = TransmogSpyDB or {}

-- Server-side log relay — shows up in Debug.log alongside TransmogBridge entries
local LOG_PREFIX = "TSPY_LOG"
C_ChatInfo.RegisterAddonMessagePrefix(LOG_PREFIX)
local function ServerLog(msg)
    local clean = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if #clean > 255 then clean = clean:sub(1, 255) end
    -- UnitName("player") omits realm; use full Name-Realm for cross-realm whisper support
    local name = UnitName("player")
    if name then
        local realm = GetNormalizedRealmName()
        if realm and realm ~= "" then name = name .. "-" .. realm end
    end
    if name then
        pcall(C_ChatInfo.SendAddonMessage, LOG_PREFIX, clean, "WHISPER", name)
    end
end

local eventLog = {}
local autoMode = false
local autoTicker = nil
local lastPendingState = false
local preApplySnapshot = nil
local preApplyTimestamp = nil
local buttonsHooked = false
local quietMode = false
local atTransmogNpc = false  -- tracks TRANSMOGRIFY_OPEN/CLOSE

-- Slot definitions
local SLOT_NAMES = {
    [0]  = "HEAD",
    [1]  = "SHOULDER",
    [2]  = "SHOULDER2",
    [3]  = "BACK",
    [4]  = "CHEST",
    [5]  = "TABARD",
    [6]  = "SHIRT",
    [7]  = "WRIST",
    [8]  = "HANDS",
    [9]  = "WAIST",
    [10] = "LEGS",
    [11] = "FEET",
    [12] = "MAINHAND",
    [13] = "OFFHAND",
}

local INV_SLOT_NAMES = {
    [0]  = "HEADSLOT",
    [1]  = "SHOULDERSLOT",
    [3]  = "BACKSLOT",
    [4]  = "CHESTSLOT",
    [5]  = "TABARDSLOT",
    [6]  = "SHIRTSLOT",
    [7]  = "WRISTSLOT",
    [8]  = "HANDSSLOT",
    [9]  = "WAISTSLOT",
    [10] = "LEGSSLOT",
    [11] = "FEETSLOT",
    [12] = "MAINHANDSLOT",
    [13] = "SECONDARYHANDSLOT",
}

local SLOT_IDS = {}
for id in pairs(SLOT_NAMES) do
    SLOT_IDS[#SLOT_IDS + 1] = id
end
table.sort(SLOT_IDS)

-- DisplayType labels (from retail sniffer analysis)
local DT_LABELS = {
    [0] = "Unassigned",
    [1] = "Assigned",
    [2] = "Hidden",
    [3] = "Equipped",
}

-------------------------------------------------------------------------------
-- API availability cache
-------------------------------------------------------------------------------

local HAS = {
    OutfitSlotInfo    = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetViewedOutfitSlotInfo ~= nil,
    SlotVisualInfo    = C_Transmog and C_Transmog.GetSlotVisualInfo ~= nil
                        and TransmogUtil and TransmogUtil.GetTransmogLocation ~= nil
                        and Enum and Enum.TransmogType ~= nil,
    SlotInfo          = C_Transmog and C_Transmog.GetSlotInfo ~= nil
                        and TransmogUtil and TransmogUtil.GetTransmogLocation ~= nil
                        and Enum and Enum.TransmogType ~= nil,
    HasPending        = C_TransmogOutfitInfo and C_TransmogOutfitInfo.HasPendingOutfitTransmogs ~= nil,
    PendingCost       = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetPendingTransmogCost ~= nil,
    SetPending        = C_TransmogOutfitInfo and C_TransmogOutfitInfo.SetPendingTransmog ~= nil,
    ClearAllPending   = C_TransmogOutfitInfo and C_TransmogOutfitInfo.ClearAllPending ~= nil,
    ClearPending      = C_TransmogOutfitInfo and C_TransmogOutfitInfo.ClearPending ~= nil,
    CommitApply       = C_TransmogOutfitInfo and C_TransmogOutfitInfo.CommitAndApplyAllPending ~= nil,
    GetOutfitsInfo    = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo ~= nil,
    CollectionOutfits = C_TransmogCollection and C_TransmogCollection.GetOutfits ~= nil,
    SourceInfo        = C_TransmogCollection and C_TransmogCollection.GetSourceInfo ~= nil,
    ActiveOutfitID    = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID ~= nil,
    ViewedOutfitID    = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID ~= nil,
}

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------

local function Timestamp()
    return date("%H:%M:%S")
end

local function Log(msg)
    local line = format("[TransmogSpy %s] %s", Timestamp(), msg)
    if not quietMode then
        print(line)
    end
    eventLog[#eventLog + 1] = line
    if #eventLog > 500 then
        table.remove(eventLog, 1)
    end
    TransmogSpyDB.log = TransmogSpyDB.log or {}
    TransmogSpyDB.log[#TransmogSpyDB.log + 1] = line
    if #TransmogSpyDB.log > 2000 then
        table.remove(TransmogSpyDB.log, 1)
    end
    ServerLog(msg)
end

local function SlotLabel(slot)
    return format("%d(%s)", slot, SLOT_NAMES[slot] or "?")
end

local function BoolStr(v)
    if v == nil then return "nil" end
    return tostring(v)
end

local function DTLabel(dt)
    if dt == nil then return "nil" end
    return format("%d(%s)", dt, DT_LABELS[dt] or "?")
end

local loggedErrors = {}

local function TryCall(label, func, ...)
    if not func then return false, nil end
    local ok, result = pcall(func, ...)
    if not ok then
        if not loggedErrors[label] then
            loggedErrors[label] = true
            Log(format("%s%s failed: %s%s", RED, label, tostring(result), RESET))
        end
        return false, nil
    end
    return true, result
end

-- Resolve IMA ID to item name/info via C_TransmogCollection.GetSourceInfo
local function ResolveIMA(imaID)
    if not imaID or imaID == 0 then return nil end
    if not HAS.SourceInfo then return nil end
    local ok, info = TryCall("GetSourceInfo", C_TransmogCollection.GetSourceInfo, imaID)
    if ok and info then
        return info
    end
    return nil
end

-- Format IMA with optional name resolution
local function FormatIMA(imaID)
    if not imaID or imaID == 0 then return "0" end
    local info = ResolveIMA(imaID)
    if info and info.name and info.name ~= "" then
        return format("%d(%s)", imaID, info.name)
    end
    return tostring(imaID)
end

-------------------------------------------------------------------------------
-- Slot State Capture
-------------------------------------------------------------------------------

local function CaptureSlotState(slot)
    local state = { slot = slot }

    -- GetViewedOutfitSlotInfo (primary API)
    if HAS.OutfitSlotInfo then
        local ok, info = TryCall("GetViewedOutfitSlotInfo",
            C_TransmogOutfitInfo.GetViewedOutfitSlotInfo, slot, 0, 0)
        if ok and info then
            state.transmogID = info.transmogID
            state.displayType = info.displayType
            state.hasPending = info.hasPending
            state.isPendingCollected = info.isPendingCollected
            state.canTransmogrify = info.canTransmogrify
            state.hasUndo = info.hasUndo
            state.isHideVisual = info.isHideVisual
            state.texture = info.texture
            state.warningText = info.warningText
            state.errorText = info.errorText
        end
        -- Secondary shoulder (option=1)
        if slot == 1 then
            local ok2, info2 = TryCall("GetViewedOutfitSlotInfo(shoulder2)",
                C_TransmogOutfitInfo.GetViewedOutfitSlotInfo, slot, 0, 1)
            if ok2 and info2 then
                state.shoulder2_transmogID = info2.transmogID
                state.shoulder2_displayType = info2.displayType
                state.shoulder2_hasPending = info2.hasPending
                state.shoulder2_isPendingCollected = info2.isPendingCollected
            end
        end
    end

    -- GetSlotVisualInfo (visual layer)
    if HAS.SlotVisualInfo then
        local invName = INV_SLOT_NAMES[slot]
        if invName then
            -- Appearance visual info
            local ok3, loc = TryCall("GetTransmogLocation(visual)",
                TransmogUtil.GetTransmogLocation, invName, Enum.TransmogType.Appearance, false)
            if ok3 and loc then
                local ok4, visInfo = TryCall("GetSlotVisualInfo",
                    C_Transmog.GetSlotVisualInfo, loc)
                if ok4 and visInfo then
                    state.visual_pendingSourceID = visInfo.pendingSourceID
                    state.visual_appliedSourceID = visInfo.appliedSourceID
                    state.visual_selectedSourceID = visInfo.selectedSourceID
                    state.visual_hasPending = visInfo.hasPending
                    state.visual_hasUndo = visInfo.hasUndo
                    state.visual_baseSourceID = visInfo.baseSourceID
                    state.visual_baseVisualID = visInfo.baseVisualID
                end
            end

            -- Illusion visual info (weapon enchant effects)
            if Enum.TransmogType.Illusion then
                local ok5, iloc = TryCall("GetTransmogLocation(illusion)",
                    TransmogUtil.GetTransmogLocation, invName, Enum.TransmogType.Illusion, false)
                if ok5 and iloc then
                    local ok6, iVisInfo = TryCall("GetSlotVisualInfo(illusion)",
                        C_Transmog.GetSlotVisualInfo, iloc)
                    if ok6 and iVisInfo then
                        state.illusion_pendingSourceID = iVisInfo.pendingSourceID
                        state.illusion_appliedSourceID = iVisInfo.appliedSourceID
                    end
                end
            end
        end
    end

    -- GetSlotInfo (old detailed info)
    if HAS.SlotInfo then
        local invName = INV_SLOT_NAMES[slot]
        if invName then
            local ok7, loc = TryCall("GetTransmogLocation(slotinfo)",
                TransmogUtil.GetTransmogLocation, invName, Enum.TransmogType.Appearance, false)
            if ok7 and loc then
                local ok8, slotInfo = TryCall("GetSlotInfo",
                    C_Transmog.GetSlotInfo, loc)
                if ok8 and slotInfo then
                    state.slotinfo_isTransmogrified = slotInfo.isTransmogrified
                    state.slotinfo_hasPending = slotInfo.hasPending
                    state.slotinfo_hasUndo = slotInfo.hasUndo
                    state.slotinfo_canTransmogrify = slotInfo.canTransmogrify
                    state.slotinfo_cannotTransmogrifyReason = slotInfo.cannotTransmogrifyReason
                end
            end
        end
    end

    return state
end

local function CaptureAllSlots()
    local snapshot = {}
    for _, slot in ipairs(SLOT_IDS) do
        snapshot[slot] = CaptureSlotState(slot)
    end

    -- Global pending state
    if HAS.HasPending then
        local ok, val = TryCall("HasPendingOutfitTransmogs",
            C_TransmogOutfitInfo.HasPendingOutfitTransmogs)
        if ok then snapshot._hasPending = val end
    end
    if HAS.PendingCost then
        local ok, val = TryCall("GetPendingTransmogCost",
            C_TransmogOutfitInfo.GetPendingTransmogCost)
        if ok then snapshot._cost = val end
    end

    -- Active/viewed outfit tracking
    if HAS.ActiveOutfitID then
        local ok, val = TryCall("GetActiveOutfitID",
            C_TransmogOutfitInfo.GetActiveOutfitID)
        if ok then snapshot._activeOutfitID = val end
    end
    if HAS.ViewedOutfitID then
        local ok, val = TryCall("GetCurrentlyViewedOutfitID",
            C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID)
        if ok then snapshot._viewedOutfitID = val end
    end

    return snapshot
end

local function PrintSlotState(prefix, state, color)
    color = color or WHITE
    local parts = { format("%s%s slot=%s:", color, prefix, SlotLabel(state.slot)) }

    if state.transmogID ~= nil then
        parts[#parts + 1] = format("IMA=%s", FormatIMA(state.transmogID))
    end
    if state.displayType ~= nil then
        parts[#parts + 1] = format("DT=%s", DTLabel(state.displayType))
    end
    if state.hasPending ~= nil then
        parts[#parts + 1] = format("pend=%s", BoolStr(state.hasPending))
    end
    if state.canTransmogrify ~= nil and not state.canTransmogrify then
        parts[#parts + 1] = format("%scannotXmog%s", RED, color)
    end
    if state.isHideVisual then
        parts[#parts + 1] = format("%shidden%s", ORANGE, color)
    end
    if state.warningText and state.warningText ~= "" then
        parts[#parts + 1] = format("warn=\"%s\"", state.warningText)
    end
    if state.errorText and state.errorText ~= "" then
        parts[#parts + 1] = format("%serr=\"%s\"%s", RED, state.errorText, color)
    end

    -- Secondary shoulder
    if state.shoulder2_transmogID ~= nil then
        parts[#parts + 1] = format("| sh2: IMA=%s DT=%s",
            FormatIMA(state.shoulder2_transmogID), DTLabel(state.shoulder2_displayType))
    end

    -- Illusion
    if state.illusion_appliedSourceID and state.illusion_appliedSourceID > 0 then
        parts[#parts + 1] = format("| illusion=%d", state.illusion_appliedSourceID)
    end
    if state.illusion_pendingSourceID and state.illusion_pendingSourceID > 0 then
        parts[#parts + 1] = format("pendIllusion=%d", state.illusion_pendingSourceID)
    end

    Log(table.concat(parts, " ") .. RESET)
end

local function CompareAndPrintSnapshots(pre, post)
    Log(CYAN .. "=== POST-APPLY COMPARISON ===" .. RESET)
    for _, slot in ipairs(SLOT_IDS) do
        local preSlot = pre[slot]
        local postSlot = post[slot]
        if preSlot and postSlot then
            local changes = {}
            if preSlot.transmogID ~= postSlot.transmogID then
                changes[#changes + 1] = format("IMA: %s->%s",
                    FormatIMA(preSlot.transmogID), FormatIMA(postSlot.transmogID))
            end
            if preSlot.displayType ~= postSlot.displayType then
                changes[#changes + 1] = format("DT: %s->%s",
                    DTLabel(preSlot.displayType), DTLabel(postSlot.displayType))
            end
            if preSlot.hasPending ~= postSlot.hasPending then
                changes[#changes + 1] = format("pend: %s->%s",
                    BoolStr(preSlot.hasPending), BoolStr(postSlot.hasPending))
            end

            if #changes > 0 then
                local hadPending = preSlot.hasPending
                local lostTransmog = hadPending and (postSlot.transmogID == 0 or postSlot.transmogID == nil)
                local color = lostTransmog and RED or YELLOW
                local suffix = lostTransmog and (RED .. " << LOST!" .. RESET) or ""
                Log(format("%sPOST-APPLY slot=%s: %s%s%s",
                    color, SlotLabel(slot), table.concat(changes, ", "), suffix, RESET))
            else
                Log(format("%sPOST-APPLY slot=%s: unchanged (IMA=%s DT=%s)%s",
                    GREEN, SlotLabel(slot), FormatIMA(postSlot.transmogID),
                    DTLabel(postSlot.displayType), RESET))
            end
        end
    end
end

-- Deferred comparison logic — shared by multiple event triggers
local function TryDeferredComparison(triggerEvent)
    if not preApplySnapshot then return end

    local age = preApplyTimestamp and (GetTime() - preApplyTimestamp) or 0
    if age > 10 then
        Log(format("%sDiscarding stale pre-apply snapshot (%.1fs old)%s", RED, age, RESET))
        preApplySnapshot = nil
        preApplyTimestamp = nil
        return
    end

    local snapshot = CaptureAllSlots()

    Log(format("%s=== DEFERRED POST-APPLY COMPARISON (trigger: %s, %.1fs after apply) ===%s",
        CYAN, triggerEvent, age, RESET))
    CompareAndPrintSnapshots(preApplySnapshot, snapshot)

    TransmogSpyDB.lastApply = TransmogSpyDB.lastApply or {}
    TransmogSpyDB.lastApply.deferred_post = snapshot
    TransmogSpyDB.lastApply.deferred_timestamp = Timestamp()
    TransmogSpyDB.lastApply.deferred_trigger = triggerEvent
    preApplySnapshot = nil
    preApplyTimestamp = nil
end

-------------------------------------------------------------------------------
-- Event Logger
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local TRANSMOG_EVENTS = {
    -- Core transmog events
    "TRANSMOGRIFY_UPDATE",
    "TRANSMOGRIFY_SUCCESS",
    "TRANSMOGRIFY_OPEN",
    "TRANSMOGRIFY_CLOSE",
    -- Collection events
    "TRANSMOG_COLLECTION_UPDATED",
    "TRANSMOG_COLLECTION_SOURCE_ADDED",
    "TRANSMOG_COLLECTION_SOURCE_REMOVED",
    "TRANSMOG_COLLECTION_CAMERA_UPDATE",
    "TRANSMOG_SEARCH_UPDATED",
    "TRANSMOG_SETS_UPDATE_FAVORITE",
    "TRANSMOG_SOURCE_COLLECTABILITY_UPDATE",
    -- Outfit events
    "TRANSMOG_OUTFIT_UPDATE",
    "TRANSMOG_OUTFITS_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_SLOTS_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED",
    "TRANSMOG_PENDING_CLEARED",
}

local registeredEvents = {}

local failedEvents = {}
for _, ev in ipairs(TRANSMOG_EVENTS) do
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, ev)
    if ok then
        registeredEvents[#registeredEvents + 1] = ev
    else
        failedEvents[#failedEvents + 1] = ev
    end
end

-- Events that trigger deferred post-apply comparison
local DEFERRED_TRIGGER_EVENTS = {
    ["TRANSMOGRIFY_SUCCESS"] = true,
    ["TRANSMOGRIFY_UPDATE"] = true,
    ["TRANSMOG_PENDING_CLEARED"] = true,
}

-- Events that trigger a full slot auto-dump
local AUTO_DUMP_EVENTS = {
    ["TRANSMOGRIFY_SUCCESS"] = true,
    ["TRANSMOGRIFY_UPDATE"] = true,
    ["VIEWED_TRANSMOG_OUTFIT_CHANGED"] = true,
    ["VIEWED_TRANSMOG_OUTFIT_SLOTS_CHANGED"] = true,
}

eventFrame:SetScript("OnEvent", function(self, event, ...)
    local args = {}
    for i = 1, select("#", ...) do
        args[#args + 1] = tostring(select(i, ...))
    end
    local argStr = #args > 0 and table.concat(args, ", ") or "none"
    Log(format("%s%s%s: args=[%s]", CYAN, event, RESET, argStr))

    -- Track NPC window state
    if event == "TRANSMOGRIFY_OPEN" then
        atTransmogNpc = true
        Log(format("%sTransmog NPC window OPENED%s", GREEN, RESET))
    elseif event == "TRANSMOGRIFY_CLOSE" then
        atTransmogNpc = false
        Log(format("%sTransmog NPC window CLOSED%s", RED, RESET))
    end

    -- Auto-dump full state on key events
    if AUTO_DUMP_EVENTS[event] then
        Log(format("%sAuto-dumping slots after %s:%s", YELLOW, event, RESET))
        local snapshot = CaptureAllSlots()
        for _, slot in ipairs(SLOT_IDS) do
            PrintSlotState("  ", snapshot[slot], WHITE)
        end
    end

    -- Try deferred comparison on any trigger event
    if DEFERRED_TRIGGER_EVENTS[event] then
        TryDeferredComparison(event)
    end
end)

-------------------------------------------------------------------------------
-- API Hooks
-------------------------------------------------------------------------------

if HAS.SetPending then
    hooksecurefunc(C_TransmogOutfitInfo, "SetPendingTransmog", function(slot, tmogType, option, transmogID, displayType)
        local typeLabel = tmogType == 0 and "appearance" or tmogType == 1 and "illusion" or tostring(tmogType)
        Log(format("%sSetPendingTransmog%s: slot=%s type=%s(%s) option=%s IMA=%s DT=%s",
            YELLOW, RESET,
            SlotLabel(slot or -1),
            tostring(tmogType), typeLabel,
            tostring(option),
            FormatIMA(transmogID),
            DTLabel(displayType)))
    end)
    Log(GREEN .. "Hooked: C_TransmogOutfitInfo.SetPendingTransmog" .. RESET)
end

if HAS.ClearAllPending then
    hooksecurefunc(C_TransmogOutfitInfo, "ClearAllPending", function()
        Log(YELLOW .. "ClearAllPending()" .. RESET)
    end)
    Log(GREEN .. "Hooked: C_TransmogOutfitInfo.ClearAllPending" .. RESET)
end

if HAS.ClearPending then
    hooksecurefunc(C_TransmogOutfitInfo, "ClearPending", function(slot, tmogType, option)
        Log(format("%sClearPending%s: slot=%s type=%s option=%s",
            YELLOW, RESET, SlotLabel(slot or -1), tostring(tmogType), tostring(option)))
    end)
    Log(GREEN .. "Hooked: C_TransmogOutfitInfo.ClearPending" .. RESET)
end

-- CommitAndApplyAllPending — posthook
if HAS.CommitApply then
    hooksecurefunc(C_TransmogOutfitInfo, "CommitAndApplyAllPending", function(useDiscount)
        Log(format("%sCommitAndApplyAllPending%s: useDiscount=%s (post-hook, pending already cleared)",
            YELLOW, RESET, BoolStr(useDiscount)))

        local postCallSnapshot = CaptureAllSlots()
        Log(format("  HasPending=%s ActiveOutfit=%s ViewedOutfit=%s",
            BoolStr(postCallSnapshot._hasPending),
            tostring(postCallSnapshot._activeOutfitID or "?"),
            tostring(postCallSnapshot._viewedOutfitID or "?")))
        Log(YELLOW .. "  (deferred comparison waiting for server response event)" .. RESET)
    end)
    Log(GREEN .. "Hooked: C_TransmogOutfitInfo.CommitAndApplyAllPending (post-hook)" .. RESET)
end

-- Capture pre-apply snapshot — called from button PreClick BEFORE the C function
local function CapturePreApplySnapshot(source)
    Log(format("%s====== PRE-APPLY SNAPSHOT (via %s) ======%s", RED, source, RESET))

    preApplySnapshot = CaptureAllSlots()
    preApplyTimestamp = GetTime()

    if preApplySnapshot._hasPending ~= nil then
        Log(format("  HasPending=%s", BoolStr(preApplySnapshot._hasPending)))
    end
    if preApplySnapshot._cost ~= nil then
        Log(format("  PendingCost=%s", tostring(preApplySnapshot._cost)))
    end
    if preApplySnapshot._activeOutfitID ~= nil then
        Log(format("  ActiveOutfitID=%s", tostring(preApplySnapshot._activeOutfitID)))
    end
    if preApplySnapshot._viewedOutfitID ~= nil then
        Log(format("  ViewedOutfitID=%s", tostring(preApplySnapshot._viewedOutfitID)))
    end
    for _, slot in ipairs(SLOT_IDS) do
        PrintSlotState("  PRE-APPLY", preApplySnapshot[slot],
            preApplySnapshot[slot].hasPending and YELLOW or WHITE)
    end

    TransmogSpyDB.lastApply = {
        timestamp = Timestamp(),
        pre = preApplySnapshot,
    }

    Log(YELLOW .. "  (post-apply comparison deferred until server responds)" .. RESET)
end

-- Hook Apply button PreClick + OnClick (12.x frame paths)
local function HookApplyButton()
    if buttonsHooked then return end

    -- 12.x button paths (confirmed from Blizzard_Transmog source)
    local buttonNames = {
        "TransmogFrame.OutfitCollection.SaveOutfitButton",
        "TransmogFrame.WardrobeCollection.TabContent.SituationsFrame.ApplyButton",
    }
    local hooked = 0
    for _, path in ipairs(buttonNames) do
        local ok, btn = pcall(function()
            local obj = _G
            for part in path:gmatch("[^%.]+") do
                obj = obj[part]
                if not obj then return nil end
            end
            return obj
        end)
        if ok and btn and btn.HookScript then
            btn:HookScript("PreClick", function()
                CapturePreApplySnapshot(path)
            end)
            btn:HookScript("OnClick", function()
                Log(format("%sApply button clicked: %s%s", YELLOW, path, RESET))
            end)
            Log(format("%sHooked button PreClick+OnClick: %s%s", GREEN, path, RESET))
            hooked = hooked + 1
        end
    end
    if hooked > 0 then
        buttonsHooked = true
    end
end

-- Delay button hook until transmog UI loads
local buttonHookFrame = CreateFrame("Frame")
buttonHookFrame:RegisterEvent("ADDON_LOADED")
buttonHookFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
buttonHookFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "TRANSMOGRIFY_OPEN" then
        -- Guaranteed moment that transmog frames exist — most reliable hook point
        if not buttonsHooked then
            HookApplyButton()
        end
    elseif event == "ADDON_LOADED" then
        if addon == "Blizzard_Transmog" or addon == "Blizzard_Collections"
            or addon == "Blizzard_EncounterJournal" then
            C_Timer.After(0.5, HookApplyButton)
        end
    end
end)
C_Timer.After(1.0, HookApplyButton)

-- Hook C_TransmogOutfitInfo functions (comprehensive list for 12.x)
local outfitInfoHooks = {
    "SetViewedOutfit",
    "SaveViewedOutfit",
    "DeleteOutfit",
    "RenameOutfit",
    "SetOutfitToFavorite",
    "UndoPending",
    "ChangeViewedOutfit",
    "ChangeDisplayedOutfit",
    "AddNewOutfit",
    "CommitOutfitInfo",
    "RevertPendingTransmog",
    "SetSecondarySlotState",
}

for _, funcName in ipairs(outfitInfoHooks) do
    if C_TransmogOutfitInfo and C_TransmogOutfitInfo[funcName] then
        hooksecurefunc(C_TransmogOutfitInfo, funcName, function(...)
            local args = {}
            for i = 1, select("#", ...) do
                args[#args + 1] = tostring(select(i, ...))
            end
            Log(format("%s%s%s(%s)", YELLOW, funcName, RESET, table.concat(args, ", ")))
        end)
        Log(format("%sHooked: C_TransmogOutfitInfo.%s%s", GREEN, funcName, RESET))
    end
end

-- Hook C_Transmog functions
local cTransmogHooks = {
    "SetPending",
    "ClearPending",
    "ClearAllPending",
    "ApplyAllPending",
}

for _, funcName in ipairs(cTransmogHooks) do
    if C_Transmog and C_Transmog[funcName] then
        hooksecurefunc(C_Transmog, funcName, function(...)
            local args = {}
            for i = 1, select("#", ...) do
                args[#args + 1] = tostring(select(i, ...))
            end
            Log(format("%sC_Transmog.%s%s(%s)", YELLOW, funcName, RESET, table.concat(args, ", ")))
        end)
        Log(format("%sHooked: C_Transmog.%s%s", GREEN, funcName, RESET))
    end
end

-------------------------------------------------------------------------------
-- Auto-monitoring
-------------------------------------------------------------------------------

local function StartAutoMonitor()
    if autoTicker then return end
    autoMode = true
    Log(GREEN .. "Auto-monitoring ENABLED (2 sec interval)" .. RESET)

    autoTicker = C_Timer.NewTicker(2.0, function()
        if not atTransmogNpc then return end

        local hasPending = false
        if HAS.HasPending then
            local ok, val = TryCall("HasPendingOutfitTransmogs(auto)",
                C_TransmogOutfitInfo.HasPendingOutfitTransmogs)
            if ok then hasPending = val end
        end

        if hasPending ~= lastPendingState then
            local transition = format("pending: %s -> %s",
                BoolStr(lastPendingState), BoolStr(hasPending))
            Log(format("%sAUTO: Pending state changed: %s%s", YELLOW, transition, RESET))
            lastPendingState = hasPending

            local snapshot = CaptureAllSlots()
            for _, slot in ipairs(SLOT_IDS) do
                PrintSlotState("  AUTO", snapshot[slot],
                    snapshot[slot].hasPending and YELLOW or WHITE)
            end
        end
    end)
end

local function StopAutoMonitor()
    autoMode = false
    if autoTicker then
        autoTicker:Cancel()
        autoTicker = nil
    end
    Log(RED .. "Auto-monitoring DISABLED" .. RESET)
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------

local function CmdDump()
    Log(CYAN .. "=== FULL SLOT DUMP ===" .. RESET)
    local snapshot = CaptureAllSlots()
    if snapshot._hasPending ~= nil then
        Log(format("  HasPending = %s", BoolStr(snapshot._hasPending)))
    end
    if snapshot._cost ~= nil then
        Log(format("  PendingCost = %s", tostring(snapshot._cost)))
    end
    if snapshot._activeOutfitID ~= nil then
        Log(format("  ActiveOutfitID = %s", tostring(snapshot._activeOutfitID)))
    end
    if snapshot._viewedOutfitID ~= nil then
        Log(format("  ViewedOutfitID = %s", tostring(snapshot._viewedOutfitID)))
    end
    for _, slot in ipairs(SLOT_IDS) do
        PrintSlotState("  DUMP", snapshot[slot], WHITE)
    end
end

local function CmdPending()
    Log(CYAN .. "=== PENDING CHANGES ===" .. RESET)
    local snapshot = CaptureAllSlots()
    if snapshot._hasPending ~= nil then
        Log(format("  HasPending = %s%s%s",
            snapshot._hasPending and GREEN or RED,
            BoolStr(snapshot._hasPending), RESET))
    end
    if snapshot._cost ~= nil then
        Log(format("  PendingCost = %s", tostring(snapshot._cost)))
    end
    local pendingCount = 0
    for _, slot in ipairs(SLOT_IDS) do
        local s = snapshot[slot]
        if s.hasPending then
            pendingCount = pendingCount + 1
            Log(format("  %sPENDING slot=%s: IMA=%s DT=%s collected=%s%s",
                YELLOW, SlotLabel(slot), FormatIMA(s.transmogID),
                DTLabel(s.displayType), BoolStr(s.isPendingCollected), RESET))
        end
    end
    if pendingCount == 0 then
        Log("  No pending changes.")
    else
        Log(format("  %s%d slot(s) with pending changes%s", YELLOW, pendingCount, RESET))
    end
end

local function CmdOutfits()
    Log(CYAN .. "=== OUTFITS ===" .. RESET)
    if HAS.GetOutfitsInfo then
        local ok, outfits = TryCall("GetOutfitsInfo",
            C_TransmogOutfitInfo.GetOutfitsInfo)
        if ok and outfits then
            for i, outfit in ipairs(outfits) do
                local parts = { format("  Outfit %d:", i) }
                if type(outfit) == "table" then
                    for k, v in pairs(outfit) do
                        parts[#parts + 1] = format("%s=%s", tostring(k), tostring(v))
                    end
                else
                    parts[#parts + 1] = tostring(outfit)
                end
                Log(table.concat(parts, " "))
            end
        else
            Log("  GetOutfitsInfo returned nil or failed")
        end
    else
        Log("  C_TransmogOutfitInfo.GetOutfitsInfo not available")
    end

    if HAS.CollectionOutfits then
        local ok, outfits = TryCall("C_TransmogCollection.GetOutfits",
            C_TransmogCollection.GetOutfits)
        if ok and outfits then
            Log("  (via C_TransmogCollection.GetOutfits):")
            for i, outfit in ipairs(outfits) do
                Log(format("    %d: %s", i, tostring(outfit)))
            end
        end
    end
end

local function CmdVisual()
    Log(CYAN .. "=== C_Transmog.GetSlotVisualInfo ===" .. RESET)
    if not HAS.SlotVisualInfo then
        Log(format("  %sAPI not available%s", RED, RESET))
        return
    end
    for _, slot in ipairs(SLOT_IDS) do
        local s = CaptureSlotState(slot)
        local parts = { format("  slot=%s:", SlotLabel(slot)) }
        if s.visual_pendingSourceID ~= nil then
            parts[#parts + 1] = format("pendSrc=%s", FormatIMA(s.visual_pendingSourceID))
            parts[#parts + 1] = format("applSrc=%s", FormatIMA(s.visual_appliedSourceID))
            parts[#parts + 1] = format("selSrc=%s", FormatIMA(s.visual_selectedSourceID))
            parts[#parts + 1] = format("baseSrc=%s", FormatIMA(s.visual_baseSourceID))
            parts[#parts + 1] = format("baseVis=%s", tostring(s.visual_baseVisualID))
            parts[#parts + 1] = format("pend=%s", BoolStr(s.visual_hasPending))
        else
            parts[#parts + 1] = "nil"
        end
        -- Illusion data
        if s.illusion_appliedSourceID and s.illusion_appliedSourceID > 0 then
            parts[#parts + 1] = format("| illusion: applied=%d", s.illusion_appliedSourceID)
        end
        if s.illusion_pendingSourceID and s.illusion_pendingSourceID > 0 then
            parts[#parts + 1] = format("pending=%d", s.illusion_pendingSourceID)
        end
        Log(table.concat(parts, " "))
    end
end

local function CmdSlotInfo()
    Log(CYAN .. "=== C_Transmog.GetSlotInfo ===" .. RESET)
    if not HAS.SlotInfo then
        Log(format("  %sAPI not available%s", RED, RESET))
        return
    end
    for _, slot in ipairs(SLOT_IDS) do
        local s = CaptureSlotState(slot)
        local parts = { format("  slot=%s:", SlotLabel(slot)) }
        if s.slotinfo_isTransmogrified ~= nil then
            parts[#parts + 1] = format("xmogged=%s", BoolStr(s.slotinfo_isTransmogrified))
            parts[#parts + 1] = format("pend=%s", BoolStr(s.slotinfo_hasPending))
            parts[#parts + 1] = format("undo=%s", BoolStr(s.slotinfo_hasUndo))
            parts[#parts + 1] = format("can=%s", BoolStr(s.slotinfo_canTransmogrify))
            if s.slotinfo_cannotTransmogrifyReason then
                parts[#parts + 1] = format("reason=%s", tostring(s.slotinfo_cannotTransmogrifyReason))
            end
        else
            parts[#parts + 1] = "nil"
        end
        Log(table.concat(parts, " "))
    end
end

local function CmdEvents()
    local total = #eventLog
    local start = math.max(1, total - 49)
    local count = total > 0 and (total - start + 1) or 0
    print(format("%s=== LAST %d EVENTS (of %d total) ===%s", CYAN, count, total, RESET))
    for i = start, total do
        print(format("  %s", eventLog[i]))
    end
end

local function CmdClear()
    eventLog = {}
    loggedErrors = {}
    TransmogSpyDB.log = {}
    TransmogSpyDB.lastApply = nil
    preApplySnapshot = nil
    preApplyTimestamp = nil
    Log(GREEN .. "Log cleared." .. RESET)
end

local function CmdAuto()
    if autoMode then
        StopAutoMonitor()
    else
        StartAutoMonitor()
    end
end

local function CmdSnapshot()
    CapturePreApplySnapshot("manual /tspy snapshot")
end

local function CmdLast()
    local last = TransmogSpyDB.lastApply
    if not last then
        Log("  No saved apply data. Use the transmog UI to apply changes first.")
        return
    end

    Log(CYAN .. "=== LAST APPLY ===" .. RESET)
    Log(format("  Timestamp: %s", last.timestamp or "?"))

    if last.pre then
        Log(YELLOW .. "  --- PRE-APPLY ---" .. RESET)
        if last.pre._hasPending ~= nil then
            Log(format("    HasPending = %s", BoolStr(last.pre._hasPending)))
        end
        if last.pre._cost ~= nil then
            Log(format("    PendingCost = %s", tostring(last.pre._cost)))
        end
        for _, slot in ipairs(SLOT_IDS) do
            local s = last.pre[slot]
            if s then
                PrintSlotState("    PRE", s, s.hasPending and YELLOW or WHITE)
            end
        end
    else
        Log(RED .. "  No pre-apply snapshot saved" .. RESET)
    end

    if last.deferred_post then
        Log(format("%s  --- POST-APPLY (trigger: %s, at %s) ---%s",
            YELLOW, last.deferred_trigger or "?", last.deferred_timestamp or "?", RESET))
        for _, slot in ipairs(SLOT_IDS) do
            local s = last.deferred_post[slot]
            if s then
                PrintSlotState("    POST", s, WHITE)
            end
        end

        if last.pre then
            CompareAndPrintSnapshots(last.pre, last.deferred_post)
        end
    else
        Log(RED .. "  No post-apply snapshot saved" .. RESET)
    end
end

local function CmdQuiet()
    quietMode = not quietMode
    print(format("[TransmogSpy %s] %sQuiet mode %s%s (logging to SavedVariables %s)",
        Timestamp(),
        quietMode and GREEN or YELLOW,
        quietMode and "ENABLED" or "DISABLED",
        RESET,
        quietMode and "only" or "+ chat"))
end

local function CmdAPIs()
    Log(CYAN .. "=== AVAILABLE TRANSMOG APIs ===" .. RESET)

    local apis = {
        { "C_TransmogOutfitInfo", C_TransmogOutfitInfo },
        { "C_Transmog", C_Transmog },
        { "C_TransmogCollection", C_TransmogCollection },
        { "C_TransmogSets", C_TransmogSets },
        { "TransmogUtil", TransmogUtil },
    }

    for _, entry in ipairs(apis) do
        local name, tbl = entry[1], entry[2]
        if tbl then
            local funcs = {}
            for k, v in pairs(tbl) do
                if type(v) == "function" then
                    funcs[#funcs + 1] = k
                end
            end
            table.sort(funcs)
            Log(format("  %s%s%s: %d functions", GREEN, name, RESET, #funcs))
            for _, fn in ipairs(funcs) do
                Log(format("    .%s", fn))
            end
        else
            Log(format("  %s%s%s: NOT AVAILABLE", RED, name, RESET))
        end
    end

    Log(CYAN .. "  --- Cached availability (HAS) ---" .. RESET)
    local hasKeys = {}
    for k in pairs(HAS) do hasKeys[#hasKeys + 1] = k end
    table.sort(hasKeys)
    for _, k in ipairs(hasKeys) do
        Log(format("    %s%s%s = %s",
            HAS[k] and GREEN or RED, k, RESET, BoolStr(HAS[k])))
    end
end

-- /tspy status — quick overview of transmog state
local function CmdStatus()
    Log(CYAN .. "=== TRANSMOG STATUS ===" .. RESET)

    -- NPC window state
    Log(format("  At transmog NPC: %s%s%s",
        atTransmogNpc and GREEN or RED, BoolStr(atTransmogNpc), RESET))

    -- Active/viewed outfit
    if HAS.ActiveOutfitID then
        local ok, val = TryCall("GetActiveOutfitID", C_TransmogOutfitInfo.GetActiveOutfitID)
        if ok then Log(format("  Active outfit ID: %s", tostring(val))) end
    else
        Log("  Active outfit ID: API unavailable")
    end
    if HAS.ViewedOutfitID then
        local ok, val = TryCall("GetCurrentlyViewedOutfitID", C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID)
        if ok then Log(format("  Viewed outfit ID: %s", tostring(val))) end
    else
        Log("  Viewed outfit ID: API unavailable")
    end

    -- Pending state
    if HAS.HasPending then
        local ok, val = TryCall("HasPendingOutfitTransmogs", C_TransmogOutfitInfo.HasPendingOutfitTransmogs)
        if ok then
            Log(format("  Has pending: %s%s%s", val and YELLOW or GREEN, BoolStr(val), RESET))
        end
    end
    if HAS.PendingCost then
        local ok, val = TryCall("GetPendingTransmogCost", C_TransmogOutfitInfo.GetPendingTransmogCost)
        if ok then Log(format("  Pending cost: %s", tostring(val))) end
    end

    -- Count pending slots
    local pendingCount = 0
    for _, slot in ipairs(SLOT_IDS) do
        local state = CaptureSlotState(slot)
        if state.hasPending then pendingCount = pendingCount + 1 end
    end
    Log(format("  Pending slots: %s%d%s / %d",
        pendingCount > 0 and YELLOW or GREEN, pendingCount, RESET, #SLOT_IDS))

    -- Auto-monitor status
    Log(format("  Auto-monitor: %s%s%s",
        autoMode and GREEN or RED, autoMode and "ON" or "OFF", RESET))
    Log(format("  Quiet mode: %s%s%s",
        quietMode and GREEN or RED, quietMode and "ON" or "OFF", RESET))
    Log(format("  Buttons hooked: %s%s%s",
        buttonsHooked and GREEN or RED, BoolStr(buttonsHooked), RESET))
end

-- /tspy bridge — simulate TransmogBridge 3-layer merge for comparison
local function CmdBridge()
    Log(CYAN .. "=== BRIDGE SIMULATION (3-layer merge) ===" .. RESET)

    local ALWAYS_NIL_SLOTS = { [0]=true, [2]=true, [12]=true, [13]=true }
    local merged = {}

    -- Layer 1: GetViewedOutfitSlotInfo snapshot
    Log(YELLOW .. "  --- Layer 1: GetViewedOutfitSlotInfo snapshot ---" .. RESET)
    for slot = 0, 13 do
        if slot ~= 2 then
            if HAS.OutfitSlotInfo then
                local ok, info = TryCall("Bridge.Layer1",
                    C_TransmogOutfitInfo.GetViewedOutfitSlotInfo, slot, 0, 0)
                if ok and info and info.transmogID and info.transmogID > 0 then
                    merged[slot] = { transmogID = info.transmogID, option = 0, source = "L1" }
                    Log(format("    slot=%s: IMA=%s DT=%s", SlotLabel(slot),
                        FormatIMA(info.transmogID), DTLabel(info.displayType)))
                else
                    Log(format("    slot=%s: nil/0", SlotLabel(slot)))
                end
            end
        end
    end
    -- Secondary shoulder
    if HAS.OutfitSlotInfo then
        local ok, info2 = TryCall("Bridge.Layer1.sh2",
            C_TransmogOutfitInfo.GetViewedOutfitSlotInfo, 1, 0, 1)
        if ok and info2 and info2.transmogID and info2.transmogID > 0 then
            merged[2] = { transmogID = info2.transmogID, option = 0, source = "L1" }
            Log(format("    slot=%s: IMA=%s (secondary shoulder)", SlotLabel(2), FormatIMA(info2.transmogID)))
        end
    end

    -- Layer 2: would be SetPendingTransmog hooks — we can't simulate this without the bridge's data
    Log(YELLOW .. "  --- Layer 2: SetPendingTransmog hooks (not available — Bridge-only) ---" .. RESET)

    -- Layer 3: GetSlotVisualInfo fallback
    Log(YELLOW .. "  --- Layer 3: GetSlotVisualInfo fallback ---" .. RESET)
    if HAS.SlotVisualInfo then
        for slot = 0, 13 do
            if not merged[slot] and slot ~= 2 then
                local invName = INV_SLOT_NAMES[slot]
                if invName then
                    local ok, loc = TryCall("Bridge.Layer3.loc",
                        TransmogUtil.GetTransmogLocation, invName, Enum.TransmogType.Appearance, false)
                    if ok and loc then
                        local ok2, visInfo = TryCall("Bridge.Layer3.vis",
                            C_Transmog.GetSlotVisualInfo, loc)
                        if ok2 and visInfo then
                            local id = visInfo.pendingSourceID
                            if (not id or id == 0) then id = visInfo.appliedSourceID end
                            if id and id > 0 then
                                merged[slot] = { transmogID = id, option = 0, source = "L3" }
                                Log(format("    slot=%s: IMA=%s (fallback)", SlotLabel(slot), FormatIMA(id)))
                            else
                                Log(format("    slot=%s: nil/0", SlotLabel(slot)))
                            end
                        end
                    end
                end
            end
        end
    end

    -- Nil detection
    Log(YELLOW .. "  --- Nil detection ---" .. RESET)
    local missing = {}
    for slot = 0, 13 do
        if not merged[slot] then
            if ALWAYS_NIL_SLOTS[slot] then
                missing[#missing + 1] = slot
            else
                merged[slot] = { transmogID = 0, option = 0, source = "nil-clear" }
                Log(format("    slot=%s: hidden (nil clear)", SlotLabel(slot)))
            end
        end
    end
    if #missing > 0 then
        Log(format("    Deferred to server: slots %s", table.concat(missing, ",")))
    end

    -- Final payload preview
    Log(CYAN .. "  --- Final merged payload ---" .. RESET)
    local parts = {}
    for slot = 0, 13 do
        local data = merged[slot]
        if data then
            parts[#parts + 1] = format("%d.%d.%d", slot, data.transmogID, data.option)
            Log(format("    slot=%s: IMA=%s opt=%d source=%s",
                SlotLabel(slot), FormatIMA(data.transmogID), data.option, data.source))
        end
    end
    local payload = table.concat(parts, ";")
    Log(format("  Payload (%d bytes): %s", #payload, payload))
end

-- /tspy resolve <imaid> — resolve IMA ID to item details
local function CmdResolve(args)
    local imaID = tonumber(args)
    if not imaID or imaID == 0 then
        Log(RED .. "Usage: /tspy resolve <imaid>" .. RESET)
        return
    end

    Log(format("%s=== RESOLVE IMA %d ===%s", CYAN, imaID, RESET))

    if not HAS.SourceInfo then
        Log(RED .. "  C_TransmogCollection.GetSourceInfo not available" .. RESET)
        return
    end

    local ok, info = TryCall("GetSourceInfo", C_TransmogCollection.GetSourceInfo, imaID)
    if not ok or not info then
        Log(format("  %sGetSourceInfo returned nil for IMA %d%s", RED, imaID, RESET))
        return
    end

    Log(format("  Name: %s%s%s", GREEN, info.name or "?", RESET))
    Log(format("  Quality: %s", tostring(info.quality)))
    Log(format("  VisualID: %s", tostring(info.visualID)))
    Log(format("  SourceType: %s", tostring(info.sourceType)))
    Log(format("  ItemID: %s", tostring(info.itemID)))
    Log(format("  CategoryID: %s", tostring(info.categoryID)))
    Log(format("  InvType: %s", tostring(info.invType)))
    if info.isCollected ~= nil then
        Log(format("  Collected: %s%s%s",
            info.isCollected and GREEN or RED, BoolStr(info.isCollected), RESET))
    end
    if info.isHideVisual ~= nil then
        Log(format("  IsHideVisual: %s", BoolStr(info.isHideVisual)))
    end
end

-- /tspy items — show equipped items with base + active transmog + pending
local function CmdItems()
    Log(CYAN .. "=== EQUIPPED ITEMS ===" .. RESET)

    for _, slot in ipairs(SLOT_IDS) do
        if slot == 2 then goto next_slot end -- secondary shoulder has no inventory slot

        local invName = INV_SLOT_NAMES[slot]
        if not invName then goto next_slot end

        local slotID = GetInventorySlotInfo(invName)
        local itemLink = GetInventoryItemLink("player", slotID)
        local itemID = GetInventoryItemID("player", slotID)

        local state = CaptureSlotState(slot)
        local parts = { format("  slot=%s:", SlotLabel(slot)) }

        if itemLink then
            parts[#parts + 1] = itemLink
        elseif itemID then
            parts[#parts + 1] = format("itemID=%d", itemID)
        else
            parts[#parts + 1] = "(empty)"
            Log(table.concat(parts, " "))
            goto next_slot
        end

        -- Base visual (what the item looks like without transmog)
        if state.visual_baseSourceID and state.visual_baseSourceID > 0 then
            parts[#parts + 1] = format("| base=%s", FormatIMA(state.visual_baseSourceID))
        end

        -- Applied transmog
        if state.visual_appliedSourceID and state.visual_appliedSourceID > 0 then
            parts[#parts + 1] = format("| xmog=%s", FormatIMA(state.visual_appliedSourceID))
        end

        -- Current viewed outfit state
        if state.transmogID and state.transmogID > 0 then
            parts[#parts + 1] = format("| viewed=%s DT=%s",
                FormatIMA(state.transmogID), DTLabel(state.displayType))
        end

        -- Pending
        if state.hasPending then
            parts[#parts + 1] = format("| %sPENDING%s", YELLOW, RESET)
        end

        -- Illusion
        if state.illusion_appliedSourceID and state.illusion_appliedSourceID > 0 then
            parts[#parts + 1] = format("| illusion=%d", state.illusion_appliedSourceID)
        end

        Log(table.concat(parts, " "))
        ::next_slot::
    end
end

local function CmdHelp()
    print(CYAN .. "TransmogSpy v2 Commands:" .. RESET)
    print("  /tspy status    - Quick overview (NPC, outfits, pending, config)")
    print("  /tspy dump      - Dump all slot states with DT + IMA resolution")
    print("  /tspy pending   - Show pending changes per slot")
    print("  /tspy items     - Equipped items with base/xmog/pending")
    print("  /tspy bridge    - Simulate TransmogBridge 3-layer merge")
    print("  /tspy resolve N - Resolve IMA ID to item name/details")
    print("  /tspy snapshot  - Manually capture pre-apply snapshot")
    print("  /tspy last      - Show last apply comparison (survives /reload)")
    print("  /tspy outfits   - List all outfit info")
    print("  /tspy visual    - Dump GetSlotVisualInfo + illusions per slot")
    print("  /tspy slotinfo  - Dump GetSlotInfo per slot")
    print("  /tspy events    - Show last 50 logged events")
    print("  /tspy clear     - Clear log and saved data")
    print("  /tspy auto      - Toggle auto-monitoring (2 sec while at NPC)")
    print("  /tspy quiet     - Toggle quiet mode (SavedVariables only)")
    print("  /tspy apis      - List all available transmog API functions")
    print("  /tspy help      - This help")
end

SLASH_TRANSMOGSPY1 = "/tspy"
SLASH_TRANSMOGSPY2 = "/transmogspy"

SlashCmdList["TRANSMOGSPY"] = function(msg)
    msg = (msg or ""):trim()
    local cmd, args = msg:match("^(%S+)%s*(.*)")
    cmd = (cmd or msg):lower()
    args = args or ""

    if cmd == "dump" then
        CmdDump()
    elseif cmd == "pending" then
        CmdPending()
    elseif cmd == "status" then
        CmdStatus()
    elseif cmd == "items" then
        CmdItems()
    elseif cmd == "bridge" then
        CmdBridge()
    elseif cmd == "resolve" then
        CmdResolve(args)
    elseif cmd == "snapshot" or cmd == "snap" then
        CmdSnapshot()
    elseif cmd == "last" then
        CmdLast()
    elseif cmd == "outfits" then
        CmdOutfits()
    elseif cmd == "visual" then
        CmdVisual()
    elseif cmd == "slotinfo" then
        CmdSlotInfo()
    elseif cmd == "events" then
        CmdEvents()
    elseif cmd == "clear" then
        CmdClear()
    elseif cmd == "auto" then
        CmdAuto()
    elseif cmd == "quiet" then
        CmdQuiet()
    elseif cmd == "apis" then
        CmdAPIs()
    elseif cmd == "help" or cmd == "" then
        CmdHelp()
    else
        print(format("%sUnknown command: %s%s", RED, cmd, RESET))
        CmdHelp()
    end
end

-------------------------------------------------------------------------------
-- Init
-------------------------------------------------------------------------------

Log(GREEN .. "TransmogSpy v2 loaded." .. RESET)
Log(format("  Registered %d/%d events", #registeredEvents, #TRANSMOG_EVENTS))
if #failedEvents > 0 then
    Log(format("  %sFAILED to register: %s%s", RED, table.concat(failedEvents, ", "), RESET))
end
Log("  Type /tspy help for commands.")

for _, ev in ipairs(registeredEvents) do
    Log(format("  %s+ %s%s", GREEN, ev, RESET))
end
