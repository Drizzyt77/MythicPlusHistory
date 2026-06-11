-- TestData.lua
-- Generates fake M+ runs for UI testing. Only triggered by /mtrack test.
local addon = MythicPlusTracker

local TEST_DUNGEONS = {
    "Windrunner Spire",
    "Maisara Caverns",
    "Magisters' Terrace",
    "Pit of Saron",
    "Skyreach",
    "Seat of the Triumvirate",
    "Nexus-Point Xenas",
    "Algeth'ar Academy",
}

local TEST_NAMES  = {
    "Zephyra", "Ironveil", "Thornwick", "Solvex", "Pyremane", "Coldash",
    "Reckker", "Vaelos", "Mirthos", "Quelari", "Dravex", "Sylvara",
}
local TEST_REALMS = {
    "Stormrage", "Illidan", "Tichondrius", "Area-52", "Mal'Ganis",
    "Sargeras", "Thrall", "Bleeding Hollow", "Emerald Dream",
}
local TEST_RACES = {
    "Human", "Dwarf", "Gnome", "Night Elf", "Draenei", "Worgen",
    "Void Elf", "Dark Iron Dwarf", "Kul Tiran",
    "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin",
    "Nightborne", "Highmountain Tauren", "Zandalari Troll", "Vulpera", "Dracthyr",
}

-- Which classes can fill each role
local ROLE_CLASSES = {
    TANK    = { "WARRIOR", "PALADIN", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "DRUID" },
    HEALER  = { "PALADIN", "PRIEST", "SHAMAN", "MONK", "DRUID", "EVOKER" },
    DAMAGER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN",
                "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "DEATHKNIGHT", "EVOKER" },
}

-- Valid specs per class per role
local ROLE_SPECS = {
    TANK = {
        WARRIOR     = { "Protection" },
        PALADIN     = { "Protection" },
        DEATHKNIGHT = { "Blood" },
        MONK        = { "Brewmaster" },
        DEMONHUNTER = { "Vengeance" },
        DRUID       = { "Guardian" },
    },
    HEALER = {
        PALADIN = { "Holy" },
        PRIEST  = { "Discipline", "Holy" },
        SHAMAN  = { "Restoration" },
        MONK    = { "Mistweaver" },
        DRUID   = { "Restoration" },
        EVOKER  = { "Preservation" },
    },
    DAMAGER = {
        WARRIOR     = { "Arms", "Fury" },
        PALADIN     = { "Retribution" },
        HUNTER      = { "Beast Mastery", "Marksmanship", "Survival" },
        ROGUE       = { "Assassination", "Outlaw", "Subtlety" },
        PRIEST      = { "Shadow" },
        SHAMAN      = { "Elemental", "Enhancement" },
        MAGE        = { "Arcane", "Fire", "Frost" },
        WARLOCK     = { "Affliction", "Demonology", "Destruction" },
        MONK        = { "Windwalker" },
        DRUID       = { "Balance", "Feral" },
        DEMONHUNTER = { "Havoc", "Devourer" },
        DEATHKNIGHT = { "Frost", "Unholy" },
        EVOKER      = { "Devastation", "Augmentation" },
    },
}

