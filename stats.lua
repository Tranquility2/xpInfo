local addonName, addonTable = ...

local statsFrame -- The main UI frame, local to this file

-- Create the UI frame
function addonTable.CreateStatsFrame(addonInstance)
    local L = addonInstance.L -- Get localization table from addonInstance
    statsFrame = CreateFrame("Frame", addonInstance.name .. "Frame", UIParent, "BasicFrameTemplateWithInset")
    statsFrame:SetWidth(300)
    statsFrame:SetHeight(200) -- Initial height, will be adjusted by UpdateStatsFrameText
    statsFrame:SetPoint(unpack(addonInstance.db.profile.framePosition))
    statsFrame:SetMovable(true)
    statsFrame:EnableMouse(true)
    statsFrame:RegisterForDrag("LeftButton")
    statsFrame:SetScript("OnDragStart", statsFrame.StartMoving)
    statsFrame:SetScript("OnDragStop", function(f) 
        f:StopMovingOrSizing()
        local xOffset = f:GetLeft()
        local yOffset = f:GetTop() - GetScreenHeight()
        addonInstance.db.profile.framePosition = { "TOPLEFT", "UIParent", "TOPLEFT", xOffset, yOffset }
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, yOffset)
        addonTable.UpdateStatsFrameText(addonInstance) 
    end)
    statsFrame:SetScript("OnMouseDown", function(f, button)
        addonTable.UpdateStatsFrameText(addonInstance) 
    end)

    statsFrame.title = statsFrame:CreateFontString(addonInstance.name .. "FrameTitle", "ARTWORK", "GameFontNormalLarge")
    statsFrame.title:SetPoint("TOP", 0, -5)
    statsFrame.title:SetText(L["Progression"])

    statsFrame.xpText = statsFrame:CreateFontString(addonInstance.name .. "FrameXPText", "ARTWORK", "GameFontNormal")
    statsFrame.xpText:SetPoint("TOPLEFT", 15, -30)
    statsFrame.xpText:SetJustifyH("LEFT")

    statsFrame.remainingText = statsFrame:CreateFontString(addonInstance.name .. "FrameRemainingXPText", "ARTWORK", "GameFontNormal")
    statsFrame.remainingText:SetPoint("TOPLEFT", statsFrame.xpText, "BOTTOMLEFT", 0, -5)
    statsFrame.remainingText:SetJustifyH("LEFT")

    statsFrame.mobsToLevelText = statsFrame:CreateFontString(addonInstance.name .. "FrameMobsToLevelText", "ARTWORK", "GameFontNormal")
    statsFrame.mobsToLevelText:SetPoint("TOPLEFT", statsFrame.remainingText, "BOTTOMLEFT", 0, -5)
    statsFrame.mobsToLevelText:SetJustifyH("LEFT")

    statsFrame.timeText = statsFrame:CreateFontString(addonInstance.name .. "FrameTimeText", "ARTWORK", "GameFontNormal")
    statsFrame.timeText:SetPoint("TOPLEFT", statsFrame.mobsToLevelText, "BOTTOMLEFT", 0, -5)
    statsFrame.timeText:SetJustifyH("LEFT")

    statsFrame.refreshButton = CreateFrame("Button", addonInstance.name .. "RefreshButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.refreshButton:SetText(L["Refresh"])
    statsFrame.refreshButton:SetWidth(80)
    statsFrame.refreshButton:SetHeight(20)
    statsFrame.refreshButton:SetPoint("BOTTOMLEFT", statsFrame, "BOTTOMLEFT", 10, 15)
    statsFrame.refreshButton:SetScript("OnClick", function()
        RequestTimePlayed() -- Global function
    end)

    statsFrame.settingsButton = CreateFrame("Button", addonInstance.name .. "SettingsButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.settingsButton:SetText(L["Settings"])
    statsFrame.settingsButton:SetWidth(80)
    statsFrame.settingsButton:SetHeight(20)
    statsFrame.settingsButton:SetPoint("BOTTOMLEFT", statsFrame, "BOTTOMLEFT", 90, 15)
    statsFrame.settingsButton:SetScript("OnClick", function()
        LibStub("AceConfigDialog-3.0"):Open(addonInstance.name) -- Use addonInstance.name
    end)

    statsFrame.debugButton = CreateFrame("Button", addonInstance.name .. "DebugButton", statsFrame, "UIPanelButtonTemplate")
    statsFrame.debugButton:SetText(L["View Snapshots"])
    statsFrame.debugButton:SetWidth(120)
    statsFrame.debugButton:SetHeight(20)
    statsFrame.debugButton:SetPoint("BOTTOMRIGHT", statsFrame, "BOTTOMRIGHT", -10, 15)
    statsFrame.debugButton:SetScript("OnClick", function()
        if addonInstance.snapshotsViewerBuidler then -- Ensure the method exists on addonInstance
            addonInstance:snapshotsViewerBuidler()
        else
            print(addonInstance.name .. " [ERROR] snapshotsViewerBuidler not found on addonInstance")
        end
    end)

    statsFrame:SetScript("OnHide", function(f)
        addonInstance.db.profile.showFrame = false
    end)

    addonTable.UpdateStatsFrameText(addonInstance)
    -- Return the created frame so it can be stored on addonInstance if needed by other modules (like options.lua)
    return statsFrame 
end

-- Update the text on the frame
function addonTable.UpdateStatsFrameText(addonInstance)
    if not statsFrame or not statsFrame:IsShown() then return end
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

    local xpString = string.format(L["Current XP"] .. ": %s / %s (%s%%)\n" .. L["Rested XP"] .. ": %s / %s (%s%%)", 
                                   currentXP, maxXP, string.format("%.1f", currentXPPerc), 
                                   restedXP, maxXP, string.format("%.1f", restedXPPerc))
    statsFrame.xpText:SetText(xpString)

    -- Access timePlayedTotal and timePlayedLevel from addonInstance if they are managed there
    -- For now, assuming they are passed or accessible via addonInstance if not global
    local timePlayedTotalString = addonInstance:FormatTime(addonInstance.timePlayedTotal or 0)
    local timePlayedLevelString = addonInstance:FormatTime(addonInstance.timePlayedLevel or 0)
    local timeToLevelString = addonInstance.timeToLevel or L["Calculating..."]


    local timeString = string.format(L["Time Played (Total)"] .. ": %s\n" .. L["Time Played (Level)"] .. ": %s\n",
                                   timePlayedTotalString, timePlayedLevelString)
    statsFrame.timeText:SetText(timeString)

    local remainingString = string.format(L["Time to Level"] .. ": %s", timeToLevelString)
    statsFrame.remainingText:SetText(remainingString)
    
    local mobsToLevelString = L["Mobs to Level"] .. ": " .. L["Calculating..."]
    if addonInstance.db.profile.xpSnapshots and #addonInstance.db.profile.xpSnapshots > 0 then
        local totalXpFromSnapshots = 0
        local numValidSnapshots = 0
        for _, snap in ipairs(addonInstance.db.profile.xpSnapshots) do
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
                local mobsNeeded = math.ceil(xpNeededToLevel / avgXpPerEvent)
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
    local mobsToLevelTextH = statsFrame.mobsToLevelText:GetStringHeight()
    local buttonH = statsFrame.refreshButton:GetHeight()
    statsFrame:SetHeight(titleH + xpTextH + remainingTextH + mobsToLevelTextH + timeTextH + buttonH + 60)
end

-- Toggle the UI frame's visibility
function addonTable.ToggleStatsFrame(addonInstance)
    if not statsFrame then
        addonTable.CreateStatsFrame(addonInstance) -- Create if it doesn't exist
    end
    
    if statsFrame:IsShown() then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
    else
        statsFrame:Show()
        addonInstance.db.profile.showFrame = true
        addonTable.UpdateStatsFrameText(addonInstance) -- Ensure text is updated when showing
    end
end

-- Explicitly show the frame
function addonTable.ShowStatsFrame(addonInstance)
    if not statsFrame then
        addonTable.CreateStatsFrame(addonInstance)
    end
    if statsFrame and not statsFrame:IsShown() then
        statsFrame:Show()
        addonInstance.db.profile.showFrame = true
        addonTable.UpdateStatsFrameText(addonInstance)
    end
end

-- Explicitly hide the frame
function addonTable.HideStatsFrame(addonInstance)
    if statsFrame and statsFrame:IsShown() then
        statsFrame:Hide()
        addonInstance.db.profile.showFrame = false
    end
end

-- Function to be called by options to set visibility
function addonTable.SetStatsFrameVisibility(addonInstance, shouldShow)
    if shouldShow then
        addonTable.ShowStatsFrame(addonInstance)
    else
        addonTable.HideStatsFrame(addonInstance)
    end
end
