local addonName, addonTable = ...

-- Local variables to hold UI elements
local AceGUI = LibStub("AceGUI-3.0")
local statsFrame, xpLabel, timeLabel, remainingLabel
local refreshButton, settingsButton, snapshotsButton
avgXpLabel = nil -- Define globally to avoid nil errors

-- Function to update the content of the frame
local function UpdateStatsFrameText(addonInstance)
    if not statsFrame or not statsFrame:IsShown() then return end
    local L = addonInstance.L

    -- XP Information
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
                                   currentXP, maxXP, string.format("%.1f", currentXPPerc), 
                                   restedXP, maxXP, string.format("%.1f", restedXPPerc))
    xpLabel:SetText(xpString)

    -- Update XP bar if the frame is showing
    addonTable.UpdateXpBarFrame(addonInstance)

    -- Time Information
    local timePlayedTotalString = addonInstance:FormatTime(addonInstance.timePlayedTotal or 0)
    local timePlayedLevelString = addonInstance:FormatTime(addonInstance.timePlayedLevel or 0)

    local timeString = string.format(L["Time Played (Total)"] .. ": %s\n" .. L["Time Played (Level)"] .. ": %s", 
                                   timePlayedTotalString, timePlayedLevelString)
    timeLabel:SetText(timeString)

    -- Combine all level progression info into a single label
    local actionsToLevelAvgXP = addonInstance.actionsToLevelAvgXP or L["Calculating..."]
    local timeToLevelString = addonInstance.timeToLevel or L["Calculating..."]
    local actionsToLevelCount = addonInstance.actionsToLevelCount or L["Calculating..."]
    
    local combinedString = string.format(
        L["Average XP"] .. ": %s\n" .. 
        L["Actions to Level"] .. ": %s\n" .. 
        L["Time to Level"] .. ": %s", 
        actionsToLevelAvgXP, actionsToLevelCount, timeToLevelString)
    
    remainingLabel:SetText(combinedString)
end

-- Create the AceGUI frame
local function CreateStatsFrame(addonInstance)
    local L = addonInstance.L
    local width = 250
    
    -- Create a frame container
    statsFrame = AceGUI:Create("Window")
    statsFrame:SetTitle(L["Progression"])
    statsFrame:SetLayout("Flow")
    statsFrame:SetWidth(width)
    statsFrame:SetHeight(300)
    statsFrame:EnableResize(false)
    
    -- Restore saved position if available
    if addonInstance.db.profile.framePosition then
        local pos = addonInstance.db.profile.framePosition
        statsFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
    end

    -- Restore visibility state
    if addonInstance.db.profile.showFrame then
        statsFrame:Show()
    else
        statsFrame:Hide()
    end
    
    -- Save position on close
    statsFrame:SetCallback("OnClose", function(widget)
        -- Save position before closing
        local frame = widget.frame
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
        addonInstance.db.profile.framePosition = { point, relativeToName, relativePoint, xOfs, yOfs }
        addonInstance.db.profile.showFrame = false
    end)
    
    -- Hook into the frame's title bar to save position when dragging ends
    if statsFrame.title then
        local originalScript = statsFrame.title:GetScript("OnMouseUp")
        statsFrame.title:SetScript("OnMouseUp", function(self, ...)
            if originalScript then originalScript(self, ...) end
            
            -- Save position after dragging
            local frame = statsFrame.frame
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
            local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
            addonInstance.db.profile.framePosition = { point, relativeToName, relativePoint, xOfs, yOfs }
        end)
    end

    -- Create an XP bar when the stats frame is created
    addonTable.ShowXpBarFrame(addonInstance)
    
    local xpHeader = AceGUI:Create("Heading")
    xpHeader:SetText(L["XP Progress"])
    xpHeader:SetFullWidth(true)
    statsFrame:AddChild(xpHeader)

    -- XP Information Label
    xpLabel = AceGUI:Create("Label")
    xpLabel:SetWidth(width - 25)
    xpLabel:SetText(L["Current XP"] .. ": 0 / 0 (0%)\n" .. L["Rested XP"] .. ": 0 / 0 (0%)")
    statsFrame:AddChild(xpLabel)

    local levelHeader = AceGUI:Create("Heading")
    levelHeader:SetText(L["Level Progress"])
    levelHeader:SetFullWidth(true)
    statsFrame:AddChild(levelHeader)

    -- Combined progression label (XP, Actions, Time)
    remainingLabel = AceGUI:Create("Label")
    remainingLabel:SetWidth(width - 25)
    remainingLabel:SetText(
        L["Average XP"] .. ": " .. L["Calculating..."] .. "\n" ..
        L["Actions to Level"] .. ": " .. L["Calculating..."] .. "\n" ..
        L["Time to Level"] .. ": " .. L["Calculating..."]
    )
    statsFrame:AddChild(remainingLabel)
    
    local sumHeader = AceGUI:Create("Heading")
    sumHeader:SetText(L["Summary"])
    sumHeader:SetFullWidth(true)
    statsFrame:AddChild(sumHeader)

    -- Time played label
    timeLabel = AceGUI:Create("Label")
    timeLabel:SetWidth(width - 25)
    timeLabel:SetText(L["Time Played (Total)"] .. ": 00:00:00\n" .. L["Time Played (Level)"] .. ": 00:00:00")
    statsFrame:AddChild(timeLabel)
    
    -- Add some space before buttons
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(width - 25)
    spacer:SetText(" ")
    statsFrame:AddChild(spacer)
    
    -- Button group container
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetWidth(width - 25)
    buttonGroup:SetHeight(30)
    statsFrame:AddChild(buttonGroup)
    
    -- Refresh button
    refreshButton = AceGUI:Create("Button")
    refreshButton:SetText(L["Refresh"])
    refreshButton:SetWidth(width - 25)
    refreshButton:SetCallback("OnClick", function()
        RequestTimePlayed() -- Global WoW function
    end)
    buttonGroup:AddChild(refreshButton)
    
    -- Settings button
    settingsButton = AceGUI:Create("Button")
    settingsButton:SetText(L["Settings"])
    settingsButton:SetWidth(width - 25)
    settingsButton:SetCallback("OnClick", function()
        LibStub("AceConfigDialog-3.0"):Open(addonInstance.name)
    end)
    buttonGroup:AddChild(settingsButton)
    
    -- Snapshots button
    snapshotsButton = AceGUI:Create("Button")
    snapshotsButton:SetText(L["View Snapshots"])
    snapshotsButton:SetWidth(width - 25)
    snapshotsButton:SetCallback("OnClick", function()
        addonInstance:snapshotsViewerBuidler()
    end)
    buttonGroup:AddChild(snapshotsButton)
    
    -- Update the frame with current data
    UpdateStatsFrameText(addonInstance)
    
    return statsFrame