local function RandInt(min, max) return math.random(min, max) end
local function RandPick(t) return t[RandInt(1, #t)] end

-- Detect the player's actual role from their current spec
local function GetPlayerRole()
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then
            local _, _, _, _, role = GetSpecializationInfo(idx)
            if role and role ~= "NONE" and role ~= "" then return role end
        end
    end
    return "DAMAGER"
end

local function GetPlayerSpecName()
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then
            local _, name = GetSpecializationInfo(idx)
            return name
        end
    end
    return nil
end

-- Build a randomized NPC for a given role, avoiding name collisions
local function MakeNPC(role, usedNames)
    local class = RandPick(ROLE_CLASSES[role])
    local specs = ROLE_SPECS[role][class]
    local name
    repeat name = RandPick(TEST_NAMES) until not usedNames[name]
    usedNames[name] = true
    return {
        name        = name,
        realm       = RandPick(TEST_REALMS),
        class       = class,
        role        = role,
        race        = RandPick(TEST_RACES),
        spec        = specs and RandPick(specs) or nil,
        mythicScore = RandInt(500, 3800),
    }
end

-- Build a full 5-man group around the player's actual role
local function BuildGroup()
    local playerName  = UnitName("player") or "Drizzyt"
    local playerRealm = GetRealmName() or "Stormrage"
    local _, playerClass = UnitClass("player")
    local playerRole  = GetPlayerRole()
    local playerScore = nil
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, s = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and s then playerScore = s.currentSeasonScore end
    end

    local usedNames = { [playerName] = true }
    local members = {
        {
            name        = playerName,
            realm       = playerRealm,
            class       = playerClass or "WARRIOR",
            role        = playerRole,
            race        = UnitRace("player"),
            spec        = GetPlayerSpecName(),
            mythicScore = playerScore,
        }
    }

    -- Fill the remaining slots so the group always has 1 tank, 1 healer, 3 DPS
    local needed = { TANK = 1, HEALER = 1, DAMAGER = 3 }
    needed[playerRole] = needed[playerRole] - 1

    local roleQueue = {}
    for role, count in pairs(needed) do
        for _ = 1, count do roleQueue[#roleQueue + 1] = role end
    end
    -- Shuffle so order isn't always tank, healer, dps, dps, dps
    for i = #roleQueue, 2, -1 do
        local j = RandInt(1, i)
        roleQueue[i], roleQueue[j] = roleQueue[j], roleQueue[i]
    end
    for _, role in ipairs(roleQueue) do
        members[#members + 1] = MakeNPC(role, usedNames)
    end

    return members, playerName, playerRealm
end


-- Builds and saves one fake completed or abandoned M+ run.
-- Outcome distribution: ~40% timed, ~25% depleted, ~20% abandoned, ~15% reset
function addon.CreateTestRun()
    local level   = RandInt(2, 22)
    local dungeon = RandPick(TEST_DUNGEONS)
    local members, playerName, playerRealm = BuildGroup()
    local timeLimitMs = RandInt(28, 38) * 60 * 1000

    local run = {
        dungeon   = dungeon,
        keyLevel  = level,
        affixes   = {},
        members   = members,
        endTime   = time(),
        completed = false,
        abandoned = false,
        character = playerName .. "-" .. playerRealm,
    }

    local roll = RandInt(1, 100)
    local result

    if roll <= 40 then
        local ms = RandInt(math.floor(timeLimitMs * 0.55), timeLimitMs - 1000)
        run.completed        = true
        run.onTime           = true
        run.runTimeMs        = ms
        run.keystoneUpgrades = RandInt(1, 3)
        run.startTime        = time() - math.floor(ms / 1000)
        result = "|cff00ff00Timed|r"
    elseif roll <= 65 then
        local ms = RandInt(timeLimitMs, math.floor(timeLimitMs * 1.25))
        run.completed        = true
        run.onTime           = false
        run.runTimeMs        = ms
        run.keystoneUpgrades = 0
        run.startTime        = time() - math.floor(ms / 1000)
        result = "|cffff4444Depleted|r"
    elseif roll <= 85 then
        run.abandoned = true
        run.startTime = time() - RandInt(5, 25) * 60
        result = "|cff888888Abandoned|r"
    else
        run.reset     = true
        run.startTime = time() - RandInt(1, 10) * 60
        result = "|cff888888Reset|r"
    end

    addon.SaveRun(run)
    if addon.RefreshUI then addon.RefreshUI() end
    print("|cff00ff00[M+ Tracker]|r Test run added: " .. result .. " +" .. level .. " " .. dungeon)
end


-- Sets a fake in-progress run so the active run banner can be tested.
function addon.CreateTestActiveRun()
    local level   = RandInt(2, 22)
    local dungeon = RandPick(TEST_DUNGEONS)
    local members, playerName, playerRealm = BuildGroup()

    local fakeRun = {
        dungeon   = dungeon,
        keyLevel  = level,
        affixes   = {},
        members   = members,
        startTime = time(),
        timeLimit = RandInt(28, 38) * 60,
        completed = false,
        abandoned = false,
        character = playerName .. "-" .. playerRealm,
    }

    addon.SetActiveRun(fakeRun)
    if addon.RefreshUI then addon.RefreshUI() end
    print("|cff00ff00[M+ Tracker]|r Test active run started: +" .. level .. " " .. dungeon)
end
