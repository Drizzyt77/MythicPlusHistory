-- Core.lua

local addon = MythicPlusHistory

local eventFrame = CreateFrame("Frame")

local activeRun = nil

local runTimeoutTicker = nil
local zoneOutTicker    = nil

local function CancelRunTimeout()
    if runTimeoutTicker then runTimeoutTicker:Cancel(); runTimeoutTicker = nil end
end

local function CancelZoneOutTimer()
    if zoneOutTicker then zoneOutTicker:Cancel(); zoneOutTicker = nil end
end

local function SaveAsAbandoned(reason)
    if not activeRun then return end
    CancelRunTimeout()
    CancelZoneOutTimer()
    local elapsed = activeRun.startTime and (time() - activeRun.startTime) or 0
    if elapsed < 60 then
        activeRun = nil
        if MythicPlusHistoryDB then MythicPlusHistoryDB.activeRun = nil end
        return
    end
    activeRun.abandoned = true
    activeRun.endTime   = time()
    addon.SaveRun(activeRun)
    activeRun = nil
    if MythicPlusHistoryDB then MythicPlusHistoryDB.activeRun = nil end
    if addon.RefreshUI then addon.RefreshUI() end
    print("|cffff9900[M+ History]|r " .. reason .. " — run saved as abandoned.")
end

local function SaveAsReset(reason)
    if not activeRun then return end
    CancelRunTimeout()
    CancelZoneOutTimer()
    activeRun.reset   = true
    activeRun.endTime = time()
    addon.SaveRun(activeRun)
    activeRun = nil
    if MythicPlusHistoryDB then MythicPlusHistoryDB.activeRun = nil end
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



local inspectFrame = CreateFrame("Frame")
local inspectRun   = nil
local inspectGen   = 0  

inspectFrame:SetScript("OnEvent", function(self, event, guid)
    if not inspectRun then return end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitGUID(unit) == guid then
            local specID = GetInspectSpecialization(unit)
            if specID and specID ~= 0 and GetSpecializationInfoByID then
                local ok, _, sName = pcall(GetSpecializationInfoByID, specID)
                if ok and sName then
                    local name = UnitName(unit)
                    for _, m in ipairs(inspectRun.members) do
                        if m.name == name then m.spec = sName; break end
                    end
                end
            end
            break
        end
    end
end)
inspectFrame:RegisterEvent("INSPECT_READY")

local function FetchPartySpecs(run)
    inspectGen = inspectGen + 1
    local gen  = inspectGen
    inspectRun = run

    local delay = 1.0
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            C_Timer.After(delay, function()
                if inspectGen ~= gen or not UnitExists(unit) then return end
                NotifyInspect(unit)
            end)
            delay = delay + 1.0
        end
    end

    C_Timer.After(delay + 3, function()
        if inspectGen ~= gen then return end
        inspectRun = nil
    end)
end


-- ─── Upgrade Threshold Helper ────────────────────────────────────────────────

local function CalcKeystoneUpgrades(runTimeMs, timeLimitSec, affixes)
    local hasPeril = false
    for _, id in ipairs(affixes or {}) do
        if id == 152 then hasPeril = true; break end
    end

    local limit2, limit3
    if hasPeril then
        local base = timeLimitSec - 90
        limit2 = base * 0.8 + 90
        limit3 = base * 0.6 + 90
    else
        limit2 = timeLimitSec * 0.8
        limit3 = timeLimitSec * 0.6
    end

    local runTimeSec = runTimeMs / 1000
    if     runTimeSec <= limit3       then return 3
    elseif runTimeSec <= limit2       then return 2
    elseif runTimeSec <= timeLimitSec then return 1
    else                                   return 0
    end
end


-- ─── Event Handlers ──────────────────────────────────────────────────────────

