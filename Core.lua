-- Core.lua

local addon = MythicPlusHistory

local eventFrame = CreateFrame("Frame")

local activeRun = nil

local runTimeoutTicker = nil

local function CancelRunTimeout()
    if runTimeoutTicker then runTimeoutTicker:Cancel(); runTimeoutTicker = nil end
end

local function SaveAsReset(reason)
    if not activeRun then return end
    CancelRunTimeout()
    activeRun.reset   = true
    activeRun.endTime = time()
    addon.SaveRun(activeRun)
    activeRun = nil
    if addon.RefreshUI then addon.RefreshUI() end
    print("|cffff9900[M+ History]|r " .. reason .. " — run saved as reset.")
end


-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function GetGroupMembers()
    local members = {}
    local units = { "player", "party1", "party2", "party3", "party4" }

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            local _, class    = UnitClass(unit)
            local role        = UnitGroupRolesAssigned(unit)
            local raceName    = UnitRace(unit)

            local specName = nil
            if UnitIsUnit(unit, "player") and GetSpecialization then
                local specIndex = GetSpecialization()
                if specIndex then
                    local _, sName = GetSpecializationInfo(specIndex)
                    specName = sName
                end
            elseif GetInspectSpecialization then
                local specID = GetInspectSpecialization(unit)
                if specID and specID ~= 0 and GetSpecializationInfoByID then
                    local ok, _, sName = pcall(GetSpecializationInfoByID, specID)
                    if ok then specName = sName end
                end
            end

            local mythicScore = nil
            if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
                local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit)
                if ok and summary then
                    mythicScore = summary.currentSeasonScore
                end
            end

            table.insert(members, {
                name        = name,
                realm       = realm or GetRealmName(),
                class       = class,
                role        = role or "NONE",
                spec        = specName,
                race        = raceName,
                mythicScore = mythicScore,
            })
        end
    end

    return members
end


-- ─── Event Handlers ──────────────────────────────────────────────────────────

local function OnChallengeStart()
    local mapID         = C_ChallengeMode.GetActiveChallengeMapID()
    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()
    local dungeonName   = "Unknown"

    local timeLimit = nil
    if mapID then
        local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
        dungeonName = name or "Unknown"
        timeLimit   = limit  -- time limit in seconds; nil if API doesn't return it
    end

    activeRun = {
        dungeon          = dungeonName,
        mapID            = mapID,
        keyLevel         = level,
        affixes          = affixes,
        members          = GetGroupMembers(),
        startTime        = time(),
        timeLimit        = timeLimit,
        completed        = false,
        abandoned        = false,
        character        = UnitName("player") .. "-" .. GetRealmName(),
    }

    -- 90-minute safety timeout: if the run never resolves, auto-save as reset
    CancelRunTimeout()
    runTimeoutTicker = C_Timer.NewTicker(5400, function()
        SaveAsReset("Run timed out after 90 min")
    end, 1)

    print("|cff00ff00[M+ History]|r Tracking started: +" .. (level or "?") .. " " .. dungeonName)
end


-- Fires when the run timer ends successfully.
local function OnChallengeCompleted(...)
    if not activeRun then return end
    CancelRunTimeout()

    local dungeonName = activeRun.dungeon

    local mapID, level, runTimeMs, onTime, keystoneUpgrades = ...

    if runTimeMs == nil then
        if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
            local ok, info = pcall(C_ChallengeMode.GetCompletionInfo)
            if ok and type(info) == "table" then
                runTimeMs        = info.time or (info.durationSec and info.durationSec * 1000)
                onTime           = info.onTime
                keystoneUpgrades = info.keystoneUpgrades or 0
                level            = info.level or level
            end
        end
    end

    if runTimeMs == nil and activeRun.startTime then
        runTimeMs = (time() - activeRun.startTime) * 1000
    end

    if onTime == nil and runTimeMs and activeRun.timeLimit then
        onTime           = runTimeMs <= (activeRun.timeLimit * 1000)
        keystoneUpgrades = onTime and 1 or 0
    end

    activeRun.completed        = true
    activeRun.runTimeMs        = runTimeMs
    activeRun.onTime           = onTime and true or false
    activeRun.keystoneUpgrades = keystoneUpgrades or 0
    activeRun.endTime          = time()

    addon.SaveRun(activeRun)
    activeRun = nil

    if addon.RefreshUI then addon.RefreshUI() end

    local displayLevel = level or "?"
    local result = (onTime) and "|cff00ff00Timed|r" or "|cffff4444Depleted|r"
    print("|cff00ff00[M+ History]|r " .. result .. " +" .. tostring(displayLevel) .. " " .. dungeonName .. " saved.")
