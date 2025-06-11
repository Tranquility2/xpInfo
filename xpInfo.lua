local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Localization: L will be populated by locale.lua
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)

-- Default database values
local defaults = {
    profile = {
        showFrame = true,
        framePosition = { "CENTER", UIParent, "CENTER", 0, 0 },
        xpSnapshots = {},
        maxSamples = 5,
        showMinimapIcon = true, 
        levelSnapshots = {}
    }
}

-- Frame
local statsFrame

-- Time tracking
local timePlayedTotal = 0
local timePlayedLevel = 0
local lastXP = 0
local xpGained = 0 -- Cumulative XP gained in the current level
local timeToLevel = "Calculating..."

-- Called when the addon is initialized
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, "profile") 
    self.defaults = defaults 
    -- Ensure xpSnapshots is initialized if loading old saved variables
    if self.db.profile.xpGainedSamples and not self.db.profile.xpSnapshots then
        self.db.profile.xpSnapshots = {} -- Or attempt migration if necessary
        self.db.profile.xpGainedSamples = nil -- Remove old data
    elseif not self.db.profile.xpSnapshots then
        self.db.profile.xpSnapshots = {}
    end
    -- ADDED: Ensure levelSnapshots exists in the profile
    if not self.db.profile.levelSnapshots then
        self.db.profile.levelSnapshots = {}
    end

    self:RegisterChatCommand("xpi", "ChatCommand")
    self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXP")
    self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("TIME_PLAYED_MSG", "OnTimePlayedMessage")

    -- Store the localization table in the addon for easy access
    self.L = L
    -- Create frame first so it's available to options and other modules
    self:CreateFrame()
    self.frame = statsFrame -- Ensure self.frame is set for other modules

    -- Initialize options from options.lua
    addonTable.InitializeOptions(self)
    
    -- Initialize chat commands from cli.lua
    addonTable.InitializeChatCommands(self)
    -- Initialize snapshot functions from snapshots.lua
    addonTable.InitializeSnapshots(self)
    -- Initialize minimap icon from minimap.lua
    addonTable.InitializeMinimapIcon(self)
    -- Make UpdateMinimapIconVisibility available on the addon instance
    self.UpdateMinimapIconVisibility = addonTable.UpdateMinimapIconVisibility
end

-- Called when the addon is enabled
function addon:OnEnable()
    if self.db.profile.showFrame and statsFrame then -- Ensure frame exists
        statsFrame:Show()
    end
    lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP()
    -- Update minimap icon visibility on enable
    self:UpdateMinimapIconVisibility(self)
end

function addonTable:GetDB()
    return self.db
end

function addon:ToggleUI()
    if statsFrame then
        if statsFrame:IsShown() then
            statsFrame:Hide()
            self.db.profile.showFrame = false
        else
            statsFrame:Show()
            self.db.profile.showFrame = true
            self:UpdateFrameText() -- Ensure text is updated when showing
        end
    else
        self:CreateFrame() -- Create the frame if it doesn't exist
        statsFrame:Show()
        self.db.profile.showFrame = true
    end
end