local function OnChallengeStart()
    local mapID          = C_ChallengeMode.GetActiveChallengeMapID()
    local level, affixes = C_ChallengeMode.GetActiveKeystoneInfo()

    if activeRun and activeRun.mapID == mapID then
        FetchPartySpecs(activeRun)
        return
    end

    if activeRun then SaveAsAbandoned("New key started") end
    local dungeonName   = "Unknown"

    local timeLimit = nil
    if mapID then
        local name, _, limit = C_ChallengeMode.GetMapUIInfo(mapID)
        dungeonName = name or "Unknown"
        timeLimit   = limit
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
        deathCount       = 0,
        season           = C_MythicPlus and C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason() or nil,
    }

    CancelRunTimeout()
    runTimeoutTicker = C_Timer.NewTicker(5400, function()
        SaveAsReset("Run timed out after 90 min")
    end, 1)

    if MythicPlusHistoryDB then MythicPlusHistoryDB.activeRun = activeRun end

    FetchPartySpecs(activeRun)

    print("|cff00ff00[M+ History]|r Tracking started: +" .. (level or "?") .. " " .. dungeonName)
end


local function OnChallengeCompleted(...)
    if not activeRun then return end
    CancelRunTimeout()
    CancelZoneOutTimer()

    local dungeonName = activeRun.dungeon

    local _, level, runTimeMs, onTime, keystoneUpgrades = ...
    local usedAPITime = false

    if C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo then
        local ok, info = pcall(C_ChallengeMode.GetChallengeCompletionInfo)
        if ok and type(info) == "table" then
            if runTimeMs == nil then runTimeMs = info.time end
            if onTime == nil           then onTime           = info.onTime           end
            if keystoneUpgrades == nil then keystoneUpgrades = info.keystoneUpgrades end
            if level == nil            then level            = info.level            end
        end
    end

    if (runTimeMs == nil or keystoneUpgrades == nil) and C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local ok, info = pcall(C_ChallengeMode.GetCompletionInfo)
        if ok and type(info) == "table" then
            if runTimeMs == nil then
                runTimeMs = info.time or (info.durationSec and info.durationSec * 1000)
                if runTimeMs then usedAPITime = true end
            end
            if onTime == nil           then onTime           = info.onTime           end
            if keystoneUpgrades == nil then keystoneUpgrades = info.keystoneUpgrades end
            if level == nil            then level            = info.level            end
        end
    end

    if runTimeMs == nil and activeRun.startTime then
        runTimeMs = math.max(0, (time() - activeRun.startTime) * 1000 - 10000)
    end

    if usedAPITime then
        runTimeMs = runTimeMs + (activeRun.timeLostSec or 0) * 1000
    end

    if onTime == nil and runTimeMs and activeRun.timeLimit then
        onTime = runTimeMs <= (activeRun.timeLimit * 1000)
    end

    if keystoneUpgrades == nil then
        if runTimeMs and activeRun.timeLimit then
            keystoneUpgrades = CalcKeystoneUpgrades(runTimeMs, activeRun.timeLimit, activeRun.affixes)
        else
            keystoneUpgrades = onTime and 1 or 0
        end
    end

    activeRun.completed        = true
    activeRun.runTimeMs        = runTimeMs
    activeRun.onTime           = onTime and true or false
    activeRun.keystoneUpgrades = keystoneUpgrades or 0
    activeRun.deathCount       = activeRun.deathCount or 0
    activeRun.endTime          = time()

    addon.SaveRun(activeRun)
    activeRun = nil
    if MythicPlusHistoryDB then MythicPlusHistoryDB.activeRun = nil end

    if addon.RefreshUI then addon.RefreshUI() end

    local displayLevel = level or "?"
    local result = (onTime) and "|cff00ff00Timed|r" or "|cffff4444Depleted|r"
    print("|cff00ff00[M+ History]|r " .. result .. " +" .. tostring(displayLevel) .. " " .. dungeonName .. " saved.")
end


local function OnChallengeReset()
    if not activeRun then return end
    SaveAsAbandoned("Key reset")
end

