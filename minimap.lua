local addonName, addonTable = ...

local icon = LibStub("LibDBIcon-1.0") 
 
function addonTable.InitializeMinimapIcon(addonInstance)
    print("Initializing minimap icon for " .. addonName)
    addonInstance.minimapIcon = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
        type = "data source",
        text = addonName,
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        OnClick = function(_, button)
            if button == "LeftButton" then
                addonInstance:ToggleUI()
            elseif button == "RightButton" then
                addonTable:OpenOptions(addonInstance)
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine(addonName)
            tooltip:AddLine("Left Click to toggle UI")
            tooltip:AddLine("Right Click for options")
        end,
    })
    
    icon:Register(addonName, addonInstance.minimapIcon, addonInstance.db.profile.minimap)
end