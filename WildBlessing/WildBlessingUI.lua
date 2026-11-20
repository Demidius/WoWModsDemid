local addonName = ...
local settings, refreshSettings

local function label(parent, text, x, y, font)
    local value = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    value:SetPoint("TOPLEFT", x, y)
    value:SetJustifyH("LEFT")
    value:SetText(text)
    return value
end

function WildBlessingToggleSettings()
    if settings then
        if settings:IsShown() then settings:Hide() else settings:Show() end
        return
    end

    settings = CreateFrame("Frame", "WildBlessingSettings", UIParent, "BasicFrameTemplateWithInset")
    settings:SetSize(510, 535)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")
    settings:SetClampedToScreen(true)
    settings:SetMovable(true)
    settings:EnableMouse(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings.TitleText:SetText("My Blessing — настройки")
    table.insert(UISpecialFrames, "WildBlessingSettings")

    local macro = CreateFrame("Button", nil, settings)
    macro:SetSize(42, 42)
    macro:SetPoint("TOPLEFT", 30, -42)
    macro:RegisterForDrag("LeftButton")
    macro:SetNormalTexture("Interface\\Icons\\Spell_Nature_Regeneration")
    macro:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    local function pickupMacro()
        if InCombatLockdown() then
            print("|cff7fcf75My Blessing:|r Перетащите макрос после боя.")
            return
        end
        local index = GetMacroIndexByName("WildMark")
        if index == 0 then
            SlashCmdList.WILDBLESSING("macro")
            index = GetMacroIndexByName("WildMark")
        end
        if index ~= 0 then PickupMacro(index) end
    end
    macro:SetScript("OnDragStart", pickupMacro)
    macro:SetScript("OnClick", pickupMacro)
    macro:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("WildMark")
        GameTooltip:AddLine("Перетащите макрос на панель действий.", 1, 1, 1)
        GameTooltip:Show()
    end)
    macro:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local instruction = label(settings, "Перетащите значок на панель действий.\nМакрос применяет Знак к цели под курсором.", 85, -48)
    instruction:SetWidth(390)
    local count = label(settings, "", 30, -100, "GameFontNormal")
    label(settings, "Тексты благословений", 30, -128, "GameFontNormal")
    label(settings, "В тексте используйте {имя} и {номер}.", 30, -151, "GameFontHighlightSmall")

    local input = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
    input:SetSize(340, 24)
    input:SetPoint("TOPLEFT", 37, -175)
    input:SetAutoFocus(false)
    input:SetMaxLetters(180)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local status = label(settings, "", 30, -204, "GameFontHighlightSmall")
    status:SetWidth(445)
    status:SetWordWrap(false)
    local add = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    add:SetSize(95, 25)
    add:SetPoint("TOPLEFT", 390, -174)
    add:SetText("Добавить")
    local function submit()
        local text = input:GetText():match("^%s*(.-)%s*$")
        if not text:find("{имя}", 1, true) or not text:find("{номер}", 1, true) then
            status:SetText("Добавьте в текст {имя} и {номер}.")
        elseif #text > 180 then
            status:SetText("Сократите текст до 180 байт.")
        else
            SlashCmdList.WILDBLESSING("add " .. text)
            input:SetText("")
            input:ClearFocus()
            status:SetText("Благословение добавлено.")
            refreshSettings()
        end
    end
    add:SetScript("OnClick", submit)
    input:SetScript("OnEnterPressed", submit)

    local scroll = CreateFrame("ScrollFrame", "WildBlessingSettingsScroll", settings, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 30, -231)
    scroll:SetSize(425, 230)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(425, 230)
    scroll:SetScrollChild(content)
    local rows = {}
    refreshSettings = function()
        count:SetText("Уникальных игроков: " .. WildBlessingDB.count)
        for index, text in ipairs(WildBlessingDB.blessings) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Frame", nil, content)
                row:SetSize(425, 48)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 48)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 2, 0)
                row.text:SetWidth(320)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(true)
                local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                remove:SetSize(82, 23)
                remove:SetPoint("RIGHT", -2, 0)
                remove:SetText("Удалить")
                remove:SetScript("OnClick", function()
                    if #WildBlessingDB.blessings <= 1 then
                        status:SetText("Нужно оставить хотя бы одно благословение.")
                        return
                    end
                    table.remove(WildBlessingDB.blessings, row.index)
                    status:SetText("Благословение удалено.")
                    refreshSettings()
                end)
                rows[index] = row
            end
            row.index = index
            row.text:SetText(index .. ". " .. text)
            row:Show()
        end
        for index = #WildBlessingDB.blessings + 1, #rows do rows[index]:Hide() end
        local height = math.max(230, #WildBlessingDB.blessings * 48)
        content:SetHeight(height)
        if scroll:GetVerticalScroll() > math.max(0, height - 230) then
            scroll:SetVerticalScroll(math.max(0, height - 230))
        end
    end
    local close = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    close:SetSize(110, 25)
    close:SetPoint("BOTTOM", 0, 18)
    close:SetText("Закрыть")
    close:SetScript("OnClick", function() settings:Hide() end)
    settings:SetScript("OnShow", function() status:SetText(""); refreshSettings() end)
    settings:SetScript("OnHide", function() input:ClearFocus() end)
    settings:Hide()
    settings:Show()
end

local minimapButton = CreateFrame("Button", "WildBlessingMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Icons\\Spell_Nature_Regeneration")
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
local function placeMinimapButton()
    local angle = math.rad(WildBlessingDB.minimapAngle or 225)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        if not centerX or not centerY then return end
        WildBlessingDB.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
        placeMinimapButton()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
minimapButton:SetScript("OnClick", WildBlessingToggleSettings)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("My Blessing")
    GameTooltip:AddLine("Нажмите, чтобы открыть настройки", 1, 1, 1)
    GameTooltip:AddLine("Перетащите, чтобы переместить значок", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
minimapButton:RegisterEvent("ADDON_LOADED")
minimapButton:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then placeMinimapButton() end
end)

