local addonName, _ = ...

local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)
if not L then return end

-- Localization strings for the addon
L["Progression"] = "Progression"
L["Current XP"] = "Current XP"
L["Rested XP"] = "Rested XP"
L["XP Progress"] = "XP Progress"
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
L["Clear Snapshots"] = "Clear Snapshots"
L["Clear all stored XP snapshots."] = "Clear all stored XP snapshots."
L["All XP snapshots cleared."] = "All XP snapshots cleared."
L["View Snapshots"] = "View Snapshots"
L["Open the XP snapshots viewer."] = "Open the XP snapshots viewer."
L["Clear"] = "Clear"
L["Actions to Level"] = "Actions to Level"
L["Actions to Level: %d (avg %s XP)"] = "Actions to Level: %d (avg %s XP)"
L["Level Progress"] = "Level Progress"
L["Summary"] = "Summary"
L["Average XP"] = "Average XP"

-- XP Bar Strings
L["Show XP Bar"] = "Show XP Bar"
L["Toggle the visibility of the standalone XP bar."] = "Toggle the visibility of the standalone XP bar."
L["XP Bar position reset."] = "XP Bar position reset."
L["Usage: /xpi [show|hide|toggle|reset|config] [xpbar]"] = "Usage: /xpi [show|hide|toggle|reset|config] [xpbar]"
L["Show Stats Frame"] = "Show Stats Frame"
L["remaining"] = "remaining"

-- Strings for Snapshot Viewer
L["Snapshots Viewer"] = "Snapshots Viewer"
L["Close"] = "Close"

-- Tooltip Position Settings
L["Tooltip Position"] = "Tooltip Position"
L["Choose where the tooltip should appear relative to the XP bar"] = "Choose where the tooltip should appear relative to the XP bar"
L["Below"] = "Below"
L["Above"] = "Above"
L["Left"] = "Left"
L["Right"] = "Right"
L["Follow Cursor"] = "Follow Cursor"
L["No XP snapshots currently recorded."] = "No XP snapshots currently recorded. Gain some XP to see data here."
L["XP Snapshots (%d of %d max)"] = "XP Snapshots (%d of %d max shown):"
L["XP"] = "XP"
L["Time"] = "Time"
L["No level snapshots recorded."] = "No level snapshots recorded. Gain some levels to see data here."
L["XP Snapshots for Levels"] = "XP Snapshots for Levels"
L["recorded"] = "recorded"
L["Level"] = "Level"
L["Time Played"] = "Time Played"

-- Strings for options
L["Reset Data"] = "Reset Data"
L["Reset the database and clear all stored data."] = "Reset the database and clear all stored data."
L["Database reset."] = "Database reset."

-- Minimap Icon
L["Minimap Icon"] = "Minimap Icon"
L["Show Minimap Icon"] = "Show Minimap Icon"
L["Toggle the visibility of the minimap icon."] = "Toggle the visibility of the minimap icon."
L["xpInfo - Click to toggle frame, Alt-Click to open settings."] = "xpInfo - Click to toggle frame, Alt-Click to open settings."
L["Frame is currently visible."] = "Frame is currently visible."
L["Frame is currently hidden."] = "Frame is currently hidden."

-- Progress bar
L["remaining"] = "remaining"
L["After Rested"] = "After Rested"
