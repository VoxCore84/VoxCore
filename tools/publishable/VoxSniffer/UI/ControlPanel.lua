-- VoxSniffer Control Panel
-- Full GUI replacing all slash commands with clickable controls
-- Left-click compartment/minimap button to open

local _, NS = ...
local C = NS.Constants
local Cfg = NS.Config
local SM = NS.SessionManager
local FM = NS.FlushManager
local Sched = NS.Scheduler
local Log = NS.Log

local PANEL_W = 340
local PANEL_H = 480
local PAD = 10
local COL_W = 148

-- ============================================================
-- Helpers
-- ============================================================

local function Header(parent, text, yOff)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", PAD, yOff)
    fs:SetText("|cff00ccff" .. text .. "|r")

    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", parent, "RIGHT", -PAD, 0)
    line:SetColorTexture(0, 0.5, 0.7, 0.4)
    return fs
end

local function Btn(parent, label, w, h, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(label)
    b:SetScript("OnClick", fn)
    return b
end

local function Check(parent, label, tip, fn)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local t = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    t:SetText(label)
    cb.label = t

    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end

    cb:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if fn then fn(self, self:GetChecked()) end
    end)
    return cb
end

-- ============================================================
-- Main frame
-- ============================================================

local panel = CreateFrame("Frame", "VoxSnifferPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:SetClampedToScreen(true)
panel:SetFrameStrata("DIALOG")
panel:SetFrameLevel(100)
panel:Hide()

panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})

-- ESC to close
tinsert(UISpecialFrames, "VoxSnifferPanel")

-- Title bar
local titleBg = panel:CreateTexture(nil, "ARTWORK")
titleBg:SetHeight(26)
titleBg:SetPoint("TOPLEFT", 4, -4)
titleBg:SetPoint("TOPRIGHT", -4, -4)
titleBg:SetColorTexture(0, 0.15, 0.25, 0.8)

local titleText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("TOPLEFT", 12, -8)
titleText:SetText("|cff00ccffVoxSniffer|r")

local verText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
verText:SetPoint("LEFT", titleText, "RIGHT", 6, 0)
verText:SetText("v" .. C.VERSION)
verText:SetTextColor(0.5, 0.5, 0.5)

local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)

-- ============================================================
-- SESSION section
-- ============================================================

local y = -36
Header(panel, "SESSION", y)
y = y - 20

local sessionLine = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sessionLine:SetPoint("TOPLEFT", PAD, y)
sessionLine:SetWidth(PANEL_W - PAD * 2)
sessionLine:SetJustifyH("LEFT")
sessionLine:SetWordWrap(false)
y = y - 16

local statsLine = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statsLine:SetPoint("TOPLEFT", PAD, y)
statsLine:SetWidth(PANEL_W - PAD * 2)
statsLine:SetJustifyH("LEFT")
statsLine:SetTextColor(0.7, 0.7, 0.7)
y = y - 20

local startBtn = Btn(panel, "Start", 90, 22, function()
    if SM.IsActive() then
        FM.FlushAll("session_stop")
        SM.Stop()
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording stopped.")
    else
        if SM.Start() then
            NS.ResetAllModuleState()
        end
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " Recording started.")
    end
end)
startBtn:SetPoint("TOPLEFT", PAD, y)

local flushBtn = Btn(panel, "Save Now", 70, 22, function()
    if not SM.IsActive() then
        print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. " No active session. Nothing buffered.")
        return
    end
    local n = FM.FlushAll("manual")
    print(C.COLOR .. "[VoxSniffer]" .. C.CLOSE .. format(" Flushed %d records.", n))
end)
flushBtn:SetPoint("LEFT", startBtn, "RIGHT", 4, 0)

local statusBtn = Btn(panel, "Print Status", 90, 22, function()
    SlashCmdList["VOXSNIFFER"]("status")
end)
statusBtn:SetPoint("LEFT", flushBtn, "RIGHT", 4, 0)

y = y - 28

-- Session label editbox
local labelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
labelLabel:SetPoint("TOPLEFT", PAD, y)
labelLabel:SetText("Label:")
labelLabel:SetTextColor(0.7, 0.7, 0.7)

local labelBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
labelBox:SetSize(PANEL_W - PAD * 2 - 40, 18)
labelBox:SetPoint("LEFT", labelLabel, "RIGHT", 6, 0)
labelBox:SetAutoFocus(false)
labelBox:SetMaxLetters(60)
labelBox:SetScript("OnEnterPressed", function(self)
    SM.SetLabel(self:GetText())
    self:ClearFocus()
end)
labelBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

y = y - 24

