local addonName, addonTable = ...

-- Local variables to hold UI elements
local xpBarFrame
-- No longer need AceGUI since we're using native frames

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

-- Function to create a standalone XP bar frame
local function CreateXpBarFrame(addonInstance)
    local L = addonInstance.L
    local width = 250
    
    -- Create the XP bar as the main frame
    xpBarFrame = CreateFrame("StatusBar", "XpInfoBarFrame", UIParent)
    xpBarFrame:SetHeight(25) -- Define an appropriate height for the XP bar
    xpBarFrame:SetWidth(width)
    xpBarFrame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- Blue color that matches WoW's default XP bar but slightly brighter
    xpBarFrame:SetStatusBarColor(0.0, 0.39, 0.88, 1.0) -- Medium blue
    xpBarFrame:SetMinMaxValues(0, 100)
    xpBarFrame:SetValue(0)
    
    -- Make the bar movable
    xpBarFrame:SetMovable(true)
    xpBarFrame:EnableMouse(true)
    xpBarFrame:RegisterForDrag("LeftButton")
    
    -- Set up drag functionality
    xpBarFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    xpBarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position after dragging
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
        local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
        addonInstance.db.profile.xpBarPosition = { point, relativeToName, relativePoint, xOfs, yOfs }
    end)
    
    -- Restore saved position if available
    if addonInstance.db.profile.xpBarPosition then
        local pos = addonInstance.db.profile.xpBarPosition
        xpBarFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
    else
        -- Default position if none saved
        xpBarFrame:SetPoint("TOP", UIParent, "TOP", 0, -20)
    end

    -- Restore visibility state
    if addonInstance.db.profile.showXpBar then
        xpBarFrame:Show()
    else
        xpBarFrame:Hide()
    end
    
    -- Store a reference to the xpBar itself for consistency with old code
    xpBarFrame.progressBar = xpBarFrame
    
    -- Rested XP overlay
    xpBarFrame.restedBar = CreateFrame("StatusBar", nil, xpBarFrame)
    xpBarFrame.restedBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBarFrame.restedBar:SetStatusBarColor(0.6, 0, 0.6, 0.6) -- Purple slightly more opaque
    xpBarFrame.restedBar:SetMinMaxValues(0, 100)
    xpBarFrame.restedBar:SetValue(0)
    xpBarFrame.restedBar:SetFrameLevel(xpBarFrame:GetFrameLevel())
    xpBarFrame.restedBar:SetAllPoints(xpBarFrame) -- Overlay, but we'll control width/position dynamically
    
    -- Add a border around the bar - using 9.0+ compatible approach
    local border = CreateFrame("Frame", nil, xpBarFrame, "BackdropTemplate")
    border:SetPoint("TOPLEFT", xpBarFrame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", xpBarFrame, "BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    border:SetFrameLevel(xpBarFrame:GetFrameLevel() - 1) -- Put border behind the bar
    
    -- Text overlay with improved visibility
    xpBarFrame.text = xpBarFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xpBarFrame.text:SetPoint("CENTER", xpBarFrame, "CENTER", 0, 0)
    xpBarFrame.text:SetText("0%")
    xpBarFrame.text:SetTextColor(1, 1, 1, 1) -- Bright white text
    xpBarFrame.text:SetShadowOffset(1, -1)   -- Text shadow for better readability
    xpBarFrame.text:SetShadowColor(0, 0, 0, 1)
    
    -- Add tooltip functionality
    xpBarFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, addonInstance.db.profile.tooltipAnchor)
        GameTooltip:ClearLines()
        
        local currentXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        local restedXP = GetXPExhaustion() or 0
        local currentXPPerc = maxXP > 0 and (currentXP / maxXP) * 100 or 0
        local restedXPPerc = maxXP > 0 and (restedXP / maxXP) * 100 or 0
        local L = addonInstance.L
        
        GameTooltip:AddDoubleLine(L["Current XP"] .. ":", string.format("%s / %s (%0.1f%%)", 
            currentXP, maxXP, currentXPPerc), 1, 1, 1, 1, 1, 1)
        
        if restedXP > 0 then
            GameTooltip:AddDoubleLine(L["Rested XP"] .. ":", string.format("%s (%0.1f%%)", 
                restedXP, restedXPPerc), 1, 1, 1, 0.6, 0, 0.6)
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
    
    xpBarFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- On click, toggle the stats frame visibility
    xpBarFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            addonInstance:ToggleStatsFrame()
        end
    end)

    -- on right click, toggle the graph visibility
    xpBarFrame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            addonInstance:ToggleLevelGraph()
        end
    end)

    
    return xpBarFrame
