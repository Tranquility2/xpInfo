local TestButton = CreateFrame("Button", "Reload", UIParent, "UIPanelButtonTemplate")
TestButton:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
TestButton:SetSize(120, 30)
TestButton:SetText("Reload")
TestButton:SetScript("OnClick", function()
    ReloadUI()
    print("UI reloaded. Check the new tab in the character frame.")
end)

-- Function to get and format position information
local function GetFormattedPositionInfo(frame)
    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    return string.format("Position\n\nPoint: %s\nRelativePoint: %s\nX: %.2f\nY: %.2f", point, relativePoint, xOfs, yOfs)
end
