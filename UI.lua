-- UI.lua
local addon = MythicPlusHistory

-- ─── Display maps ─────────────────────────────────────────────────────────────

local ROLE_LABEL = { TANK = "Tank", HEALER = "Heal", DAMAGER = "DPS", NONE = "?" }
local ROLE_COLOR = {
    TANK    = "|cff0070dd",
    HEALER  = "|cff00cc44",
    DAMAGER = "|cffff7700",
    NONE    = "|cff888888",
}

local CLASS_ICON = {
    WARRIOR     = "Interface\\Icons\\ClassIcon_Warrior",
    PALADIN     = "Interface\\Icons\\ClassIcon_Paladin",
    HUNTER      = "Interface\\Icons\\ClassIcon_Hunter",
    ROGUE       = "Interface\\Icons\\ClassIcon_Rogue",
    PRIEST      = "Interface\\Icons\\ClassIcon_Priest",
    SHAMAN      = "Interface\\Icons\\ClassIcon_Shaman",
    MAGE        = "Interface\\Icons\\ClassIcon_Mage",
    WARLOCK     = "Interface\\Icons\\ClassIcon_Warlock",
    MONK        = "Interface\\Icons\\ClassIcon_Monk",
    DRUID       = "Interface\\Icons\\ClassIcon_Druid",
    DEMONHUNTER = "Interface\\Icons\\ClassIcon_DemonHunter",
    DEATHKNIGHT = "Interface\\Icons\\ClassIcon_DeathKnight",
    EVOKER      = "Interface\\Icons\\ClassIcon_Evoker",
}


-- ─── Spec icon lookup (memoised) ──────────────────────────────────────────────

local classIDCache  = {}
local specIconCache = {}
local MISS          = {}

local function GetClassID(classToken)
    if classIDCache[classToken] then return classIDCache[classToken] end
    for i = 1, GetNumClasses() do
        local _, token = GetClassInfo(i)
        if token == classToken then classIDCache[classToken] = i; return i end
    end
end

local function GetSpecIconID(classToken, specName)
    if not classToken or not specName then return nil end
    local key    = classToken .. ":" .. specName
    local cached = specIconCache[key]
    if cached ~= nil then return cached ~= MISS and cached or nil end

    local classID = GetClassID(classToken)
    if not classID then specIconCache[key] = MISS; return nil end

    local numSpecs = GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID) or 4
    for i = 1, numSpecs do
        local ok, _, name, _, icon = pcall(GetSpecializationInfoForClassID, classID, i)
        if ok and name == specName then specIconCache[key] = icon; return icon end
    end
    specIconCache[key] = MISS
    return nil
end


-- ─── Main Window ──────────────────────────────────────────────────────────────

local mainFrame = CreateFrame("Frame", "MythicPlusHistoryFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(520, 638)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:SetResizable(true)
mainFrame:SetResizeBounds(480, 470, 900, 820)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", function(self) self:StartMoving(); self:Raise() end)
mainFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if addon.db then
        local cx, cy = UIParent:GetCenter()
        local x,  y  = self:GetCenter()
        addon.db.window.x = x - cx
        addon.db.window.y = y - cy
    end
end)
mainFrame:SetFrameStrata("HIGH")
mainFrame:Hide()
table.insert(UISpecialFrames, "MythicPlusHistoryFrame")

mainFrame:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
mainFrame:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
mainFrame:SetBackdropBorderColor(0.3, 0.3, 0.4, 1)


-- ─── Title Bar ────────────────────────────────────────────────────────────────

local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", mainFrame, "TOP", 0, -14)
title:SetText("|cff00ccffMythic+ History|r")

local subtitle = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
subtitle:SetText("Run History")

local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

local settingsPanel, timeGroup, trackGroup, testBtn, statsPanel, notesPanel

local gearBtn = CreateFrame("Button", nil, mainFrame)
gearBtn:SetSize(20, 20)
gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
gearTex:SetAllPoints()
gearTex:SetTexture("Interface\\AddOns\\MythicPlusHistory\\ICONS\\settings_gear_icon")
gearTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
gearTex:SetAlpha(0.55)
gearBtn.tex = gearTex
local gearHL = gearBtn:CreateTexture(nil, "HIGHLIGHT")
gearHL:SetAllPoints(); gearHL:SetColorTexture(1, 1, 1, 0.18)
gearBtn:SetScript("OnEnter", function(self) self.tex:SetAlpha(1.0) end)
gearBtn:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.55) end)
gearBtn:SetScript("OnClick", function()
    if settingsPanel:IsShown() then
        settingsPanel:Hide()
    else
        statsPanel:Hide()
        notesPanel:Hide()
        if addon.db and addon.db.settings then
            timeGroup.SetValue(addon.db.settings.timeFormat or "12h")
            trackGroup.SetValue(addon.db.settings.trackingMode or "account")
        end
        settingsPanel:Show()
    end
end)

local statsBtn = CreateFrame("Button", nil, mainFrame)
statsBtn:SetSize(20, 20)
statsBtn:SetPoint("RIGHT", gearBtn, "LEFT", -6, 0)
local statsTex = statsBtn:CreateTexture(nil, "ARTWORK")
statsTex:SetAllPoints()
statsTex:SetTexture("Interface\\AddOns\\MythicPlusHistory\\ICONS\\statistics_icon")
statsTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
statsTex:SetAlpha(0.55)
statsBtn.tex = statsTex
local statsHL = statsBtn:CreateTexture(nil, "HIGHLIGHT")
statsHL:SetAllPoints(); statsHL:SetColorTexture(1, 1, 1, 0.18)
statsBtn:SetScript("OnEnter", function(self) self.tex:SetAlpha(1.0) end)
statsBtn:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.55) end)
statsBtn:SetScript("OnClick", function()
    if statsPanel:IsShown() then
        statsPanel:Hide()
    else
        settingsPanel:Hide()
        notesPanel:Hide()
        statsPanel:Show()
        addon.RefreshStats()
    end
end)


local notesBtn = CreateFrame("Button", nil, mainFrame)
notesBtn:SetSize(20, 20)
notesBtn:SetPoint("RIGHT", statsBtn, "LEFT", -6, 0)
local notesTex = notesBtn:CreateTexture(nil, "ARTWORK")
notesTex:SetAllPoints()
notesTex:SetTexture("Interface\\AddOns\\MythicPlusHistory\\ICONS\\notes_icon")
notesTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
notesTex:SetAlpha(0.55)
notesBtn.tex = notesTex
local notesHL = notesBtn:CreateTexture(nil, "HIGHLIGHT")
notesHL:SetAllPoints(); notesHL:SetColorTexture(1, 1, 1, 0.18)
notesBtn:SetScript("OnEnter", function(self) self.tex:SetAlpha(1.0) end)
notesBtn:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.55) end)
notesBtn:SetScript("OnClick", function()
    if notesPanel:IsShown() then
        notesPanel:Hide()
    else
        settingsPanel:Hide()
        statsPanel:Hide()
        notesPanel:Show()
    end
end)


-- ─── Scale Slider ─────────────────────────────────────────────────────────────

local scaleLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -50)
scaleLabel:SetText("|cffaaaaaa Scale |r")

local scaleValueText = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleValueText:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -30, -50)
scaleValueText:SetJustifyH("RIGHT")
scaleValueText:SetText("100%")

local scaleSlider = CreateFrame("Slider", "MPHScaleSlider", mainFrame, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  52, -46)
scaleSlider:SetPoint("TOPRIGHT", scaleValueText, "TOPLEFT", -8, 4)

for _, key in ipairs({ "Text", "Low", "High" }) do
    local lbl = scaleSlider[key] or _G["MPHScaleSlider" .. key]
    if lbl then lbl:SetText(""); lbl:Hide() end
end

scaleSlider:SetMinMaxValues(0.5, 2.0)
scaleSlider:SetValueStep(0.05)
scaleSlider:SetValue(1.0)
scaleSlider:SetScript("OnValueChanged", function(self, value)
    scaleValueText:SetText(math.floor(value * 100 + 0.5) .. "%")
    mainFrame:SetScale(value)
    if addon.db then addon.db.window.scale = value end
end)


-- ─── Divider 1 ────────────────────────────────────────────────────────────────

local divider1 = mainFrame:CreateTexture(nil, "ARTWORK")
divider1:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8, -66)
divider1:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -66)
divider1:SetHeight(1)
divider1:SetColorTexture(0.3, 0.3, 0.4, 0.8)


addon.selectedRun = nil


-- ─── Detail Panel ─────────────────────────────────────────────────────────────

local detailPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
detailPanel:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8, -70)
detailPanel:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -70)
detailPanel:SetHeight(206)
detailPanel:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
detailPanel:SetBackdropColor(0.08, 0.08, 0.12, 0.7)
detailPanel:SetBackdropBorderColor(0.2, 0.2, 0.3, 0.5)

local detailPlaceholder = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
detailPlaceholder:SetPoint("CENTER", detailPanel, "CENTER")
detailPlaceholder:SetText("Click a run to view group details")
detailPlaceholder:Show()

local detailTitle = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detailTitle:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  6, -7)
detailTitle:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -6, -7)
detailTitle:SetJustifyH("LEFT")
detailTitle:Hide()

local detailSeparator = detailPanel:CreateTexture(nil, "ARTWORK")
detailSeparator:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  4, -38)
detailSeparator:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -4, -38)
detailSeparator:SetHeight(1)
detailSeparator:SetColorTexture(0.3, 0.3, 0.4, 0.45)
detailSeparator:Hide()

local detailInfo = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
detailInfo:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  6, -24)
detailInfo:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -6, -24)
detailInfo:SetJustifyH("LEFT")
detailInfo:Hide()

