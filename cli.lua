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
        local args = {}
        for word in inputLower:gmatch("%S+") do
            table.insert(args, word)
        end
        
        -- Main command handling
        if args[1] == "show" then
            if args[2] == "xpbar" then
                -- Show XP bar
                addonInstance:ShowXpBarFrame(addonInstance)
                if db and db.profile then
                    db.profile.showXpBar = true
                end
            else
                -- Show stats frame (default)
                if frame then frame:Show() end
                if db and db.profile then
                    db.profile.showFrame = true
                end
            end
        elseif args[1] == "hide" then
            if args[2] == "xpbar" then
                -- Hide XP bar
                addonInstance:HideXpBarFrame(addonInstance)
                if db and db.profile then
                    db.profile.showXpBar = false
                end
            else
                -- Hide stats frame (default)
                if frame then frame:Hide() end
                if db and db.profile then
                    db.profile.showFrame = false
                end
            end
        elseif args[1] == "toggle" then
            if args[2] == "xpbar" then
                -- Toggle XP bar
                addonInstance:ToggleXpBarFrame(addonInstance)
            else
                -- Toggle stats frame
                addonInstance:ToggleStatsFrame(addonInstance)
            end
        elseif args[1] == "reset" then
            if args[2] == "xpbar" then
                -- Reset XP bar position
                if db and db.profile and defaults and defaults.profile then
                    db.profile.xpBarPosition = defaults.profile.xpBarPosition
                    print(addonNameForPrint .. ": " .. L["XP Bar position reset."])
                end
            else
                -- Reset stats frame position
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
            end
        elseif args[1] == "config" then
            LibStub("AceConfigDialog-3.0"):Open(addonNameForPrint)
        else
            print(addonNameForPrint .. ": " .. L["Usage: /xpi [show|hide|toggle|reset|config] [xpbar]"])
            print(addonNameForPrint .. ": Examples:")
            print("  /xpi show - Show the stats frame")
            print("  /xpi hide - Hide the stats frame")
            print("  /xpi show xpbar - Show the XP bar")
            print("  /xpi hide xpbar - Hide the XP bar")
            print("  /xpi toggle xpbar - Toggle the XP bar visibility")
            print("  /xpi reset - Reset the stats frame position")
            print("  /xpi reset xpbar - Reset the XP bar position")
            print("  /xpi config - Open the configuration panel")
        end
    end

    addonInstance:RegisterChatCommand("xpi", ChatCommandHandler)
end
