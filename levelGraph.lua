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
    
    -- Set fixed axis ranges: X-axis 0-100 hours, Y-axis 1 to maxLevel
    local maxLevel = addonInstance.db.profile.maxLevel or 60
    graph:SetXAxis(0, 100)  -- Fixed 0-100 hours
    graph:SetYAxis(1, maxLevel)  -- 1 to configured max level
    graph:SetGridSpacing(20, 10)  -- X-axis every 20 hours, Y-axis every 10 levels (limited grid lines)
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
    
    -- Create X-axis labels (0, 20, 40, 60, 80, 100 hours)
    levelGraphFrame.xAxisLabels = {}
    for i = 0, 100, 20 do
        local label = levelGraphFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOP", graph, "BOTTOMLEFT", (i/100) * graph:GetWidth(), -10)
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
    
    -- Prepare data points from snapshots
    local dataPoints = {}
    for _, snapshot in ipairs(levelSnapshots) do
        local timeInHours = snapshot.time / 3600  -- Convert seconds to hours
        table.insert(dataPoints, {timeInHours, snapshot.level})
    end
    
    -- Add the data series to the graph (blue line)
    graph:AddDataSeries(dataPoints, {0.2, 0.6, 1.0, 0.9})
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
