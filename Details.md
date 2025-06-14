# xpInfo - Detailed Technical Documentation

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Data Model](#data-model)
3. [Algorithms](#algorithms)
4. [API Reference](#api-reference)
5. [Event System](#event-system)
6. [Graph Implementation](#graph-implementation)
7. [Configuration System](#configuration-system)
9. [Localization](#localization)
10. [Troubleshooting](#troubleshooting)
11. [Development](#development)

## Architecture Overview

xpInfo follows a modular architecture with each component handling specific functionality:

- **Core Module** (`xpInfo.lua`) - Main addon logic, event handling, data management
- **UI Components** - Stats frame, XP bar, level graph, configuration interface
- **Data Layer** - Character profiles, experience snapshots, historical tracking
- **Calculation Engine** - XP analysis, time predictions, linear regression
- **Configuration** - Options management, user preferences, profile switching

### Dependencies
- **LibGraph-2.0** - Graph rendering and visualization
- **LibDataBroker-1.1** - Minimap icon integration
- **LibDBIcon-1.0** - Icon positioning and management
- **Ace3** - Utility functions for string manipulation, table handling

## Data Model

### Profile Structure
Each character maintains a profile with the following schema:

```lua
profile = {
    -- Basic Settings
    showStatsFrame = true,
    showXpBar = true, 
    showGraph = false,
    showMinimapIcon = true,
    
    -- Configuration
    maxLevel = 60,                    -- Configurable max level (10-80)
    xpSampleSize = 10,               -- XP calculation sample size
    tooltipAnchor = "ANCHOR_RIGHT",  -- Tooltip positioning
    
    -- Position Data
    statsFramePos = { x, y },        -- Stats frame position
    xpBarPos = { x, y },            -- XP bar position
    graphPos = { x, y },            -- Graph window position
    
    -- Experience Data
    levelSnapshots = {              -- Historical level data
        [timestamp] = {
            level = number,
            xp = number,
            maxXp = number,
            playedTime = number
        }
    },
    
    -- Calculated Fields
    estimatedMaxLevel = nil,        -- Estimated time to max level
    lastXpGain = 0,                -- Most recent XP gain
    xpGains = {},                  -- Recent XP gain history
}
```

### Experience Snapshots
Level snapshots are created at key moments:
- **Level Up** - Automatic snapshot with full data
- **Login** - Initial state capture
- **Logout** - Final state preservation
- **Manual** - Via `/xpi snapshot` command

Each snapshot includes:
- Current level and XP values
- Total played time
- Timestamp for progression tracking
- Rested XP state (if available)

## Algorithms

### Linear Regression for Time Prediction

The addon uses linear regression to predict leveling time based on recent progression:

```lua
function calculateEstimatedMaxLevel(levelSnapshots, currentLevel, maxLevel)
    if currentLevel >= maxLevel then return 0 end
    
    -- Collect recent data points (level vs time)
    local dataPoints = {}
    for timestamp, snapshot in pairs(levelSnapshots) do
        if snapshot.level >= currentLevel - 5 then  -- Recent levels only
            table.insert(dataPoints, {
                x = snapshot.playedTime or 0,
                y = snapshot.level
            })
        end
    end
    
    -- Require minimum data for accuracy
    if #dataPoints < 2 then return nil end
    
    -- Calculate linear regression
    local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0
    for _, point in ipairs(dataPoints) do
        sumX = sumX + point.x
        sumY = sumY + point.y  
        sumXY = sumXY + (point.x * point.y)
        sumX2 = sumX2 + (point.x * point.x)
    end
    
    local n = #dataPoints
    local slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
    local intercept = (sumY - slope * sumX) / n
    
    -- Project time to reach max level
    local timeToMaxLevel = (maxLevel - intercept) / slope
    local currentTime = GetTime()
    
    return math.max(0, timeToMaxLevel - currentTime)
end
```

### XP Efficiency Calculation

Average XP per action uses weighted recent data:

```lua
function calculateAverageXp(xpGains, sampleSize)
    local recentGains = {}
    local count = 0
    
    -- Get most recent gains up to sample size
    for i = #xpGains, math.max(1, #xpGains - sampleSize + 1), -1 do
        table.insert(recentGains, xpGains[i])
        count = count + 1
    end
    
    if count == 0 then return 0 end
    
    -- Calculate weighted average (recent gains weighted higher)
    local totalXp = 0
    local totalWeight = 0
    
    for i, xp in ipairs(recentGains) do
        local weight = i  -- More recent = higher weight
        totalXp = totalXp + (xp * weight)
        totalWeight = totalWeight + weight
    end
    
    return totalXp / totalWeight
end
```

## API Reference

### Core Functions

#### `xpInfo:Initialize()`
Initializes the addon, sets up saved variables, registers events.

#### `xpInfo:UpdateExperience()`
Updates all XP-related calculations and UI elements. Called on XP changes.

#### `xpInfo:TakeSnapshot(reason)`
Creates a level snapshot with current character state.
- `reason` (string): Why the snapshot was taken ("levelup", "login", etc.)

#### `xpInfo:CalculateEstimatedMaxLevel()`
Runs linear regression to calculate time-to-max-level estimate.

### Configuration API

#### `xpInfo:SetMaxLevel(level)`
Updates the maximum level for calculations and graph display.
- `level` (number): New max level (10-80)

#### `xpInfo:SetXpSampleSize(size)`
Changes the sample size for XP efficiency calculations.
- `size` (number): Sample size (2-20)

### UI API

#### `xpInfo:ToggleStatsFrame()`
Shows/hides the statistics frame.

#### `xpInfo:ToggleXpBar()`
Shows/hides the standalone XP bar.

#### `xpInfo:ToggleGraph()`
Shows/hides the level progression graph.

#### `xpInfo:RefreshGraph()`
Updates the level graph with current data.

## Event System

### Registered Events

```lua
-- Core XP Events
"PLAYER_XP_UPDATE"          -- XP gained
"PLAYER_LEVEL_UP"           -- Level increased
"UPDATE_EXHAUSTION"         -- Rested XP changed

-- Session Events  
"PLAYER_LOGIN"              -- Character logged in
"PLAYER_LOGOUT"             -- Character logging out
"TIME_PLAYED_MSG"           -- Played time received

-- UI Events
"ADDON_LOADED"              -- Addon initialization
"VARIABLES_LOADED"          -- Saved variables ready
```

### Event Handler Pattern

```lua
function xpInfo:OnEvent(event, ...)
    local handler = self[event]
    if handler then
        handler(self, ...)
    end
end

function xpInfo:PLAYER_XP_UPDATE()
    self:UpdateExperience()
    self:RefreshUI()
end

function xpInfo:PLAYER_LEVEL_UP(newLevel)
    self:TakeSnapshot("levelup")
    self:CalculateEstimatedMaxLevel()
    self:UpdateGraph()
end
```

## Graph Implementation

### LibGraph-2.0 Integration

The level progression graph uses LibGraph-2.0 for rendering:

```lua
-- Graph initialization
local graph = LibGraph:CreateGraphRealtime(
    "xpInfoLevelGraph",     -- Unique name
    parent,                 -- Parent frame
    "BOTTOMLEFT",          -- Anchor point
    "BOTTOMLEFT",          -- Relative point
    0, 0,                  -- X, Y offsets
    400, 200               -- Width, height
)

-- Configure graph appearance
graph:SetXAxis(0, maxTimeRange)         -- Time axis
graph:SetYAxis(1, maxLevel)             -- Level axis
graph:SetGridSpacing(nil, 5)            -- Grid every 5 levels
graph:SetGridColor({0.3, 0.3, 0.3, 1}) -- Gray grid lines
graph:SetAxisDrawing(true, true)        -- Show both axes
graph:SetAxisColor({1, 1, 1, 1})       -- White axes
graph:SetAutoScale(true, false)         -- Auto-scale time, fixed levels
```

### Data Plotting

```lua
-- Plot historical data
for timestamp, snapshot in pairs(levelSnapshots) do
    local relativeTime = timestamp - startTime
    graph:AddTimeDataPoint(relativeTime, snapshot.level)
end

-- Plot estimated progression
if estimatedMaxLevel then
    local currentTime = GetTime() - startTime
    local estimatedTime = currentTime + estimatedMaxLevel
    graph:AddTimeDataPoint(estimatedTime, maxLevel, {1, 0, 0, 1}) -- Red
end
```

### Axis Labels

Custom axis labeling for better readability:

```lua
-- Y-axis level label
local yLabel = graph:CreateFontString(nil, "OVERLAY", "GameFontNormal")
yLabel:SetText("Level")
yLabel:SetPoint("LEFT", graph, "LEFT", 25, graph:GetHeight()/2)

-- X-axis time labels
local function updateTimeLabels()
    -- Clear existing labels
    for _, label in pairs(timeLabels) do
        label:Hide()
    end
    
    -- Create new labels based on time range
    local timeRange = graph:GetXRange()
    local labelCount = math.min(10, math.floor(timeRange / 3600)) -- Max 10 labels
    
    for i = 1, labelCount do
        local time = (timeRange * i) / labelCount
        local hours = math.floor(time / 3600)
        local label = timeLabels[i] or graph:CreateFontString(nil, "OVERLAY")
        label:SetText(hours .. "h")
        label:SetPoint("TOP", graph, "BOTTOMLEFT", 
                      (graph:GetWidth() * i) / labelCount, -5)
        label:Show()
        timeLabels[i] = label
    end
end
```

## Configuration System

### Options Panel Integration

Uses Blizzard's Interface Options framework:

```lua
local panel = CreateFrame("Frame")
panel.name = "xpInfo"
panel.okay = function() xpInfo:SaveOptions() end
panel.cancel = function() xpInfo:RestoreOptions() end
panel.default = function() xpInfo:ResetToDefaults() end

InterfaceOptions_AddCategory(panel)
```

### Option Controls

#### Range Slider for Max Level
```lua
local maxLevelSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
maxLevelSlider:SetMinMaxValues(10, 80)
maxLevelSlider:SetValue(profile.maxLevel)
maxLevelSlider:SetValueStep(1)

maxLevelSlider:SetScript("OnValueChanged", function(self, value)
    profile.maxLevel = value
    xpInfo:RefreshGraph()
end)
```

#### Sample Size Configuration
```lua
local sampleSlider = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate") 
sampleSlider:SetMinMaxValues(2, 20)
sampleSlider:SetValue(profile.xpSampleSize)
sampleSlider:SetValueStep(1)

sampleSlider:SetScript("OnValueChanged", function(self, value)
    profile.xpSampleSize = value
    xpInfo:UpdateExperience()
end)
```

## Localization

### Locale System

Centralized localization in `locale.lua`:

```lua
local L = {}
xpInfo.L = L

-- English (default)
L["Level"] = "Level"
L["Experience"] = "Experience" 
L["Time to Level"] = "Time to Level"
L["Estimated Max Level"] = "Estimated Max Level"
L["Actions to Level"] = "Actions to Level"

-- Localization loading
local locale = GetLocale()
if locale == "deDE" then
    L["Level"] = "Stufe"
    L["Experience"] = "Erfahrung"
    -- ... German translations
elseif locale == "frFR" then
    -- ... French translations
end
```

### Usage Pattern
```lua
-- Access localized strings
local levelText = xpInfo.L["Level"]
local xpText = xpInfo.L["Experience"]

-- Use in UI elements
levelLabel:SetText(xpInfo.L["Level"] .. ": " .. currentLevel)
```

## Troubleshooting

### Common Issues

#### 1. Graph Not Displaying
**Symptoms**: Level graph window opens but shows no data
**Causes**: 
- Insufficient level snapshots (< 2 data points)
- LibGraph-2.0 not loaded properly
- Invalid data in levelSnapshots table

**Solutions**:
```lua
-- Check data availability
if #levelSnapshots < 2 then
    print("Need at least 2 level snapshots for graph")
end

-- Verify LibGraph loading
if not LibGraph then
    print("LibGraph-2.0 not found - check Libs folder")
end

-- Reset corrupted data
/xpi reset snapshots
```

#### 2. Estimated Max Level Shows Nil
**Symptoms**: Time-to-max-level shows "Unknown" or nil
**Causes**:
- Insufficient progression data
- Character at or above max level
- Calculation errors in linear regression

**Solutions**:
```lua
-- Check current vs max level
if currentLevel >= maxLevel then
    -- Estimation not applicable
    return 0
end

-- Verify progression data
local validSnapshots = 0
for _, snapshot in pairs(levelSnapshots) do
    if snapshot.level and snapshot.playedTime then
        validSnapshots = validSnapshots + 1
    end
end

if validSnapshots < 2 then
    -- Need more data points
    self:TakeSnapshot("manual")
end
```

#### 3. XP Bar Not Updating
**Symptoms**: XP bar doesn't reflect current XP values
**Causes**:
- Event handler not firing
- Incorrect XP calculations
- UI refresh timing issues

**Solutions**:
```lua
-- Force XP update
xpInfo:UpdateExperience()

-- Check event registration
if not xpInfo:IsEventRegistered("PLAYER_XP_UPDATE") then
    xpInfo:RegisterEvent("PLAYER_XP_UPDATE")
end

-- Manual UI refresh
xpInfo:RefreshUI()
```

#### 4. Configuration Not Saving
**Symptoms**: Settings reset after reload/logout
**Causes**:
- SavedVariables not registered properly
- Profile data corruption
- Timing issues with VARIABLES_LOADED

**Solutions**:
```lua
-- Verify SavedVariables registration in .toc
## SavedVariables: xpInfoDB

-- Check profile structure
if not xpInfoDB or not xpInfoDB.profiles then
    xpInfoDB = { profiles = {} }
end

-- Force save
xpInfo:SaveProfile()
```

### Debug Commands

Enable debug mode for detailed logging:
```lua
/xpi debug on              -- Enable debug output
/xpi debug off             -- Disable debug output
/xpi debug status          -- Show debug status
/xpi debug snapshots       -- List all snapshots
/xpi debug calculations    -- Show calculation details
```

### Error Logging

The addon includes comprehensive error handling:

```lua
function xpInfo:SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        self:DebugPrint("Error in function call: " .. tostring(result))
        return nil
    end
    return result
end

function xpInfo:DebugPrint(message)
    if self.db.profile.debugMode then
        print("|cff00ff00xpInfo Debug:|r " .. tostring(message))
    end
end
```

## Development

### Setting Up Development Environment

1. **Clone/Extract** the addon to your AddOns folder
2. **Enable Debug Mode** via `/xpi debug on`
3. **Use Dev Commands** for testing:
   ```lua
   /xpi test calculations     -- Test XP calculations
   /xpi test graph           -- Test graph rendering
   /xpi generate snapshots   -- Generate test data
   /xpi reset all           -- Reset all data
   ```

### Code Style Guidelines

- **Indentation**: 4 spaces, no tabs
- **Naming**: camelCase for functions, PascalCase for classes
- **Comments**: Document complex algorithms and API functions
- **Error Handling**: Use pcall for potentially failing operations
- **Localization**: All user-facing strings must be localized

### Testing Procedures

#### Unit Testing
```lua
-- Test XP calculations
local testXpGains = {100, 150, 120, 200, 175}
local avgXp = xpInfo:CalculateAverageXp(testXpGains, 5)
assert(avgXp > 0, "Average XP calculation failed")

-- Test snapshot creation
local snapshot = xpInfo:CreateSnapshot("test")
assert(snapshot.level == UnitLevel("player"), "Snapshot level mismatch")
```

#### Integration Testing
```lua
-- Test full workflow
xpInfo:TakeSnapshot("test_start")
-- Simulate XP gain
xpInfo:UpdateExperience() 
xpInfo:TakeSnapshot("test_end")
-- Verify calculations
local estimate = xpInfo:CalculateEstimatedMaxLevel()
assert(estimate ~= nil, "Estimation calculation failed")
```

### Performance Considerations

#### Efficient Data Storage
- Limit levelSnapshots to recent data (last 50 levels)
- Use timestamp-based cleanup for old data
- Compress large datasets when needed

#### Update Frequency
- XP updates: On event only (not timer-based)
- Graph refresh: Maximum once per second
- UI updates: Throttled to prevent spam

#### Memory Management
```lua
-- Cleanup old snapshots
function xpInfo:CleanupOldSnapshots()
    local currentTime = time()
    local maxAge = 30 * 24 * 60 * 60  -- 30 days
    
    for timestamp, snapshot in pairs(self.db.profile.levelSnapshots) do
        if currentTime - timestamp > maxAge then
            self.db.profile.levelSnapshots[timestamp] = nil
        end
    end
end
```

### Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

### Version History

- **1.0.0** - Initial release with core functionality

---

This technical documentation covers the complete implementation of xpInfo. For basic usage, see [README.md](README.md).