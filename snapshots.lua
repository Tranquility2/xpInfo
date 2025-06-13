local addonName, addonTable = ...

local AceGUI = LibStub("AceGUI-3.0")
local snapshotsFrame -- Local to this file, will be managed by the functions here

-- Function to update the snapshots viewer with current data
local function updateSnapshotsViewer(addonInstance)
    if not snapshotsFrame or not snapshotsFrame:IsShown() then return end
    
    local L = addonInstance.L
    local snapshots = addonInstance.db.profile.xpSnapshots
    local levelSnapshots = addonInstance.db.profile.levelSnapshots
    local maxSamples = addonInstance.db.profile.maxSamples
    
    -- Get the content container and clear it
    local content = snapshotsFrame.content
    content:ReleaseChildren()
    
    -- XP Snapshots section
    local xpHeading = AceGUI:Create("Heading")
    xpHeading:SetFullWidth(true)
    if not snapshots or #snapshots == 0 then
        xpHeading:SetText(L["No XP snapshots currently recorded."])
    else
        xpHeading:SetText(string.format(L["XP Snapshots (%d of %d max)"], #snapshots, maxSamples))
    end
    content:AddChild(xpHeading)
    
    -- Add XP snapshots data
    if snapshots and #snapshots > 0 then
        local scrollContainer = AceGUI:Create("SimpleGroup")
        scrollContainer:SetFullWidth(true)
        scrollContainer:SetHeight(150)
        scrollContainer:SetLayout("Fill")
        content:AddChild(scrollContainer)
        
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("List")
        scrollContainer:AddChild(scroll)
        
        for i, snap in ipairs(snapshots) do
            local label = AceGUI:Create("Label")
            label:SetText(string.format("  %d: " .. L["XP"] .. " %d, " .. L["Time"] .. " %.2f", i, snap.xp or 0, snap.time or 0))
            label:SetFullWidth(true)
            scroll:AddChild(label)
        end
    end
    
    -- Spacer
    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    content:AddChild(spacer)
    
    -- Level Snapshots section
    local levelHeading = AceGUI:Create("Heading")
    levelHeading:SetFullWidth(true)
    if not levelSnapshots or #levelSnapshots == 0 then
        levelHeading:SetText(L["No level snapshots recorded."])
    else
        levelHeading:SetText(L["XP Snapshots for Levels"] .. " (" .. #levelSnapshots .. " " .. L["recorded"] .. "):")
    end
    content:AddChild(levelHeading)
    
    -- Add level snapshots data
    if levelSnapshots and #levelSnapshots > 0 then
        local scrollContainer = AceGUI:Create("SimpleGroup")
        scrollContainer:SetFullWidth(true)
        scrollContainer:SetHeight(150)
        scrollContainer:SetLayout("Fill")
        content:AddChild(scrollContainer)
        
        local scroll = AceGUI:Create("ScrollFrame")
        scroll:SetLayout("List")
        scrollContainer:AddChild(scroll)
        
        for i, snap in ipairs(levelSnapshots) do
            local timeString = snap.time
            if addonInstance.FormatTime then
                timeString = addonInstance:FormatTime(snap.time)
            end
            
            local label = AceGUI:Create("Label")
            label:SetText(string.format("  %d: " .. L["Level"] .. " %d, " .. L["Time Played"] .. " %s", i, snap.level or 0, timeString or "0:00:00"))
            label:SetFullWidth(true)
            scroll:AddChild(label)
        end
    end
    
    -- Button container
    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetFullWidth(true)
    buttonGroup:SetLayout("Flow")
    content:AddChild(buttonGroup)
    
    -- Clear XP button
    local clearButton = AceGUI:Create("Button")
    clearButton:SetText(L["Clear"])
    clearButton:SetWidth(120)
    clearButton:SetCallback("OnClick", function()
        if addonInstance.db.profile then
            addonInstance.db.profile.xpSnapshots = {}
            print(addonName .. ": " .. L["All XP snapshots cleared."])
            updateSnapshotsViewer(addonInstance)
        end
    end)
    buttonGroup:AddChild(clearButton)
    
    -- Close button
    local closeButton = AceGUI:Create("Button")
    closeButton:SetText(L["Close"])
    closeButton:SetWidth(120)
    closeButton:SetCallback("OnClick", function() 
        snapshotsFrame:Hide()
    end)
    buttonGroup:AddChild(closeButton)
end

-- Function to build the snapshots viewer
local function snapshotsViewerBuilder(addonInstance)
    -- Don't create a new one if it already exists
    if snapshotsFrame and snapshotsFrame:IsShown() then
        updateSnapshotsViewer(addonInstance)
        return
    end
    
    local L = addonInstance.L
    
    -- Create main frame
    snapshotsFrame = AceGUI:Create("Window")
    snapshotsFrame:SetTitle(L["Snapshots Viewer"])
    snapshotsFrame:SetLayout("Fill")
    snapshotsFrame:SetWidth(500)
    snapshotsFrame:SetHeight(400)
    snapshotsFrame:EnableResize(false)
    
    -- Create scrolling content area
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetLayout("Fill")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    snapshotsFrame:AddChild(scrollContainer)
    
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollContainer:AddChild(scroll)
    
    -- Save the content pane for later updates
    snapshotsFrame.content = scroll
    
    -- Initial update
    updateSnapshotsViewer(addonInstance)
end

-- Initialize the snapshots module
function addonTable.InitializeAceGUISnapshots(addonInstance)
    -- Attach functions to the addon instance
    addonInstance.updateAceGUISnapshotsViewer = function() updateSnapshotsViewer(addonInstance) end
    addonInstance.snapshotsAceGUIViewerBuilder = function() snapshotsViewerBuilder(addonInstance) end
    
    -- Export to addonTable if needed
    addonTable.UpdateAceGUISnapshotsViewer = updateSnapshotsViewer
    addonTable.SnapshotsAceGUIViewerBuilder = snapshotsViewerBuilder
end
