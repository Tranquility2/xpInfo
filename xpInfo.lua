-- Get the addon object
local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Localization
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)
if L then
    L["Player Progression"] = "Player Progression"
    L["Current XP: %s / %s\nRested XP: %s"] = "Current XP: %s / %s\nRested XP: %s"
    L["Time Played (Total): %s\nTime Played (Level): %s\nTime to Level: %s"] = "Time Played (Total): %s\nTime Played (Level): %s\nTime to Level: %s"
    L["N/A"] = "N/A"
    L["Calculating..."] = "Calculating..."
    L["Frame position reset."] = "Frame position reset."
    L["Usage: /pp [show|hide|reset]"] = "Usage: /xpi [show|hide|reset]"
    L["Congratulations on leveling up!"] = "Congratulations on leveling up!"
    L["Refresh"] = "Refresh" -- ADDED
end
-- After NewLocale, GetLocale can be called.
L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Default database values
local defaults = {
    profile = {
        showFrame = true,
        framePosition = { "CENTER", UIParent, "CENTER", 0, 0 },
    }
}

-- Frame
local frame

-- Time tracking
local timePlayedTotal = 0
local timePlayedLevel = 0
local lastXP = 0
local xpGained = 0
local timeToLevel = "Calculating..."

-- Called when the addon is initialized
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, true)
    self:RegisterChatCommand("xpi", "ChatCommand")
    self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXP")
    self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("TIME_PLAYED_MSG", "OnTimePlayedMessage") -- Ensure this is registered

    -- Create the frame
    self:CreateFrame()
end

-- Called when the addon is enabled
function addon:OnEnable()
    if self.db.profile.showFrame then
        frame:Show()
    end
    lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP() 
end

-- Create the UI frame
function addon:CreateFrame()
    frame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetWidth(250)
    frame:SetHeight(150) -- Initial height, will be adjusted by UpdateFrameText
    frame:SetPoint(unpack(self.db.profile.framePosition))
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f) 
        f:StopMovingOrSizing()

        local xOffset = f:GetLeft()
        local yOffset = f:GetTop() - GetScreenHeight()

        addon.db.profile.framePosition = { "TOPLEFT", "UIParent", "TOPLEFT", xOffset, yOffset }
        
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, yOffset)
        
        addon:UpdateFrameText() 
    end)
    frame:SetScript("OnMouseDown", function(f, button)
        self:UpdateFrameText() 
    end)

    frame.title = frame:CreateFontString(addonName .. "FrameTitle", "ARTWORK", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -5)
    frame.title:SetText(L["Player Progression"])

    frame.xpText = frame:CreateFontString(addonName .. "FrameXPText", "ARTWORK", "GameFontNormal")
    frame.xpText:SetPoint("TOPLEFT", 15, -30)
    frame.xpText:SetJustifyH("LEFT")

    frame.timeText = frame:CreateFontString(addonName .. "FrameTimeText", "ARTWORK", "GameFontNormal")
    frame.timeText:SetPoint("TOPLEFT", frame.xpText, "BOTTOMLEFT", 0, -5)
    frame.timeText:SetJustifyH("LEFT")

    -- Refresh Button -- ADDED BLOCK
    frame.refreshButton = CreateFrame("Button", addonName .. "RefreshButton", frame, "UIPanelButtonTemplate")
    frame.refreshButton:SetText(L["Refresh"])
    frame.refreshButton:SetWidth(80)
    frame.refreshButton:SetHeight(20)
    frame.refreshButton:SetPoint("TOP", frame.timeText, "BOTTOM", 0, -10) -- Position below timeText

    frame.refreshButton:SetScript("OnClick", function()
        RequestTimePlayed()
        -- addon:Print("Refresh clicked, requesting time data.") -- Optional debug
    end)
    -- END ADDED BLOCK

    frame:SetScript("OnHide", function(f) -- f is the frame itself
        addon.db.profile.showFrame = false
    end)

    self:UpdateFrameText()
