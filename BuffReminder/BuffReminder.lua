local addonName = ...
local events = CreateFrame("Frame")
local db, settings, refreshSettings, update, openSettings

local function say(message)
    print("|cffffd100Buff Reminder:|r " .. message)
end
local function spellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    if GetSpellInfo then return GetSpellInfo(id) end
end
local function entryName(entry)
    if type(entry) == "number" then return spellName(entry) or ("ID " .. entry) end
    return entry
end
local function entryDescription(entry)
    if type(entry) == "number" then return entryName(entry) .. " (" .. entry .. ")" end
    return entry
end
local function parseEntry(value)
    value = (value or ""):match("^%s*(.-)%s*$")
    local linkID = value:match("|Hspell:(%d+)")
    local id = tonumber(linkID or value)
    if id then
        if id > 0 and id % 1 == 0 then return id end
        return nil
    end
    if value ~= "" and not value:find("|H") then return value end
end
local function addEntry(value)
    local entry = parseEntry(value)
    if not entry then return false, "Введите название эффекта или ID заклинания." end
    for _, existing in ipairs(db.buffs) do
        if existing == entry then return false, "Этот эффект уже добавлен." end
    end
    db.buffs[#db.buffs + 1] = entry
    update()
    if refreshSettings then refreshSettings() end
    return true, "Добавлено: " .. entryDescription(entry)
end

local ICON_SIZE, ICON_GAP, ICONS_PER_ROW = 42, 5, 8
local fallbackIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
local panel = CreateFrame("Frame", "BuffReminderPanel", UIParent)
panel:SetSize(ICON_SIZE, ICON_SIZE)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:SetFrameStrata("MEDIUM")
panel:Hide()
local icons = {}

local function beginDrag()
    if db and (IsShiftKeyDown() or db.unlocked) then
        panel.isMoving = true
        panel:StartMoving()
        GameTooltip:Hide()
    end
end
local function endDrag()
    if not panel.isMoving then return end
    panel.isMoving = false
    panel:StopMovingOrSizing()
    local point, _, relativePoint, x, y = panel:GetPoint()
    db.position = { point, relativePoint, x, y }
end
local function spellIcon(spell)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
    if GetSpellTexture then return GetSpellTexture(spell) end
end
local function makeIcon(index)
    local frame = CreateFrame("Frame", nil, panel)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    local border = frame:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0.55, 0.12, 0.08, 1)
    frame.texture = frame:CreateTexture(nil, "ARTWORK")
    frame.texture:SetPoint("TOPLEFT", 2, -2)
    frame.texture:SetPoint("BOTTOMRIGHT", -2, 2)
    frame.texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame:SetScript("OnDragStart", beginDrag)
    frame:SetScript("OnDragStop", endDrag)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.description, 1, 0.82, 0)
        GameTooltip:AddLine("Shift + перетаскивание — переместить", 1, 1, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    icons[index] = frame
    return frame
end
local function showIcons(missing)
    for index, effect in ipairs(missing) do
        local frame = icons[index] or makeIcon(index)
        local column = (index - 1) % ICONS_PER_ROW
        local row = math.floor((index - 1) / ICONS_PER_ROW)
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", panel, "TOPLEFT", column * (ICON_SIZE + ICON_GAP), -row * (ICON_SIZE + ICON_GAP))
        frame.texture:SetTexture(effect.icon or fallbackIcon)
        frame.description = effect.description
        frame:Show()
    end
    for index = #missing + 1, #icons do icons[index]:Hide() end
    local columns = math.min(#missing, ICONS_PER_ROW)
    local rows = math.ceil(#missing / ICONS_PER_ROW)
    panel:SetSize(columns * ICON_SIZE + (columns - 1) * ICON_GAP, rows * ICON_SIZE + (rows - 1) * ICON_GAP)
    panel:Show()
end
local function auras()
    local foundIds, foundNames = {}, {}
    for i = 1, 255 do
        local name, id
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not aura then break end
            name, id = aura.name, aura.spellId
        else
            local icon, count, debuffType, duration, expiration, source, stealable, nameplate
            name, icon, count, debuffType, duration, expiration, source, stealable, nameplate, id = UnitBuff("player", i)
            if not name then break end
        end
        if name then foundNames[name] = true end
        if id then foundIds[id] = true end
    end
    return foundIds, foundNames
end

local function atMaxLevel()
    if UnitXPMax("player") == 0 then return true end
    if GetMaxPlayerLevel then
        local maximum = GetMaxPlayerLevel()
        if maximum and maximum > 0 and UnitLevel("player") >= maximum then return true end
    end
    return false
end
update = function()
    if not db then return end
    if not db.enabled or (InCombatLockdown and InCombatLockdown()) or UnitIsDeadOrGhost("player") then
        panel:Hide()
        return
    end
    local ids, names = auras()
    local missing = {}
    local fedName = spellName(19705)
    if db.food and not (names["Well Fed"] or names["Сытость"] or (fedName and names[fedName])) then
        missing[#missing + 1] = {
            icon = spellIcon(19705) or "Interface\\Icons\\INV_Misc_Food_15",
            description = "Нет эффекта от еды",
        }
    end
    -- Well-Rested from the Cozy Sleeping Bag is an aura, separate from rested XP.
    local sleepBuffID = 429959
    local sleepBuffName = spellName(sleepBuffID)
    local hasSleepBuff = ids[sleepBuffID] or (sleepBuffName and names[sleepBuffName])
        or names["Прилив сил"] or names["Well-Rested"]
    if db.rest and not atMaxLevel() and not hasSleepBuff then
        missing[#missing + 1] = {
            icon = spellIcon(sleepBuffID) or "Interface\\Icons\\INV_Drink_15",
            description = "Нет эффекта «Прилив сил» от спального мешка",
        }
    end
    for _, entry in ipairs(db.buffs) do
        local name = type(entry) == "number" and spellName(entry) or entry
        if not (type(entry) == "number" and ids[entry]) and not (name and names[name]) then
            missing[#missing + 1] = { icon = spellIcon(entry), description = "Нет: " .. entryName(entry) }
        end
    end
    if #missing == 0 then
        if not db.unlocked then panel:Hide(); return end
        missing[1] = { icon = fallbackIcon, description = "Перетащите окно напоминаний" }
    end
    showIcons(missing)
end
openSettings = function()
    if settings then
        if settings:IsShown() then settings:Hide() else settings:Show() end
        return
    end
    settings = CreateFrame("Frame", "BuffReminderSettings", UIParent, "BasicFrameTemplateWithInset")
    settings:SetSize(460, 490)
    settings:SetPoint("CENTER")
    settings:SetFrameStrata("DIALOG")
    settings:SetClampedToScreen(true)
    settings:SetMovable(true)
    settings:EnableMouse(true)
    settings:RegisterForDrag("LeftButton")
    settings:SetScript("OnDragStart", settings.StartMoving)
    settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
    settings.TitleText:SetText("Buff Reminder — настройки")
    table.insert(UISpecialFrames, "BuffReminderSettings")
    local checks = {}
    local function checkbox(y, title, key)
        local button = CreateFrame("CheckButton", nil, settings, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", 25, y)
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", button, "RIGHT", 2, 0)
        text:SetText(title)
        button:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            update()
        end)
        checks[key] = button
    end
    checkbox(-40, "Показывать напоминания", "enabled")
    checkbox(-70, "Напоминать о еде", "food")
    checkbox(-100, "Напоминать о «Приливе сил»", "rest")
    local heading = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 32, -145)
    heading:SetText("Дополнительные эффекты")
    local hint = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 32, -168)
    hint:SetText("Введите точное название эффекта или ID заклинания:")
    local input = CreateFrame("EditBox", nil, settings, "InputBoxTemplate")
    input:SetSize(275, 24)
    input:SetPoint("TOPLEFT", 40, -191)
    input:SetAutoFocus(false)
    input:SetMaxLetters(100)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    local status = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", 32, -222)
    status:SetWidth(390)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(false)
    local add = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    add:SetSize(95, 25)
    add:SetPoint("TOPLEFT", 330, -190)
    add:SetText("Добавить")
    local function submit()
        local ok, message = addEntry(input:GetText())
        status:SetText(message)
        if ok then input:SetText(""); input:ClearFocus() end
    end
    add:SetScript("OnClick", submit)
    input:SetScript("OnEnterPressed", submit)
    local listTitle = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", 32, -250)
    listTitle:SetText("Отслеживаемые эффекты")
    local scroll = CreateFrame("ScrollFrame", "BuffReminderEffectsScroll", settings, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 32, -274)
    scroll:SetSize(365, 153)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(365, 153)
    scroll:SetScrollChild(content)
    local rows = {}
    local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 4, -8)
    empty:SetText("Пока ничего не добавлено")
    local close = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
    close:SetSize(110, 25)
    close:SetPoint("BOTTOM", 0, 20)
    close:SetText("Закрыть")
    close:SetScript("OnClick", function() settings:Hide() end)
    refreshSettings = function()
        for key, check in pairs(checks) do check:SetChecked(db[key]) end
        empty:SetShown(#db.buffs == 0)
        for index, entry in ipairs(db.buffs) do
            local row = rows[index]
            if not row then
                row = CreateFrame("Frame", nil, content)
                row:SetSize(365, 31)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 31)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.text:SetPoint("LEFT", 4, 0)
                row.text:SetWidth(265)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                remove:SetSize(85, 23)
                remove:SetPoint("RIGHT", -2, 0)
                remove:SetText("Удалить")
                remove:SetScript("OnClick", function()
                    table.remove(db.buffs, row.index)
                    update()
                    refreshSettings()
                end)
                rows[index] = row
            end
            row.index = index
            row.text:SetText(entryDescription(entry))
            row:Show()
        end
        for index = #db.buffs + 1, #rows do rows[index]:Hide() end
        local height = math.max(153, #db.buffs * 31)
        content:SetHeight(height)
        local maxScroll = math.max(0, height - 153)
        if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
    end
    settings:SetScript("OnShow", function() status:SetText(""); refreshSettings() end)
    settings:SetScript("OnHide", function() input:ClearFocus() end)
    settings:Hide()
    settings:Show()
end

local minimapButton = CreateFrame("Button", "BuffReminderMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetMovable(true)
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")
icon:SetTexture("Interface\\Icons\\INV_Misc_Food_15")
local border = minimapButton:CreateTexture(nil, "OVERLAY")
border:SetSize(53, 53)
border:SetPoint("TOPLEFT")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
local function placeMinimapButton()
    local angle = math.rad(db.minimapAngle or 225)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local centerX, centerY = Minimap:GetCenter()
        if not centerX or not centerY then return end
        db.minimapAngle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
        placeMinimapButton()
    end)
end)
minimapButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
minimapButton:SetScript("OnClick", function() openSettings() end)
minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Buff Reminder")
    GameTooltip:AddLine("Нажмите, чтобы открыть настройки", 1, 1, 1)
    GameTooltip:AddLine("Перетащите, чтобы переместить ярлык", 1, 1, 1)
    GameTooltip:Show()
end)
minimapButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("UPDATE_EXHAUSTION")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        BuffReminderDB = type(BuffReminderDB) == "table" and BuffReminderDB or {}
        db = BuffReminderDB
        if db.enabled == nil then db.enabled = true end
        if db.food == nil then db.food = true end
        if db.rest == nil then db.rest = true end
        if type(db.buffs) ~= "table" then db.buffs = {} end
        db.unlocked = false
        if type(db.position) == "table" then
            panel:ClearAllPoints()
            panel:SetPoint(db.position[1], UIParent, db.position[2], db.position[3], db.position[4])
        end
        placeMinimapButton()
    elseif event == "UNIT_AURA" and arg ~= "player" then
        return
    end
    update()
