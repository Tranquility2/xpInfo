-- Create a mini map icon
local myMiniMapIcon = CreateFrame("Button", "MyMiniMapIcon", Minimap)
myMiniMapIcon:SetSize(16, 16)
myMiniMapIcon:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -5, -5)
myMiniMapIcon:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
myMiniMapIcon:SetScript("OnClick", function()
    if myFrame:IsShown() then
        myFrame:Hide()
    else
        myFrame:Show()
    end
end)