local function OnPlayerEnteringWorld(isInitialLogin, isReloadingUI)
    if MythicPlusHistoryDB and not MythicPlusHistoryDB.seasonMigratedV2 then
        local season1ID = C_MythicPlus and C_MythicPlus.GetCurrentSeason and C_MythicPlus.GetCurrentSeason()
        if season1ID and season1ID > 0 then
            local SEASON1_END = 1785542400  -- Aug 1, 2026 00:00 UTC
            local tagged = 0
            for _, run in ipairs(MythicPlusHistoryDB.runs or {}) do
                if run.season == nil and (run.startTime or 0) < SEASON1_END then
                    run.season = season1ID
                    tagged = tagged + 1
                end
            end
            MythicPlusHistoryDB.seasonMigratedV2 = true
            if tagged > 0 then
                print("|cff00ff00[M+ History]|r Season migration: tagged " .. tagged .. " runs as Season " .. season1ID)
            end
        end
    end

    if not (isInitialLogin or isReloadingUI) then return end
    if not activeRun then return end
    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
                  and C_ChallengeMode.GetActiveChallengeMapID()
    if mapID and mapID == activeRun.mapID then
        -- Still in the same key after a DC/reload — refresh what may have changed.
        if C_ChallengeMode.GetDeathCount then
            local count, timeLost = C_ChallengeMode.GetDeathCount()
            activeRun.deathCount  = count    or 0
            activeRun.timeLostSec = timeLost or 0
        end
        FetchPartySpecs(activeRun)
        print("|cff00ff00[M+ History]|r Reconnected — resuming +" .. (activeRun.keyLevel or "?") .. " " .. activeRun.dungeon)
    elseif not isReloadingUI then
        SaveAsAbandoned("Disconnected mid-key")
    end
end


local ZONE_OUT_GRACE = 180

local function OnZoneChanged()
    if not activeRun then return end
    local inInstance = IsInInstance()

    if not inInstance then
        if not zoneOutTicker then
            zoneOutTicker = C_Timer.NewTicker(ZONE_OUT_GRACE, function()
                zoneOutTicker = nil
                SaveAsAbandoned("Dungeon left")
            end, 1)
        end
    else
        if zoneOutTicker then
            CancelZoneOutTimer()
            local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
                          and C_ChallengeMode.GetActiveChallengeMapID()

            if mapID and mapID ~= activeRun.mapID then
                SaveAsAbandoned("Left dungeon")
            end
        end
    end
end


-- ─── Death Tracking ──────────────────────────────────────────────────────────

local function OnDeathCountUpdated()
    if not activeRun then return end
    if not (C_ChallengeMode and C_ChallengeMode.GetDeathCount) then return end
    local count, timeLost = C_ChallengeMode.GetDeathCount()
    activeRun.deathCount  = count    or 0
    activeRun.timeLostSec = timeLost or 0
end


-- ─── Group Note Alerts ───────────────────────────────────────────────────────

local alertedPlayers = {}

local function CheckNewGroupMembers()
    if not (addon.db and addon.db.playerNotes) then return end

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


-- ─── LFG Search Result Note Lookup ──────────────────────────────────────────

local function LFG_NotesForSearchResult(resultID)
    if not (addon.db and addon.db.playerNotes) then return {} end
    local ok, info = pcall(C_LFGList.GetSearchResultInfo, resultID)
    if not ok or not info then return {} end
    local found = {}
    local seen  = {}

    local function checkName(name)
        if type(name) ~= "string" or name == "" or seen[name] then return end
        seen[name] = true
        local key  = name:find("-") and name or (name .. "-" .. GetRealmName())
        local note = addon.GetPlayerNote(key)
        if note and note ~= "" then
            table.insert(found, { name = name, note = note })
        end
    end

    if info.leaderName and info.leaderName ~= "" then
        checkName(info.leaderName)
    end

    if C_LFGList.GetSearchResultLeaderInfo then
        local lOk, lInfo = pcall(C_LFGList.GetSearchResultLeaderInfo, resultID)
        if lOk and lInfo and lInfo.name then checkName(lInfo.name) end
    end

    local memberCount = math.max(info.numMembers or 0, 5)
    for i = 1, memberCount do
        local mOk, mInfo = pcall(C_LFGList.GetSearchResultPlayerInfo, resultID, i)
        if mOk and mInfo and mInfo.name then checkName(mInfo.name) end
    end

    return found
end


-- ─── LFG Applicant Tooltip Notes ─────────────────────────────────────────────

local function FindApplicantID(frame)
    for _ = 1, 3 do
        if not frame then break end
        if frame.applicantID then return frame.applicantID, frame.memberIdx end
        frame = frame.GetParent and frame:GetParent()
    end
    return nil, nil
end