-- Create the UI frame
function addon:CreateFrame()
    statsFrame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    statsFrame:SetWidth(300)
    statsFrame:SetHeight(200) -- Initial height, will be adjusted by UpdateFrameText
    statsFrame:SetPoint(unpack(self.db.profile.framePosition))
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag("LeftButton")
    statsFrame:SetScript("OnDragStart", statsFrame.StartMoving)
    statsFrame:SetScript("OnDragStop", function(f) 
        f:StopMovingOrSizing()

        local xOffset = f:GetLeft()
        local yOffset = f:GetTop() - GetScreenHeight()

        addon.db.profile.framePosition = { "TOPLEFT", "UIParent", "TOPLEFT", xOffset, yOffset }
        
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, yOffset)
        
        addon:UpdateFrameText() 
    end)
    statsFrame:SetScript("OnMouseDown", function(f, button)
        self:UpdateFrameText() 
    end)

    statsFrame.title = statsFrame:CreateFontString(addonName .. "FrameTitle", "ARTWORK", "GameFontNormalLarge")
    statsFrame.title:SetPoint("TOP", 0, -5)
    statsFrame.title:SetText(L["Progression"])

    statsFrame.xpText = statsFrame:CreateFontString(addonName .. "FrameXPText", "ARTWORK", "GameFontNormal")
    statsFrame.xpText:SetPoint("TOPLEFT", 15, -30)
    statsFrame.xpText:SetJustifyH("LEFT")

    statsFrame.remainingText = statsFrame:CreateFontString(addonName .. "FrameRemainingXPText", "ARTWORK", "GameFontNormal")
    statsFrame.remainingText:SetPoint("TOPLEFT", statsFrame.xpText, "BOTTOMLEFT", 0, -5)
    statsFrame.remainingText:SetJustifyH("LEFT")

    -- ADDED: Mobs to level text
    statsFrame.mobsToLevelText = statsFrame:CreateFontString(addonName .. "FrameMobsToLevelText", "ARTWORK", "GameFontNormal")
    statsFrame.mobsToLevelText:SetPoint("TOPLEFT", statsFrame.remainingText, "BOTTOMLEFT", 0, -5)
    statsFrame.mobsToLevelText:SetJustifyH("LEFT")

    statsFrame.timeText = statsFrame:CreateFontString(addonName .. "FrameTimeText", "ARTWORK", "GameFontNormal")
    statsFrame.timeText:SetPoint("TOPLEFT", statsFrame.mobsToLevelText, "BOTTOMLEFT", 0, -5) -- MODIFIED: Anchor to new mobsToLevelText
    statsFrame.timeText:SetJustifyH("LEFT")

    -- Refresh button 
    statsFrame.refreshButton = CreateFrame("Button", addonName .. "RefreshButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.refreshButton:SetText(L["Refresh"])
    statsFrame.refreshButton:SetWidth(80)
    statsFrame.refreshButton:SetHeight(20)
    statsFrame.refreshButton:SetPoint("BOTTOMLEFT", statsFrame, "BOTTOMLEFT", 10, 15)
    statsFrame.refreshButton:SetScript("OnClick", function()
        RequestTimePlayed()
    end)

    -- Settings button
    statsFrame.settingsButton = CreateFrame("Button", addonName .. "SettingsButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.settingsButton:SetText(L["Settings"])
    statsFrame.settingsButton:SetWidth(80)
    statsFrame.settingsButton:SetHeight(20)
    statsFrame.settingsButton:SetPoint("BOTTOMLEFT", statsFrame, "BOTTOMLEFT", 90, 15)
    statsFrame.settingsButton:SetScript("OnClick", function()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end)

    -- Debug button to view snapshots
    statsFrame.debugButton = CreateFrame("Button", addonName .. "DebugButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.debugButton:SetText(L["View Snapshots"])
    statsFrame.debugButton:SetWidth(120)
    statsFrame.debugButton:SetHeight(20)
    statsFrame.debugButton:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -10, 15)
    statsFrame.debugButton:SetScript("OnClick", function()
        self:snapshotsViewerBuidler()
    end)

    statsFrame:SetScript("OnHide", function(f) -- f is the frame itself
        addon.db.profile.showFrame = false
    end)

    self:UpdateFrameText()
end

-- Update the text on the frame
function addon:UpdateFrameText()
    if not statsFrame or not statsFrame:IsShown() then return end

    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    local currentXPPerc = 0
    local restedXPPerc = 0

    if maxXP > 0 then
        currentXPPerc = (currentXP / maxXP) * 100
        restedXPPerc = (restedXP / maxXP) * 100
    end

    local xpString = string.format(L["Current XP"] .. ": %s / %s (%s%%)\n" .. L["Rested XP"] .. ": %s / %s (%s%%)", 
                                   currentXP, 
                                   maxXP, 
                                   string.format("%.1f", currentXPPerc), 
                                   restedXP, 
                                   maxXP,
                                   string.format("%.1f", restedXPPerc))
    statsFrame.xpText:SetText(xpString)

    local timePlayedTotalString = self:FormatTime(timePlayedTotal)
    local timePlayedLevelString = self:FormatTime(timePlayedLevel)

    local timeString = string.format(L["Time Played (Total)"] .. ": %s\n" .. L["Time Played (Level)"] .. ": %s\n",
                                   timePlayedTotalString, timePlayedLevelString)
    statsFrame.timeText:SetText(timeString)

    remainingString = string.format(L["Time to Level"] .. ": %s", timeToLevel)
    statsFrame.remainingText:SetText(remainingString)
    
    -- ADDED: Calculate and set mobs to level text
    local mobsToLevelString = L["Mobs to Level"] .. ": " .. L["Calculating..."] -- Default text
    if self.db.profile.xpSnapshots and #self.db.profile.xpSnapshots > 0 then
        local totalXpFromSnapshots = 0
        local numValidSnapshots = 0
        for _, snap in ipairs(self.db.profile.xpSnapshots) do
            -- Assuming snap.xp stores the XP gained from a single event (newXPGained)
            if snap.xp and snap.xp > 0 then
                totalXpFromSnapshots = totalXpFromSnapshots + snap.xp
                numValidSnapshots = numValidSnapshots + 1
            end
        end

        if numValidSnapshots > 0 then
            local avgXpPerEvent = totalXpFromSnapshots / numValidSnapshots
            local currentXPValue = UnitXP("player") -- Renamed to avoid conflict with local currentXP in some scopes
            local maxXPValue = UnitXPMax("player")   -- Renamed
            local xpNeededToLevel = maxXPValue - currentXPValue

            if xpNeededToLevel > 0 and avgXpPerEvent > 0 then
                local mobsNeeded = math.ceil(xpNeededToLevel / avgXpPerEvent)
                -- TODO: Add L["Mobs to Level: %d (avg %s XP)"] to locale.lua
                mobsToLevelString = string.format(L["Mobs to Level: %d (avg %s XP)"], mobsNeeded, string.format("%.0f", avgXpPerEvent))
            elseif xpNeededToLevel <= 0 then
                mobsToLevelString = L["Mobs to Level"] .. ": " .. L["N/A"]
            end
        end
    end
    statsFrame.mobsToLevelText:SetText(mobsToLevelString)
    
    local titleH = statsFrame.title:GetStringHeight()
    local xpTextH = statsFrame.xpText:GetStringHeight()
    local timeTextH = statsFrame.timeText:GetStringHeight()
    local remainingTextH = statsFrame.remainingText:GetStringHeight()
    local mobsToLevelTextH = statsFrame.mobsToLevelText:GetStringHeight() -- ADDED: Get height of new text
    local buttonH = statsFrame.refreshButton:GetHeight()

    -- The constant 50 here is an estimate for all vertical paddings combined
    -- (e.g., above title, between elements, below button)
    statsFrame:SetHeight(titleH + xpTextH + remainingTextH + mobsToLevelTextH + timeTextH + buttonH + 60) -- MODIFIED: Added mobsToLevelTextH and increased padding slightly
end

-- Update XP and calculate time to level
function addon:UpdateXP()
    local currentXP = UnitXP("player")
    local newXPGained = currentXP - lastXP

    if newXPGained > 0 then
        -- xpGained = xpGained + newXPGained -- xpGained is cumulative for the current level

        -- Ensure snapshots table exists
        if not self.db.profile.xpSnapshots then
            self.db.profile.xpSnapshots = {}
        end

        -- Add a new snapshot: {cumulative XP for this level, session time when snapshot taken}
        table.insert(self.db.profile.xpSnapshots, {xp = newXPGained, time = GetTime()})
        self:updateSnapshotsViewer()

        -- for i, snap in ipairs(self.db.profile.xpSnapshots) do
        --     print(string.format("Snapshot %d: {xp=%d, time=%0.f}", i, snap.xp, snap.time)) -- Debug print
        -- end

        local maxSamples = self.db.profile.maxSamples 
        if not maxSamples or maxSamples < 2 or maxSamples > 10 then maxSamples = defaults.profile.maxSamples end 
        if maxSamples < 2 then maxSamples = 2 end -- Ensure min 2 for rate calc

        while #self.db.profile.xpSnapshots > maxSamples do
            table.remove(self.db.profile.xpSnapshots, 1) -- Remove the oldest snapshot
        end
    end
    lastXP = currentXP

    local xpNeeded = UnitXPMax("player") - currentXP

    if xpNeeded <= 0 and UnitXPMax("player") > 0 then 
        timeToLevel = L["N/A"]
    elseif self.db.profile.xpSnapshots and #self.db.profile.xpSnapshots >= 2 then
        local oldestSnapshot = self.db.profile.xpSnapshots[1]
        local latestSnapshot = self.db.profile.xpSnapshots[#self.db.profile.xpSnapshots]

        local totalGainedXP = 0
        for i = 1, #self.db.profile.xpSnapshots do
            totalGainedXP = totalGainedXP + self.db.profile.xpSnapshots[i].xp
        end
        local deltaTime = latestSnapshot.time - oldestSnapshot.time

        if deltaTime > 0 and totalGainedXP > 0 then
            local xpPerHour = (totalGainedXP / deltaTime) * 3600
            -- xpNeeded is > 0 here because of the first if condition
            local timeToLevelSeconds = (xpNeeded / xpPerHour) * 3600 
            timeToLevel = self:FormatTime(timeToLevelSeconds)
        else
            timeToLevel = L["Calculating..."] -- Not enough change in XP/time or deltaTime was zero
            print("totalGainedXP=" .. totalGainedXP .. ", deltatime=" .. deltaTime) -- Debug print
        end
    else
        timeToLevel = L["Calculating..."] -- Not enough snapshots to calculate rate
    end
    
    self:UpdateFrameText()
end

-- Handle level up event
function addon:LevelUp()
    timePlayedLevel = 0 -- RESET for the new level
    xpGained = 0        -- Reset cumulative XP for the new level
    if self.db.profile then 
        self.db.profile.xpSnapshots = {} -- Clear snapshots for the new level
    end
    timeToLevel = L["Calculating..."]
    lastXP = UnitXP("player") -- Reset lastXP for the new level
    RequestTimePlayed() -- Request new time played data after level up

    print(addonName .. ": " .. L["Congratulations on leveling up!"])

    -- Store the time and level in the database if needed under a levelSnapshots table
    if not self.db.profile.levelSnapshots then
        self.db.profile.levelSnapshots = {}
    end
    table.insert(self.db.profile.levelSnapshots, {level = UnitLevel("player"), time = timePlayedTotal})

    -- Debug print for level snapshots
    for i, snap in ipairs(self.db.profile.levelSnapshots) do
        print(string.format("Level Snapshot %d: {level=%d, time=%0.f}", i, snap.level, snap.time))
    end

    self:UpdateFrameText() -- Update the frame text after level up
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
    self:UpdateXP() -- This will update calculations and then call UpdateFrameText
end

-- Format seconds into a readable string (hh:mm:ss)
function addon:FormatTime(seconds)
    if not seconds or seconds < 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end
