-- Popups.lua

local addon = MythicPlusHistory


StaticPopupDialogs["MYTHICPLUSHISTORY_DELETE_RUN"] = {
    text           = "Delete |cff00ccff%s +%s|r?\nThis cannot be undone.",
    button1        = "Delete",
    button2        = "Cancel",
    OnAccept       = function(self, run)
        addon.DeleteRun(run)
        if addon.selectedRun == run then
            addon.selectedRun = nil
            addon.ClearRunDetail()
        end
        if addon.RefreshUI then addon.RefreshUI() end
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

StaticPopupDialogs["MYTHICPLUSHISTORY_PLAYER_NOTE"] = {
    text           = "Note for |cffdddddd%s|r",
    button1        = "Save",
    button2        = "Cancel",
    hasEditBox     = true,
    maxLetters     = 300,
    OnAccept       = function(self, playerKey)
        local text = self.EditBox:GetText():match("^%s*(.-)%s*$")
        addon.SetPlayerNote(playerKey, text ~= "" and text or nil)
        if addon.selectedRun then addon.ShowRunDetail(addon.selectedRun) end
        if addon.RefreshNotes then addon.RefreshNotes() end
    end,
    EditBoxOnEnterPressed = function(self)
        StaticPopup_OnClick(self:GetParent(), 1)
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

StaticPopupDialogs["MYTHICPLUSHISTORY_DELETE_NOTE"] = {
    text           = "Delete note for |cffdddddd%s|r?\nThis cannot be undone.",
    button1        = "Delete",
    button2        = "Cancel",
    OnAccept       = function(self, playerKey)
        addon.DeletePlayerNote(playerKey)
        if addon.RefreshNotes then addon.RefreshNotes() end
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}