end)

SLASH_BUFFREMINDER1 = "/buffreminder"
SLASH_BUFFREMINDER2 = "/brm"
SlashCmdList.BUFFREMINDER = function(message)
    local command, value = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "settings" then openSettings(); return
    elseif command == "food" or command == "rest" then
        db[command] = not db[command]
        say((command == "food" and "Еда" or "Прилив сил") .. (db[command] and ": включено" or ": выключено"))
    elseif command == "on" or command == "off" then
        db.enabled = command == "on"
        say(db.enabled and "Включено" or "Выключено")
    elseif command == "move" or command == "lock" then
        db.unlocked = command == "move"
        say(db.unlocked and "Перетащите окно; затем введите /brm lock" or "Окно закреплено")
    elseif command == "add" then
        local _, result = addEntry(value)
        say(result)
    elseif command == "remove" then
        local entry = parseEntry(value)
        local removed = false
        for i = #db.buffs, 1, -1 do
            if db.buffs[i] == entry then table.remove(db.buffs, i); removed = true end
        end
        say(removed and "Напоминание удалено" or "Эффект не найден в списке")
    elseif command == "list" then
        say("Еда: " .. (db.food and "да" or "нет") .. "; Прилив сил: " .. (db.rest and "да" or "нет"))
        if #db.buffs == 0 then say("Дополнительных эффектов нет") end
        for _, entry in ipairs(db.buffs) do say(entryDescription(entry)) end
    else
        say("/brm — настройки; /brm add НАЗВАНИЕ или ID — добавить эффект")
        say("/brm remove НАЗВАНИЕ или ID; /brm list; /brm food; /brm rest; /brm on/off")
    end
    update()
    if refreshSettings then refreshSettings() end
end