local memberCols = {}
for i = 1, 5 do
    local x   = 4 + (i - 1) * 100
    local col = {}

    local function FS(font, yOff)
        local fs = detailPanel:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, yOff)
        fs:SetWidth(96)
        fs:SetJustifyH("LEFT")
        fs:Hide()
        return fs
    end

    col.role  = FS("GameFontNormalSmall", -44)
    col.name  = FS("GameFontNormal",      -58)
    col.realm = FS("GameFontNormalSmall", -74)
    col.race  = FS("GameFontNormalSmall", -114)
    col.score = FS("GameFontNormalSmall", -130)
    col.name:SetWordWrap(false)
    col.race:SetWordWrap(false)

    col.noteBtn = CreateFrame("Button", nil, detailPanel)
    col.noteBtn:SetHeight(14)
    col.noteBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -148)
    col.noteBtn:SetWidth(96)
    col.noteBtn:Hide()
    col.noteLabel = col.noteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    col.noteLabel:SetPoint("LEFT", col.noteBtn, "LEFT", 0, 0)
    col.noteLabel:SetWidth(94)
    col.noteLabel:SetWordWrap(false)
    col.noteLabel:SetJustifyH("LEFT")
    col.noteBtn:SetScript("OnClick", function(self)
        if not self.playerKey then return end
        local popup = StaticPopup_Show("MYTHICPLUSHISTORY_PLAYER_NOTE", self.playerName or "?", nil, self.playerKey)
        if popup and popup.EditBox then
            popup.EditBox:SetText(addon.GetPlayerNote(self.playerKey) or "")
            popup.EditBox:SetFocus()
        end
    end)
    col.noteBtn:SetScript("OnEnter", function(self)
        if not self.playerKey then return end
        local note = addon.GetPlayerNote(self.playerKey)
        if note then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("|cffdddddd" .. (self.playerName or "?") .. "|r")
            GameTooltip:AddLine(note, 1, 1, 0.7, true)
            GameTooltip:Show()
        end
    end)
    col.noteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    col.classIcon = detailPanel:CreateTexture(nil, "ARTWORK")
    col.classIcon:SetSize(20, 20)
    col.classIcon:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -90)
    col.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    col.classIcon:Hide()

    col.specIcon = detailPanel:CreateTexture(nil, "ARTWORK")
    col.specIcon:SetSize(20, 20)
    col.specIcon:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x + 22, -90)
    col.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    col.specIcon:Hide()

    memberCols[i] = col
end

local function HideCol(col)
    col.role:Hide(); col.name:Hide(); col.realm:Hide()
    col.race:Hide(); col.score:Hide(); col.classIcon:Hide(); col.specIcon:Hide()
    col.noteBtn:Hide()
end


-- ─── Run Note (inside detail panel) ──────────────────────────────────────────

local runNoteSep = detailPanel:CreateTexture(nil, "ARTWORK")
runNoteSep:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",  4, -165)
runNoteSep:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -4, -165)
runNoteSep:SetHeight(1)
runNoteSep:SetColorTexture(0.3, 0.3, 0.4, 0.3)
runNoteSep:Hide()

local runNoteBox = CreateFrame("EditBox", nil, detailPanel, "BackdropTemplate")
runNoteBox:SetPoint("TOPLEFT",  detailPanel, "TOPLEFT",   6, -169)
runNoteBox:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -6, -169)
runNoteBox:SetHeight(28)
runNoteBox:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
runNoteBox:SetBackdropColor(0.08, 0.08, 0.12, 0.5)
runNoteBox:SetBackdropBorderColor(0.25, 0.25, 0.40, 0.5)
runNoteBox:SetAutoFocus(false)
runNoteBox:SetFontObject("GameFontNormalSmall")
runNoteBox:SetTextInsets(6, 4, 2, 2)
runNoteBox:SetMaxLetters(500)
runNoteBox:Hide()

local runNotePlaceholder = runNoteBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
runNotePlaceholder:SetPoint("LEFT", runNoteBox, "LEFT", 8, 0)
runNotePlaceholder:SetText("Add a note about this run…")
runNotePlaceholder:Show()

runNoteBox:SetScript("OnEditFocusGained", function(self)
    if self:GetText() == "" then runNotePlaceholder:Hide() end
end)
runNoteBox:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then runNotePlaceholder:Show() end
end)
runNoteBox:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then return end
    local text = self:GetText()
    if text == "" then runNotePlaceholder:Show() else runNotePlaceholder:Hide() end
    if addon.selectedRun then addon.selectedRun.note = text ~= "" and text or nil end
end)
runNoteBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
runNoteBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)


local function UpdateMemberColumns()
    local innerW = detailPanel:GetWidth()
    if innerW < 10 then return end
    innerW = innerW - 8
    local colW = math.floor(innerW / 5)
    local txtW = colW - 4

    for i, col in ipairs(memberCols) do
        local x = 4 + (i - 1) * colW
        col.role:ClearAllPoints();  col.role:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -44);  col.role:SetWidth(txtW)
        col.name:ClearAllPoints();  col.name:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -58);  col.name:SetWidth(txtW)
        col.realm:ClearAllPoints(); col.realm:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -74); col.realm:SetWidth(txtW)
        col.classIcon:ClearAllPoints(); col.classIcon:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -90)
        col.specIcon:ClearAllPoints();  col.specIcon:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x + 22, -90)
        col.race:ClearAllPoints();  col.race:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -114); col.race:SetWidth(txtW)
        col.score:ClearAllPoints(); col.score:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -130); col.score:SetWidth(txtW)
        col.noteBtn:ClearAllPoints(); col.noteBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", x, -148); col.noteBtn:SetWidth(txtW); col.noteLabel:SetWidth(txtW - 2)
    end
end

function addon.ShowRunDetail(run)
    detailPlaceholder:Hide()
    local resultStr
    if run.reset then resultStr = "|cffff8800Reset|r"
    elseif run.abandoned then resultStr = "|cff888888Abandoned|r"
    elseif run.completed then resultStr = run.onTime and "|cff00ff00Timed|r" or "|cffff4444Depleted|r"
    else resultStr = "|cff888888-----|r" end
    detailTitle:SetText("|cff00ccff" .. run.dungeon .. "  +" .. run.keyLevel .. "|r    " .. resultStr)
    detailTitle:Show()

    local timeMs = run.runTimeMs
    if not timeMs and run.startTime and run.endTime then
        timeMs = (run.endTime - run.startTime) * 1000
    end

    local upgradeStr
    if run.reset or run.abandoned then
        upgradeStr = "|cff888888—|r"
    elseif run.completed then
        local u = run.keystoneUpgrades or 0
        if     u >= 3 then upgradeStr = "|cff00ff00+3|r"
        elseif u == 2 then upgradeStr = "|cffffff00+2|r"
        elseif u == 1 then upgradeStr = "|cffffcc00+1|r"
        else               upgradeStr = "|cff666666+0|r" end
    else
        upgradeStr = "|cff888888—|r"
    end

    local deaths    = run.deathCount or 0
    local deathStr  = deaths > 0 and "|cffff6666" .. deaths .. "|r" or "|cff888888—|r"

    detailInfo:SetText(
        "|cff888888Time|r  |cffdddddd" .. addon.FormatTime(timeMs) .. "|r" ..
        "     |cff888888Key Upgrade|r  " .. upgradeStr ..
        "     |cff888888Deaths|r  " .. deathStr)
    detailInfo:Show()
    detailSeparator:Show()

    local order  = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
    local sorted = {}
    for _, m in ipairs(run.members or {}) do table.insert(sorted, m) end
    table.sort(sorted, function(a, b) return (order[a.role] or 4) < (order[b.role] or 4) end)

    for i = 1, 5 do
        local col = memberCols[i]; local member = sorted[i]
        if member then
            local role = member.role or "NONE"
            col.role:SetText((ROLE_COLOR[role] or "|cffffffff") .. (ROLE_LABEL[role] or role) .. "|r"); col.role:Show()
            local cc = RAID_CLASS_COLORS[member.class] or { r=1, g=1, b=1 }
            col.name:SetText(string.format("|cff%02x%02x%02x%s|r", cc.r*255, cc.g*255, cc.b*255, member.name or "?")); col.name:Show()
            col.realm:SetText("|cff888888" .. (member.realm or "?") .. "|r"); col.realm:Show()
            local classPath = CLASS_ICON[member.class]
            if classPath then col.classIcon:SetTexture(classPath); col.classIcon:Show() else col.classIcon:Hide() end
            local specIconID = member.spec and GetSpecIconID(member.class, member.spec) or nil
            if specIconID then col.specIcon:SetTexture(specIconID); col.specIcon:Show() else col.specIcon:Hide() end
            if member.race then col.race:SetText("|cffaaaaaa" .. member.race .. "|r"); col.race:Show() else col.race:Hide() end
            if member.mythicScore and member.mythicScore > 0 then
                col.score:SetText("|cffffff44" .. member.mythicScore .. "|r")
                col.score:Show()
            else
                col.score:Hide()
            end

            local pKey = (member.name or "?") .. "-" .. (member.realm or "")
            col.noteBtn.playerKey  = pKey
            col.noteBtn.playerName = member.name or "?"
            local pNote = addon.GetPlayerNote(pKey)
            if pNote then
                local preview = pNote:len() > 20 and pNote:sub(1, 20) .. "…" or pNote
                col.noteLabel:SetText("|cffffff88" .. preview .. "|r")
            else
                col.noteLabel:SetText("|cff555555[add note]|r")
            end
            col.noteBtn:Show()
        else
            HideCol(col)
        end
    end

    runNoteBox:SetText(run.note or "")
    if run.note and run.note ~= "" then runNotePlaceholder:Hide() else runNotePlaceholder:Show() end
    runNoteSep:Show()
    runNoteBox:Show()
