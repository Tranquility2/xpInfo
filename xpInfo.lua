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
local frame

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
    self.frame = frame -- Ensure self.frame is set for other modules

    -- Initialize options from options.lua
    addonTable.InitializeOptions(self)
    
    -- Initialize chat commands from cli.lua
    addonTable.InitializeChatCommands(self)
    -- Initialize snapshot functions from snapshots.lua
    addonTable.InitializeSnapshots(self)
    -- Initialize minimap icon from minimap.lua
    addonTable.InitializeMinimapIcon(self)
end

-- Called when the addon is enabled
function addon:OnEnable()
    if self.db.profile.showFrame and frame then -- Ensure frame exists
        frame:Show()
    end
    lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP()
end

function addonTable:GetDB()
    return self.db
end

function addon:ToggleUI()
    if frame then
        if frame:IsShown() then
            frame:Hide()
            self.db.profile.showFrame = false
        else
            frame:Show()
            self.db.profile.showFrame = true
            self:UpdateFrameText() -- Ensure text is updated when showing
        end
    else
        self:CreateFrame() -- Create the frame if it doesn't exist
        frame:Show()
        self.db.profile.showFrame = true
    end
end

-- Create the UI frame
function addon:CreateFrame()
    frame = CreateFrame("Frame", addonName .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetWidth(300)
    frame:SetHeight(200) -- Initial height, will be adjusted by UpdateFrameText
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
    frame.title:SetText(L["Progression"])

    frame.xpText = frame:CreateFontString(addonName .. "FrameXPText", "ARTWORK", "GameFontNormal")
    frame.xpText:SetPoint("TOPLEFT", 15, -30)
    frame.xpText:SetJustifyH("LEFT")

    frame.remainingText = frame:CreateFontString(addonName .. "FrameRemainingXPText", "ARTWORK", "GameFontNormal")
    frame.remainingText:SetPoint("TOPLEFT", frame.xpText, "BOTTOMLEFT", 0, -5)
    frame.remainingText:SetJustifyH("LEFT")

    -- ADDED: Mobs to level text
    frame.mobsToLevelText = frame:CreateFontString(addonName .. "FrameMobsToLevelText", "ARTWORK", "GameFontNormal")
    frame.mobsToLevelText:SetPoint("TOPLEFT", frame.remainingText, "BOTTOMLEFT", 0, -5)
    frame.mobsToLevelText:SetJustifyH("LEFT")

    frame.timeText = frame:CreateFontString(addonName .. "FrameTimeText", "ARTWORK", "GameFontNormal")
    frame.timeText:SetPoint("TOPLEFT", frame.mobsToLevelText, "BOTTOMLEFT", 0, -5) -- MODIFIED: Anchor to new mobsToLevelText
    frame.timeText:SetJustifyH("LEFT")

    -- Refresh button 
    frame.refreshButton = CreateFrame("Button", addonName .. "RefreshButton", frame, "UIPanelButtonTemplate")
    frame.refreshButton:SetText(L["Refresh"])
    frame.refreshButton:SetWidth(80)
    frame.refreshButton:SetHeight(20)
    frame.refreshButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 15)
    frame.refreshButton:SetScript("OnClick", function()
        RequestTimePlayed()
    end)

    -- Settings button
    frame.settingsButton = CreateFrame("Button", addonName .. "SettingsButton", frame, "UIPanelButtonTemplate")
    frame.settingsButton:SetText(L["Settings"])
    frame.settingsButton:SetWidth(80)
    frame.settingsButton:SetHeight(20)
    frame.settingsButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 90, 15)
    frame.settingsButton:SetScript("OnClick", function()
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end)

    -- Debug button to view snapshots
    frame.debugButton = CreateFrame("Button", addonName .. "DebugButton", frame, "UIPanelButtonTemplate")
    frame.debugButton:SetText(L["View Snapshots"])
    frame.debugButton:SetWidth(120)
    frame.debugButton:SetHeight(20)
    frame.debugButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 15)
    frame.debugButton:SetScript("OnClick", function()
        self:snapshotsViewerBuidler()
    end)

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
    frame.xpText:SetText(xpString)

    local timePlayedTotalString = self:FormatTime(timePlayedTotal)
    local timePlayedLevelString = self:FormatTime(timePlayedLevel)

    local timeString = string.format(L["Time Played (Total)"] .. ": %s\n" .. L["Time Played (Level)"] .. ": %s\n",
                                   timePlayedTotalString, timePlayedLevelString)
    frame.timeText:SetText(timeString)

    remainingString = string.format(L["Time to Level"] .. ": %s", timeToLevel)
    frame.remainingText:SetText(remainingString)
    
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
    frame.mobsToLevelText:SetText(mobsToLevelString)
    
    local titleH = frame.title:GetStringHeight()
    local xpTextH = frame.xpText:GetStringHeight()
    local timeTextH = frame.timeText:GetStringHeight()
    local remainingTextH = frame.remainingText:GetStringHeight()
    local mobsToLevelTextH = frame.mobsToLevelText:GetStringHeight() -- ADDED: Get height of new text
    local buttonH = frame.refreshButton:GetHeight()

    -- The constant 50 here is an estimate for all vertical paddings combined
    -- (e.g., above title, between elements, below button)
    frame:SetHeight(titleH + xpTextH + remainingTextH + mobsToLevelTextH + timeTextH + buttonH + 60) -- MODIFIED: Added mobsToLevelTextH and increased padding slightly
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
