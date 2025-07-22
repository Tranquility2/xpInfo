local addonName, addonTable = ...

-- Local variables to hold UI elements
local levelGraphFrame
local LibGraph = LibStub("LibGraph-2.0")
local graph

-- Debug flag for CalculateTimeToMaxLevel function
local DEBUG_ESTIMATION = false

-- Function to format time in hours to a readable string
local function FormatTimeEstimate(hours)
    if not hours or hours <= 0 then
        return "N/A"
    end
    
    local days = math.floor(hours / 24)
    local remainingHours = math.floor(hours % 24)
    local minutes = math.floor((hours % 1) * 60)
    
    local parts = {}
    
    if days > 0 then
        table.insert(parts, days .. (days == 1 and " day" or " days"))
    end
    
    if remainingHours > 0 then
        table.insert(parts, remainingHours .. (remainingHours == 1 and " hour" or " hours"))
    end
    
    if minutes > 0 and days == 0 then  -- Only show minutes if less than a day
        table.insert(parts, minutes .. (minutes == 1 and " minute" or " minutes"))
    end
    
    if #parts == 0 then
        return "Less than 1 minute"
    end
    
    return table.concat(parts, ", ")
end

-- Function to calculate estimated time to reach max level using logarithmic regression
local function CalculateTimeToMaxLevel(levelSnapshots, maxLevel)
    if DEBUG_ESTIMATION then
        print("Debug: CalculateTimeToMaxLevel called (logarithmic regression)")
        print("Debug: Number of snapshots:", levelSnapshots and #levelSnapshots or 0)
        print("Debug: Max level:", maxLevel)
    end
    
    if not levelSnapshots or #levelSnapshots < 2 then
        if DEBUG_ESTIMATION then
            print("Debug: Insufficient snapshots (need at least 2)")
        end
        return nil
    end
    
    -- Get the latest snapshot to check current state
    local latestSnapshot = levelSnapshots[#levelSnapshots]
    local currentLevel = latestSnapshot.level
    
    if DEBUG_ESTIMATION then
        print("Debug: Current level:", currentLevel)
    end
    
    if currentLevel >= maxLevel then
        if DEBUG_ESTIMATION then
            print("Debug: Already at or above max level")
        end
        return nil
    end
    
    -- Prepare data points for logarithmic regression (ln(time) vs level)
    local validSnapshots = {}
    
    -- First pass: filter out invalid time values
    for i, snapshot in ipairs(levelSnapshots) do
        local timeInHours = snapshot.time / 3600
        if timeInHours > 0 then
            table.insert(validSnapshots, snapshot)
        else
            if DEBUG_ESTIMATION then
                print("Debug: Skipping point", i, "- invalid time:", timeInHours)
            end
        end
    end
    
    local n = #validSnapshots
    if DEBUG_ESTIMATION then
        print("Debug: Starting logarithmic regression calculations with", n, "valid data points")
    end
    
    -- Check if we have enough valid points
    if n < 2 then
        if DEBUG_ESTIMATION then
            print("Debug: Not enough valid data points after filtering")
        end
        return nil
    end
    
    local sumX = 0  -- sum of ln(time) values
    local sumY = 0  -- sum of level values
    local sumXY = 0 -- sum of (ln(time) * level)
    local sumX2 = 0 -- sum of (ln(time)^2)
    
    -- Calculate sums for logarithmic regression formula: level = a * ln(time) + b
    for i, snapshot in ipairs(validSnapshots) do
        local timeInHours = snapshot.time / 3600
        local level = snapshot.level
        local lnTime = math.log(timeInHours)  -- natural logarithm of time
        
        if DEBUG_ESTIMATION then
            print(string.format("Debug: Point %d - Time: %.2f hours, ln(Time): %.3f, Level: %d", i, timeInHours, lnTime, level))
        end
        
        sumX = sumX + lnTime
        sumY = sumY + level
        sumXY = sumXY + (lnTime * level)
        sumX2 = sumX2 + (lnTime * lnTime)
    end
    
    if DEBUG_ESTIMATION then
        print("Debug: Regression sums - sumX:", sumX, "sumY:", sumY, "sumXY:", sumXY, "sumX2:", sumX2)
    end
    
    -- Calculate logarithmic regression coefficients: level = a * ln(time) + b
    local denominator = n * sumX2 - sumX * sumX
    if DEBUG_ESTIMATION then
        print("Debug: Denominator:", denominator)
    end
    
    if denominator == 0 then
        if DEBUG_ESTIMATION then
            print("Debug: Cannot calculate regression - denominator is zero")
        end
        return nil
    end
    
    local a = (n * sumXY - sumX * sumY) / denominator  -- coefficient for ln(time)
    local b = (sumY - a * sumX) / n                    -- y-intercept
    
    if DEBUG_ESTIMATION then
        print("Debug: Logarithmic regression coefficients - a:", a, "b:", b)
    end
    
    -- Validate the coefficient - should be positive (leveling up with time)
    if a <= 0 then
        if DEBUG_ESTIMATION then
            print("Debug: Invalid regression - coefficient is not positive:", a)
        end
        return nil
    end
    
    -- Calculate estimated time to reach max level
    local lnEstimatedTime = (maxLevel - b) / a
    local estimatedTimeToMaxLevel = math.exp(lnEstimatedTime)
    
    if DEBUG_ESTIMATION then
        print("Debug: ln(estimated time):", lnEstimatedTime)
        print("Debug: Raw estimation:", estimatedTimeToMaxLevel, "hours")
    end
    
    -- Additional validation: check if estimate is reasonable compared to current progress
    local currentTime = latestSnapshot.time / 3600
    local currentLevel = latestSnapshot.level
    local levelsRemaining = maxLevel - currentLevel
    local levelsCompleted = currentLevel - 1  -- assuming started at level 1
    
    -- Calculate a simple linear estimate for comparison
    local averageTimePerLevel = currentTime / levelsCompleted
    local linearEstimate = currentTime + (levelsRemaining * averageTimePerLevel)
    
    if DEBUG_ESTIMATION then
        print("Debug: Current time:", currentTime, "hours")
        print("Debug: Levels completed:", levelsCompleted, "Levels remaining:", levelsRemaining)
        print("Debug: Average time per level:", averageTimePerLevel, "hours")
        print("Debug: Linear estimate for comparison:", linearEstimate, "hours")
    end
    
    -- If logarithmic estimate is more than 3x the linear estimate, use a capped version
    local finalEstimate = estimatedTimeToMaxLevel
    if estimatedTimeToMaxLevel > linearEstimate * 3 then
        finalEstimate = linearEstimate * 2  -- Use 2x linear as a more conservative estimate
        if DEBUG_ESTIMATION then
            print("Debug: Logarithmic estimate too high, using conservative estimate:", finalEstimate, "hours")
        end
    end
    
    if DEBUG_ESTIMATION then
        print("Debug: Final estimation:", finalEstimate, "hours")
        print("Debug: Formatted estimation:", FormatTimeEstimate(finalEstimate))
    end
    
    -- Accept reasonable estimates (up to 500 hours, reduced from 1000)
    if finalEstimate > 0 and finalEstimate <= 500 then
        if DEBUG_ESTIMATION then
            print("Debug: Returning valid estimation:", FormatTimeEstimate(finalEstimate))
        end
        return finalEstimate
    else
        if DEBUG_ESTIMATION then
            print("Debug: Estimation out of reasonable range:", FormatTimeEstimate(finalEstimate))
        end
        return nil
    end
end

-- Function to create the level progression graph frame
local function CreateLevelGraphFrame(addonInstance)
    local L = addonInstance.L
    
    -- Create main frame container
    levelGraphFrame = CreateFrame("Frame", "XpInfoLevelGraph", UIParent, "BackdropTemplate")
    levelGraphFrame:SetSize(500, 300)
    levelGraphFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    levelGraphFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    levelGraphFrame:EnableMouse(true)
    levelGraphFrame:SetMovable(true)
    levelGraphFrame:RegisterForDrag("LeftButton")
    
    -- Set up drag functionality
    levelGraphFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    levelGraphFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint(1)
        local relativeToName = relativeTo and (relativeTo:GetName() or "UIParent") or "UIParent"
        addonInstance.db.profile.levelGraphPosition = { point, relativeToName, relativePoint, xOfs, yOfs }
    end)
    
    -- Restore saved position if available
    if addonInstance.db.profile.levelGraphPosition then
        local pos = addonInstance.db.profile.levelGraphPosition
        levelGraphFrame:SetPoint(pos[1], pos[2], pos[3], pos[4], pos[5])
    end
    
    -- Title text
    local titleText = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", levelGraphFrame, "TOPLEFT", 20, -20)
    titleText:SetText(L["Level Progression"] or "Level Progression")
    
    -- Create a graph object using LibGraph-2.0
    graph = LibGraph:CreateGraphLine("XpInfoLevelProgressGraph", levelGraphFrame, "CENTER", "CENTER", 0, 0, 400, 250)
    
    -- Calculate dynamic X-axis range based on estimated time to max level
    local levelSnapshots = addonInstance.db.profile.levelSnapshots
    local maxLevel = addonInstance.db.profile.maxLevel or 60
    local timeToMaxLevel = CalculateTimeToMaxLevel(levelSnapshots, maxLevel)
    
    -- Determine X-axis maximum (minimum 100 hours)
    local xAxisMax = 100  -- Default minimum
    if timeToMaxLevel and timeToMaxLevel > 0 then
        -- Round up to nearest 50 hours, with minimum of 100
        xAxisMax = math.max(100, math.ceil(timeToMaxLevel / 50) * 50)
    end
    
    -- Set dynamic axis ranges: X-axis 0 to calculated max, Y-axis 1 to maxLevel
    graph:SetXAxis(0, xAxisMax)
    graph:SetYAxis(1, maxLevel)  -- 1 to configured max level
    graph:SetGridSpacing(math.max(20, xAxisMax / 5), 10)  -- Adjust grid spacing based on range
    graph:SetGridColor({0.2, 0.2, 0.2, 0.4})
    graph:SetAxisDrawing(true, true)
    graph:SetAxisColor({1.0, 1.0, 1.0, 1.0})
    graph:SetAutoScale(false)  -- Disable auto-scaling to maintain fixed ranges
    
    -- Position the graph inside our frame
    graph:SetPoint("TOPLEFT", levelGraphFrame, "TOPLEFT", 60, -60) 
    graph:SetPoint("BOTTOMRIGHT", levelGraphFrame, "BOTTOMRIGHT", -30, 60)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, levelGraphFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", levelGraphFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        levelGraphFrame:Hide()
        addonInstance.db.profile.showLevelGraph = false
    end)
    
    -- Create X-axis labels dynamically based on the calculated range
    levelGraphFrame.xAxisLabels = {}
    local labelInterval = math.max(20, xAxisMax / 5)  -- Adjust interval based on range
    for i = 0, xAxisMax, labelInterval do
        local label = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOP", graph, "BOTTOMLEFT", (i/xAxisMax) * graph:GetWidth(), -10)
        label:SetText(i .. "h")  -- Display as "0h", "20h", "40h", etc.
        table.insert(levelGraphFrame.xAxisLabels, label)
    end
    
    -- Create Y-axis labels (1, 5, 10, 15, ... up to maxLevel)
    levelGraphFrame.yAxisLabels = {}
    
    -- Always show level 1 (at bottom)
    local label1 = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local yPos1 = ((maxLevel - 1) / (maxLevel - 1)) * graph:GetHeight()  -- Bottom position
    label1:SetPoint("RIGHT", graph, "TOPLEFT", -10, -yPos1)
    label1:SetText("1")
    table.insert(levelGraphFrame.yAxisLabels, label1)
    
    -- Show every 5 levels starting from 5
    for i = 5, maxLevel, 5 do
        local label = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local yPos = ((maxLevel - i) / (maxLevel - 1)) * graph:GetHeight()  -- Reversed position
        label:SetPoint("RIGHT", graph, "TOPLEFT", -10, -yPos)
        label:SetText(tostring(i))
        table.insert(levelGraphFrame.yAxisLabels, label)
    end
    
    -- Always show max level if it's not already shown (at top)
    if maxLevel % 5 ~= 0 then
        local labelMax = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local yPosMax = ((maxLevel - maxLevel) / (maxLevel - 1)) * graph:GetHeight()  -- Top position
        labelMax:SetPoint("RIGHT", graph, "TOPLEFT", -10, -yPosMax)
        labelMax:SetText(tostring(maxLevel))
        table.insert(levelGraphFrame.yAxisLabels, labelMax)
    end
    
    -- Add axis titles
    local xAxisLabel = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xAxisLabel:SetPoint("TOP", levelGraphFrame, "BOTTOM", 0, 25)
    xAxisLabel:SetText(L["Time Played (Hours)"] or "Time Played (Hours)")
    
    local yAxisLabel = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yAxisLabel:SetPoint("CENTER", levelGraphFrame, "LEFT", 15, 0)
    yAxisLabel:SetRotation(1.5708) -- 90 degrees
    yAxisLabel:SetText(L["Character Level"] or "Character Level")
    
    return levelGraphFrame
