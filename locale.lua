local addonName, _ = ...

local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)
if not L then return end

L["Player Progression"] = "Player Progression"
L["Current XP"] = "Current XP"
L["Rested XP"] = "Rested XP"
L["Time Played (Total)"] = "Time Played (Total)"
L["Time Played (Level)"] = "Time Played (Level)"
L["Time to Level"] = "Time to Level"
L["N/A"] = "N/A"
L["Calculating..."] = "Calculating..."
L["Usage: /xpi [show|hide|reset|config]"] = "Usage: /xpi [show|hide|reset|config]"
L["Congratulations on leveling up!"] = "Congratulations on leveling up!"
L["Refresh"] = "Refresh"
L["Settings"] = "Settings"
L["Max XP Snapshots"] = "Max XP Snapshots"
L["Set the maximum number of recent XP snapshots to store for rate calculation."] = "Set the maximum number of recent XP snapshots to store for rate calculation."
L["Show Frame"] = "Show Frame"
L["Toggle the visibility of the player progression frame."] = "Toggle the visibility of the player progression frame."
L["Frame Position"] = "Frame Position"
L["Profile"] = "Profile"
L["Profile Settings"] = "Profile Settings"
L["Configure profile-specific settings."] = "Configure profile-specific settings."
L["Frame position reset."] = "Frame position reset."