local function FindSearchResultID(frame)
    for _ = 1, 8 do
        if not frame then break end
        local id = frame.searchResultID or frame.resultID or frame.lfgSearchResultID or frame.entryID
        if id then return id end
        frame = frame.GetParent and frame:GetParent()
    end
    return nil
end

GameTooltip:HookScript("OnShow", function(self)
    if not (addon.db and addon.db.playerNotes) then return end
    local owner = self:GetOwner()
    if not owner then return end

    local applicantID = FindApplicantID(owner)
    if applicantID then
        C_Timer.After(0, function()
            if not self:IsShown() then return end
            local name, note = LFG_NoteForApplicant(applicantID)
            if name and note then
                self:AddLine(" ")
                self:AddLine("|cff00ff00M+ History Note:|r")
                self:AddLine("|cffffff88" .. note .. "|r", 1, 1, 1, true)
                self:Show()
            end
        end)
        return
    end

    local resultID = FindSearchResultID(owner)
    if resultID then
        C_Timer.After(0, function()
            if not self:IsShown() then return end
            local notes = LFG_NotesForSearchResult(resultID)
            if #notes > 0 then
                self:AddLine(" ")
                self:AddLine("|cff00ff00M+ History Notes:|r")
                for _, entry in ipairs(notes) do
                    self:AddLine("|cffffff88[" .. entry.name .. "]|r " .. entry.note, 1, 1, 1, true)
                end
                self:Show()
            end
        end)
    end
end)

if LFGListSearchResultButton_OnEnter then
    hooksecurefunc("LFGListSearchResultButton_OnEnter", function(self)
        if not (addon.db and addon.db.playerNotes) then return end
        local resultID = self.searchResultID or self.resultID or self.lfgSearchResultID or self.entryID
        if not resultID then return end
        C_Timer.After(0.05, function()
            if not GameTooltip:IsShown() then return end
            local notes = LFG_NotesForSearchResult(resultID)
            if #notes > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ff00M+ History Notes:|r")
                for _, entry in ipairs(notes) do
                    GameTooltip:AddLine("|cffffff88[" .. entry.name .. "]|r " .. entry.note, 1, 1, 1, true)
                end
                GameTooltip:Show()
            end
        end)
    end)
end


-- ─── Event Dispatcher ────────────────────────────────────────────────────────

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "MythicPlusHistory" then
            addon.InitDB()
            if MythicPlusHistoryDB and MythicPlusHistoryDB.activeRun then
                activeRun = MythicPlusHistoryDB.activeRun
            end
            C_Timer.NewTicker(60, function()
                if not activeRun then return end
                local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
                              and C_ChallengeMode.GetActiveChallengeMapID()
                if not mapID then
                    SaveAsAbandoned("Run no longer active")
                end
            end)
            print("|cff00ff00[M+ History]|r Loaded! Type |cffffd700/mtrack|r to open.")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        OnPlayerEnteringWorld(...)

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
            if activeRun then
                C_Timer.After(3, function()
                    if not activeRun then return end
                    local mapID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID
                                  and C_ChallengeMode.GetActiveChallengeMapID()
                    if not mapID then SaveAsAbandoned("Group disbanded") end
                end)
            end
        else
            CheckNewGroupMembers()
        end

    elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
        OnDeathCountUpdated()

    elseif event == "LFG_LIST_APPLICANT_LIST_UPDATED"
        or event == "LFG_LIST_APPLICANT_UPDATED" then
        CheckApplicants()

    elseif event == "PLAYER_LOGOUT" then
    end
end)

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHALLENGE_MODE_DEATH_COUNT_UPDATED")
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
    SaveAsAbandoned("Force stopped by user")
end


-- ─── Slash Command ───────────────────────────────────────────────────────────

-- "/mtrack"      → open/close window
-- "/mtrack test" → inject a test run
SLASH_MYTHICPLUSHISTORY1 = "/mtrack"
SLASH_MYTHICPLUSHISTORY2 = "/mythicplushistory"
SlashCmdList["MYTHICPLUSHISTORY"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(%a*)") or ""
    if cmd == "test" then
        local seasonArg = msg and msg:match("test%s+(%d+)")
        addon.CreateTestRun(seasonArg and tonumber(seasonArg))
    elseif addon.ToggleUI then
        addon.ToggleUI()
    end
end
