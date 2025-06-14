local addonName, addonTable = ...

-- Local variables to hold UI elements
local levelGraphFrame
local LibGraph = LibStub("LibGraph-2.0")
local graph

-- Function to create the level progression graph frame
local function CreateLevelGraphFrame(addonInstance)
    local L = addonInstance.L
    
    -- Create main frame container
    levelGraphFrame = CreateFrame("Frame", "XpInfoLevelGraph", UIParent, "BackdropTemplate")
    levelGraphFrame:SetSize(400, 300)
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
    graph = LibGraph:CreateGraphLine("XpInfoLevelProgressGraph", levelGraphFrame, "CENTER", "CENTER", 0, 0, 360, 220)
    graph:SetXAxis(0, 1)
    graph:SetYAxis(1, 60)  -- Default Y range for levels 1-60
    graph:SetGridSpacing(1, 5)
    graph:SetGridColor({0.2, 0.2, 0.2, 0.5})
    graph:SetAxisDrawing(true, true)
    graph:SetAxisColor({1.0, 1.0, 1.0, 1.0})
    graph:SetAutoScale(true)
    
    -- Enable axis labels
    graph:SetYLabels(true)   -- Show Y-axis labels (level numbers)
    -- X-axis labels will be created manually
    
    -- Position the graph inside our frame with extra left margin for y-axis label
    graph:SetPoint("TOPLEFT", levelGraphFrame, "TOPLEFT", 40, -50) 
    graph:SetPoint("BOTTOMRIGHT", levelGraphFrame, "BOTTOMRIGHT", -20, 50)  -- Increased bottom margin for X-axis label
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, levelGraphFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", levelGraphFrame, "TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        levelGraphFrame:Hide()
        addonInstance.db.profile.showLevelGraph = false
    end)
    
    -- Add axis labels
    local xAxisLabel = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xAxisLabel:SetPoint("BOTTOM", levelGraphFrame, "BOTTOM", 0, 15)
    xAxisLabel:SetText(L["Time Played (Hours)"] or "Time Played (Hours)")
    
    local yAxisLabel = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Position the y-axis label inside the frame, to the left of the graph's y-axis labels
    -- This positions it in the space between the frame edge and the graph
    yAxisLabel:SetPoint("CENTER", levelGraphFrame, "LEFT", 25, 0)
    yAxisLabel:SetRotation(1.5708) -- 90 degrees in radians (π/2)
    yAxisLabel:SetText(L["Character Level"] or "Character Level")
    
    -- Set a higher strata to ensure the label renders above everything else
    yAxisLabel:SetDrawLayer("OVERLAY", 7)
    
    return levelGraphFrame
end

