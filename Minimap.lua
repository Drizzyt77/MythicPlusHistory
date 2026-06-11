-- Minimap.lua
-- LibDBIcon-1.0 minimap button. addon.RegisterMinimapIcon() is called from
-- UI.lua's stateRestoreFrame once addon.db is ready (so LibDBIcon can
-- read/write the saved angle without the DB being nil).
local addon = MythicPlusTracker

local LDB    = LibStub and LibStub("LibDataBroker-1.1", true)
local DBIcon = LibStub and LibStub("LibDBIcon-1.0",     true)

local minimapDataObj
if LDB then
    minimapDataObj = LDB:NewDataObject("MythicPlusTracker", {
        type  = "launcher",
        text  = "MythicPlusTracker",
        icon  = "Interface\\Icons\\achievement_challengemode_goldmedal",
        OnClick = function(_, button)
            if button == "LeftButton" then addon.ToggleUI() end
        end,
        OnTooltipShow = function(tt)
            tt:SetText("|cff00ccffMythic Tracker|r")
            tt:AddLine("Click to open or close", 1, 1, 1)
            tt:AddLine("Drag to reposition",     0.7, 0.7, 0.7)
        end,
    })
end

function addon.RegisterMinimapIcon()
    if not (DBIcon and minimapDataObj) then return end
    DBIcon:Register("MythicPlusTracker", minimapDataObj, addon.db.minimap)
    -- Swap in the actual keystone icon once the item is in the client cache
    local function ApplyKeystoneIcon()
        local id = GetItemIcon and GetItemIcon(180653)
        if not id then return false end
        minimapDataObj.icon = id
        return true
    end
    if not ApplyKeystoneIcon() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        w:SetScript("OnEvent", function(self, _, itemID)
            if itemID == 180653 and ApplyKeystoneIcon() then
                self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
            end
        end)
        GetItemInfo(180653)
    end
end