-- ============================================================
-- MODULES section (2-column checkbox grid)
-- ============================================================

Header(panel, "MODULES  (14)", y)
y = y - 20

local MODULE_LIST = {
    { key = "UnitScanner",     label = "Units",     tip = "Passive NPC discovery via nameplates, target, mouseover" },
    { key = "CombatCapture",   label = "Combat",    tip = "CLEU combat log events — spells, damage, healing" },
    { key = "CombatEnricher",  label = "Combat+",   tip = "Health/power snapshots, cast tracking, target changes" },
    { key = "AuraScanner",     label = "Auras",     tip = "Periodic aura/buff/debuff scanning on visible NPCs" },
    { key = "GossipCapture",   label = "Gossip",    tip = "NPC gossip menus, dialog text, quest options" },
    { key = "VendorCapture",   label = "Vendors",   tip = "Vendor item lists when you open a merchant" },
    { key = "QuestCapture",    label = "Quests",    tip = "Quest text, objectives, rewards on offer/accept/turn-in" },
    { key = "LootCapture",     label = "Loot",      tip = "Loot drops — items, quantities, quality, source NPC" },
    { key = "EmoteCapture",    label = "Emotes",    tip = "NPC speech, yells, emotes — CHAT_MSG_MONSTER_*" },
    { key = "ObjectTracker",   label = "Objects",   tip = "GameObjects via mouseover + vignettes (rares/treasures)" },
    { key = "PhaseTracker",    label = "Phases",    tip = "Phase transitions, zone changes, nameplate flickers" },
    { key = "CoverageHeatmap", label = "Heatmap",   tip = "Player position coverage grid per map" },
    { key = "MovementTracker", label = "Movement",  tip = "NPC patrol waypoint sampling (high volume, off by default)" },
    { key = "DeltaHints",      label = "Deltas",    tip = "Live comparison vs baseline hotset (requires hotset data)" },
}

local moduleChecks = {}
local col = 0
local rowY = y

for _, m in ipairs(MODULE_LIST) do
    local cb = Check(panel, m.label, m.tip, function(self, checked)
        local enabled = checked and true or false
        Cfg.SetModuleEnabled(m.key, enabled)
        local mod = NS.modules[m.key]
        if mod then
            if enabled and mod.Enable then
                mod.Enable()
            elseif not enabled and mod.Disable then
                mod.Disable()
            end
        end
        Sched.SetEnabled(m.key, enabled)
    end)
    cb:SetPoint("TOPLEFT", PAD + col * COL_W, rowY)
    moduleChecks[m.key] = cb

    col = col + 1
    if col >= 2 then
        col = 0
        rowY = rowY - 22
    end
end

if col > 0 then rowY = rowY - 22 end
y = rowY - 8

-- All-on / All-off buttons
-- Modules that are off by default for a reason (high volume or requires setup)
local OFF_BY_DEFAULT = {
    MovementTracker = true,
    DeltaHints = true,
}

local allOnBtn = Btn(panel, "All On", 60, 20, function()
    for _, m in ipairs(MODULE_LIST) do
        if not OFF_BY_DEFAULT[m.key] then
            Cfg.SetModuleEnabled(m.key, true)
            local mod = NS.modules[m.key]
            if mod and mod.Enable then mod.Enable() end
            Sched.SetEnabled(m.key, true)
        end
    end
end)
allOnBtn:SetPoint("TOPLEFT", PAD, y)

local allOffBtn = Btn(panel, "All Off", 60, 20, function()
    for _, m in ipairs(MODULE_LIST) do
        Cfg.SetModuleEnabled(m.key, false)
        local mod = NS.modules[m.key]
        if mod and mod.Disable then mod.Disable() end
        Sched.SetEnabled(m.key, false)
    end
end)
allOffBtn:SetPoint("LEFT", allOnBtn, "RIGHT", 4, 0)

y = y - 28

-- ============================================================
-- SETTINGS section
-- ============================================================

Header(panel, "SETTINGS", y)
y = y - 20

local autoStartCb = Check(panel, "Auto-start on login", "Begin recording automatically when you log in", function(_, checked)
    local cfg = Cfg.Get()
    cfg.autoStartSession = checked and true or false
end)
autoStartCb:SetPoint("TOPLEFT", PAD, y)

local debugCb = Check(panel, "Debug", "Show debug-level log messages in chat", function(_, checked)
    Cfg.SetDebug(checked and true or false)
end)
debugCb:SetPoint("TOPLEFT", PAD + COL_W, y)
y = y - 22

local verboseCb = Check(panel, "Verbose", "Show verbose per-event log messages in chat", function(_, checked)
    Cfg.SetVerbose(checked and true or false)
end)
verboseCb:SetPoint("TOPLEFT", PAD, y)
y = y - 28