end

function addon.ClearRunDetail()
    detailTitle:Hide(); detailInfo:Hide(); detailSeparator:Hide(); detailPlaceholder:Show()
    runNoteSep:Hide(); runNoteBox:Hide(); runNoteBox:ClearFocus()
    for i = 1, 5 do HideCol(memberCols[i]) end
end


-- ─── Divider 2 (under detail panel) ──────────────────────────────────────────

local divider2 = mainFrame:CreateTexture(nil, "ARTWORK")
divider2:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8, -280)
divider2:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -8, -280)
divider2:SetHeight(1)
divider2:SetColorTexture(0.3, 0.3, 0.4, 0.8)


-- ─── Search Box ───────────────────────────────────────────────────────────────

local searchBox = CreateFrame("EditBox", "MythicPlusHistorySearch", mainFrame, "BackdropTemplate")
searchBox:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8,   -284)
searchBox:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -28, -284)
searchBox:SetHeight(22)
searchBox:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
searchBox:SetBackdropColor(0.10, 0.10, 0.15, 0.9)
searchBox:SetBackdropBorderColor(0.30, 0.30, 0.50, 0.8)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("GameFontNormalSmall")
searchBox:SetTextInsets(6, 4, 2, 2)
searchBox:SetMaxLetters(64)

local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
searchHint:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
searchHint:SetText("Search by dungeon, player, date, timed/depleted…")
searchHint:Show()


-- ─── Run Count + Test Button ──────────────────────────────────────────────────

local runCountLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
runCountLabel:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 12, -312)
runCountLabel:SetText("Total Runs: 0")


-- ─── Autocomplete Dropdown ────────────────────────────────────────────────────

local AC_MAX     = 7
local acDropdown = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
acDropdown:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  8,   -308)
acDropdown:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -28, -308)
acDropdown:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
acDropdown:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
acDropdown:SetBackdropColor(0.10, 0.12, 0.18, 0.97)
acDropdown:SetBackdropBorderColor(0.40, 0.40, 0.60, 1)
acDropdown:Hide()

local acButtons = {}
for i = 1, AC_MAX do
    local btn = CreateFrame("Button", nil, acDropdown)
    btn:SetHeight(18)
    btn:SetPoint("TOPLEFT",  acDropdown, "TOPLEFT",  3, -2 - (i-1)*18)
    btn:SetPoint("TOPRIGHT", acDropdown, "TOPRIGHT", -3, -2 - (i-1)*18)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0); btn.bg = bg
    btn:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.2,0.3,0.5,0.5) end)
    btn:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0,0,0,0) end)
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); label:SetPoint("LEFT", btn, "LEFT", 4, 0); btn.label = label
    btn:SetScript("OnClick", function(self)
        searchBox:SetText(self.value or ""); acDropdown:Hide()
        if addon.RefreshUI then addon.RefreshUI() end
    end)
    acButtons[i] = btn; btn:Hide()
end

local function GetSuggestions(query)
    if not query or #query < 1 then return {} end
    local q, results, seen = query:lower(), {}, {}
    for _, kw in ipairs({ "Timed", "Depleted", "Abandoned" }) do
        if kw:lower():find(q,1,true) and not seen[kw] then table.insert(results,kw); seen[kw]=true end
    end
    if addon.GetRuns then
        for _, run in ipairs(addon.GetRuns()) do
            local d = run.dungeon
            if d and d:lower():find(q,1,true) and not seen[d] then table.insert(results,d); seen[d]=true end
            for _, m in ipairs(run.members or {}) do
                local n = m.name
                if n and n:lower():find(q,1,true) and not seen[n] then table.insert(results,n); seen[n]=true end
            end
        end
    end
    return results
end

local function UpdateAutocomplete(query)
    if not query or #query < 1 then acDropdown:Hide(); return end
    local suggestions = GetSuggestions(query)
    local count = math.min(#suggestions, AC_MAX)
    if count == 0 then acDropdown:Hide(); return end
    for i = 1, AC_MAX do
        if i <= count then acButtons[i].value = suggestions[i]; acButtons[i].label:SetText(suggestions[i]); acButtons[i]:Show()
        else acButtons[i]:Hide() end
    end
    acDropdown:SetHeight(count * 18 + 4); acDropdown:Show()
end

searchBox:SetScript("OnEditFocusGained", function(self)
    self:SetText("")
    searchHint:Hide()
    if addon.RefreshUI then addon.RefreshUI() end
end)
searchBox:SetScript("OnEditFocusLost",   function(self)
    if self:GetText() == "" then searchHint:Show() end
    C_Timer.After(0.15, function() acDropdown:Hide() end)
end)
searchBox:SetScript("OnTextChanged", function(self)
    local text = self:GetText()
    if text == "" then searchHint:Show() else searchHint:Hide() end
    if addon.RefreshUI then addon.RefreshUI() end
    UpdateAutocomplete(text)
end)
searchBox:SetScript("OnEnterPressed",  function(self) acDropdown:Hide(); self:ClearFocus() end)
searchBox:SetScript("OnEscapePressed", function(self)
    self:SetText(""); acDropdown:Hide(); self:ClearFocus()
    if addon.RefreshUI then addon.RefreshUI() end
end)


-- ─── Scroll Frame ─────────────────────────────────────────────────────────────

local scrollFrame = CreateFrame("ScrollFrame", nil, mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",    8,  -336)
scrollFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -28, 8)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(content)


-- ─── In-Progress Banner ───────────────────────────────────────────────────────

local IN_PROGRESS_HEIGHT = 30

local inProgressRow = CreateFrame("Frame", nil, content, "BackdropTemplate")
inProgressRow:SetHeight(IN_PROGRESS_HEIGHT)
inProgressRow:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, 0)
inProgressRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
inProgressRow:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
inProgressRow:SetBackdropColor(0.04, 0.16, 0.07, 0.95)
inProgressRow:SetBackdropBorderColor(0.1, 0.75, 0.25, 0.9)
inProgressRow:Hide()

local ipStatus = inProgressRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ipStatus:SetPoint("LEFT", inProgressRow, "LEFT", 8, 0)
ipStatus:SetText("|cff00ee44>> IN PROGRESS|r")

local ipStopBtn = CreateFrame("Button", nil, inProgressRow, "BackdropTemplate")
ipStopBtn:SetSize(88, 20)
ipStopBtn:SetPoint("RIGHT", inProgressRow, "RIGHT", -4, 0)
ipStopBtn:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
ipStopBtn:SetBackdropColor(0.25, 0.05, 0.05, 0.9)
ipStopBtn:SetBackdropBorderColor(0.6, 0.15, 0.15, 0.85)
local ipStopLabel = ipStopBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ipStopLabel:SetPoint("CENTER"); ipStopLabel:SetText("|cffff5555[X] Force Stop|r")
ipStopBtn:SetScript("OnEnter", function(self)
    self:SetBackdropColor(0.4, 0.05, 0.05, 0.95); self:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
end)
ipStopBtn:SetScript("OnLeave", function(self)
    self:SetBackdropColor(0.25, 0.05, 0.05, 0.9); self:SetBackdropBorderColor(0.6, 0.15, 0.15, 0.85)
end)
ipStopBtn:SetScript("OnClick", function()
    if addon.ForceStopRun then addon.ForceStopRun() end
end)

local ipTimer = inProgressRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ipTimer:SetPoint("RIGHT", ipStopBtn, "LEFT", -8, 0)
ipTimer:SetJustifyH("RIGHT")
ipTimer:SetText("|cffffff00--:--|r")
inProgressRow.timerText = ipTimer

local ipRun = inProgressRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
ipRun:SetPoint("LEFT", inProgressRow, "LEFT", 128, 0)
inProgressRow.runText = ipRun


-- ─── Resize Handle ────────────────────────────────────────────────────────────

local resizeHandle = CreateFrame("Button", nil, mainFrame)
resizeHandle:SetSize(16, 16)
resizeHandle:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", 0, 0)
resizeHandle:EnableMouse(true)
resizeHandle:SetFrameLevel(mainFrame:GetFrameLevel() + 5)

