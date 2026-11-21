local addonName = ...
local settings, refreshSettings
local playersWindow, refreshPlayers

local function label(parent, text, x, y, font)
    local value = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    value:SetPoint("TOPLEFT", x, y)
    value:SetJustifyH("LEFT")
    value:SetText(text)
    return value
end

local function togglePlayers()
    if playersWindow then
        if playersWindow:IsShown() then playersWindow:Hide() else playersWindow:Show() end
        return
    end
    playersWindow = CreateFrame("Frame", "WildBlessingPlayers", UIParent, "BasicFrameTemplateWithInset")
    playersWindow:SetSize(390, 520)
    playersWindow:SetPoint("CENTER")
    playersWindow:SetFrameStrata("DIALOG")
    playersWindow:SetClampedToScreen(true)
    playersWindow:SetMovable(true)
    playersWindow:EnableMouse(true)
    playersWindow:RegisterForDrag("LeftButton")
    playersWindow:SetScript("OnDragStart", playersWindow.StartMoving)
    playersWindow:SetScript("OnDragStop", playersWindow.StopMovingOrSizing)
    playersWindow.TitleText:SetText("My Blessing — игроки")
    table.insert(UISpecialFrames, "WildBlessingPlayers")

    local count = label(playersWindow, "", 28, -40, "GameFontNormal")
    local scroll = CreateFrame("ScrollFrame", "WildBlessingPlayersScroll", playersWindow, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 28, -70)
    scroll:SetSize(310, 315)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(310, 315)
    scroll:SetScrollChild(content)
    local rows = {}
    local selectedName
    local empty = label(content, "Пока нет сохранённых игроков.", 4, -8, "GameFontDisable")
    label(playersWindow, "Нажмите на имя, затем Ctrl+C для копирования.", 28, -397, "GameFontHighlightSmall")
    local copyBox = CreateFrame("EditBox", nil, playersWindow, "InputBoxTemplate")
    copyBox:SetSize(220, 24)
    copyBox:SetPoint("TOPLEFT", 35, -424)
    copyBox:SetAutoFocus(false)
    copyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    copyBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local findButton = CreateFrame("Button", nil, playersWindow, "UIPanelButtonTemplate")
    findButton:SetSize(95, 25)
    findButton:SetPoint("TOPLEFT", 266, -423)
    findButton:SetText("Найти")
    findButton:Disable()
    findButton:SetScript("OnClick", function()
        if not selectedName then return end
        local query = 'n-"' .. selectedName:gsub('"', '') .. '"'
        if C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule
            and Enum.GameRule.IngameWhoListDisabled
            and C_GameRules.IsGameRuleActive(Enum.GameRule.IngameWhoListDisabled) then
            print("|cff7fcf75My Blessing:|r Игровой поиск персонажей сейчас недоступен.")
            return
        end
        if C_FriendList and C_FriendList.SendWho then
            local ok = pcall(function()
                if ShowWhoPanel then ShowWhoPanel() end
                if WhoFrameEditBox then WhoFrameEditBox:SetText(query) end
                local origin = Enum and Enum.SocialWhoOrigin and Enum.SocialWhoOrigin.Chat
                C_FriendList.SendWho(query, origin)
            end)
            if ok then
                playersWindow:Hide()
                if settings and settings:IsShown() then settings:Hide() end
                return
            end
        end
        ChatFrame_OpenChat("/who " .. query)
    end)
    refreshPlayers = function()
        local entries, seen = {}, {}
        for _, player in pairs(WildBlessingDB.names or {}) do
            entries[#entries + 1] = { name = player.name, number = player.number }
            if player.guid then seen[player.guid] = true end
        end
        -- Earlier versions could store a GUID without a name; retain its number visibly.
        for guid, number in pairs(WildBlessingDB.players or {}) do
            if not seen[guid] then
                entries[#entries + 1] = { name = "Имя не сохранено", number = number, missingName = true }
            end
        end
        table.sort(entries, function(a, b)
            if a.number == b.number then return a.name < b.name end
            return a.number < b.number
        end)
        count:SetText("Уникальных игроков: " .. WildBlessingDB.count)
        empty:SetShown(#entries == 0)
        for i, player in ipairs(entries) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Button", nil, content)
                row:SetPoint("TOPLEFT", 4, -(i - 1) * 26 - 4)
                row:SetSize(300, 24)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", 0, 0)
                row.text:SetWidth(300)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                row:SetScript("OnClick", function(self)
                    if not self.playerName then return end
                    selectedName = self.playerName
                    copyBox:SetText(selectedName)
                    copyBox:SetFocus()
                    copyBox:HighlightText()
                    findButton:Enable()
                end)
                row:SetScript("OnEnter", function(self)
                    if not self.playerName then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(self.playerName)
                    GameTooltip:AddLine("Нажмите, чтобы скопировать или найти", 1, 1, 1)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                rows[i] = row
            end
            row.playerName = not player.missingName and player.name or nil
            row.text:SetText("#" .. player.number .. "  " .. player.name)
            row:Show()
        end
        for i = #entries + 1, #rows do rows[i]:Hide() end
        local height = math.max(315, #entries * 26)
        content:SetHeight(height)
        if scroll:GetVerticalScroll() > math.max(0, height - 315) then
            scroll:SetVerticalScroll(math.max(0, height - 315))
        end
    end
    local close = CreateFrame("Button", nil, playersWindow, "UIPanelButtonTemplate")
    close:SetSize(110, 25)
    close:SetPoint("BOTTOM", 0, 18)
    close:SetText("Закрыть")
    close:SetScript("OnClick", function() playersWindow:Hide() end)
    playersWindow:SetScript("OnShow", function()
        if settings and settings:IsShown() then settings:Hide() end
        refreshPlayers()
    end)
    playersWindow:SetScript("OnHide", function()
        copyBox:ClearFocus()
        if settings and not settings:IsShown() then settings:Show() end
    end)
    playersWindow:Hide()
    playersWindow:Show()
end

function WildBlessingToggleSettings()
    if playersWindow and playersWindow:IsShown() then
        playersWindow:Hide()
        return
    end
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
    local playersButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    playersButton:SetSize(145, 25)
    playersButton:SetPoint("TOPRIGHT", -25, -94)
    playersButton:SetText("Список игроков")
    playersButton:SetScript("OnClick", togglePlayers)
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

function WildBlessingRefreshSettings()
    if settings and settings:IsShown() and refreshSettings then refreshSettings() end
    if playersWindow and playersWindow:IsShown() and refreshPlayers then refreshPlayers() end
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

