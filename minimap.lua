local addonName, addonTable = ...
local L = addonTable.L

local LibDBIcon = LibStub("LibDBIcon-1.0")

function addonTable:InitializeMinimapIcon(addonInstance)
    local db

    local function GetDb()
        if not db then
            db = addonInstance.db.profile
        end
        return db
    end

    local ldbIcon = LibDBIcon:New(addonName .. "MinimapIcon", {
        icon = "Interface\Icons\INV_Misc_Spyglass_01", -- Default icon, can be changed
        tooltip = L["xpInfo - Click to toggle frame, Alt-Click to open settings."],
        onClick = function(self, button)
            if button == "LeftButton" then
                if IsAltKeyDown() then
                    -- Open options
                    LibStub("AceConfigDialog-3.0"):Open(addonName)
                else
                    -- Toggle main frame
                    addonInstance:ToggleFrame()
                end
            elseif button == "RightButton" then
                 -- Toggle main frame (or provide another function, e.g. toggle snapshots)
                 addonInstance:ToggleFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(addonName)
            tooltip:AddLine(L["xpInfo - Click to toggle frame, Alt-Click to open settings."])
            if GetDb().showFrame then
                tooltip:AddLine(L["Frame is currently visible."])
            else
                tooltip:AddLine(L["Frame is currently hidden."])
            end
        end,
        OnEnter = function(self)
            -- Optional: Could show a more detailed tooltip on hover using GameTooltip
        end,
        OnLeave = function(self)
            -- Optional: Hide GameTooltip if shown
        end
    })

    addonInstance.minimapIcon = ldbIcon -- Store it if needed for direct access

    function addonTable:UpdateMinimapIconVisibility()
        if GetDb().showMinimapIcon then
            ldbIcon:Show()
        else
            ldbIcon:Hide()
        end
    end

    -- Initial update
    addonTable:UpdateMinimapIconVisibility()

    -- Register for profile updates to show/hide icon
    addonInstance:RegisterMessage("XPINFO_PROFILE_UPDATED", function()
        GetDb() -- Ensure db is initialized
        addonTable:UpdateMinimapIconVisibility()
    end)
end

-- Fallback for older AceDB versions or direct calls if needed
function addonTable:ShowMinimapIcon()
    if addonInstance and addonInstance.minimapIcon then
        addonInstance.minimapIcon:Show()
    end
end

function addonTable:HideMinimapIcon()
    if addonInstance and addonInstance.minimapIcon then
        addonInstance.minimapIcon:Hide()
    end
end