end


-- Fires when the key is reset from the menu or the run is abandoned.
local function OnChallengeReset()
    if not activeRun then return end
    CancelRunTimeout()

    activeRun.abandoned = true
    activeRun.endTime   = time()

    addon.SaveRun(activeRun)
    activeRun = nil

    print("|cffff9900[M+ History]|r Run abandoned — saved to history.")
end

-- Fires when the player changes zones. If leaving an instance with an active
-- run, that means the group walked out and reset rather than using the
-- formal abandon button.
local function OnZoneChanged()
    if not activeRun then return end
    local inInstance = IsInInstance()
    if not inInstance then
        CancelRunTimeout()
        activeRun.abandoned = true
        activeRun.endTime   = time()
        addon.SaveRun(activeRun)
        activeRun = nil
        if addon.RefreshUI then addon.RefreshUI() end
        print("|cffff9900[M+ History]|r Dungeon left — run saved as abandoned.")
    end
end


-- ─── Group Note Alerts ───────────────────────────────────────────────────────

-- Tracks players already alerted this session so GROUP_ROSTER_UPDATE spam
-- doesn't print the same note multiple times.
local alertedPlayers = {}

local function CheckNewGroupMembers()
    if not (addon.db and addon.db.playerNotes) then return end

    -- Build unit list: party1-4 for groups, raid1-N for raids
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units+1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do units[#units+1] = "party" .. i end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local name, realm = UnitName(unit)
            if name then
                realm = realm or GetRealmName()
                local key = name .. "-" .. realm
                if not alertedPlayers[key] then
                    alertedPlayers[key] = true
                    local note = addon.GetPlayerNote(key)
                    if note then
                        local _, class = UnitClass(unit)
                        local cc = (class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
                                   or { r = 1, g = 1, b = 1 }
                        DEFAULT_CHAT_FRAME:AddMessage(string.format(
                            "|cff00ff00[M+ History]|r Note for |cff%02x%02x%02x%s|r: %s",
                            math.floor(cc.r * 255), math.floor(cc.g * 255), math.floor(cc.b * 255),
                            name, note))
                    end
                end
            end
        end
    end
end


-- ─── LFG Applicant Helpers ───────────────────────────────────────────────────

local function LFG_GetApplicantIDs()
    if not C_LFGList then return {} end
    local fn = C_LFGList.GetApplicants
           or  C_LFGList.GetApplicantIDs
           or  C_LFGList.GetApplicantList
    if not fn then return {} end
    return fn() or {}
end

-- GetApplicantMemberInfo returns multiple plain values; first is "Name-Realm".
local function LFG_GetMemberName(applicantID, idx)
    if not (C_LFGList and C_LFGList.GetApplicantMemberInfo) then return nil end
    local ok, name = pcall(C_LFGList.GetApplicantMemberInfo, applicantID, idx)
    if not ok or type(name) ~= "string" or name == "" then return nil end
    return name
end

local function LFG_GetApplicantInfo(applicantID)
    if not (C_LFGList and C_LFGList.GetApplicantInfo) then return nil end
    local ok, info = pcall(C_LFGList.GetApplicantInfo, applicantID)
    return ok and info or nil
end

local function LFG_NoteForApplicant(applicantID)
    if not (addon.db and addon.db.playerNotes) then return nil, nil end
    local info = LFG_GetApplicantInfo(applicantID)
    if not info then return nil, nil end
    for i = 1, (info.numMembers or 1) do
        local name = LFG_GetMemberName(applicantID, i)
        if name then
            local key  = name:find("-") and name or (name .. "-" .. GetRealmName())
            local note = addon.GetPlayerNote(key)
            if note then return name, note end
        end
    end
    return nil, nil
end


-- ─── LFG Applicant Note Alerts ───────────────────────────────────────────────

local alertedApplicants = {}

local function CheckApplicants()
    local ids = LFG_GetApplicantIDs()
    for _, applicantID in ipairs(ids) do
        if not alertedApplicants[applicantID] then
            local name, note = LFG_NoteForApplicant(applicantID)
            if name and note then
                alertedApplicants[applicantID] = true
                DEFAULT_CHAT_FRAME:AddMessage(string.format(
                    "|cff00ff00[M+ History]|r Applicant |cffffd700%s|r has a note: |cffffff88%s|r",
                    name, note))
            end
        end
    end
end


-- ─── LFG Applicant Tooltip Notes ─────────────────────────────────────────────

local function FindApplicantID(frame)
    -- Walk up two levels — the tooltip owner may be a child of the actual button.
    for _ = 1, 3 do
        if not frame then break end
        if frame.applicantID then return frame.applicantID, frame.memberIdx end
        frame = frame.GetParent and frame:GetParent()
    end
    return nil, nil
end

GameTooltip:HookScript("OnShow", function(self)
    if not (addon.db and addon.db.playerNotes) then return end
    local owner = self:GetOwner()
    if not owner then return end

    local applicantID = FindApplicantID(owner)
    if not applicantID then return end

    -- Defer one frame so all LFG tooltip lines are added before ours.
    C_Timer.After(0, function()
        if not self:IsShown() then return end
        local name, note = LFG_NoteForApplicant(applicantID)
        if name and note then
            self:AddLine("|cff00ff00M+ History Note:|r")
            self:AddLine("|cffffff88" .. note .. "|r", 1, 1, 1, true)
            self:Show()  -- force resize after adding lines
        end
    end)
end)



-- ─── Event Dispatcher ────────────────────────────────────────────────────────

-- Single OnEvent handler routes to the right function.
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "MythicPlusHistory" then
            addon.InitDB()
            print("|cff00ff00[M+ History]|r Loaded! Type |cffffd700/mtrack|r to open.")
        end

    elseif event == "CHALLENGE_MODE_START" then
        OnChallengeStart()

    elseif event == "CHALLENGE_MODE_COMPLETED" then
        OnChallengeCompleted(...)

    elseif event == "CHALLENGE_MODE_RESET" then
        OnChallengeReset()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        OnZoneChanged()

    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() and not IsInRaid() then
            wipe(alertedPlayers)
        else
            CheckNewGroupMembers()
        end

    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED"
        or event == "LFG_LIST_APPLICANT_UPDATED" then
        CheckApplicants()

    elseif event == "PLAYER_LOGOUT" then
        -- WoW auto-saves SavedVariables on logout, nothing extra needed.
    end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("CHALLENGE_MODE_START")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_LIST_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_APPLICANT_UPDATED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")


-- ─── Active Run API ──────────────────────────────────────────────────────────

function addon.GetActiveRun()
    return activeRun
end

function addon.SetActiveRun(run)
    activeRun = run
end

function addon.ForceStopRun()
    if not activeRun then return end
    SaveAsReset("Force stopped by user")
end


-- ─── Slash Command ───────────────────────────────────────────────────────────

-- "/mtrack"      → open/close window
-- "/mtrack test" → inject a fake run for testing
SLASH_MYTHICPLUSHISTORY1 = "/mtrack"
SLASH_MYTHICPLUSHISTORY2 = "/mythicplushistory"
SlashCmdList["MYTHICPLUSHISTORY"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(%a*)") or ""
    if cmd == "test" then
        addon.CreateTestRun()
    elseif addon.ToggleUI then
        addon.ToggleUI()
    end
end
