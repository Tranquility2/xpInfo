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

- **Core Module** (`main.lua`) - Main addon logic, event handling, data management
- **UI Components** - Stats frame, Bar, Graph, configuration interface
- **Data Layer** - Character profiles, experience snapshots, historical tracking
- **Calculation Engine** - XP analysis, time predictions, linear regression
- **Configuration** - Options management, user preferences, profile switching

### Dependencies
xpInfo relies on several major libraries and frameworks to provide its features:

- **AceAddon-3.0**: Core addon framework (modularization, lifecycle, registration)
- **AceEvent-3.0**: Event registration and dispatch
- **AceConsole-3.0**: Slash command and chat command handling
- **AceDB-3.0**: SavedVariables/profile management
- **AceConfig-3.0**: Configuration UI and options panel
- **AceGUI-3.0**: Widget and frame creation for custom UI
- **LibGraph-2.0**: Graph rendering and visualization (level progression graph)
- **LibDataBroker-1.1**: Data broker for minimap icon and launcher integration
- **LibDBIcon-1.0**: Minimap icon display and management
- **CallbackHandler-1.0**: Event/callback utility (used by Ace3 and LibDataBroker)
- **LibStub**: Library versioning and loading utility

All dependencies are included in the `libs/` folder and loaded via `embeds.xml`.

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
    xpBarPosition = { x, y },              -- Bar position
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

### Recent Rate Estimation for Time Prediction

The addon now estimates time-to-max-level using your recent leveling pace:
- Uses the last 5 level snapshots (or all if fewer) to calculate your average hours per level.
- Multiplies this rate by the number of levels remaining to estimate total time required.
- No blending, convergence, or regression is used—estimates reflect your actual recent pace.
- If insufficient data is available (fewer than 2 snapshots), no estimate is shown.

**Debugging & Testing:**
- `DEBUG_ESTIMATION` flag: Enables detailed debug output in the chat window for development and troubleshooting.
- `FAKE_SNAPSHOTS` flag: Populates the addon with realistic fake data for development/testing. This data simulates a typical WoW Classic leveling curve.

#### Pseudocode:

```
function CalculateTimeToMaxLevel(snapshots, maxLevel):
    if not enough snapshots:
        return nil
    recent = last 5 snapshots (or all if fewer)
    start = first of recent
    end = last of recent
    recentTime = (end.time - start.time) in hours
    recentLevels = end.level - start.level
    if recentTime <= 0 or recentLevels <= 0:
        return nil
    hoursPerLevel = recentTime / recentLevels
    levelsLeft = maxLevel - end.level
    timeRemaining = levelsLeft * hoursPerLevel
    totalEstimate = (end.time in hours) + timeRemaining
    return totalEstimate  // total hours played at max level
```

Note: To get the time remaining from now, subtract your current played time (in hours) from the result.

---

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

#### `addon:OnInitialize()`
Initializes the addon, sets up saved variables, registers events, and wires up UI modules.

#### `addon:UpdateXP()`
Updates XP-related calculations and UI elements. Called on XP changes.

#### `addon:LevelUp()`
Handles logic for when the player levels up, including snapshotting and updating estimates.

#### `addon:CalculateEstimatedMaxLevel()`
Calculates time-to-max-level estimate using recent rate estimation.

#### `addon:GetEstimatedMaxLevelText()`
Returns a formatted string with the current time-to-max-level estimate.

### UI and Data Management

- **Stats Frame, XP Bar, and Graph**: These are implemented in their respective modules (`src/stats.lua`, `src/bar.lua`, `src/graph.lua`).
- **Snapshots**: Managed by the snapshots module and called from main as needed.
- **Configuration and CLI**: Handled by `src/options.lua` and `src/cli.lua`.

> **Note:** Functions like `TakeSnapshot`, `SetMaxLevel`, `SetXpSampleSize`, `ToggleBar`, `ToggleGraph`, and `RefreshGraph` are not present in `main.lua` and are managed by their respective modules.

## Event System

### Registered Events

```lua
-- Core XP Events
"PLAYER_XP_UPDATE"          -- XP gained
"PLAYER_LEVEL_UP"           -- Level increased

-- Session Events  
"PLAYER_LOGIN"              -- Character logged in
"PLAYER_LOGOUT"             -- Character logging out
"TIME_PLAYED_MSG"           -- Played time received
"PLAYER_ENTERING_WORLD"     -- Entering world
```

### Event Handler Pattern

The addon uses AceEvent-3.0 to register event handlers. Each event is mapped to a method on the addon object:

```lua
self:RegisterEvent("PLAYER_XP_UPDATE", "UpdateXP")
self:RegisterEvent("PLAYER_LEVEL_UP", "LevelUp")
self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
self:RegisterEvent("TIME_PLAYED_MSG", "OnTimePlayedMessage")
```

- `UpdateXP` handles XP changes and updates UI.
- `LevelUp` handles level up logic and updates estimates.
- `OnPlayerEnteringWorld` and `OnTimePlayedMessage` handle session and played time events.

## Graph Implementation

The level progression graph is implemented in `src/graph.lua` using LibGraph-2.0. The main graph creation function is:

```lua
local graph = LibGraph:CreateGraphLine("XpInfoLevelProgressGraph", parentFrame, "CENTER", "CENTER", 0, 0, 400, 250)
```

- The graph is updated and shown/hidden using functions in `src/graph.lua` (e.g., `UpdateLevelGraph`, `ShowLevelGraph`, `HideLevelGraph`).
- The main addon module wires these functions to the addon instance for use in other modules.

> Note: There is no function named `RefreshUI`, `UpdateExperience`, or direct event handler like `OnEvent` in the codebase. All event handling is done via AceEvent-3.0's registration system.

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
panel.okay = function() main:SaveOptions() end
panel.cancel = function() main:RestoreOptions() end
panel.default = function() main:ResetToDefaults() end

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
    main:RefreshGraph()
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
    main:UpdateExperience()
end)
```

## Localization

### Locale System

Centralized localization in `Locales/enUS.lua`:

```lua
local L = {}
main.L = L

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
local levelText = main.L["Level"]
local xpText = main.L["Experience"]

-- Use in UI elements
levelLabel:SetText(main.L["Level"] .. ": " .. currentLevel)
```

## Troubleshooting

### Common Issues
TBD

### Error Logging
TBD

## Development

### Setting Up Development Environment

1. **Clone/Extract** the addon to your AddOns folder
2. **Enable Debug Mode** via `/xpi debug on` (not implemented yet)
3. **Use Dev Commands** for testing: (not implemented yet)
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
TBD

#### Integration Testing
TBD

### Performance Considerations

#### Efficient Data Storage
- Limit levelSnapshots to recent data (last 50 levels)
- Use timestamp-based cleanup for old data (manual or via future updates)
- Compress large datasets when needed

#### Update Frequency
- XP updates: On event only (not timer-based)
- Graph refresh: Maximum once per second
- UI updates: Throttled to prevent spam

#### Memory Management
> Note: There is currently no CleanupOldSnapshots or automated snapshot cleanup function in the codebase. Old data should be managed manually or with future updates.

### Contributing

Contributions are welcome! Please open an issue or submit a pull request on GitHub.

### Version History

- **1.1.2** - Recent rate estimation replaces regression/convergence; debug and fake data flags documented; documentation and UI updated for clarity
- **1.0.0** - Initial release with core functionality

---

This technical documentation covers the complete implementation of xpInfo. For basic usage, see [README.md](README.md).