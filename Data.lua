-- Data.lua

MythicPlusHistory = MythicPlusHistory or {}
local addon = MythicPlusHistory


-- Called once on first load to set up default structure.
function addon.InitDB()
    if not MythicPlusHistoryDB then
        MythicPlusHistoryDB = {
            runs        = {},
            playerNotes = {},
            version     = 1,
        }
    end
    addon.db = MythicPlusHistoryDB

    if not addon.db.window then
        addon.db.window = { x = 0, y = 0, width = 520, height = 638, scale = 1.0 }
    end
    if not addon.db.minimap then
        addon.db.minimap = { minimapPos = 220 }
    end
    if not addon.db.settings then
        addon.db.settings = { timeFormat = "12h", trackingMode = "account" }
    end
end


function addon.SaveRun(runData)
    table.insert(addon.db.runs, runData)
end


function addon.GetRuns()
    return addon.db.runs
end


function addon.GetRunCount()
    return #addon.db.runs
end


function addon.GetDisplayRuns()
    local runs     = addon.db.runs
    local settings = addon.db.settings
    if settings and settings.trackingMode == "character" then
        local myName  = UnitName("player")
        local myRealm = GetRealmName()
        if myName and myRealm then
            local myKey    = myName .. "-" .. myRealm
            local filtered = {}
            for _, run in ipairs(runs) do
                -- nil character means pre-feature run; include it on all characters
                if not run.character or run.character == myKey then
                    table.insert(filtered, run)
                end
            end
            return filtered
        end
    end
    return runs
end


function addon.SetPlayerNote(playerKey, note)
    addon.db.playerNotes[playerKey] = note
end


function addon.GetPlayerNote(playerKey)
    return addon.db.playerNotes[playerKey]
end


function addon.DeletePlayerNote(playerKey)
    addon.db.playerNotes[playerKey] = nil
end


function addon.DeleteRun(run)
    local runs = addon.db.runs
    for i = #runs, 1, -1 do
        if runs[i] == run then table.remove(runs, i); return end
    end
end


function addon.FormatTime(ms)
    if not ms then return "--:--" end
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%d:%02d", minutes, seconds)
end


function addon.FormatDate(timestamp)
    if not timestamp then return "Unknown" end
    return date("%m/%d/%y", timestamp)
end


function addon.FormatStartTime(timestamp)
    if not timestamp then return "--:--" end
    local fmt = (addon.db and addon.db.settings and addon.db.settings.timeFormat == "24h")
                and "%H:%M" or "%I:%M %p"
    return date(fmt, timestamp)
end
