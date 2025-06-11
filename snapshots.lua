local snapshotsAddonName, addonTable = ...

local snapshotsFrame -- Local to this file, will be managed by the functions here

local function snapshotsReport(addonInstance)
    local snapshots = addonInstance.db.profile.xpSnapshots
    local maxSamples = addonInstance.db.profile.maxSamples
    local levelSnapshots = addonInstance.db.profile.levelSnapshots
    local L = addonInstance.L

    local lines = {}
    local title = ""
    
    if not snapshots or #snapshots == 0 then
        lines = { L["No XP snapshots currently recorded."] }
    else
        title = string.format(L["XP Snapshots (%d of %d max)"], #snapshots, maxSamples)
        lines = { title }
        
        for i, snap in ipairs(snapshots) do
            table.insert(lines, string.format("  %d: " .. L["XP"] .. " %d, " .. L["Time"] .. " %s", i, snap.xp, snap.time))
        end
    end

    lines[#lines + 1] = "" -- Add a blank line before level snapshots

    if not levelSnapshots or #levelSnapshots == 0 then
        lines[#lines + 1] = L["No level snapshots recorded."]
    else
        title = L["XP Snapshots for Levels"]
        lines[#lines + 1] = title .. " (" .. #levelSnapshots .. " " .. L["recorded"] .. "):" -- Added L["recorded"]
        for i, snap in ipairs(levelSnapshots) do
            -- Assuming snap.time is totalTimePlayed from LevelUp, format it if addonInstance.FormatTime exists
            local timeString = snap.time
            if addonInstance.FormatTime then
                timeString = addonInstance:FormatTime(snap.time)
            end
            table.insert(lines, string.format("  %d: " .. L["Level"] .. " %d, " .. L["Time Played"] .. " %s", i, snap.level, timeString))
        end
    end

    return table.concat(lines, "\n")
end

local function updateSnapshotsViewer(addonInstance)
    if snapshotsFrame and snapshotsFrame.text then
        local reportText = snapshotsReport(addonInstance)
        snapshotsFrame.text:SetText(reportText)
    end
end

local function ensureDebugFrameCreated(addonInstance)
    if not snapshotsFrame then
        local L = addonInstance.L
        local currentAddonName = addonInstance.name -- Use the main addon's name for UI elements

        snapshotsFrame = CreateFrame("Frame", currentAddonName .. "DebugFrame", UIParent, "BasicFrameTemplateWithInset") -- Retaining DebugFrame in name for now to avoid breaking existing saved var if any, can be changed later
        snapshotsFrame:SetWidth(350)
        snapshotsFrame:SetHeight(250)
        snapshotsFrame:SetPoint("CENTER", UIParent, "TOP", 0, -150)
        snapshotsFrame:SetMovable(true)
        snapshotsFrame:EnableMouse(true)
        snapshotsFrame:RegisterForDrag("LeftButton")
        snapshotsFrame:SetScript("OnDragStart", snapshotsFrame.StartMoving)
        snapshotsFrame:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
        end)

        snapshotsFrame.title = snapshotsFrame:CreateFontString(currentAddonName .. "DebugFrameTitle", "ARTWORK", "GameFontNormalLarge")
        snapshotsFrame.title:SetPoint("TOP", 0, -5)
        snapshotsFrame.title:SetText(L["Snapshots Viewer"]) 

        snapshotsFrame.text = snapshotsFrame:CreateFontString(currentAddonName .. "DebugFrameText", "ARTWORK", "GameFontNormal")
        snapshotsFrame.text:SetPoint("TOPLEFT", 15, -30)
        snapshotsFrame.text:SetJustifyH("LEFT")
        snapshotsFrame.text:SetWidth(snapshotsFrame:GetWidth() - 30)

        local closeButton = CreateFrame("Button", currentAddonName .. "DebugCloseButton", snapshotsFrame, "UIPanelButtonTemplate")
        closeButton:SetText(L["Close"]) 
        closeButton:SetWidth(80)
        closeButton:SetHeight(20)
        closeButton:SetPoint("BOTTOMRIGHT", -10, 10)
        closeButton:SetScript("OnClick", function()
            snapshotsFrame:Hide()
        end)

        local clearButton = CreateFrame("Button", currentAddonName .. "DebugClearButton", snapshotsFrame, "UIPanelButtonTemplate")
        clearButton:SetText(L["Clear"]) 
        clearButton:SetWidth(100)
        clearButton:SetHeight(20)
        clearButton:SetPoint("BOTTOMLEFT", 10, 10)
        clearButton:SetScript("OnClick", function()
            addonInstance.db.profile.xpSnapshots = {} 
            print(currentAddonName .. ": " .. L["All XP snapshots cleared."]) 
            if addonInstance.UpdateFrameText then addonInstance:UpdateFrameText() end
            updateSnapshotsViewer(addonInstance) 
        end)
        snapshotsFrame:Hide() 
    end
end

local function snapshotsViewerBuidler(addonInstance)
    ensureDebugFrameCreated(addonInstance) 

    if snapshotsFrame:IsShown() then
        snapshotsFrame:Hide()
    else
        updateSnapshotsViewer(addonInstance) 
        snapshotsFrame:Show()
        snapshotsFrame:Raise() 
    end
end

function addonTable.InitializeSnapshots(addonInstance)
    -- Attach functions to the addon instance so they can be called with self:methodName()
    addonInstance.snapshotsReport = function() return snapshotsReport(addonInstance) end
    addonInstance.updateSnapshotsViewer = function() updateSnapshotsViewer(addonInstance) end
    -- ensureDebugFrameCreated is mostly internal to this module, but snapshotsViewerBuidler needs it.
    -- snapshotsViewerBuidler is the main public method for the UI interaction.
    addonInstance.snapshotsViewerBuidler = function() snapshotsViewerBuidler(addonInstance) end

    -- For direct calls from other modules if needed (e.g. addonTable.UpdateSnapshotsViewer(addonInstance))
    -- However, instance methods are generally preferred.
    addonTable.UpdateSnapshotsViewer = updateSnapshotsViewer 
end
