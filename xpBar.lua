local addonName, addonTable = ...

-- Local variables to hold UI elements
local xpBarFrame
local AceGUI = LibStub("AceGUI-3.0")

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
    
    -- Create a frame container
    xpBarFrame = AceGUI:Create("Window")
    xpBarFrame:SetTitle(L["XP Progress"])
    xpBarFrame:SetLayout("Flow")
    xpBarFrame:SetWidth(width)
    xpBarFrame:SetHeight(80)
    xpBarFrame:EnableResize(false)
    
    -- Restore saved position if available
    if addonInstance.db.profile.xpBarPosition then
        local pos = addonInstance.db.profile.xpBarPosition
        xpBarFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
    end

    -- Restore visibility state
    if addonInstance.db.profile.showXpBar then
        xpBarFrame:Show()
    else
        xpBarFrame:Hide()
    end
    
    -- Save position on close
    xpBarFrame:SetCallback("OnClose", function(widget)
        -- Save position before closing
        local frame = widget.frame
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
        addonInstance.db.profile.xpBarPosition = { point, relativeToName, relativePoint, xOfs, yOfs }
        addonInstance.db.profile.showXpBar = false
    end)
    
    -- Hook into the frame's title bar to save position when dragging ends
    if xpBarFrame.title then
        local originalScript = xpBarFrame.title:GetScript("OnMouseUp")
        xpBarFrame.title:SetScript("OnMouseUp", function(self, ...)
            if originalScript then originalScript(self, ...) end
            
            -- Save position after dragging
            local frame = xpBarFrame.frame
            local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
            local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
            addonInstance.db.profile.xpBarPosition = { point, relativeToName, relativePoint, xOfs, yOfs }
        end)
    end

    -- Create the XP bar
    local xpBar = CreateFrame("StatusBar", nil, xpBarFrame.frame)
    xpBar:SetHeight(25) -- Define an appropriate height for the XP bar
    xpBar:SetPoint("TOPLEFT", xpBarFrame.frame, 15, -35) -- Adjust position without container
    xpBar:SetPoint("RIGHT", xpBarFrame.frame, -15, 0)
    xpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    -- Blue color that matches WoW's default XP bar but slightly brighter
    xpBar:SetStatusBarColor(0.0, 0.39, 0.88, 1.0) -- Medium blue
    xpBar:SetMinMaxValues(0, 100)
    xpBar:SetValue(0)
    xpBar:SetFrameLevel(xpBarFrame.frame:GetFrameLevel() + 1)
    
    -- Store the progress bar in the xpBarFrame for access elsewhere
    xpBarFrame.progressBar = xpBar
    
    -- Rested XP overlay
    xpBar.restedBar = CreateFrame("StatusBar", nil, xpBarFrame.frame)
    xpBar.restedBar:SetPoint("TOPLEFT", xpBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    xpBar.restedBar:SetPoint("BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", 0, 0)
    xpBar.restedBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    xpBar.restedBar:SetStatusBarColor(0.6, 0, 0.6, 0.6) -- Purple slightly more opaque
    xpBar.restedBar:SetMinMaxValues(0, 100)
    xpBar.restedBar:SetValue(0)
    xpBar.restedBar:SetFrameLevel(xpBar:GetFrameLevel())
    
    -- Add a border around the bar - using 9.0+ compatible approach
    local border = CreateFrame("Frame", nil, xpBarFrame.frame, "BackdropTemplate")
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
    
    xpBar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    return xpBarFrame
end

-- Function to update the XP bar values
local function UpdateXpBarFrame(addonInstance)
    if not xpBarFrame or not xpBarFrame:IsShown() then return end
    
    local xpBar = xpBarFrame.progressBar
    if not xpBar then return end
    
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

    xpBar:SetValue(currentXPPerc)
    
    -- Better format for the text display - show percentage and remaining XP
    if xpBar.text then
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
