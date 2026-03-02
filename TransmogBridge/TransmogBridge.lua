-- TransmogBridge: Sends pending transmog selections to the server via addon message.
-- The 12.x client's CommitAndApplyAllPending() C++ serializer omits HEAD, MH, OH,
-- weapon enchants, and sends stale data for all other slots. This addon captures
-- the correct IMAIDs from SetPendingTransmog and delivers them to the server.

local ADDON_PREFIX = "TMOG_BRIDGE"
local LOG_PREFIX  = "TMOG_LOG"
local pendingOverrides = {}

C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
C_ChatInfo.RegisterAddonMessagePrefix(LOG_PREFIX)

-- Send log entries to the server via addon message → shows up in Debug.log
local function Log(msg)
    local entry = date("%H:%M:%S") .. " " .. msg
    -- Truncate to 255 byte addon message limit
    if #entry > 255 then entry = entry:sub(1, 255) end
    C_ChatInfo.SendAddonMessage(LOG_PREFIX, entry, "WHISPER", UnitName("player"))
end

-- Capture every SetPendingTransmog call.
-- Client slot indices (confirmed via TransmogSpy):
--   0=HEAD, 1=SHOULDER, 2=SECONDARY_SHOULDER, 3=BACK, 4=CHEST,
--   5=TABARD, 6=SHIRT, 7=WRIST, 8=HANDS, 9=WAIST, 10=LEGS,
--   11=FEET, 12=MAINHAND, 13=OFFHAND
-- tmogType: 0=appearance, 1=illusion (weapon enchant visual)
-- transmogID: IMAID (type 0) or SpellItemEnchantmentID (type 1)
hooksecurefunc(C_TransmogOutfitInfo, "SetPendingTransmog", function(slot, tmogType, option, transmogID, displayType)
    if tmogType ~= 0 then
        Log(string.format("SetPending SKIP type=%d slot=%d id=%d", tmogType, slot, transmogID or 0))
        return
    end
    pendingOverrides[slot] = pendingOverrides[slot] or {}
    pendingOverrides[slot].transmogID = transmogID
    pendingOverrides[slot].option = option
    Log(string.format("SetPending slot=%d IMAID=%d opt=%d", slot, transmogID or 0, option or 0))
end)

-- Clear on window close (also handles cancel — ClearAllPending doesn't exist in 12.x)
local f = CreateFrame("Frame")
f:RegisterEvent("TRANSMOGRIFY_CLOSE")
f:SetScript("OnEvent", function(self, event)
    if event == "TRANSMOGRIFY_CLOSE" then
        local count = 0
        for _ in pairs(pendingOverrides) do count = count + 1 end
        if count > 0 then
            Log(string.format("TRANSMOGRIFY_CLOSE — cleared %d pending overrides", count))
        end
        wipe(pendingOverrides)
    end
end)

-- Send overrides on apply (post-hook: fires after CommitAndApplyAllPending queues the CMSG)
hooksecurefunc(C_TransmogOutfitInfo, "CommitAndApplyAllPending", function(useDiscount)
    if not next(pendingOverrides) then return end

    -- Encode: "slot.transmogID.option;..."
    local parts = {}
    for slot, data in pairs(pendingOverrides) do
        local tmogID = data.transmogID or 0
        local opt = data.option or 0
        if tmogID > 0 then
            parts[#parts + 1] = string.format("%d.%d.%d", slot, tmogID, opt)
        end
    end

    if #parts == 0 then return end

    local payload = table.concat(parts, ";")

    -- Addon message payload limit is 255 bytes.
    -- 14 slots * ~18 chars = ~252 bytes. Tight but fits.
    if #payload <= 255 then
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, payload, "WHISPER", UnitName("player"))
    else
        -- Split at nearest ; boundary
        local mid = payload:sub(1, 255):match(".*;") or payload:sub(1, 255)
        local part1 = mid
        local part2 = payload:sub(#mid + 1)
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "1>" .. part1, "WHISPER", UnitName("player"))
        C_ChatInfo.SendAddonMessage(ADDON_PREFIX, "2>" .. part2, "WHISPER", UnitName("player"))
    end

    Log(string.format("Sent %d overrides (%d bytes): %s", #parts, #payload, payload))

    wipe(pendingOverrides)
end)
