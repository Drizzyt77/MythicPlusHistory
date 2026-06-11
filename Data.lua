-- Data.lua
-- Database layer: initializes SavedVariables and exposes read/write helpers.

MythicPlusTracker = MythicPlusTracker or {}
local addon = MythicPlusTracker


-- Called once on first load to set up default structure.
function addon.InitDB()
    if not MythicPlusTrackerDB then
        MythicPlusTrackerDB = {
            runs        = {},
            playerNotes = {},
            version     = 1,
        }
    end
    addon.db = MythicPlusTrackerDB

    -- Migrate: ensure window state exists for older saves
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


-- Append a finished run to the history.
function addon.SaveRun(runData)
    table.insert(addon.db.runs, runData)
end


-- Returns the full runs array.
function addon.GetRuns()
    return addon.db.runs
end


-- Returns run count
function addon.GetRunCount()
    return #addon.db.runs
end


-- Returns runs filtered by the current tracking mode setting.
-- "character" mode: only runs tagged to the logged-in character (plus any untagged
-- legacy runs, which predate the character-tagging feature).
-- "account" mode (default): returns the full runs array unmodified.
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


-- Save or update a note for a player.
-- playerKey format: "Playername-RealmName"
function addon.SetPlayerNote(playerKey, note)
    addon.db.playerNotes[playerKey] = note
end


-- Returns the note string for a player, or nil if none saved.
function addon.GetPlayerNote(playerKey)
    return addon.db.playerNotes[playerKey]
end


-- Delete a player note entirely.
function addon.DeletePlayerNote(playerKey)
    addon.db.playerNotes[playerKey] = nil
end


-- Remove a specific run from history by reference.
function addon.DeleteRun(run)
    local runs = addon.db.runs
    for i = #runs, 1, -1 do
        if runs[i] == run then table.remove(runs, i); return end
    end
end


-- Formats milliseconds into "MM:SS" string for display.
-- e.g. 1923000 ms -> "32:03"
function addon.FormatTime(ms)
    if not ms then return "--:--" end
    local totalSeconds = math.floor(ms / 1000)
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%d:%02d", minutes, seconds)
end


-- Formats a Unix timestamp into a readable date string.
-- e.g. 1749000000 -> "06/04/25"
function addon.FormatDate(timestamp)
    if not timestamp then return "Unknown" end
    return date("%m/%d/%y", timestamp)
end


-- Formats a Unix timestamp into a local 24-hour time string.
-- e.g. 1749000000 -> "23:41"
function addon.FormatStartTime(timestamp)
    if not timestamp then return "--:--" end
    local fmt = (addon.db and addon.db.settings and addon.db.settings.timeFormat == "24h")
                and "%H:%M" or "%I:%M %p"
    return date(fmt, timestamp)
end