end

-- Function to update the level graph with snapshot data
local function UpdateLevelGraph(addonInstance)
    if not levelGraphFrame or not levelGraphFrame:IsShown() or not graph then 
        return 
    end
    
    -- Clear the graph
    graph:ResetData()
    
    -- Get level snapshots from the player's profile
    local levelSnapshots = addonInstance.db.profile.levelSnapshots
    if not levelSnapshots or #levelSnapshots < 1 then
        return
    end
    
    -- Prepare actual data points from snapshots
    local dataPoints = {}
    for _, snapshot in ipairs(levelSnapshots) do
        local timeInHours = snapshot.time / 3600  -- Convert seconds to hours
        table.insert(dataPoints, {timeInHours, snapshot.level})
    end
    
    -- Add the actual data series to the graph (blue line)
    graph:AddDataSeries(dataPoints, {0.2, 0.6, 1.0, 0.9})
    
    -- -- Calculate estimated time to max level and add as a point
    -- local maxLevel = addonInstance.db.profile.maxLevel
    -- local estimatedTimeToMaxLevel = CalculateTimeToMaxLevel(levelSnapshots, maxLevel)

    -- if estimatedTimeToMaxLevel then
    --     -- Extend X-axis if needed to show the estimation point
    --     local currentXMax = 100
    --     if estimatedTimeToMaxLevel > currentXMax then
    --         local newXMax = math.ceil(estimatedTimeToMaxLevel / 50) * 50  -- Round up to nearest 50
    --         graph:SetXAxis(0, newXMax)
    --     end
        
    --     -- Add the estimated max level point as a separate series (red point)
    --     -- Create multiple points around the estimation to make it more visible
    --     local maxLevelPoints = {
    --         {estimatedTimeToMaxLevel, maxLevel},
    --         {estimatedTimeToMaxLevel - 0.1, maxLevel},
    --         {estimatedTimeToMaxLevel + 0.1, maxLevel},
    --         {estimatedTimeToMaxLevel, maxLevel - 0.1},
    --         {estimatedTimeToMaxLevel, maxLevel + 0.1}
    --     }
    --     graph:AddDataSeries(maxLevelPoints, {1.0, 0.2, 0.2, 1.0})
    -- end