local gripTex = resizeHandle:CreateTexture(nil, "OVERLAY")
gripTex:SetAllPoints()
gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeHandle:SetScript("OnEnter", function() gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight") end)
resizeHandle:SetScript("OnLeave", function() gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end)
resizeHandle:SetScript("OnMouseDown", function() mainFrame:StartSizing("BOTTOMRIGHT"); mainFrame:Raise() end)
resizeHandle:SetScript("OnMouseUp", function()
    mainFrame:StopMovingOrSizing()
    if addon.db then addon.db.window.width = mainFrame:GetWidth(); addon.db.window.height = mainFrame:GetHeight() end
    C_Timer.After(0, function()
        UpdateMemberColumns()
        content:SetWidth(scrollFrame:GetWidth())
        if addon.RefreshUI then addon.RefreshUI() end
    end)
end)


-- ─── Row Builder ──────────────────────────────────────────────────────────────

local ROW_HEIGHT         = 20
local rows               = {}
local ROW_COLOR_EVEN     = { 0.12, 0.12, 0.16, 0.6 }
local ROW_COLOR_ODD      = { 0.08, 0.08, 0.10, 0.4 }
local ROW_COLOR_SELECTED = { 0.20, 0.25, 0.35, 0.85 }

local HEADER_HEIGHT  = 22
local headerRows     = {}
local collapsedDates = {}

local function GetOrCreateRow(index)
    if rows[index] then return rows[index] end
    local row = CreateFrame("Button", nil, content, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("LEFT",  content, "LEFT",  0, 0)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); row.bg = bg

    local function MakeText(anchor, xOffset, justify)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint(anchor, row, anchor, xOffset, 0); fs:SetJustifyH(justify or "LEFT"); return fs
    end
    row.dateText    = MakeText("LEFT",   4,  "LEFT")
    row.dungeonText = MakeText("LEFT", 118,  "LEFT")
    row.levelText   = MakeText("LEFT",  280, "LEFT")
    row.timeText    = MakeText("LEFT",  330, "LEFT"); row.timeText:SetWidth(40)
    row.resultText  = MakeText("RIGHT", -26, "RIGHT")
    row.noteIcon = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.noteIcon:SetPoint("LEFT", row, "LEFT", 308, 0)

    local deleteBtn = CreateFrame("Button", nil, row)
    deleteBtn:SetSize(18, ROW_HEIGHT)
    deleteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    deleteBtn:SetFrameLevel(row:GetFrameLevel() + 2)
    local deleteBg = deleteBtn:CreateTexture(nil, "BACKGROUND")
    deleteBg:SetAllPoints(); deleteBg:SetColorTexture(0.6, 0.1, 0.1, 0)
    local deleteLabel = deleteBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    deleteLabel:SetPoint("CENTER"); deleteLabel:SetText("|cffaa3333\195\151|r")
    deleteBtn:SetScript("OnEnter", function(self)
        deleteBg:SetColorTexture(0.7, 0.1, 0.1, 0.75)
        deleteLabel:SetText("|cffff5555\195\151|r")
        GameTooltip:Hide()
    end)
    deleteBtn:SetScript("OnLeave", function(self)
        deleteBg:SetColorTexture(0.6, 0.1, 0.1, 0)
        deleteLabel:SetText("|cffaa3333\195\151|r")
    end)
    deleteBtn:SetScript("OnClick", function(self)
        local run = self:GetParent().runData
        if not run then return end
        StaticPopup_Show("MYTHICPLUSHISTORY_DELETE_RUN",
            run.dungeon or "Unknown", tostring(run.keyLevel or "?"), run)
    end)
    row.deleteBtn = deleteBtn

    row:SetScript("OnEnter", function(self)
        if not self.runData then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText("|cff00ccff" .. self.runData.dungeon .. " +" .. self.runData.keyLevel .. "|r")
        GameTooltip:AddLine(" "); GameTooltip:AddLine("|cffffd700Group:|r")
        for _, member in ipairs(self.runData.members or {}) do
            local cc = RAID_CLASS_COLORS[member.class] or {r=1,g=1,b=1}
            local rl = ROLE_LABEL[member.role] or member.role or "?"
            GameTooltip:AddLine(string.format("|cff%02x%02x%02x  %s|r  |cff888888(%s — %s)|r",
                cc.r*255, cc.g*255, cc.b*255, member.name, member.realm, rl), 1,1,1)
        end
        if self.runData.note and self.runData.note ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("|cff66aaff[Note]|r " .. self.runData.note, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self)
        if not self.runData then return end
        addon.selectedRun = self.runData; addon.ShowRunDetail(self.runData)
        if addon.RefreshUI then addon.RefreshUI() end
    end)
    rows[index] = row; return row
end


-- ─── Date Group Helpers ───────────────────────────────────────────────────────

local function FormatDateLabel(dayKey)
    local today     = date("%Y%m%d")
    local yesterday = date("%Y%m%d", time() - 86400)
    if dayKey == today          then return "|cffffff00Today|r"
    elseif dayKey == yesterday  then return "|cffd0d0d0Yesterday|r"
    else
        local y = tonumber(dayKey:sub(1,4))
        local m = tonumber(dayKey:sub(5,6))
        local d = tonumber(dayKey:sub(7,8))
        return "|cffd0d0d0" .. date("%b %d, %Y", time({year=y, month=m, day=d, hour=12, min=0, sec=0})) .. "|r"
    end
end

local function GroupSummary(runs)
    local t, d, a, r = 0, 0, 0, 0
    for _, run in ipairs(runs) do
        if run.reset         then r = r + 1
        elseif run.abandoned then a = a + 1
        elseif run.completed and run.onTime then t = t + 1
        elseif run.completed then d = d + 1 end
    end
    local parts = {}
    if t > 0 then table.insert(parts, "|cff00ff00" .. t .. "T|r") end
    if d > 0 then table.insert(parts, "|cffff4444" .. d .. "D|r") end
    if a > 0 then table.insert(parts, "|cff888888" .. a .. "A|r") end
    if r > 0 then table.insert(parts, "|cffff8800" .. r .. "R|r") end
    return table.concat(parts, "  ")
end

local function GetOrCreateHeaderRow(index)
    if headerRows[index] then return headerRows[index] end
    local h = CreateFrame("Button", nil, content, "BackdropTemplate")
    h:SetHeight(HEADER_HEIGHT)
    h:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 1, bottom = 1 },
    })
    h:SetBackdropColor(0.08, 0.08, 0.18, 0.9)
    h:SetBackdropBorderColor(0.25, 0.25, 0.45, 0.7)

    h.arrow = h:CreateTexture(nil, "OVERLAY")
    h.arrow:SetSize(14, 14)
    h.arrow:SetPoint("LEFT", h, "LEFT", 6, 0)

    h.dateLabel = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.dateLabel:SetPoint("LEFT", h, "LEFT", 22, 0)

    h.countLabel = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.countLabel:SetPoint("LEFT", h, "LEFT", 150, 0)

    h.summaryLabel = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.summaryLabel:SetPoint("RIGHT", h, "RIGHT", -30, 0)
    h.summaryLabel:SetJustifyH("RIGHT")

    h:SetScript("OnEnter", function(self) self:SetBackdropColor(0.12, 0.12, 0.25, 0.95) end)
    h:SetScript("OnLeave", function(self) self:SetBackdropColor(0.08, 0.08, 0.18, 0.9) end)
    h:SetScript("OnClick", function(self)
        if self.dayKey then
            collapsedDates[self.dayKey] = not collapsedDates[self.dayKey]
            if addon.RefreshUI then addon.RefreshUI() end
        end
    end)

    headerRows[index] = h
    return h
end


-- ─── Filter ───────────────────────────────────────────────────────────────────

local function RunMatchesFilter(run, query)
    if not query or query == "" then return true end
    local q = query:lower()
    if q == "timed"     then return run.completed and run.onTime end
    if q == "depleted"  then return run.completed and not run.onTime and not run.abandoned end
    if q == "abandoned" then return run.abandoned end
    if q == "reset"     then return run.reset end
    local level = q:match("^%+?(%d+)$")
    if level then return tostring(run.keyLevel) == level end
    if run.dungeon and run.dungeon:lower():find(q,1,true) then return true end
    local dateStr = addon.FormatDate and addon.FormatDate(run.startTime) or ""
    if dateStr:find(q,1,true) then return true end
    for _, m in ipairs(run.members or {}) do
        if m.name and m.name:lower():find(q,1,true) then return true end
    end
    return false
end


-- ─── Live Timer ──────────────────────────────────────────────────────────────

local liveTimerTicker = nil

local function StartLiveTimer()
    if liveTimerTicker then return end
    liveTimerTicker = C_Timer.NewTicker(1, function()
        if not mainFrame:IsShown() then return end
        local ar = addon.GetActiveRun and addon.GetActiveRun()
        if not ar then return end
        local elapsed = (time() - (ar.startTime or 0)) * 1000
        inProgressRow.timerText:SetText("|cffffff00" .. addon.FormatTime(elapsed) .. "|r")
    end)
end

local function StopLiveTimer()
    if liveTimerTicker then liveTimerTicker:Cancel(); liveTimerTicker = nil end
end


-- ─── Refresh ──────────────────────────────────────────────────────────────────

local function RenderRunRow(row, run, yOff, colorOverride)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -yOff)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOff)
    row.bg:SetColorTexture(unpack(colorOverride or ROW_COLOR_ODD))
    row.dateText:SetText(addon.FormatDate(run.startTime) .. "  " .. addon.FormatStartTime(run.startTime))
    row.dungeonText:SetText(run.dungeon or "Unknown")
    row.levelText:SetText("|cffffff00+" .. (run.keyLevel or "?") .. "|r")
    row.timeText:SetText(addon.FormatTime(run.runTimeMs))
    if run.reset then row.resultText:SetText("|cffff8800Reset|r")
    elseif run.abandoned then row.resultText:SetText("|cff888888Abandoned|r")
    elseif run.completed and run.onTime then row.resultText:SetText("|cff00ff00Timed|r")
    elseif run.completed then row.resultText:SetText("|cffff4444Depleted|r")
    else row.resultText:SetText("|cff888888-----|r") end
    row.noteIcon:SetText((run.note and run.note ~= "") and "|cff66aaff*|r" or "")
    row.runData = run; row:Show()
end