end

-- Function to update the XP bar values
local function UpdateXpBarFrame(addonInstance)
    if not xpBarFrame or not xpBarFrame:IsShown() then return end
    
    local L = addonInstance.L
    local currentXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0
    local currentXPPerc = 0
    local restedXPPerc = 0

    if maxXP > 0 then
        currentXPPerc = (currentXP / maxXP) * 100
        restedXPPerc = (restedXP / maxXP) * 100
    end

    xpBarFrame:SetValue(currentXPPerc)
    
    -- Better format for the text display - show percentage and remaining XP
    if xpBarFrame.text then
        -- Format large numbers for better readability
        local function FormatNumber(num)
            if num >= 1000 then
                return string.format("%s", FormatLargeNumber(num))
            else
                return tostring(num)
            end
        end
        
        local formattedPercent = string.format("%.1f%%", currentXPPerc)
        local formattedRemaining = FormatNumber(maxXP - currentXP)
        
        xpBarFrame.text:SetText(string.format("%s (%s %s)", 
            formattedPercent, formattedRemaining, L["remaining"]))
    end
    
    -- Update rested bonus display if it exists
    if xpBarFrame.restedBar then
        local barWidth = xpBarFrame:GetWidth()
        local currentWidth = (currentXPPerc / 100) * barWidth
        local restedWidth = (restedXPPerc / 100) * barWidth
        local availableWidth = barWidth - currentWidth
        -- Only show if there's rested XP and not at max XP
        if restedXPPerc > 0 and currentXPPerc < 100 then
            xpBarFrame.restedBar:Show()
            xpBarFrame.restedBar:ClearAllPoints()
            -- Anchor to the right edge of the current XP fill
            xpBarFrame.restedBar:SetPoint("LEFT", xpBarFrame, "LEFT", currentWidth, 0)
            xpBarFrame.restedBar:SetPoint("TOP", xpBarFrame, "TOP", 0, 0)
            xpBarFrame.restedBar:SetPoint("BOTTOM", xpBarFrame, "BOTTOM", 0, 0)
            -- Ensure width is at least 1 pixel if any rested XP is available
            local displayWidth = math.max(1, math.min(restedWidth, availableWidth))
            xpBarFrame.restedBar:SetWidth(displayWidth)
            xpBarFrame.restedBar:SetMinMaxValues(0, 1)
            xpBarFrame.restedBar:SetValue(1)
        else
            xpBarFrame.restedBar:Hide()
        end
    end
end

-- Toggle the XP Bar frame visibility
local function ToggleXpBarFrame(addonInstance)
    if xpBarFrame and xpBarFrame:IsShown() then
        xpBarFrame:Hide()
        addonInstance.db.profile.showXpBar = false
    else
        if not xpBarFrame then
            CreateXpBarFrame(addonInstance)
        end
        xpBarFrame:Show()
        addonInstance.db.profile.showXpBar = true
        UpdateXpBarFrame(addonInstance)
    end
end

-- Explicitly show the XP Bar frame
local function ShowXpBarFrame(addonInstance)
    if not xpBarFrame then
        CreateXpBarFrame(addonInstance)
    end
    xpBarFrame:Show()
    addonInstance.db.profile.showXpBar = true
    UpdateXpBarFrame(addonInstance)
end

-- Explicitly hide the XP Bar frame
local function HideXpBarFrame(addonInstance)
    if xpBarFrame then
        xpBarFrame:Hide()
        addonInstance.db.profile.showXpBar = false
    end
end

-- Function to be called by options to set visibility
local function SetXpBarFrameVisibility(addonInstance, shouldShow)
    if shouldShow then
        ShowXpBarFrame(addonInstance)
    else
        HideXpBarFrame(addonInstance)
    end
end

-- Export functions to the addon table
addonTable.CreateXpBarFrame = CreateXpBarFrame
addonTable.UpdateXpBarFrame = UpdateXpBarFrame
addonTable.ToggleXpBarFrame = ToggleXpBarFrame
addonTable.ShowXpBarFrame = ShowXpBarFrame
addonTable.HideXpBarFrame = HideXpBarFrame
addonTable.SetXpBarFrameVisibility = SetXpBarFrameVisibility