end

-- Toggle the Level Graph frame visibility
local function ToggleLevelGraph(addonInstance)
    if levelGraphFrame and levelGraphFrame:IsShown() then
        levelGraphFrame:Hide()
        addonInstance.db.profile.showLevelGraph = false
    else
        if not levelGraphFrame then
            CreateLevelGraphFrame(addonInstance)
        end
        levelGraphFrame:Show()
        addonInstance.db.profile.showLevelGraph = true
        UpdateLevelGraph(addonInstance)
    end
end

-- Explicitly show the Level Graph frame
local function ShowLevelGraph(addonInstance)
    if not levelGraphFrame then
        CreateLevelGraphFrame(addonInstance)
    end
    levelGraphFrame:Show()
    addonInstance.db.profile.showLevelGraph = true
    UpdateLevelGraph(addonInstance)
end

-- Explicitly hide the Level Graph frame
local function HideLevelGraph(addonInstance)
    if levelGraphFrame then
        levelGraphFrame:Hide()
        addonInstance.db.profile.showLevelGraph = false
    end
end

-- Export functions to the addon table
addonTable.CreateLevelGraphFrame = CreateLevelGraphFrame
addonTable.UpdateLevelGraph = UpdateLevelGraph
addonTable.ToggleLevelGraph = ToggleLevelGraph
addonTable.ShowLevelGraph = ShowLevelGraph
addonTable.HideLevelGraph = HideLevelGraph
addonTable.CalculateTimeToMaxLevel = CalculateTimeToMaxLevel
