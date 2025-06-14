local addonName, addonTable = ...

-- Local variables to hold UI elements
local AceGUI = LibStub("AceGUI-3.0")
local statsFrame, xpLabel, timeLabel, remainingLabel, actionsLabel, avgXpLabel
local refreshButton, settingsButton, debugButton

-- Helper function to format large numbers (e.g., 1000 -> 1k, 1000000 -> 1M)
local function FormatLargeNumber(num)
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 10000 then
        return string.format("%.1fk", num / 1000)
    elseif num >= 1000 then
        return string.format("%.1fk", num / 1000)
    else
        return tostring(num)
    end
end

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

    -- Update progress bar if it exists
    if statsFrame.xpProgressBar then
        local xpBar = statsFrame.xpProgressBar
        xpBar:SetValue(currentXPPerc)
        
        -- Better format for the text display - show percentage and remaining XP
        if xpBar.text then
            -- Format large numbers with commas for better readability
            local function FormatNumber(num)
                if num >= 1000 then
                    return string.format("%s", FormatLargeNumber(num))
                else
                    return tostring(num)
                end
            end
            
            local formattedPercent = string.format("%.1f%%", currentXPPerc)
            local formattedRemaining = FormatNumber(maxXP - currentXP)
            
            xpBar.text:SetText(string.format("%s (%s %s)", 
                formattedPercent, formattedRemaining, L["remaining"]))
        end
        
        -- Update rested bonus display if it exists
        if xpBar.restedBar then
            local restedWidth = 0
            if currentXPPerc < 100 then
                -- Set the width based on where the current XP ends
                restedWidth = math.min(restedXPPerc, 100 - currentXPPerc)
                xpBar.restedBar:SetValue(restedWidth)
            else
                -- At max XP, don't show rested bonus
                xpBar.restedBar:SetValue(0)
            end
        end
    end

    -- Time Information
    local timePlayedTotalString = addonInstance:FormatTime(addonInstance.timePlayedTotal or 0)
    local timePlayedLevelString = addonInstance:FormatTime(addonInstance.timePlayedLevel or 0)

    local timeString = string.format(L["Time Played (Total)"] .. ": %s\n" .. L["Time Played (Level)"] .. ": %s", 
                                   timePlayedTotalString, timePlayedLevelString)
    timeLabel:SetText(timeString)

    -- Avrage XP per action
    local actionsToLevelAvgXP = addonInstance.actionsToLevelAvgXP or L["Calculating..."]
    local avgXpString = string.format(L["Average XP"] .. ": %s", actionsToLevelAvgXP)
    avgXpLabel:SetText(avgXpString)

    -- Remaining time info
    local timeToLevelString = addonInstance.timeToLevel or L["Calculating..."]
    local remainingString = string.format(L["Time to Level"] .. ": %s", timeToLevelString)
    remainingLabel:SetText(remainingString)

    -- Actions to Level
    local mobsToLevelString = addonInstance.mobsToLevelString or (L["Actions to Level"] .. ": " .. L["Calculating..."])
    actionsLabel:SetText(mobsToLevelString)
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
    statsFrame:SetHeight(315)
    statsFrame:EnableResize(false)
    
    -- Restore saved position if available
    if addonInstance.db.profile.framePosition then
        local pos = addonInstance.db.profile.framePosition
        statsFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
    end
    
    -- Save position on close
    statsFrame:SetCallback("OnClose", function(widget)
        addonInstance.db.profile.showFrame = false
    end)

    -- Main XP bar - using local variable and storing in the statsFrame
    local xpBar = CreateFrame("StatusBar", nil, statsFrame.frame)
    xpBar:SetHeight(25) -- Define an appropriate height for the XP bar
    xpBar:SetPoint("TOPLEFT", statsFrame.frame, 15, -35) -- Adjust position without container
    xpBar:SetPoint("RIGHT", statsFrame.frame, -15, 0)
    xpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- Blue color that matches WoW's default XP bar but slightly brighter
    xpBar:SetStatusBarColor(0.0, 0.39, 0.88, 1.0) -- Medium blue
    xpBar:SetMinMaxValues(0, 100)
    xpBar:SetValue(0)
    xpBar:SetFrameLevel(statsFrame.frame:GetFrameLevel() + 1)
    
    -- Store the progress bar in the statsFrame for access elsewhere
    statsFrame.xpProgressBar = xpBar
    
    -- Rested XP overlay
    xpBar.restedBar = CreateFrame("StatusBar", nil, statsFrame.frame)
    xpBar.restedBar:SetPoint("TOPLEFT", xpBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    xpBar.restedBar:SetPoint("BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", 0, 0)
    xpBar.restedBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBar.restedBar:SetStatusBarColor(0.6, 0, 0.6, 0.6) -- Purple slightly more opaque
    xpBar.restedBar:SetMinMaxValues(0, 100)
    xpBar.restedBar:SetValue(0)
    xpBar.restedBar:SetFrameLevel(xpBar:GetFrameLevel())
    
    -- Add a border around the bar - using 9.0+ compatible approach
    local border = CreateFrame("Frame", nil, statsFrame.frame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", xpBar, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    border:SetFrameLevel(xpBar:GetFrameLevel() - 1) -- Put border behind the bar
    
    -- Text overlay with improved visibility
    xpBar.text = xpBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpBar.text:SetPoint("CENTER", xpBar, "CENTER", 0, 0)
    xpBar.text:SetText("0%")
    xpBar.text:SetTextColor(1, 1, 1, 1) -- Bright white text
    xpBar.text:SetShadowOffset(1, -1)   -- Text shadow for better readability
    xpBar.text:SetShadowColor(0, 0, 0, 1)
    
    -- Add tooltip functionality
    xpBar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        
        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local restedXP = GetXPExhaustion() or 0
        local currentXPPerc = maxXP > 0 and (currentXP / maxXP) * 100 or 0
        local restedXPPerc = maxXP > 0 and (restedXP / maxXP) * 100 or 0
        local L = addonInstance.L
        
        -- GameTooltip:AddLine(L["Progress"], 1, 1, 1)
        -- GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Current XP"] .. ":", string.format("%s / %s (%0.1f%%)", 
            currentXP, maxXP, currentXPPerc), 1, 1, 1, 1, 1, 1)
        
        if restedXP > 0 then
            GameTooltip:AddDoubleLine(L["Rested XP"] .. ":", string.format("%s (%0.1f%%)", 
                restedXP, restedXPPerc), 1, 1, 1, 0.6, 0, 0.6)
            -- GameTooltip:AddDoubleLine(L["After Rested"] .. ":", string.format("%0.1f%%", 
            --     math.min(100, currentXPPerc + restedXPPerc)), 1, 1, 1, 0.6, 0.6, 1)
        end
        
        if addonInstance.actionsToLevelAvgXP then
            GameTooltip:AddDoubleLine(L["Average XP"] .. ":", string.format("%d", addonInstance.actionsToLevelAvgXP), 1, 1, 1, 0, 0.6, 0.6)
        end

        if addonInstance.actionsToLevelCount then
            GameTooltip:AddDoubleLine(L["Actions to Level"] .. ":", string.format("%d", addonInstance.actionsToLevelCount), 1, 1, 1, 0, 1, 0)
        end

        if addonInstance.timeToLevel and addonInstance.timeToLevel ~= L["Calculating..."] and addonInstance.timeToLevel ~= L["N/A"] then
            GameTooltip:AddDoubleLine(L["Time to Level"] .. ":", addonInstance.timeToLevel, 1, 1, 1, 0.6, 0.6, 1)
        end
        
        GameTooltip:Show()
    end)
    
    xpBar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Add some tripple space before the first heading
    for i = 1, 3 do
        local spacer = AceGUI:Create("Label")
        spacer:SetWidth(width - 25) -- Adjust width to match the frame
        spacer:SetText(" ")
        statsFrame:AddChild(spacer)
    end
    
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

    -- Average XP per action label
    avgXpLabel = AceGUI:Create("Label")
    avgXpLabel:SetWidth(width - 25)
    avgXpLabel:SetText(L["Average XP"] .. ": " .. L["Calculating..."])
    statsFrame:AddChild(avgXpLabel)
    
    -- Actions to level label
    actionsLabel = AceGUI:Create("Label")
    actionsLabel:SetWidth(width - 25)
    actionsLabel:SetText(L["Actions to Level"] .. ": " .. L["Calculating..."])
    statsFrame:AddChild(actionsLabel)
    
    -- Time to level label
    remainingLabel = AceGUI:Create("Label")
    remainingLabel:SetWidth(width - 25)
    remainingLabel:SetText(L["Time to Level"] .. ": " .. L["Calculating..."])
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
    debugButton = AceGUI:Create("Button")
    debugButton:SetText(L["View Snapshots"])
    debugButton:SetWidth(width - 25)
    debugButton:SetCallback("OnClick", function()
        addonInstance:snapshotsViewerBuidler()
    end)
    buttonGroup:AddChild(debugButton)
    
    -- Update the frame with current data
    UpdateStatsFrameText(addonInstance)
    
    return statsFrame
end

-- Toggle the UI frame visibility
local function ToggleStatsFrame(addonInstance)
    if statsFrame and statsFrame:IsShown() then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
    else
        if not statsFrame then
            CreateStatsFrame(addonInstance)
        end
        statsFrame:Show()
        addonInstance.db.profile.showFrame = true
        UpdateStatsFrameText(addonInstance)
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
end

-- Explicitly hide the frame
local function HideStatsFrame(addonInstance)
    if statsFrame then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
    end
end

-- Function to be called by options to set visibility
local function SetStatsFrameVisibility(addonInstance, shouldShow)
    if shouldShow then
        ShowStatsFrame(addonInstance)
    else
        HideStatsFrame(addonInstance)
    end
end

-- Export functions to the addon table
addonTable.CreateAceGUIStatsFrame = CreateStatsFrame
addonTable.UpdateAceGUIStatsFrameText = UpdateStatsFrameText
addonTable.ToggleAceGUIStatsFrame = ToggleStatsFrame
addonTable.ShowAceGUIStatsFrame = ShowStatsFrame
addonTable.HideAceGUIStatsFrame = HideStatsFrame
addonTable.SetAceGUIStatsFrameVisibility = SetStatsFrameVisibility