-- ============================================================
-- DANGER ZONE
-- ============================================================

Header(panel, "MAINTENANCE", y)
y = y - 22

local resetBtn = Btn(panel, "Reset All Data", 120, 22, function()
    StaticPopup_Show("VOXSNIFFER_RESET")
end)
resetBtn:SetPoint("TOPLEFT", PAD, y)

-- Adjust panel height to fit content
local finalH = math.abs(y) + 40
panel:SetHeight(math.max(finalH, 420))

-- ============================================================
-- Recording indicator (always visible when recording)
-- Must be declared BEFORE the OnUpdate closure that references it
-- ============================================================

local recIndicator = CreateFrame("Frame", "VoxSnifferRecIndicator", UIParent)
recIndicator:SetSize(80, 22)
recIndicator:SetPoint("TOP", UIParent, "TOP", 0, -4)
recIndicator:SetFrameStrata("HIGH")
recIndicator:Hide()

local recBg = recIndicator:CreateTexture(nil, "BACKGROUND")
recBg:SetAllPoints()
recBg:SetColorTexture(0.15, 0, 0, 0.7)

local recDot = recIndicator:CreateTexture(nil, "ARTWORK")
recDot:SetSize(10, 10)
recDot:SetPoint("LEFT", 6, 0)
recDot:SetColorTexture(1, 0, 0, 1)

local recText = recIndicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
recText:SetPoint("LEFT", recDot, "RIGHT", 4, 0)
recText:SetText("REC")
recText:SetTextColor(1, 0.3, 0.3)

-- Blink the dot
local recElapsed = 0
recIndicator:SetScript("OnUpdate", function(_, dt)
    recElapsed = recElapsed + dt
    local alpha = (math.sin(recElapsed * 3) + 1) / 2
    recDot:SetAlpha(alpha)

    local session = SM.GetSession()
    if session then
        local dur = time() - session.start_time
        local mm = math.floor(dur / 60)
        local ss = dur % 60
        recText:SetText(format("REC %02d:%02d", mm, ss))
    end
end)

-- Allow dragging the indicator
recIndicator:SetMovable(true)
recIndicator:EnableMouse(true)
recIndicator:RegisterForDrag("LeftButton")
recIndicator:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:StartMoving()
end)
recIndicator:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    C_Timer.After(0.05, function() self.isDragging = false end)
end)
recIndicator:SetClampedToScreen(true)

-- Click to open panel (only if not dragging)
recIndicator:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and not self.isDragging then
        if NS.TogglePanel then NS.TogglePanel() end
    end
end)

NS.RecIndicator = recIndicator

-- ============================================================
-- Live update (0.5s tick)
-- ============================================================

local elapsed = 0
panel:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0

    -- Session status + recording indicator
    local session = SM.GetSession()
    if session then
        if not recIndicator:IsShown() then recIndicator:Show() end
    elseif recIndicator:IsShown() then
        recIndicator:Hide()
    end
    if session then
        local dur = time() - session.start_time
        local mm = math.floor(dur / 60)
        local ss = dur % 60
        startBtn:SetText("Stop")
        sessionLine:SetText(format("|cff00ff00REC|r  #%d  %s  %02d:%02d",
            session.session_id,
            session.label ~= "" and ('"' .. session.label .. '"') or "",
            mm, ss))
        statsLine:SetText(format("Obs: |cffffffff%d|r   Chunks: |cffffffff%d|r   Pending: |cffffffff%d|r",
            session.observation_count, session.chunk_count, FM.GetPendingCount()))
    else
        startBtn:SetText("Start")
        sessionLine:SetText("|cff888888Not recording|r")
        statsLine:SetText(format("Pending: %d", FM.GetPendingCount()))
    end

    -- Sync label editbox (only when not focused, to avoid fighting user input)
    if not labelBox:HasFocus() then
        local curLabel = session and session.label or ""
        if labelBox:GetText() ~= curLabel then
            labelBox:SetText(curLabel)
        end
    end
    labelBox:SetEnabled(session ~= nil)

    -- Module checkboxes
    local cfg = Cfg.Get()
    for key, cb in pairs(moduleChecks) do
        cb:SetChecked(cfg.modules[key] ~= false)
    end

    -- Settings
    autoStartCb:SetChecked(cfg.autoStartSession)
    debugCb:SetChecked(cfg.debugMode)
    verboseCb:SetChecked(cfg.verboseMode)
end)

-- ============================================================
-- Public API
-- ============================================================

NS.ControlPanel = panel

function NS.TogglePanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end