function addon.RefreshUI()
    if not mainFrame:IsShown() then return end
    content:SetWidth(scrollFrame:GetWidth())

    local ar = addon.GetActiveRun and addon.GetActiveRun()
    local inProgressOffset = 0
    if ar then
        inProgressRow.runText:SetText(
            "|cffffd700" .. (ar.dungeon or "Unknown") .. "  +" .. (ar.keyLevel or "?") .. "|r")
        local elapsed = (time() - (ar.startTime or 0)) * 1000
        inProgressRow.timerText:SetText("|cffffff00" .. addon.FormatTime(elapsed) .. "|r")
        inProgressRow:Show()
        inProgressOffset = IN_PROGRESS_HEIGHT
        StartLiveTimer()
        testBtn:SetText("|cffff8844Stop Test|r")
    else
        inProgressRow:Hide()
        StopLiveTimer()
        testBtn:SetText("+ Test Run")
    end

    local query      = searchBox and searchBox:GetText() or ""
    local allRuns    = addon.GetDisplayRuns()
    local total      = #allRuns
    local grandTotal = addon.GetRunCount()
    local isCharMode = addon.db and addon.db.settings and addon.db.settings.trackingMode == "character"

    for _, row in ipairs(rows)       do row:Hide() end
    for _, h   in ipairs(headerRows) do h:Hide()   end

    if total == 0 then
        content:SetHeight(1)
        if isCharMode and grandTotal > 0 then
            runCountLabel:SetText("Runs: 0  |cff888888(" .. grandTotal .. " account-wide)|r")
        else
            runCountLabel:SetText("Total Runs: 0")
        end
        return
    end

    if query ~= "" then
        -- ── Flat search: all matching runs, no grouping ──────────────────────
        local filtered = {}
        for i = total, 1, -1 do
            if RunMatchesFilter(allRuns[i], query) then table.insert(filtered, allRuns[i]) end
        end
        if isCharMode then
            runCountLabel:SetText("Runs: " .. total .. "  |cff888888(of " .. grandTotal .. " account-wide, showing " .. #filtered .. ")|r")
        else
            runCountLabel:SetText("Total Runs: " .. total .. "  |cff888888(showing " .. #filtered .. ")|r")
        end
        if #filtered == 0 then content:SetHeight(1); return end
        for idx, run in ipairs(filtered) do
            local color = run == addon.selectedRun and ROW_COLOR_SELECTED
                          or ((idx % 2 == 0) and ROW_COLOR_EVEN or ROW_COLOR_ODD)
            RenderRunRow(GetOrCreateRow(idx), run, (idx - 1) * ROW_HEIGHT + inProgressOffset, color)
        end
        content:SetHeight(#filtered * ROW_HEIGHT + inProgressOffset)
    else
        -- ── Grouped by date, newest first ────────────────────────────────────
        local dayOrder  = {}
        local dayGroups = {}
        for i = total, 1, -1 do
            local run    = allRuns[i]
            local dayKey = date("%Y%m%d", run.startTime or 0)
            if not dayGroups[dayKey] then
                table.insert(dayOrder, dayKey)
                dayGroups[dayKey] = {}
            end
            table.insert(dayGroups[dayKey], run)
        end

        if isCharMode then
            runCountLabel:SetText("Runs: " .. total .. "  |cff888888(" .. grandTotal .. " account-wide)|r")
        else
            runCountLabel:SetText("Total Runs: " .. total)
        end

        local yOff   = inProgressOffset
        local runIdx = 0
        local hdrIdx = 0
        for _, dayKey in ipairs(dayOrder) do
            local runs      = dayGroups[dayKey]
            local collapsed = collapsedDates[dayKey]

            -- Date group header
            hdrIdx = hdrIdx + 1
            local h = GetOrCreateHeaderRow(hdrIdx)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -yOff)
            h:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOff)
            h.dayKey = dayKey
            h.arrow:SetTexture(collapsed
    and "Interface\\AddOns\\MythicPlusHistory\\ICONS\\arrow_right"
    or  "Interface\\AddOns\\MythicPlusHistory\\ICONS\\arrow_down")
            h.dateLabel:SetText(FormatDateLabel(dayKey))
            h.countLabel:SetText("|cff888888" .. #runs .. " run" .. (#runs == 1 and "" or "s") .. "|r")
            h.summaryLabel:SetText(GroupSummary(runs))
            h:Show()
            yOff = yOff + HEADER_HEIGHT

            -- Run rows (hidden when group is collapsed)
            if not collapsed then
                for _, run in ipairs(runs) do
                    runIdx = runIdx + 1
                    local color = run == addon.selectedRun and ROW_COLOR_SELECTED or ROW_COLOR_ODD
                    RenderRunRow(GetOrCreateRow(runIdx), run, yOff, color)
                    yOff = yOff + ROW_HEIGHT
                end
            end
        end
        content:SetHeight(math.max(yOff, 1))
    end
end


-- ─── Settings Panel ──────────────────────────────────────────────────────────

settingsPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
settingsPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     8, -70)
settingsPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8,  8)
settingsPanel:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
settingsPanel:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
settingsPanel:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
settingsPanel:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
settingsPanel:Hide()

local stTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
stTitle:SetPoint("TOP", settingsPanel, "TOP", 0, -16)
stTitle:SetText("|cffaaccffSettings|r")

local stDiv = settingsPanel:CreateTexture(nil, "ARTWORK")
stDiv:SetPoint("TOPLEFT",  settingsPanel, "TOPLEFT",   8, -40)
stDiv:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT",  -8, -40)
stDiv:SetHeight(1)
stDiv:SetColorTexture(0.3, 0.3, 0.4, 0.6)

local stCloseBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelCloseButton")
stCloseBtn:SetSize(28, 28)
stCloseBtn:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", 2, 2)
stCloseBtn:SetScript("OnClick", function() settingsPanel:Hide() end)

local function CreateOptionGroup(parent, yTop, header, opts)
    local hdr = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hdr:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yTop)
    hdr:SetText("|cffdddddd" .. header .. "|r")

    local group = { buttons = {} }

    local function SelectBtn(btn)
        for _, b in ipairs(group.buttons) do
            b.selected = false
            b:SetBackdropColor(0.08, 0.08, 0.14, 0.8)
            b:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6)
            b.dot:SetColorTexture(0.25, 0.25, 0.35, 1)
            b.lbl:SetTextColor(0.65, 0.65, 0.65)
        end
        btn.selected = true
        btn:SetBackdropColor(0.08, 0.14, 0.26, 0.9)
        btn:SetBackdropBorderColor(0.2, 0.45, 0.75, 1)
        btn.dot:SetColorTexture(0.15, 0.55, 1.0, 1)
        btn.lbl:SetTextColor(1, 1, 1)
        group.selected = btn.value
        if group.onChange then group.onChange(btn.value) end
    end

    for i, opt in ipairs(opts) do
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetHeight(32)
        btn:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yTop - 24 - (i-1) * 38)
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yTop - 24 - (i-1) * 38)
        btn:SetBackdrop({
            bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        btn:SetBackdropColor(0.08, 0.08, 0.14, 0.8)
        btn:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6)

        local dot = btn:CreateTexture(nil, "ARTWORK")
        dot:SetSize(10, 10)
        dot:SetPoint("LEFT", btn, "LEFT", 12, 0)
        dot:SetColorTexture(0.25, 0.25, 0.35, 1)
        btn.dot = dot

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", btn, "LEFT", 30, 0)
        lbl:SetTextColor(0.65, 0.65, 0.65)
        lbl:SetText(opt.label)
        btn.lbl = lbl

        btn.value    = opt.value
        btn.selected = false

        btn:SetScript("OnEnter", function(self)
            if not self.selected then self:SetBackdropBorderColor(0.3, 0.3, 0.5, 0.8) end
        end)
        btn:SetScript("OnLeave", function(self)
            if not self.selected then self:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6) end
        end)
        btn:SetScript("OnClick", function(self) SelectBtn(self) end)
        table.insert(group.buttons, btn)
    end

    function group.SetValue(val)
        for _, b in ipairs(group.buttons) do
            if b.value == val then SelectBtn(b); return end
        end
    end
    function group.GetValue() return group.selected end
    group.totalHeight = 24 + #opts * 38
    return group
end

timeGroup = CreateOptionGroup(settingsPanel, -50, "Time Format", {
    { value = "12h", label = "12-hour  (e.g. 11:41 PM)" },
    { value = "24h", label = "24-hour  (e.g. 23:41)" },
})
timeGroup.onChange = function(val)
    if addon.db and addon.db.settings then
        addon.db.settings.timeFormat = val
        if addon.RefreshUI then addon.RefreshUI() end
    end
end

trackGroup = CreateOptionGroup(settingsPanel, -50 - timeGroup.totalHeight - 20, "Run Tracking", {
    { value = "account",   label = "Account-wide  (all characters)" },
    { value = "character", label = "This character only" },
})
trackGroup.onChange = function(val)
    if addon.db and addon.db.settings then
        addon.db.settings.trackingMode = val
        if addon.RefreshUI then addon.RefreshUI() end
    end
end

local stTestDiv = settingsPanel:CreateTexture(nil, "ARTWORK")
stTestDiv:SetPoint("TOPLEFT",  settingsPanel, "TOPLEFT",   8, -280)
stTestDiv:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT",  -8, -280)
stTestDiv:SetHeight(1)
stTestDiv:SetColorTexture(0.3, 0.3, 0.4, 0.6)

local stTestHeader = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
stTestHeader:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 16, -292)
stTestHeader:SetText("|cffddddddTesting|r")

testBtn = CreateFrame("Button", nil, settingsPanel, "UIPanelButtonTemplate")
testBtn:SetSize(130, 24)
testBtn:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 16, -316)
testBtn:SetText("+ Test Run")
testBtn:SetScript("OnClick", function()
    if addon.GetActiveRun and addon.GetActiveRun() then
        if addon.ForceStopRun then addon.ForceStopRun() end
    else
        if addon.CreateTestActiveRun then addon.CreateTestActiveRun() end
    end
end)


-- ─── Statistics Panel ────────────────────────────────────────────────────────
local SP_COLS = { 4, 162, 202, 242, 282, 346, 406 }

statsPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
statsPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     8, -70)
statsPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8,  8)
statsPanel:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
statsPanel:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
statsPanel:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
statsPanel:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
statsPanel:Hide()

local spTitle = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
spTitle:SetPoint("TOP", statsPanel, "TOP", 0, -16)
spTitle:SetText("|cffaaccffStatistics|r")

