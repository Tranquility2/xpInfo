-- Options to configure the behavior of the script
function initOptions(addonRef)
    local name = addonRef.name -- Use local for clarity and scope
    local L = addonRef.L
    local frame = addonRef.frame

    local options = {
        type = "group",
        name = name,
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
                get = function() return addonRef.db.profile.showFrame end,
                set = function(_, value)
                    addonRef.db.profile.showFrame = value
                    if value then
                        frame:Show()
                    else
                        frame:Hide()
                    end
                end,
            },
            maxSamples = {
                type = "range",
                order = 30, 
                name = L["Max XP Snapshots"], -- CHANGED text
                desc = L["Set the maximum number of recent XP snapshots to store for rate calculation."], -- CHANGED text
                min = 2, -- Need at least 2 for a rate
                max = 20,
                step = 1,
                get = function(info)
                    return addonRef.db.profile.maxSamples
                end,
                set = function(info, value)
                    addonRef.db.profile.maxSamples = value
                    -- Debug print to confirm change
                    -- print(addonName .. ": Max XP Snapshots changed to " .. addonRef.db.profile.maxSamples)
                    
                    -- Prune snapshots if new maxSamples is less than current number of snapshots
                    if addonRef.db.profile.xpSnapshots then
                        while #addonRef.db.profile.xpSnapshots > addonRef.db.profile.maxSamples do
                            table.remove(addonRef.db.profile.xpSnapshots, 1)
                        end
                    end
                    addonRef:UpdateXP() 
                end,
            },
            ResetDataBase = {
                type = "execute",
                order = 40,
                name = L["Reset Data"],
                desc = L["Reset the database and clear all stored data."],
                func = function()
                    addonRef.db:ResetProfile()
                    addonRef:Print(L["Database reset."])
                    addonRef:UpdateXP() -- Refresh XP display
                end,
            },
        },
    }

    return options
end