end

-- Update the text on the frame
function addon:UpdateFrameText()
    if not frame or not frame:IsShown() then return end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local xpString = string.format(L["Current XP: %s / %s\nRested XP: %s"], currentXP, maxXP, restedXP)
    frame.xpText:SetText(xpString)

    local timePlayedTotalString = self:FormatTime(timePlayedTotal)
    local timePlayedLevelString = self:FormatTime(timePlayedLevel)

    local timeString = string.format(L["Time Played (Total): %s\nTime Played (Level): %s\nTime to Level: %s"],
                                   timePlayedTotalString, timePlayedLevelString, timeToLevel)
    frame.timeText:SetText(timeString)
    
    -- Adjusted height calculation -- MODIFIED LINE
    local titleH = frame.title:GetStringHeight()
    local xpTextH = frame.xpText:GetStringHeight()
    local timeTextH = frame.timeText:GetStringHeight()
    local buttonH = frame.refreshButton:GetHeight() -- This is 20 as set in CreateFrame

    -- The constant 50 here is an estimate for all vertical paddings combined
    -- (e.g., above title, between elements, below button)
    frame:SetHeight(titleH + xpTextH + timeTextH + buttonH + 50)
end

-- Handle chat commands
function addon:ChatCommand(input)
    if input == "show" then
        frame:Show()
        self.db.profile.showFrame = true
    elseif input == "hide" then
        frame:Hide()
        self.db.profile.showFrame = false
    elseif input == "reset" then
        -- Reset frame position or other settings if needed
        self.db.profile.framePosition = defaults.profile.framePosition
        frame:ClearAllPoints()
        frame:SetPoint(unpack(self.db.profile.framePosition))
        print(addonName .. ": " .. L["Frame position reset."])
    else
        print(addonName .. ": " .. L["Usage: /pp [show|hide|reset]"])
    end
end

-- Update XP and calculate time to level
function addon:UpdateXP()
    local currentXP = UnitXP("player")
    local newXPGained = currentXP - lastXP
    if newXPGained > 0 then
        xpGained = xpGained + newXPGained
    end
    lastXP = currentXP

    if xpGained > 0 and timePlayedLevel > 0 then
        local xpPerHour = (xpGained / timePlayedLevel) * 3600
        local xpNeeded = UnitXPMax("player") - currentXP
        if xpNeeded > 0 and xpPerHour > 0 then
            local timeToLevelSeconds = xpNeeded / xpPerHour * 3600 -- Corrected calculation
            timeToLevel = self:FormatTime(timeToLevelSeconds)
        else
            timeToLevel = L["N/A"]
        end
    else
        timeToLevel = L["Calculating..."]
    end
    self:UpdateFrameText()
end


-- Handle level up event
function addon:LevelUp()
    timePlayedLevel = 0 -- RESET for the new level
    xpGained = 0
    timeToLevel = L["Calculating..."]
    lastXP = UnitXP("player") -- Reset lastXP for the new level
    RequestTimePlayed() -- Request new time played data after level up
    self:UpdateFrameText()
    print(addonName .. ": " .. L["Congratulations on leveling up!"])
end

-- Handler for PLAYER_ENTERING_WORLD
function addon:OnPlayerEnteringWorld()
    RequestTimePlayed() -- Request time played data on entering world
    self:UpdateXP() 
end

-- Handler for TIME_PLAYED_MSG
function addon:OnTimePlayedMessage(event, totalTimeArg, levelTimeArg)
    -- totalTimeArg is total time played in seconds on this character
    -- levelTimeArg is total time played in seconds at the current level on this character
    if totalTimeArg and levelTimeArg then
        timePlayedTotal = totalTimeArg
        timePlayedLevel = levelTimeArg
    end
    self:UpdateXP()           -- This will update calculations and then call UpdateFrameText
end

-- Format seconds into a readable string (hh:mm:ss)
function addon:FormatTime(seconds)
    if not seconds or seconds < 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end