local spCloseBtn = CreateFrame("Button", nil, statsPanel, "UIPanelCloseButton")
spCloseBtn:SetSize(28, 28)
spCloseBtn:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT", 2, 2)
spCloseBtn:SetScript("OnClick", function() statsPanel:Hide() end)

local spDiv1 = statsPanel:CreateTexture(nil, "ARTWORK")
spDiv1:SetPoint("TOPLEFT",  statsPanel, "TOPLEFT",   8, -40)
spDiv1:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT",  -8, -40)
spDiv1:SetHeight(1); spDiv1:SetColorTexture(0.3, 0.3, 0.4, 0.6)

-- Overall summary labels
local spStatLabels = {}
local SP_STAT_KEYS = {
    { key = "total",    label = "Total Runs",   color = "|cffffff00" },
    { key = "timed",    label = "Timed",        color = "|cff00ff00" },
    { key = "depleted", label = "Depleted",     color = "|cffff4444" },
    { key = "notdone",  label = "Abandon/Reset", color = "|cff888888" },
}
for i, def in ipairs(SP_STAT_KEYS) do
    local col = math.floor((i - 1) / 3)
    local row = (i - 1) % 3
    local fs = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 16 + col * 200, -52 - row * 22)
    spStatLabels[def.key] = { fs = fs, color = def.color, label = def.label }
end

local spDiv2 = statsPanel:CreateTexture(nil, "ARTWORK")
spDiv2:SetPoint("TOPLEFT",  statsPanel, "TOPLEFT",   8, -124)
spDiv2:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT",  -8, -124)
spDiv2:SetHeight(1); spDiv2:SetColorTexture(0.3, 0.3, 0.4, 0.6)

local spDungTitle = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
spDungTitle:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 16, -136)
spDungTitle:SetText("|cffddddddPer Dungeon|r")

local function MakeKeyBox(parent)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(40, 22)
    box:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0.12, 0.12, 0.22, 0.95)
    box:SetBackdropBorderColor(0.55, 0.55, 0.80, 1.0)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormal")
    box:SetTextInsets(5, 4, 2, 2)
    box:SetMaxLetters(3)
    box:SetNumeric(true)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function() addon.RefreshStats() end)
    return box
end

local spMaxBox = MakeKeyBox(statsPanel)
spMaxBox:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT", -12, -132)

local spDashLbl = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spDashLbl:SetPoint("RIGHT", spMaxBox, "LEFT", -5, 0)
spDashLbl:SetText("|cffdddddd-|r")

local spMinBox = MakeKeyBox(statsPanel)
spMinBox:SetPoint("RIGHT", spDashLbl, "LEFT", -5, 0)

local spRangeLbl = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spRangeLbl:SetPoint("RIGHT", spMinBox, "LEFT", -6, 0)
spRangeLbl:SetText("|cffddddddKey +|r")

local spDateFilter = "all"  -- "all" | "this" | "last"

local function GetResetStart(weeksAgo)
    weeksAgo = weeksAgo or 0
    local now   = time()
    local t     = date("*t", now)
    local daysSinceTue = (t.wday - 3 + 7) % 7
    local todayMidnight = now - (t.hour * 3600 + t.min * 60 + t.sec)
    return todayMidnight - daysSinceTue * 86400 - weeksAgo * 604800
end

local spDateBtns = {}
local DATE_OPTS  = {
    { key = "all",  label = "All Time"    },
    { key = "this", label = "This Reset"  },
    { key = "last", label = "Last Reset"  },
}

local function SelectDateBtn(key)
    spDateFilter = key
    for _, b in ipairs(spDateBtns) do
        if b.key == key then
            b:SetBackdropColor(0.08, 0.18, 0.32, 0.95)
            b:SetBackdropBorderColor(0.25, 0.55, 0.90, 1)
            b.lbl:SetTextColor(1, 1, 1)
        else
            b:SetBackdropColor(0.08, 0.08, 0.14, 0.8)
            b:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6)
            b.lbl:SetTextColor(0.6, 0.6, 0.6)
        end
    end
    if addon.RefreshStats then addon.RefreshStats() end
end

for i, opt in ipairs(DATE_OPTS) do
    local btn = CreateFrame("Button", nil, statsPanel, "BackdropTemplate")
    btn:SetHeight(20)
    btn:SetPoint("TOPLEFT",  statsPanel, "TOPLEFT",  12 + (i - 1) * 118, -158)
    btn:SetWidth(110)
    btn:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.08, 0.08, 0.14, 0.8)
    btn:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER"); lbl:SetText(opt.label); lbl:SetTextColor(0.6, 0.6, 0.6)
    btn.lbl = lbl; btn.key = opt.key
    btn:SetScript("OnEnter", function(self)
        if self.key ~= spDateFilter then self:SetBackdropBorderColor(0.3, 0.3, 0.5, 0.8) end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.key ~= spDateFilter then self:SetBackdropBorderColor(0.2, 0.2, 0.35, 0.6) end
    end)
    btn:SetScript("OnClick", function(self) SelectDateBtn(self.key) end)
    spDateBtns[i] = btn
end
SelectDateBtn("all")

-- Dungeon filter dropdown
local spDungFilter = "all"

local spDungDropdown = CreateFrame("Frame", nil, statsPanel, "BackdropTemplate")
spDungDropdown:SetFrameLevel(statsPanel:GetFrameLevel() + 15)
spDungDropdown:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
spDungDropdown:SetBackdropColor(0.08, 0.08, 0.16, 0.98)
spDungDropdown:SetBackdropBorderColor(0.40, 0.40, 0.65, 1)
spDungDropdown:Hide()

local spDungRowPool = {}
local function GetOrCreateDDRow(i)
    if spDungRowPool[i] then return spDungRowPool[i] end
    local r = CreateFrame("Button", nil, spDungDropdown)
    r:SetHeight(20)
    r:SetPoint("TOPLEFT",  spDungDropdown, "TOPLEFT",  3, -2 - (i-1)*20)
    r:SetPoint("TOPRIGHT", spDungDropdown, "TOPRIGHT", -3, -2 - (i-1)*20)
    local bg = r:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0); r.bg=bg
    local lbl = r:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); lbl:SetPoint("LEFT",r,"LEFT",6,0); r.lbl=lbl
    r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.2,0.3,0.5,0.5) end)
    r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0,0,0,0) end)
    spDungRowPool[i] = r
    return r
end

local spDungBtnLabel
local function SetDungeonFilter(name)
    spDungFilter = name
    spDungBtnLabel:SetText(name == "all" and "|cffddddddAll Dungeons|r" or ("|cffdddddd" .. name .. "|r"))
    spDungDropdown:Hide()
    if addon.RefreshStats then addon.RefreshStats() end
end

local function OpenDungDropdown()
    local seen, list = {}, { "all" }
    for _, run in ipairs(addon.GetDisplayRuns()) do
        if run.dungeon and not seen[run.dungeon] then
            seen[run.dungeon] = true; table.insert(list, run.dungeon)
        end
    end
    table.sort(list, function(a, b)
        if a == "all" then return true end
        if b == "all" then return false end
        return a < b
    end)
    for i, name in ipairs(list) do
        local r = GetOrCreateDDRow(i)
        r.lbl:SetText(name == "all" and "|cffaaaaaaAll Dungeons|r" or name)
        r:SetScript("OnClick", function() SetDungeonFilter(name) end)
        r:Show()
    end
    for i = #list + 1, #spDungRowPool do spDungRowPool[i]:Hide() end
    spDungDropdown:SetHeight(#list * 20 + 4)
    spDungDropdown:Show()
end

local spDungBtn = CreateFrame("Button", nil, statsPanel, "BackdropTemplate")
spDungBtn:SetHeight(22)
spDungBtn:SetPoint("TOPLEFT",  statsPanel, "TOPLEFT",  12, -184)
spDungBtn:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT", -12, -184)
spDungBtn:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
spDungBtn:SetBackdropColor(0.08, 0.08, 0.16, 0.9)
spDungBtn:SetBackdropBorderColor(0.35, 0.35, 0.60, 0.9)
spDungBtnLabel = spDungBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spDungBtnLabel:SetPoint("LEFT", spDungBtn, "LEFT", 8, 0)
spDungBtnLabel:SetText("|cffddddddAll Dungeons|r")
local spDungArrow = spDungBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
spDungArrow:SetPoint("RIGHT", spDungBtn, "RIGHT", -8, 0)
spDungArrow:SetText("|cff888888v|r")
spDungBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.5, 0.5, 0.8, 1) end)
spDungBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.35, 0.35, 0.60, 0.9) end)
spDungBtn:SetScript("OnClick", function()
    if spDungDropdown:IsShown() then
        spDungDropdown:Hide()
    else
        OpenDungDropdown()
    end
end)

-- Dropdown anchors below the selector button
spDungDropdown:SetPoint("TOPLEFT",  spDungBtn, "BOTTOMLEFT",  0, -2)
spDungDropdown:SetPoint("TOPRIGHT", spDungBtn, "BOTTOMRIGHT", 0, -2)

-- Column headers (panel-relative = SP_COLS[i] + 8)
local SP_COL_LABELS = { "Dungeon", "Total", "Timed", "Depl.", "Abandon", "Best Time", "Peak +" }
for i, lbl in ipairs(SP_COL_LABELS) do
    local fs = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", SP_COLS[i] + 8, -210)
    fs:SetText("|cff666666" .. lbl .. "|r")
end

local spHdrDiv = statsPanel:CreateTexture(nil, "ARTWORK")
spHdrDiv:SetPoint("TOPLEFT",  statsPanel, "TOPLEFT",   8, -222)
spHdrDiv:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT",  -8, -222)
spHdrDiv:SetHeight(1); spHdrDiv:SetColorTexture(0.2, 0.2, 0.3, 0.5)

