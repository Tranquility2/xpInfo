local addonName, addonTable = ...

-- Local variables to hold UI elements
local levelGraphFrame
local LibGraph = LibStub("LibGraph-2.0")
local graph

-- Debug flag for CalculateTimeToMaxLevel function
local DEBUG_ESTIMATION = true
-- Flag to use fake snapshots for testing
local FAKE_SNAPSHOTS = true

-- Global variables for level progression data
local levelSnapshots
local maxLevel
local estimatedTimeToMaxLevel

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
    
    -- Mathematical convergence towards 400 hours using weighted averaging
    -- The closer we get to 400, the more we trust the regression
    -- The further we are, the more we pull towards 400
    local targetTime = 400  -- Target convergence point
    local rawEstimate = estimatedTimeToMaxLevel
    
    -- Calculate distance from target as a ratio
    local distanceRatio = math.abs(rawEstimate - targetTime) / targetTime
    
    -- Use a sigmoid-like function to determine blending weight
    -- When estimate is close to 400, use more of the raw estimate
    -- When estimate is far from 400, use more of the target
    local blendFactor = 1 / (1 + math.exp(distanceRatio * 2))  -- Sigmoid function
    
    -- Apply mathematical convergence
    local finalEstimate = (blendFactor * rawEstimate) + ((1 - blendFactor) * targetTime)
    
    -- Additional safeguard: if linear estimate suggests much longer, respect it partially
    if linearEstimate > targetTime then
        local linearWeight = math.min(0.3, (linearEstimate - targetTime) / targetTime)
        finalEstimate = finalEstimate + (linearWeight * (linearEstimate - finalEstimate))
    end
    
    if DEBUG_ESTIMATION then
        print("Debug: Raw logarithmic estimate:", rawEstimate, "hours")
        print("Debug: Distance ratio from 400h:", distanceRatio)
        print("Debug: Blend factor (closer to 1 = trust regression more):", blendFactor)
        print("Debug: Convergence-adjusted estimate:", finalEstimate, "hours")
        print("Debug: Linear estimate:", linearEstimate, "hours")
        print("Debug: Final estimation:", finalEstimate, "hours")
        print("Debug: Formatted estimation:", FormatTimeEstimate(finalEstimate))
    end
    
    -- Accept estimates within a reasonable range around our target
    if finalEstimate > 0 and finalEstimate <= 600 then  -- Allow some flexibility above 400
        if DEBUG_ESTIMATION then
            print("Debug: Returning convergence-adjusted estimation:", FormatTimeEstimate(finalEstimate))
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
    levelSnapshots = addonInstance.db.profile.levelSnapshots
    
    -- Create fake levelSnapshots for debugging if none exist
    if FAKE_SNAPSHOTS then
        levelSnapshots = {
            {time = 3600, level = 5},      -- 1 hour, level 5
            {time = 7200, level = 8},      -- 2 hours, level 8
            {time = 14400, level = 12},    -- 4 hours, level 12
            {time = 25200, level = 16},    -- 7 hours, level 16
            {time = 39600, level = 20},    -- 11 hours, level 20
            {time = 57600, level = 24},    -- 16 hours, level 24
            {time = 79200, level = 28},    -- 22 hours, level 28
            {time = 104400, level = 32},   -- 29 hours, level 32
            {time = 133200, level = 36},   -- 37 hours, level 36
            {time = 165600, level = 40},   -- 46 hours, level 40
            {time = 201600, level = 44},   -- 56 hours, level 44
            {time = 241200, level = 48},   -- 67 hours, level 48
            {time = 284400, level = 52},   -- 79 hours, level 52
        }
        if DEBUG_ESTIMATION then
            print("Debug: Using fake levelSnapshots for testing")
        end
    end
    
    maxLevel = addonInstance.db.profile.maxLevel or 60
    estimatedTimeToMaxLevel = CalculateTimeToMaxLevel(levelSnapshots, maxLevel)
    
    -- Determine X-axis maximum (minimum 100 hours)
    local xAxisMax = 100  -- Default minimum
    if estimatedTimeToMaxLevel and estimatedTimeToMaxLevel > 0 then
        -- Round up to nearest 50 hours, with minimum of 100
        xAxisMax = math.max(100, math.ceil(estimatedTimeToMaxLevel / 50) * 50)
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

-- Function to add logarithmic estimation curve to the graph
local function AddEstimationCurveToGraph()
    if not estimatedTimeToMaxLevel or estimatedTimeToMaxLevel <= 0 or not maxLevel then
        return
    end
    
    -- Get current progress from the latest snapshot
    local latestSnapshot = levelSnapshots[#levelSnapshots]
    local currentTime = latestSnapshot.time / 3600
    local currentLevel = latestSnapshot.level
    
    -- Create logarithmic estimation curve from current point to max level point
    local estimationPoints = {}
    
    -- Calculate the logarithmic regression coefficients for the curve
    -- We'll approximate the curve by sampling points along the logarithmic function
    local timeStep = (estimatedTimeToMaxLevel - currentTime) / 20  -- 20 points for smooth curve
    
    for i = 0, 20 do
        local t = currentTime + (i * timeStep)
        if t > 0 then  -- Ensure positive time for logarithm
            -- Use a logarithmic interpolation between current and estimated points
            local progress = i / 20  -- 0 to 1
            
            -- Logarithmic progression: slower growth initially, faster later
            local logProgress = math.log(1 + progress * (math.exp(1) - 1)) / 1  -- Normalized log curve
            local level = currentLevel + logProgress * (maxLevel - currentLevel)
            
            table.insert(estimationPoints, {t, level})
        end
    end
    
    -- Ensure we end exactly at the estimation point
    table.insert(estimationPoints, {estimatedTimeToMaxLevel, maxLevel})
    
    -- Add the logarithmic estimation curve to the graph (red curved line)
    graph:AddDataSeries(estimationPoints, {1.0, 0.2, 0.2, 0.8})
    
    -- Also add a point at the estimation to make it more visible
    local estimationPoint = {{estimatedTimeToMaxLevel, maxLevel}}
    graph:AddDataSeries(estimationPoint, {1.0, 0.0, 0.0, 1.0})
end

-- Function to update the level graph with snapshot data
local function UpdateLevelGraph(addonInstance)
    if not levelGraphFrame or not levelGraphFrame:IsShown() or not graph then 
        return 
    end
    
    -- Clear the graph
    graph:ResetData()
    
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
    
    -- Add estimation curve if we have a valid estimate
    AddEstimationCurveToGraph()
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
