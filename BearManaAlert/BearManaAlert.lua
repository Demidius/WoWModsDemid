local addonName = ...
local initializer = CreateFrame("Frame")
initializer:RegisterEvent("ADDON_LOADED")
initializer:SetScript("OnEvent", function(self, _, name)
    if name ~= addonName then return end
    BearManaAlertDB = type(BearManaAlertDB) == "table" and BearManaAlertDB or {}
    self:UnregisterEvent("ADDON_LOADED")
end)

local function openSettings()
    BearManaAlertOpenBarSettings()
end
local shortcutEvents = CreateFrame("Frame")
shortcutEvents:RegisterEvent("PLAYER_LOGIN")
shortcutEvents:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    BearManaAlertDB.minimap = type(BearManaAlertDB.minimap) == "table" and BearManaAlertDB.minimap or {}
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local icons = LibStub and LibStub("LibDBIcon-1.0", true)
    if broker and icons then
        local data = broker:NewDataObject("BearManaAlert", {
            type = "launcher",
            icon = "Interface\\Icons\\Ability_Racial_BearForm",
            OnClick = openSettings,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("MyMana")
                tooltip:AddLine("Нажмите, чтобы открыть настройки", 1, 1, 1)
            end,
        })
        if data then icons:Register("BearManaAlert", data, BearManaAlertDB.minimap) end
        return
    end
    -- A simple minimap button remains available if broker libraries are absent.
    local button = CreateFrame("Button", "BearManaAlertMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, -2)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("CENTER", 0, 0)
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\Icons\\Ability_Racial_BearForm")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetScript("OnClick", openSettings)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("MyMana")
        GameTooltip:AddLine("Нажмите, чтобы открыть настройки", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end)
SLASH_BEARMANA1 = "/bearmana"
SlashCmdList.BEARMANA = openSettings