local spScrollFrame = CreateFrame("ScrollFrame", nil, statsPanel, "UIPanelScrollFrameTemplate")
spScrollFrame:SetPoint("TOPLEFT",     statsPanel, "TOPLEFT",     8,  -226)
spScrollFrame:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -28,  8)

local spContent = CreateFrame("Frame", nil, spScrollFrame)
spContent:SetSize(spScrollFrame:GetWidth(), 1)
spScrollFrame:SetScrollChild(spContent)

local DUNG_ROW_H = 20
local dungRows   = {}

local function GetOrCreateDungRow(idx)
    if dungRows[idx] then return dungRows[idx] end
    local row = CreateFrame("Frame", nil, spContent)
    row:SetHeight(DUNG_ROW_H)
    row:SetPoint("TOPLEFT",  spContent, "TOPLEFT",  0, -(idx - 1) * DUNG_ROW_H)
    row:SetPoint("TOPRIGHT", spContent, "TOPRIGHT", 0, -(idx - 1) * DUNG_ROW_H)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, idx % 2 == 0 and 0.25 or 0.1)
    local function MakeFS(colIdx)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", row, "LEFT", SP_COLS[colIdx], 0)
        fs:SetJustifyH("LEFT")
        return fs
    end
    row.dungeon   = MakeFS(1)
    row.total     = MakeFS(2)
    row.timed     = MakeFS(3)
    row.depleted  = MakeFS(4)
    row.abandoned = MakeFS(5)
    row.bestTime  = MakeFS(6)
    row.highKey   = MakeFS(7)
    dungRows[idx] = row
    return row
end

function addon.RefreshStats()
    if not statsPanel:IsShown() then return end
    local runs = addon.GetDisplayRuns()
    local minK   = tonumber(spMinBox:GetText()) or 0
    local maxK   = tonumber(spMaxBox:GetText()) or 99999
    local dateFrom, dateTo
    if spDateFilter == "this" then
        dateFrom = GetResetStart(0)
    elseif spDateFilter == "last" then
        dateFrom = GetResetStart(1)
        dateTo   = GetResetStart(0) - 1
    end

    local totals = { total = 0, timed = 0, depleted = 0, notdone = 0 }
    local byDungeon = {}

    for _, run in ipairs(runs) do
        local kl = run.keyLevel or 0
        local st = run.startTime or 0
        local keyOk  = kl >= minK and kl <= maxK
        local dateOk = (not dateFrom or st >= dateFrom) and (not dateTo or st <= dateTo)
        local dungOk = spDungFilter == "all" or run.dungeon == spDungFilter
        if keyOk and dateOk and dungOk then
            totals.total = totals.total + 1
            local d = run.dungeon or "Unknown"
            if not byDungeon[d] then
                byDungeon[d] = { name = d, total = 0, timed = 0, depleted = 0, notdone = 0, bestMs = nil, highKey = 0 }
            end
            local ds = byDungeon[d]
            ds.total = ds.total + 1
            if run.reset or run.abandoned then
                totals.notdone = totals.notdone + 1
                ds.notdone = ds.notdone + 1
            elseif run.completed and run.onTime then
                totals.timed = totals.timed + 1
                ds.timed = ds.timed + 1
                if run.runTimeMs and (not ds.bestMs or run.runTimeMs < ds.bestMs) then
                    ds.bestMs = run.runTimeMs
                end
                if kl > ds.highKey then ds.highKey = kl end
            elseif run.completed then
                totals.depleted = totals.depleted + 1
                ds.depleted = ds.depleted + 1
            end
        end
    end

    local n = totals.total
    local function pct(v) return n > 0 and ("  |cff666666(" .. math.floor(v / n * 100 + 0.5) .. "%)|r") or "" end
    for key, def in pairs(spStatLabels) do
        local v = totals[key]
        def.fs:SetText("|cff888888" .. def.label .. ":|r  " .. def.color .. v .. "|r" .. (key ~= "total" and pct(v) or ""))
    end

    local sorted = {}
    for _, ds in pairs(byDungeon) do table.insert(sorted, ds) end
    table.sort(sorted, function(a, b) return a.total > b.total end)

    for i, ds in ipairs(sorted) do
        local row = GetOrCreateDungRow(i)
        row.dungeon:SetText(ds.name)
        row.total:SetText(tostring(ds.total))
        row.timed:SetText("|cff00ff00" .. ds.timed .. "|r")
        row.depleted:SetText("|cffff4444" .. ds.depleted .. "|r")
        row.abandoned:SetText("|cff888888" .. ds.notdone .. "|r")
        row.bestTime:SetText(ds.bestMs and addon.FormatTime(ds.bestMs) or "|cff444444—|r")
        row.highKey:SetText(ds.highKey > 0 and ("|cffffff00+" .. ds.highKey .. "|r") or "|cff444444—|r")
        row:Show()
    end
    for i = #sorted + 1, #dungRows do dungRows[i]:Hide() end
    spContent:SetHeight(math.max(#sorted * DUNG_ROW_H, 1))
end


-- ─── Player Notes Panel ───────────────────────────────────────────────────────

notesPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
notesPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     8, -70)
notesPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -8,  8)
notesPanel:SetFrameLevel(mainFrame:GetFrameLevel() + 20)
notesPanel:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
notesPanel:SetBackdropColor(0.04, 0.04, 0.08, 0.98)
notesPanel:SetBackdropBorderColor(0.3, 0.3, 0.5, 1)
notesPanel:Hide()

local npTitle = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
npTitle:SetPoint("TOP", notesPanel, "TOP", 0, -16)
npTitle:SetText("|cffaaccffPlayer Notes|r")

local npCloseBtn = CreateFrame("Button", nil, notesPanel, "UIPanelCloseButton")
npCloseBtn:SetSize(28, 28)
npCloseBtn:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT", 2, 2)
npCloseBtn:SetScript("OnClick", function() notesPanel:Hide() end)

local npDiv1 = notesPanel:CreateTexture(nil, "ARTWORK")
npDiv1:SetPoint("TOPLEFT",  notesPanel, "TOPLEFT",   8, -40)
npDiv1:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT",  -8, -40)
npDiv1:SetHeight(1); npDiv1:SetColorTexture(0.3, 0.3, 0.4, 0.6)

local npSearch = CreateFrame("EditBox", nil, notesPanel, "BackdropTemplate")
npSearch:SetPoint("TOPLEFT",  notesPanel, "TOPLEFT",   8, -44)
npSearch:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT", -8, -44)
npSearch:SetHeight(22)
npSearch:SetBackdrop({
    bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
npSearch:SetBackdropColor(0.08, 0.08, 0.14, 0.9)
npSearch:SetBackdropBorderColor(0.28, 0.28, 0.45, 0.8)
npSearch:SetAutoFocus(false)
npSearch:SetFontObject("GameFontNormalSmall")
npSearch:SetTextInsets(6, 4, 2, 2)
npSearch:SetMaxLetters(60)
npSearch:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
npSearch:SetScript("OnTextChanged",   function() if addon.RefreshNotes then addon.RefreshNotes() end end)

local npSearchHint = npSearch:CreateFontString(nil, "OVERLAY", "GameFontDisable")
npSearchHint:SetPoint("LEFT", npSearch, "LEFT", 6, 0)
npSearchHint:SetText("Search by name or realm...")
npSearch:SetScript("OnEditFocusGained", function() npSearchHint:Hide() end)
npSearch:SetScript("OnEditFocusLost",   function(self) if self:GetText() == "" then npSearchHint:Show() end end)

local npDiv2 = notesPanel:CreateTexture(nil, "ARTWORK")
npDiv2:SetPoint("TOPLEFT",  notesPanel, "TOPLEFT",   8, -70)
npDiv2:SetPoint("TOPRIGHT", notesPanel, "TOPRIGHT",  -8, -70)
npDiv2:SetHeight(1); npDiv2:SetColorTexture(0.2, 0.2, 0.3, 0.5)

local npScrollFrame = CreateFrame("ScrollFrame", nil, notesPanel, "UIPanelScrollFrameTemplate")
npScrollFrame:SetPoint("TOPLEFT",     notesPanel, "TOPLEFT",     8, -74)
npScrollFrame:SetPoint("BOTTOMRIGHT", notesPanel, "BOTTOMRIGHT", -28, 106)

local npContent = CreateFrame("Frame", nil, npScrollFrame)
npContent:SetSize(npScrollFrame:GetWidth(), 1)
npScrollFrame:SetScrollChild(npContent)

local NP_ROW_H = 30
local npRows   = {}

local function GetOrCreateNPRow(idx)
    if npRows[idx] then return npRows[idx] end
    local row = CreateFrame("Frame", nil, npContent)
    row:SetHeight(NP_ROW_H)
    row:SetPoint("TOPLEFT",  npContent, "TOPLEFT",  0, -(idx - 1) * NP_ROW_H)
    row:SetPoint("TOPRIGHT", npContent, "TOPRIGHT", 0, -(idx - 1) * NP_ROW_H)
    local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    if idx % 2 == 0 then
        bg:SetColorTexture(0.10, 0.10, 0.18, 0.65)
    else
        bg:SetColorTexture(0.05, 0.05, 0.10, 0.35)
    end

    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    sep:SetHeight(1)
    sep:SetColorTexture(0.22, 0.22, 0.38, 0.8)

    row.delBtn = CreateFrame("Button", nil, row)
    row.delBtn:SetSize(24, NP_ROW_H)
    row.delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local delLbl = row.delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    delLbl:SetPoint("CENTER"); delLbl:SetText("|cffaa3333\195\151|r")
    row.delBtn:SetScript("OnEnter", function() delLbl:SetText("|cffff5555\195\151|r") end)
    row.delBtn:SetScript("OnLeave", function() delLbl:SetText("|cffaa3333\195\151|r") end)

    row.editBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.editBtn:SetSize(42, NP_ROW_H - 8)
    row.editBtn:SetPoint("RIGHT", row.delBtn, "LEFT", -4, 0)
    row.editBtn:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    row.editBtn:SetBackdropColor(0.10, 0.10, 0.20, 0.8)
    row.editBtn:SetBackdropBorderColor(0.30, 0.30, 0.55, 0.7)
    local editLbl = row.editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    editLbl:SetPoint("CENTER"); editLbl:SetText("|cffaaaaaaEdit|r")
    row.editBtn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(0.5, 0.5, 0.8, 1) end)
    row.editBtn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.30, 0.30, 0.55, 0.7) end)

    row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameLabel:SetPoint("TOPLEFT",  row, "TOPLEFT", 6, -3)
    row.nameLabel:SetPoint("TOPRIGHT", row.editBtn, "TOPLEFT", -8, -3)
    row.nameLabel:SetJustifyH("LEFT")
    row.nameLabel:SetWordWrap(false)

    row.noteLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.noteLabel:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT", 6, 3)
    row.noteLabel:SetPoint("BOTTOMRIGHT", row.editBtn, "BOTTOMLEFT", -8, 3)
    row.noteLabel:SetJustifyH("LEFT")
    row.noteLabel:SetWordWrap(false)

    npRows[idx] = row
    return row
