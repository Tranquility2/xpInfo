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
    
    -- Use AceGUI snapshots viewer
    self.snapshotsViewerBuidler = self.snapshotsAceGUIViewerBuilder -- Fix the typo in the original function name
    
    -- Create the initial frame - but don't show it yet
    self.statsFrame = addonTable.CreateAceGUIStatsFrame(self)
    self.frame = self.statsFrame -- Alias for compatibility with options.lua if it uses self.frame
end

-- Called when the addon is enabled
function addon:OnEnable()
    if self.db.profile.showFrame and self.ShowStatsFrame then
        self:ShowStatsFrame(self) -- Pass self as addonInstance
    end
    self.lastXP = UnitXP("player") -- Initialize lastXP
    RequestTimePlayed() -- Request initial time played data
    self:UpdateXP() -- This will call UpdateStatsFrameText
    self:UpdateAction() -- Update action-related stats
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
    
    -- For debugging if needed:
    -- for i, snap in ipairs(self.db.profile.levelSnapshots) do
    --     print(string.format("Level Snapshot %d: {level=%d, time=%0.f}", i, snap.level, snap.time))
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

    -- Trigger the UI update for the stats frame
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
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
    if self.UpdateStatsFrameText then
        self:UpdateStatsFrameText(self)
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
