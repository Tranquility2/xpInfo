-- Create the frame
local myFrame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplate")
myFrame:SetFrameStrata("DIALOG")
myFrame:SetWidth(200)
myFrame:SetHeight(200)
myFrame:SetPoint("CENTER")

local lastLevelUpTime = nil -- Stores the timestamp of the last level up

-- Function to get XP related information (Ensured to be defined before use in event handler)
local function GetXPInfo()
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local neededXP = maxXP - currentXP
    local restedXP = GetXPExhaustion() -- This can be nil if no rested XP

    local restedXPString = "N/A"
    if restedXP then
        restedXPString = tostring(restedXP)
    end

    local timeOnLevelString = "N/A"
    if lastLevelUpTime then
        local timeSinceLastLevelUp = GetTime() - lastLevelUpTime
        local hours = math.floor(timeSinceLastLevelUp / 3600)
        local minutes = math.floor((timeSinceLastLevelUp % 3600) / 60)
        local seconds = math.floor(timeSinceLastLevelUp % 60)
        timeOnLevelString = string.format("%02dh %02dm %02ds", hours, minutes, seconds)
    end

    -- Note: "Time on level" is now tracked via PLAYER_LEVEL_UP event.
    return string.format("XP Information:\n\nCurrent XP: %d / %d\nXP to Next Level: %d\nRested XP: %s\nTime on Level: %s", currentXP, maxXP, neededXP, restedXPString, timeOnLevelString)
end

-- Create a FontString for displaying text (Ensured to be defined before use in event handler)
local myFrameText = myFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
myFrameText:SetPoint("TOPLEFT", myFrame, "TOPLEFT", 5, -5)
myFrameText:SetPoint("BOTTOMRIGHT", myFrame, "BOTTOMRIGHT", -5, 5) -- Allow text to wrap
myFrameText:SetJustifyH("LEFT")
myFrameText:SetJustifyV("TOP")
myFrameText:SetText("Info") -- Initial text, will be updated by GetXPInfo or OnDragStop

-- Event frame to listen for PLAYER_LEVEL_UP
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        lastLevelUpTime = GetTime()
        print("PLAYER_LEVEL_UP event fired. Last level-up time recorded.")
        -- If the frame is visible, update its text
        if myFrame and myFrame:IsShown() and myFrameText and GetXPInfo then
            myFrameText:SetText(GetXPInfo())
        end
    end
end)

myFrame:SetMovable(true)
myFrame:EnableMouse(true)
myFrame:RegisterForDrag("LeftButton")
myFrame:SetScript("OnDragStart", myFrame.StartMoving)
myFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local xpString = GetXPInfo()
    myFrameText:SetText(xpString) -- Update the text in the frame
end)
myFrame:Show()