end

-- Add Note section (bottom 106 px of the panel)
local npAddDiv = notesPanel:CreateTexture(nil, "ARTWORK")
npAddDiv:SetPoint("BOTTOMLEFT",  notesPanel, "BOTTOMLEFT",   8, 102)
npAddDiv:SetPoint("BOTTOMRIGHT", notesPanel, "BOTTOMRIGHT", -8, 102)
npAddDiv:SetHeight(1); npAddDiv:SetColorTexture(0.3, 0.3, 0.4, 0.6)

local npAddHdr = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
npAddHdr:SetPoint("BOTTOMLEFT", notesPanel, "BOTTOMLEFT", 16, 88)
npAddHdr:SetText("|cffddddddAdd Note|r")

local function MakeNPEditBox(parent, w)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    if w and w > 0 then box:SetWidth(w) end
    box:SetHeight(22)
    box:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0.10, 0.10, 0.18, 0.9)
    box:SetBackdropBorderColor(0.35, 0.35, 0.58, 0.9)
    box:SetAutoFocus(false)
    box:SetFontObject("GameFontNormalSmall")
    box:SetTextInsets(5, 4, 2, 2)
    box:SetMaxLetters(64)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local npNameBox = MakeNPEditBox(notesPanel, 152)
npNameBox:SetPoint("BOTTOMLEFT", notesPanel, "BOTTOMLEFT", 16, 64)

local npDashLbl = notesPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
npDashLbl:SetPoint("LEFT", npNameBox, "RIGHT", 4, 0)
npDashLbl:SetText("|cff888888-|r")

local npRealmBox = MakeNPEditBox(notesPanel, 152)
npRealmBox:SetPoint("LEFT", npDashLbl, "RIGHT", 4, 0)

local npNoteBox = MakeNPEditBox(notesPanel, 0)
npNoteBox:SetPoint("BOTTOMLEFT",  notesPanel, "BOTTOMLEFT",  16, 36)
npNoteBox:SetPoint("BOTTOMRIGHT", notesPanel, "BOTTOMRIGHT", -72, 36)
npNoteBox:SetMaxLetters(300)

local npSaveBtn = CreateFrame("Button", nil, notesPanel, "UIPanelButtonTemplate")
npSaveBtn:SetSize(60, 24)
npSaveBtn:SetPoint("BOTTOMRIGHT", notesPanel, "BOTTOMRIGHT", -10, 34)
npSaveBtn:SetText("Add Note")

local function MakeNPHint(box, text)
    local h = box:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    h:SetPoint("LEFT", box, "LEFT", 6, 0)
    h:SetText(text)
    box:HookScript("OnTextChanged",     function(self) h:SetShown(self:GetText() == "") end)
    box:HookScript("OnEditFocusGained", function() h:Hide() end)
    box:HookScript("OnEditFocusLost",   function(self) if self:GetText() == "" then h:Show() end end)
end
MakeNPHint(npNameBox,  "Name")
MakeNPHint(npRealmBox, "Realm")
MakeNPHint(npNoteBox,  "Note text...")

local function SaveNPNote()
    local name  = npNameBox:GetText():match("^%s*(.-)%s*$")
    local realm = npRealmBox:GetText():match("^%s*(.-)%s*$")
    local note  = npNoteBox:GetText():match("^%s*(.-)%s*$")
    if name == "" or note == "" then return end
    if realm == "" then realm = GetRealmName() end
    addon.SetPlayerNote(name .. "-" .. realm, note)
    npNameBox:SetText(""); npNoteBox:SetText("")
    npNameBox:ClearFocus(); npRealmBox:ClearFocus(); npNoteBox:ClearFocus()
    addon.RefreshNotes()
end
npSaveBtn:SetScript("OnClick", SaveNPNote)
npNoteBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveNPNote() end)

notesPanel:SetScript("OnShow", function()
    addon.RefreshNotes()
end)

function addon.RefreshNotes()
    if not (notesPanel and notesPanel:IsShown()) then return end
    local query = npSearch:GetText():lower()
    local sorted = {}
    if addon.db and addon.db.playerNotes then
        for key, note in pairs(addon.db.playerNotes) do
            if query == "" or key:lower():find(query, 1, true) then
                table.insert(sorted, { key = key, note = note })
            end
        end
    end
    table.sort(sorted, function(a, b) return a.key:lower() < b.key:lower() end)

    for i, entry in ipairs(sorted) do
        local row = GetOrCreateNPRow(i)
        local displayName = entry.key:match("^([^%-]+)") or entry.key
        local preview = #entry.note > 50 and entry.note:sub(1, 50) .. "..." or entry.note
        row.nameLabel:SetText("|cffdddddd" .. entry.key .. "|r")
        row.noteLabel:SetText("|cff888888" .. preview .. "|r")
        row.editBtn:SetScript("OnClick", function()
            local popup = StaticPopup_Show("MYTHICPLUSHISTORY_PLAYER_NOTE", displayName, nil, entry.key)
            if popup and popup.EditBox then
                popup.EditBox:SetText(entry.note)
                popup.EditBox:SetFocus()
            end
        end)
        row.delBtn:SetScript("OnClick", function()
            StaticPopup_Show("MYTHICPLUSHISTORY_DELETE_NOTE", entry.key, nil, entry.key)
        end)
        row:Show()
    end
    for i = #sorted + 1, #npRows do npRows[i]:Hide() end
    npContent:SetHeight(math.max(#sorted * NP_ROW_H, 1))
end


-- ─── Restore window state after DB loads ──────────────────────────────────────

local stateRestoreFrame = CreateFrame("Frame")
stateRestoreFrame:RegisterEvent("ADDON_LOADED")
stateRestoreFrame:SetScript("OnEvent", function(self, _, addonName)
    if addonName ~= "MythicPlusHistory" then return end
    self:UnregisterEvent("ADDON_LOADED")
    if addon.db and addon.db.window then
        local win = addon.db.window
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", win.x or 0, win.y or 0)

        local scale = win.scale or 1.0
        scaleSlider:SetValue(scale) 
    end
    if addon.db and addon.db.settings then
        timeGroup.SetValue(addon.db.settings.timeFormat or "12h")
        trackGroup.SetValue(addon.db.settings.trackingMode or "account")
    end
    addon.RegisterMinimapIcon()
end)


-- ─── Reset UI ────────────────────────────────────────────────────────────────

function addon.ResetUI()
    local defaults = { x = 0, y = 0, width = 520, height = 638, scale = 1.0 }
    if addon.db then addon.db.window = defaults end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    mainFrame:SetSize(520, 638)
    scaleSlider:SetValue(1.0)
end


-- ─── Toggle ───────────────────────────────────────────────────────────────────

function addon.ToggleUI()
    if mainFrame:IsShown() then
        StopLiveTimer()
        mainFrame:Hide()
    else
        addon.ClearRunDetail()
        addon.selectedRun = nil
        if addon.db and addon.db.window then
            local win = addon.db.window
            mainFrame:SetSize(win.width or 520, win.height or 582)
        end
        mainFrame:Show()
        mainFrame:Raise()
        C_Timer.After(0, function()
            UpdateMemberColumns()
            content:SetWidth(scrollFrame:GetWidth())
            addon.RefreshUI()
        end)
    end
end


-- ─── Addon Options Panel (ESC > Options > Addons > Mythic+ History) ───────────

local optPanel = CreateFrame("Frame")

local resetBtn = CreateFrame("Button", nil, optPanel, "UIPanelButtonTemplate")
resetBtn:SetSize(200, 28)
resetBtn:SetPoint("TOPLEFT", optPanel, "TOPLEFT", 16, -16)
resetBtn:SetText("Reset Position & Scale")
resetBtn:SetScript("OnClick", function() addon.ResetUI() end)

local resetDesc = optPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
resetDesc:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", 0, -6)
resetDesc:SetText("|cff888888Resets the tracker window to the center of the screen\nat 100% scale and default size.|r")
resetDesc:SetJustifyH("LEFT")

if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(optPanel, "Mythic+ History")
    Settings.RegisterAddOnCategory(category)
end
