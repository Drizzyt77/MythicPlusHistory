-- TestData.lua
-- Generates fake M+ runs for UI testing.
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

local TEST_NAMES   = { "Drizzyt", "Zephyra", "Ironveil", "Lúnara", "Thornwick", "Solvex", "Pyremane", "Coldash" }
local TEST_REALMS  = { "Stormrage", "Illidan", "Tichondrius", "Area-52", "Mal'Ganis" }
local TEST_CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "DEATHKNIGHT", "EVOKER" }

local TEST_RACES = {
    "Human", "Dwarf", "Gnome", "Night Elf", "Draenei", "Worgen",
    "Void Elf", "Dark Iron Dwarf", "Kul Tiran",
    "Orc", "Undead", "Tauren", "Troll", "Blood Elf", "Goblin",
    "Nightborne", "Highmountain Tauren", "Zandalari Troll", "Vulpera", "Dracthyr",
}

local CLASS_SPECS = {
    WARRIOR     = { "Arms", "Fury", "Protection" },
    PALADIN     = { "Holy", "Protection", "Retribution" },
    HUNTER      = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE       = { "Assassination", "Outlaw", "Subtlety" },
    PRIEST      = { "Discipline", "Holy", "Shadow" },
    SHAMAN      = { "Elemental", "Enhancement", "Restoration" },
    MAGE        = { "Arcane", "Fire", "Frost" },
    WARLOCK     = { "Affliction", "Demonology", "Destruction" },
    MONK        = { "Brewmaster", "Mistweaver", "Windwalker" },
    DRUID       = { "Balance", "Feral", "Guardian", "Restoration" },
    DEMONHUNTER = { "Havoc", "Devourer", "Vengeance" },
    DEATHKNIGHT = { "Blood", "Frost", "Unholy" },
    EVOKER      = { "Devastation", "Preservation", "Augmentation" },
}

local function RandInt(min, max) return math.random(min, max) end
local function RandPick(t) return t[RandInt(1, #t)] end


-- Builds and saves one fake completed M+ run.
function addon.CreateTestRun()
    local level   = RandInt(2, 20)
    local dungeon = RandPick(TEST_DUNGEONS)
    local onTime  = RandInt(1, 3) ~= 1  -- ~66% timed

    local timeLimitMs = RandInt(25, 40) * 60 * 1000
    local runTimeMs
    if onTime then
        runTimeMs = RandInt(math.floor(timeLimitMs * 0.6), timeLimitMs - 1000)
    else
        runTimeMs = RandInt(timeLimitMs, math.floor(timeLimitMs * 1.3))
    end

    local members    = {}
    local usedNames  = {}
    local roles      = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }

    local playerName  = UnitName("player") or "Drizzyt"
    local playerRealm = GetRealmName() or "Stormrage"
    local _, playerClass = UnitClass("player")
    local playerRace  = UnitRace("player")
    local playerSpecName = nil
    if GetSpecialization then
        local specIdx = GetSpecialization()
        if specIdx then
            local _, sName = GetSpecializationInfo(specIdx)
            playerSpecName = sName
        end
    end
    local playerScore = nil
    if C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
        if ok and summary then playerScore = summary.currentSeasonScore end
    end
    table.insert(members, {
        name        = playerName,
        realm       = playerRealm,
        class       = playerClass or "WARRIOR",
        role        = roles[1],
        race        = playerRace,
        spec        = playerSpecName,
        mythicScore = playerScore,
    })
    usedNames[playerName] = true

    for i = 2, 5 do
        local name
        repeat name = RandPick(TEST_NAMES) until not usedNames[name]
        usedNames[name] = true
        local memberClass = RandPick(TEST_CLASSES)
        table.insert(members, {
            name        = name,
            realm       = RandPick(TEST_REALMS),
            class       = memberClass,
            role        = roles[i],
            race        = RandPick(TEST_RACES),
            spec        = RandPick(CLASS_SPECS[memberClass]),
            mythicScore = RandInt(500, 3800),
        })
    end

    local run = {
        dungeon          = dungeon,
        keyLevel         = level,
        affixes          = {},
        members          = members,
        startTime        = time() - math.floor(runTimeMs / 1000),
        endTime          = time(),
        completed        = true,
        abandoned        = false,
        runTimeMs        = runTimeMs,
        onTime           = onTime,
        keystoneUpgrades = onTime and RandInt(1, 3) or 0,
    }

    addon.SaveRun(run)
    if addon.RefreshUI then addon.RefreshUI() end

    local result = onTime and "|cff00ff00Timed|r" or "|cffff4444Depleted|r"
    print("|cff00ff00[M+ Tracker]|r Test run added: " .. result .. " +" .. level .. " " .. dungeon)
end


-- Sets a fake in-progress run so the active run banner can be tested.
-- Shared member-building logic reuses the same tables as CreateTestRun.
function addon.CreateTestActiveRun()
    local level   = RandInt(2, 20)
    local dungeon = RandPick(TEST_DUNGEONS)
    local members = {}
    local usedNames = {}
    local roles = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }

    local playerName  = UnitName("player") or "Drizzyt"
    local playerRealm = GetRealmName() or "Stormrage"
    local _, playerClass = UnitClass("player")
    local playerRace     = UnitRace("player")
    local playerSpec     = nil
    if GetSpecialization then
        local idx = GetSpecialization()
        if idx then local _, sName = GetSpecializationInfo(idx); playerSpec = sName end
    end
    table.insert(members, {
        name = playerName, realm = playerRealm,
        class = playerClass or "WARRIOR", role = roles[1],
        race = playerRace, spec = playerSpec,
    })
    usedNames[playerName] = true

    for i = 2, 5 do
        local name
        repeat name = RandPick(TEST_NAMES) until not usedNames[name]
        usedNames[name] = true
        local cls = RandPick(TEST_CLASSES)
        table.insert(members, {
            name = name, realm = RandPick(TEST_REALMS),
            class = cls, role = roles[i],
            race = RandPick(TEST_RACES), spec = RandPick(CLASS_SPECS[cls]),
            mythicScore = RandInt(500, 3800),
        })
    end

    local fakeRun = {
        dungeon   = dungeon,
        keyLevel  = level,
        affixes   = {},
        members   = members,
        startTime = time(),
        timeLimit = RandInt(25, 40) * 60,
        completed = false,
        abandoned = false,
        character = playerName .. "-" .. playerRealm,
    }

    addon.SetActiveRun(fakeRun)
    if addon.RefreshUI then addon.RefreshUI() end
    print("|cff00ff00[M+ Tracker]|r Test active run started: +" .. level .. " " .. dungeon)
end