-- Function to update the level graph with the latest data
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
    
    -- Determine min/max values for proper scaling
    local minLevel = 60
    local maxLevel = 1
    local maxTime = 0
    
    for _, snapshot in ipairs(levelSnapshots) do
        minLevel = math.min(minLevel, snapshot.level)
        maxLevel = math.max(maxLevel, snapshot.level)
        maxTime = math.max(maxTime, snapshot.time)
    end
    
    -- Adjust ranges if needed
    if maxLevel <= minLevel then
        -- If only one level exists, add some padding
        minLevel = minLevel - 1
        maxLevel = maxLevel + 1
    end
    
    if maxTime == 0 then
        maxTime = 1  -- Default if no time data
    end
    
    -- Set the axis ranges
    local maxHours = maxTime / 3600
    graph:SetXAxis(0, maxHours)  -- Convert seconds to hours
    graph:SetYAxis(minLevel, maxLevel + 1)
    
    -- Set grid spacing for nice round numbers
    local xGridSpacing = 1
    if maxHours > 50 then
        xGridSpacing = 10  -- Every 10 hours if playing time is long
    elseif maxHours > 20 then
        xGridSpacing = 5   -- Every 5 hours for medium playtime
    elseif maxHours > 10 then
        xGridSpacing = 2   -- Every 2 hours for shorter playtime
    end
    
    local yGridSpacing = 1 -- Default to 1 level intervals
    if maxLevel - minLevel > 20 then
        yGridSpacing = 5   -- Every 5 levels if level range is large
    elseif maxLevel - minLevel > 10 then
        yGridSpacing = 2   -- Every 2 levels if medium range
    end
    
    graph:SetGridSpacing(xGridSpacing, yGridSpacing)
    
    -- Function to add custom X-axis time labels
    local function AddTimeAxisLabels()
        -- Calculate how many labels to show based on grid spacing, but limit to prevent overflow
        local numLabels = math.min(math.floor(maxHours / xGridSpacing), 10) -- Cap at 10 labels max
        
        -- Get the graph's dimensions and position
        local graphWidth = graph:GetWidth()
        
        -- Create a container frame for the x-axis labels if it doesn't exist
        if not levelGraphFrame.xAxisLabelContainer then
            levelGraphFrame.xAxisLabelContainer = CreateFrame("Frame", nil, levelGraphFrame)
            levelGraphFrame.xAxisLabelContainer:SetPoint("TOPLEFT", graph, "BOTTOMLEFT", 0, -5)
            levelGraphFrame.xAxisLabelContainer:SetPoint("TOPRIGHT", graph, "BOTTOMRIGHT", 0, -5)
            levelGraphFrame.xAxisLabelContainer:SetHeight(20)
        end
        
        -- To properly align with the grid lines, we need to perform some calculations
        -- Calculate left and right edges of the graph area (where the grid starts and ends)
        local graphStartX = graph:GetWidth() * 0.08  -- More conservative padding estimation
        local graphEndX = graph:GetWidth() - (graph:GetWidth() * 0.08)  -- Right padding
        local usableWidth = graphEndX - graphStartX
        
        -- Calculate exact grid positions, ensuring they stay within bounds
        for i = 0, numLabels do
            local hourValue = i * xGridSpacing
            -- Skip if this would exceed our max hours (safety check)
            if hourValue > maxHours then
                break
            end
            
            -- Calculate exact grid position with proper adjustment for graph internal margins
            local xPosFraction = hourValue / maxHours
            local xPos = graphStartX + (usableWidth * xPosFraction)
            
            -- Ensure the label position stays within the container bounds
            xPos = math.max(10, math.min(xPos, graphWidth - 10))
            
            local label = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            -- Center the label directly under the grid line
            label:SetPoint("TOP", levelGraphFrame.xAxisLabelContainer, "TOPLEFT", xPos, 0)
            label:SetJustifyH("CENTER")
            label:SetText(string.format("%d", hourValue))  -- Display hours as integers
            table.insert(levelGraphFrame.xAxisLabels, label)
        end
    end
    
    -- Constants for the X time axis (seconds to hours)
    local SEC_PER_HOUR = 3600
    
    -- Prepare data series for the graph
    local dataPoints = {}
    
    for _, snapshot in ipairs(levelSnapshots) do
        table.insert(dataPoints, {snapshot.time / SEC_PER_HOUR, snapshot.level})
    end
    
    -- Add the current level if not already included
    local currentLevel = UnitLevel("player")
    local currentTime = addonInstance.timePlayedTotal
    
    -- Check if the last snapshot isn't already the current level/time
    local lastSnap = levelSnapshots[#levelSnapshots]
    if not lastSnap or lastSnap.level ~= currentLevel or math.abs(lastSnap.time - currentTime) > 60 then
        table.insert(dataPoints, {currentTime / SEC_PER_HOUR, currentLevel})
    end
    
    -- Add the data series to the graph
    graph:AddDataSeries(dataPoints, {0.0, 0.6, 1.0, 0.8})
    
    -- Remove any existing X-axis labels before adding new ones
    -- This is necessary when the graph is refreshed
    if levelGraphFrame.xAxisLabels then
        for _, label in ipairs(levelGraphFrame.xAxisLabels) do
            label:Hide()
        end
        levelGraphFrame.xAxisLabels = {}
    else
        levelGraphFrame.xAxisLabels = {}
    end
    
    -- Add the hour labels
    AddTimeAxisLabels()
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
