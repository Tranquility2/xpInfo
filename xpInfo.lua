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

-- Called when the addon is initialized
function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName .. "DB", defaults, "profile") 
    self.defaults = defaults 

    -- Initialize time tracking variables on the addon instance
    self.timePlayedTotal = 0
    self.timePlayedLevel = 0
    self.lastXP = 0
    self.xpGained = 0 -- Cumulative XP gained in the current level
    self.timeToLevel = L["Calculating..."]


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
    
    -- Initialize stats frame from stats.lua
    -- The CreateStatsFrame function in stats.lua will create and return the frame.
    -- We store it on self.statsFrame so other parts (like options.lua if it needs a direct reference) can use it.
    -- Note: options.lua was previously looking for self.frame. We'll need to update that or keep self.frame aliased.
    self.statsFrame = addonTable.CreateStatsFrame(self) 
    self.frame = self.statsFrame -- Alias for compatibility with options.lua if it uses self.frame

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

    -- Make frame control functions from stats.lua available on the addon instance
    self.ToggleStatsFrame = addonTable.ToggleStatsFrame
    self.UpdateStatsFrameText = addonTable.UpdateStatsFrameText
    self.ShowStatsFrame = addonTable.ShowStatsFrame
    self.HideStatsFrame = addonTable.HideStatsFrame
    self.SetStatsFrameVisibility = addonTable.SetStatsFrameVisibility -- For options
end

-- Called when the addon is enabled
function addon:OnEnable()
    if self.db.profile.showFrame and self.ShowStatsFrame then
        self:ShowStatsFrame(self) -- Pass self as addonInstance
    end
    self.lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP() -- This will call UpdateStatsFrameText
    -- Update minimap icon visibility on enable
    if self.UpdateMinimapIconVisibility then
        self:UpdateMinimapIconVisibility(self)
    end
end

function addonTable:GetDB()
    return self.db
end

-- Update XP and calculate time to level
function addon:UpdateXP()
    local currentXP = UnitXP("player")
    local newXPGained = currentXP - self.lastXP

    if newXPGained > 0 then
        -- Ensure snapshots table exists
        if not self.db.profile.xpSnapshots then
            self.db.profile.xpSnapshots = {}
        end

        -- Add a new snapshot: {cumulative XP for this level, session time when snapshot taken}
        table.insert(self.db.profile.xpSnapshots, {xp = newXPGained, time = GetTime()})
        if self.updateSnapshotsViewer then self:updateSnapshotsViewer() end -- Check if snapshot viewer exists

        local maxSamples = self.db.profile.maxSamples 
        if not maxSamples or maxSamples < 2 or maxSamples > 10 then maxSamples = defaults.profile.maxSamples end 
        if maxSamples < 2 then maxSamples = 2 end -- Ensure min 2 for rate calc

        while #self.db.profile.xpSnapshots > maxSamples do
            table.remove(self.db.profile.xpSnapshots, 1) -- Remove the oldest snapshot
        end
    end
    self.lastXP = currentXP

    local xpNeeded = UnitXPMax("player") - currentXP

    if xpNeeded <= 0 and UnitXPMax("player") > 0 then 
        self.timeToLevel = L["N/A"]
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
            local timeToLevelSeconds = (xpNeeded / xpPerHour) * 3600 
            self.timeToLevel = self:FormatTime(timeToLevelSeconds)
        else
            self.timeToLevel = L["Calculating..."] 
            print("totalGainedXP=" .. totalGainedXP .. ", deltatime=" .. deltaTime) 
        end
    else
        self.timeToLevel = L["Calculating..."] 
    end
    
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end
end

-- Handle level up event
function addon:LevelUp()
    self.timePlayedLevel = 0 
    self.xpGained = 0        
    if self.db.profile then 
        self.db.profile.xpSnapshots = {} 
    end
    self.timeToLevel = L["Calculating..."]
    self.lastXP = UnitXP("player") 
    RequestTimePlayed() 

    print(addonName .. ": " .. L["Congratulations on leveling up!"])

    if not self.db.profile.levelSnapshots then
        self.db.profile.levelSnapshots = {}
    end
    table.insert(self.db.profile.levelSnapshots, {level = UnitLevel("player"), time = self.timePlayedTotal})

    for i, snap in ipairs(self.db.profile.levelSnapshots) do
        print(string.format("Level Snapshot %d: {level=%d, time=%0.f}", i, snap.level, snap.time))
    end

    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end
end

-- Handler for PLAYER_ENTERING_WORLD
function addon:OnPlayerEnteringWorld()
    RequestTimePlayed() 
    self:UpdateXP() 
end

-- Handler for TIME_PLAYED_MSG
function addon:OnTimePlayedMessage(event, totalTimeArg, levelTimeArg)
    if totalTimeArg and levelTimeArg then
        self.timePlayedTotal = totalTimeArg
        self.timePlayedLevel = levelTimeArg
    end
    self:UpdateXP() 
end

-- Format seconds into a readable string (hh:mm:ss)
function addon:FormatTime(seconds)
    if not seconds or seconds < 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end