end

-- Toggle the UI frame visibility
local function ToggleStatsFrame(addonInstance)
    if statsFrame and statsFrame:IsShown() then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
        -- Also hide the XP bar if the main frame is hidden
        addonTable.HideXpBarFrame(addonInstance)
    else
        if not statsFrame then
            CreateStatsFrame(addonInstance)
        end
        statsFrame:Show()
        addonInstance.db.profile.showFrame = true
        UpdateStatsFrameText(addonInstance)
        -- Show the XP bar when the main frame is shown
        addonTable.ShowXpBarFrame(addonInstance)
    end
end

-- Explicitly show the frame
local function ShowStatsFrame(addonInstance)
    if not statsFrame then
        CreateStatsFrame(addonInstance)
    end
    statsFrame:Show()
    addonInstance.db.profile.showFrame = true
    UpdateStatsFrameText(addonInstance)
    -- Show the XP bar when the main frame is shown
    addonTable.ShowXpBarFrame(addonInstance)
end

-- Explicitly hide the frame
local function HideStatsFrame(addonInstance)
    if statsFrame then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
        -- Also hide the XP bar if the main frame is hidden
        addonTable.HideXpBarFrame(addonInstance)
    end
end

-- Function to be called by options to set visibility
local function SetStatsFrameVisibility(addonInstance, shouldShow)
    if shouldShow then
        ShowStatsFrame(addonInstance)
    else
        HideStatsFrame(addonInstance)
    end
    
    -- Also set the XP bar visibility to match
    addonTable.SetXpBarFrameVisibility(addonInstance, shouldShow)
end

-- Export functions to the addon table
addonTable.CreateAceGUIStatsFrame = CreateStatsFrame
addonTable.UpdateAceGUIStatsFrameText = UpdateStatsFrameText
addonTable.ToggleAceGUIStatsFrame = ToggleStatsFrame
addonTable.ShowAceGUIStatsFrame = ShowStatsFrame
addonTable.HideAceGUIStatsFrame = HideStatsFrame
addonTable.SetAceGUIStatsFrameVisibility = SetStatsFrameVisibility
