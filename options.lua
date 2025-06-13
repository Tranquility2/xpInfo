local optionsAddonName, addonTable = ...

-- This function will be called from xpInfo.lua's OnInitialize
function addonTable.InitializeOptions(addonInstance)
    local L = addonInstance.L
    local frame = addonInstance.frame -- This is the main UI frame, set by addonInstance:CreateFrame()
    local db = addonInstance.db

    local options = {
        type = "group",
        name = addonInstance.name, -- Use the main addon name
        width = "normal",
        args = {
            header = {
                type = "header",
                order = 10,
                name = L["Settings"],
            },
            showFrame = {
                type = "toggle",
                order = 20, 
                name = L["Show Frame"],
                desc = L["Toggle the visibility of the player progression frame."],
                get = function() return db.profile.showFrame end,
                set = function(_, value)
                    db.profile.showFrame = value
                    addonTable.SetAceGUIStatsFrameVisibility(addonInstance, value)
                end,
            },
            showMinimapIcon = {
                type = "toggle",
                order = 25, -- Place it after Show Frame
                name = L["Show Minimap Icon"],
                desc = L["Toggle the visibility of the minimap icon."],
                get = function() return db.profile.showMinimapIcon end,
                set = function(_, value)
                    db.profile.showMinimapIcon = value
                    -- Directly call the function on addonInstance to update minimap icon visibility
                    addonInstance:UpdateMinimapIconVisibility(addonInstance)
                end,
            },
            maxSamples = {
                type = "range",
                order = 30, 
                name = L["Max XP Snapshots"],
                desc = L["Set the maximum number of recent XP snapshots to store for rate calculation."],
                min = 2, -- Need at least 2 for a rate
                max = 20,
                step = 1,
                get = function(info)
                    return db.profile.maxSamples
                end,
                set = function(info, value)
                    db.profile.maxSamples = value
                    -- Prune snapshots if new maxSamples is less than current number of snapshots
                    if db.profile.xpSnapshots then
                        while #db.profile.xpSnapshots > db.profile.maxSamples do
                            table.remove(db.profile.xpSnapshots, 1)
                        end
                    end
                    if addonInstance.UpdateXP then addonInstance:UpdateXP() end
                end,
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db)
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonInstance.name, options)
end

function addonTable.OpenOptions()
    LibStub("AceConfigDialog-3.0"):Open(optionsAddonName)
end