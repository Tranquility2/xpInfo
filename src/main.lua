local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")

-- Localization: L will be populated by Locales/enUS.lua
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)    -- Default database values
-- Defaults for the addon database
local defaults = {
    profile = {
        showFrame = true,
        framePosition = { "CENTER", UIParent, "CENTER", 0, 0 },
        showXpBar = true,
        xpBarPosition = { "CENTER", UIParent, "CENTER", 0, -100 },
        xpSnapshots = {},
        maxSamples = 5,
        showMinimapIcon = true, 
        tooltipAnchor = "ANCHOR_BOTTOM",
        showLevelGraph = true, -- Default to showing the level graph
        levelGraphPosition = { "CENTER", UIParent, "CENTER", 200, 0 },
        levelSnapshots = {},
        maxLevel = 60, -- Default max level for Classic WoW
        estimatedMaxLevel = nil -- Calculated estimate: {level = maxLevel-1, time = estimated_time_to_max}
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
    
    -- ADDED: Ensure estimatedMaxLevel exists in the profile
    if self.db.profile.estimatedMaxLevel == nil then
        self.db.profile.estimatedMaxLevel = nil
    end

    self:RegisterChatCommand("xpi", "ChatCommand")
    self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXP")
    self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterEvent("TIME_PLAYED_MSG", "OnTimePlayedMessage")

    -- Store the localization table in the addon for easy access
    self.L = L
    
    -- Initialize options from options.lua
    addonTable.InitializeOptions(self)
    -- Initialize chat commands from cli.lua
    addonTable.InitializeChatCommands(self)
    -- Initialize AceGUI snapshot functions
    addonTable.InitializeAceGUISnapshots(self)
    -- Initialize minimap icon from minimap.lua
    addonTable.InitializeMinimapIcon(self)
    -- Make UpdateMinimapIconVisibility available on the addon instance
    self.UpdateMinimapIconVisibility = addonTable.UpdateMinimapIconVisibility

    -- Use AceGUI stats frame functions
    self.ToggleStatsFrame = addonTable.ToggleAceGUIStatsFrame
    self.UpdateStatsFrameText = addonTable.UpdateAceGUIStatsFrameText
    self.ShowStatsFrame = addonTable.ShowAceGUIStatsFrame
    self.HideStatsFrame = addonTable.HideAceGUIStatsFrame
    self.SetStatsFrameVisibility = addonTable.SetAceGUIStatsFrameVisibility -- For options
    
    -- Use XP Bar functions
    self.CreateXpBarFrame = addonTable.CreateXpBarFrame
    self.UpdateXpBarFrame = addonTable.UpdateXpBarFrame
    self.ToggleXpBarFrame = addonTable.ToggleXpBarFrame
    self.ShowXpBarFrame = addonTable.ShowXpBarFrame
    self.HideXpBarFrame = addonTable.HideXpBarFrame
    self.SetXpBarFrameVisibility = addonTable.SetXpBarFrameVisibility
    
    -- Use Level Graph functions
    self.CreateLevelGraphFrame = addonTable.CreateLevelGraphFrame
    self.UpdateLevelGraph = addonTable.UpdateLevelGraph
    self.ToggleLevelGraph = addonTable.ToggleLevelGraph
    self.ShowLevelGraph = addonTable.ShowLevelGraph
    self.HideLevelGraph = addonTable.HideLevelGraph
    
    -- Use AceGUI snapshots viewer
    self.snapshotsViewerBuidler = self.snapshotsAceGUIViewerBuilder -- Fix the typo in the original function name
    
    -- Create the initial frame - but don't show it yet
    self.statsFrame = addonTable.CreateAceGUIStatsFrame(self)
    self.frame = self.statsFrame -- Alias for compatibility with options.lua if it uses self.frame
end

-- Called when the addon is enabled
function addon:OnEnable()
    -- Show the stats frame if enabled
    if self.db.profile.showFrame and self.ShowStatsFrame then
        self:ShowStatsFrame(self) -- Pass self as addonInstance
    end
    
    -- Show the standalone XP bar if enabled
    if self.db.profile.showXpBar then
        addonTable.ShowXpBarFrame(self)
    end
    
    -- Show the level progression graph if enabled
    if self.db.profile.showLevelGraph then
        addonTable.ShowLevelGraph(self)
    end
    
    self.lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP() -- This will call UpdateStatsFrameText
    self:UpdateAction() -- Update action-related stats
    
    -- Calculate estimated max level with existing data
    self:CalculateEstimatedMaxLevel()
    
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
        
        -- Update the snapshots viewer if it exists (check both old and new methods)
        if self.updateSnapshotsViewer then 
            self:updateSnapshotsViewer() 
        end
        if self.updateAceGUISnapshotsViewer then 
            self:updateAceGUISnapshotsViewer() 
        end

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
        local snapshots = self.db.profile.xpSnapshots
        local N = #snapshots
        local oldestSnapshotTime = snapshots[1].time
        local latestSnapshotTime = snapshots[N].time
        local effectiveDeltaTime = latestSnapshotTime - oldestSnapshotTime

        -- Require some minimal time to have passed for a stable rate
        if effectiveDeltaTime > 0.001 then 
            local sum_x = 0.0
            local sum_y = 0.0
            local sum_xy = 0.0
            local sum_x_squared = 0.0
            local cumulative_xp_in_window = 0.0

            for i = 1, N do
                local snap = snapshots[i]
                local xp_gain = snap.xp or 0 -- Default to 0 if snap.xp is nil (shouldn't happen)
                local relative_time = snap.time - oldestSnapshotTime
                cumulative_xp_in_window = cumulative_xp_in_window + xp_gain

                sum_x = sum_x + relative_time
                sum_y = sum_y + cumulative_xp_in_window
                sum_xy = sum_xy + relative_time * cumulative_xp_in_window
                sum_x_squared = sum_x_squared + relative_time^2
            end

            local denominator = N * sum_x_squared - sum_x^2
            
            -- Check if denominator is reasonably positive (variance of time points is sufficiently positive)
            if denominator > 0.000001 then 
                local xp_per_second_candidate = (N * sum_xy - sum_x * sum_y) / denominator
                if xp_per_second_candidate > 0.000001 then -- Rate must be meaningfully positive
                    local xpPerHour = xp_per_second_candidate * 3600
                    -- xpNeeded is positive here due to the outer if condition
                    local timeToLevelSeconds = (xpNeeded / xpPerHour) * 3600 
                    self.timeToLevel = self:FormatTime(timeToLevelSeconds)
                else
                    self.timeToLevel = L["Calculating..."] -- Regression resulted in zero/negative rate
                end
            else
                -- Denominator too small (all time points are effectively the same). Fallback to simple average.
                -- cumulative_xp_in_window here holds the total XP gained in the window.
                if cumulative_xp_in_window > 0 then 
                    local xpPerHour_fallback = (cumulative_xp_in_window / effectiveDeltaTime) * 3600
                    if xpPerHour_fallback > 0.000001 then
                        local timeToLevelSeconds_fallback = (xpNeeded / xpPerHour_fallback) * 3600
                        self.timeToLevel = self:FormatTime(timeToLevelSeconds_fallback)
                    else
                        self.timeToLevel = L["Calculating..."]
                    end
                else
                    self.timeToLevel = L["Calculating..."] -- No XP gained in the window
                end
            end
        else 
            -- Not enough time elapsed for a stable rate calculation, or time anomaly
            self.timeToLevel = L["Calculating..."]
        end
    else
        self.timeToLevel = L["Calculating..."] -- Not enough snapshots
    end
    
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end

    self:UpdateAction()
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
    
    -- Update snapshots viewer if it exists
    if self.updateSnapshotsViewer then 
        self:updateSnapshotsViewer() 
    end
    if self.updateAceGUISnapshotsViewer then 
        self:updateAceGUISnapshotsViewer() 
    end
    
    -- Update the level graph with the new level data
    if self.UpdateLevelGraph then
        self:UpdateLevelGraph(self)
    end
    
    -- Calculate estimated max level progression
    self:CalculateEstimatedMaxLevel()
    
    -- For debugging if needed:
    -- for i, snap in ipairs(self.db.profile.levelSnapshots) do
    --     print(string.format("Level Snapshot %d: {level=%d, time=%0.f}", i, snap.level, snap.time))
    -- end
    -- if self.db.profile.estimatedMaxLevel then
    --     local est = self.db.profile.estimatedMaxLevel
    --     print(string.format("Estimated Max Level: {level=%d, time=%0.f hours}", est.level, est.time/3600))
    -- end

    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end
end

function addon:UpdateAction()
    local L = self.L

    self.mobsToLevelString = L["Actions to Level"] .. ": " .. L["Calculating..."]
    self.avgXPFormatted = nil

    if self.db.profile.xpSnapshots and #self.db.profile.xpSnapshots > 0 then
        local totalXpFromSnapshots = 0
        local numValidSnapshots = 0
        for _, snap in ipairs(self.db.profile.xpSnapshots) do
            if snap.xp and snap.xp > 0 then
                totalXpFromSnapshots = totalXpFromSnapshots + snap.xp
                numValidSnapshots = numValidSnapshots + 1
            end
        end
        if numValidSnapshots > 0 then
            local avgXpPerEvent = totalXpFromSnapshots / numValidSnapshots
            local currentXPValue = UnitXP("player")
            local maxXPValue = UnitXPMax("player")
            local xpNeededToLevel = maxXPValue - currentXPValue
            if xpNeededToLevel > 0 and avgXpPerEvent > 0 then
                self.actionsToLevelCount = math.ceil(xpNeededToLevel / avgXpPerEvent)
                self.actionsToLevelAvgXP = avgXpPerEvent
                self.avgXPFormatted = string.format("%.0f", avgXpPerEvent)
                self.mobsToLevelString = string.format(L["Actions to Level: %d (avg %s XP)"], self.actionsToLevelCount, self.avgXPFormatted)
            elseif xpNeededToLevel <= 0 then
                self.mobsToLevelString = L["Actions to Level"] .. ": " .. L["N/A"]
            end
        end
    end

    -- Trigger UI updates
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end
    
    -- Also update the standalone XP bar if it exists
    if self.UpdateXpBarFrame then
        self:UpdateXpBarFrame(self)
    end
end


-- Handler for PLAYER_ENTERING_WORLD
function addon:OnPlayerEnteringWorld()
    RequestTimePlayed() 
end

-- Handler for TIME_PLAYED_MSG
function addon:OnTimePlayedMessage(event, totalTimeArg, levelTimeArg)
    if totalTimeArg and levelTimeArg then
        self.timePlayedTotal = totalTimeArg
        self.timePlayedLevel = levelTimeArg
    end
    
    -- Recalculate estimated max level with updated time data
    self:CalculateEstimatedMaxLevel()
    
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
    end
    if self.UpdateLevelGraph then
        self:UpdateLevelGraph(self)
    end
end

-- Format seconds into a readable string (hh:mm:ss)
function addon:FormatTime(seconds)
    if not seconds or seconds < 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- Calculate estimated time to reach max level based on level progression data
function addon:CalculateEstimatedMaxLevel()
    local levelSnapshots = self.db.profile.levelSnapshots
    local maxLevel = self.db.profile.maxLevel or 60
    local currentLevel = UnitLevel("player")
    
    -- Need at least 2 data points and player must be below max level
    if not levelSnapshots or #levelSnapshots < 2 or currentLevel >= maxLevel then
        self.db.profile.estimatedMaxLevel = nil
        return
    end
    
    -- Filter out any snapshots at or above max level
    local validSnapshots = {}
    for _, snapshot in ipairs(levelSnapshots) do
        if snapshot.level < maxLevel then
            table.insert(validSnapshots, snapshot)
        end
    end
    
    -- Need at least 2 valid snapshots for calculation
    if #validSnapshots < 2 then
        self.db.profile.estimatedMaxLevel = nil
        return
    end
    
    -- Perform linear regression on level vs time data
    local N = #validSnapshots
    local sum_x = 0.0  -- time
    local sum_y = 0.0  -- level
    local sum_xy = 0.0
    local sum_x_squared = 0.0
    
    for _, snapshot in ipairs(validSnapshots) do
        local time = snapshot.time
        local level = snapshot.level
        
        sum_x = sum_x + time
        sum_y = sum_y + level
        sum_xy = sum_xy + time * level
        sum_x_squared = sum_x_squared + time * time
    end
    
    local denominator = N * sum_x_squared - sum_x * sum_x
    
    -- Check if we have enough variance in time data for meaningful regression
    if denominator > 0.000001 then
        -- Calculate slope (levels per second) and intercept
        local slope = (N * sum_xy - sum_x * sum_y) / denominator
        local intercept = (sum_y - slope * sum_x) / N
        
        -- Only proceed if we have a positive progression rate
        if slope > 0.000001 then
            -- Calculate estimated time to reach max level - 1
            local targetLevel = maxLevel - 1
            local estimatedTime = (targetLevel - intercept) / slope
            
            -- Ensure the estimated time is reasonable (not in the past, not too far in future)
            local currentTime = self.timePlayedTotal or 0
            if estimatedTime > currentTime and estimatedTime < currentTime + (365 * 24 * 3600) then -- Within 1 year
                self.db.profile.estimatedMaxLevel = {
                    level = targetLevel,
                    time = estimatedTime
                }
                return
            end
        end
    end
    
    -- Fallback: simple rate calculation if regression fails
    if #validSnapshots >= 2 then
        local firstSnapshot = validSnapshots[1]
        local lastSnapshot = validSnapshots[#validSnapshots]
        
        local timeDiff = lastSnapshot.time - firstSnapshot.time
        local levelDiff = lastSnapshot.level - firstSnapshot.level
        
        if timeDiff > 0 and levelDiff > 0 then
            local levelsPerSecond = levelDiff / timeDiff
            local levelsNeeded = (maxLevel - 1) - currentLevel
            
            if levelsNeeded > 0 then
                local estimatedTimeToMax = (self.timePlayedTotal or 0) + (levelsNeeded / levelsPerSecond)
                self.db.profile.estimatedMaxLevel = {
                    level = maxLevel - 1,
                    time = estimatedTimeToMax
                }
                return
            end
        end
    end
    
    -- If all calculations fail, set to nil
    self.db.profile.estimatedMaxLevel = nil
end

-- Get formatted string for estimated max level information
function addon:GetEstimatedMaxLevelText()
    local estimatedMaxLevel = self.db.profile.estimatedMaxLevel
    if not estimatedMaxLevel or not estimatedMaxLevel.time then
        return L["Insufficient data for estimate"]
    end
    
    local currentTime = self.timePlayedTotal or 0
    local timeToMax = estimatedMaxLevel.time - currentTime
    
    if timeToMax <= 0 then
        return L["Insufficient data for estimate"]
    end
    
    local formattedTime = self:FormatTime(timeToMax)
    return string.format("%s: %s (%s)", L["Estimated Time to Max Level"], formattedTime, L["Based on current progression"])
end
