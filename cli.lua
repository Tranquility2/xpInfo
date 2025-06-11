local cliAddonName, addonTable = ...

-- This function will be called from xpInfo.lua's OnInitialize
function addonTable.InitializeChatCommands(addonInstance)
    local L = addonInstance.L
    local frame = addonInstance.frame -- This is the main UI frame, set by addonInstance:CreateFrame()
    local db = addonInstance.db
    local defaults = addonInstance.defaults -- This will be set on addonInstance in OnInitialize
    local addonNameForPrint = cliAddonName -- Use the addonName from this file's scope for prints

    local function ChatCommandHandler(input)
        local inputLower = string.lower(input or "") -- Normalize input, handle nil input
        
        if inputLower == "show" then
            if frame then frame:Show() end
            if db and db.profile then
                db.profile.showFrame = true
            end
        elseif inputLower == "hide" then
            if frame then frame:Hide() end
            if db and db.profile then
                db.profile.showFrame = false
            end
        elseif inputLower == "reset" then
            if db and db.profile and defaults and defaults.profile then
                db.profile.framePosition = defaults.profile.framePosition
                if frame then
                    frame:ClearAllPoints()
                    frame:SetPoint(unpack(db.profile.framePosition))
                end
                print(addonNameForPrint .. ": " .. L["Frame position reset."])
            else
                -- Potentially print an error if essential components are missing
                print(addonNameForPrint .. ": Error resetting frame - db, defaults, or profile not fully available.")
            end
        elseif inputLower == "config" then
            LibStub("AceConfigDialog-3.0"):Open(addonNameForPrint)
        else
            print(addonNameForPrint .. ": " .. L["Usage: /xpi [show|hide|reset|config]"])
        end
    end

    addonInstance:RegisterChatCommand("xpi", ChatCommandHandler)
end
