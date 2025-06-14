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
                name = L["Show Stats Frame"],
                desc = L["Toggle the visibility of the player progression frame."],
                get = function() return db.profile.showFrame end,
                set = function(_, value)
                    db.profile.showFrame = value
                    addonTable.SetAceGUIStatsFrameVisibility(addonInstance, value)
                end,
            },
            showXpBar = {
                type = "toggle",
                order = 22, 
                name = L["Show XP Bar"],
                desc = L["Toggle the visibility of the standalone XP bar."],
                get = function() return db.profile.showXpBar end,
                set = function(_, value)
                    db.profile.showXpBar = value
                    addonTable.SetXpBarFrameVisibility(addonInstance, value)
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
            tooltipAnchor = {
                type = "select",
                order = 35,
                name = L["Tooltip Position"] or "Tooltip Position",
                desc = L["Choose where the tooltip should appear relative to the XP bar"] or "Choose where the tooltip should appear relative to the XP bar",
                values = {
                    ["ANCHOR_BOTTOM"] = L["Below"] or "Below",
                    ["ANCHOR_TOP"] = L["Above"] or "Above", 
                    ["ANCHOR_LEFT"] = L["Left"] or "Left",
                    ["ANCHOR_RIGHT"] = L["Right"] or "Right",
                    ["ANCHOR_CURSOR"] = L["Follow Cursor"] or "Follow Cursor"
                },
                get = function() return db.profile.tooltipAnchor end,
                set = function(_, value)
                    db.profile.tooltipAnchor = value
                    -- No immediate update needed as the setting will be used the next time tooltip shows
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