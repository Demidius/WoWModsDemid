local addon = CreateFrame("Frame")
local panel, browse, status, filter, header, scaleButton, minPriceBox, maxPriceBox, statMinBox
local rows, entries = {}, {}
local page, ascending, onlyUpgrades = 1, false, true
local generation = 0
local PAGE_SIZE = 12
local selectedScale
local minPrice, maxPrice, priceError
local selectedStat, statMinimum, statError
local selectedPerson, inspected, inspectMessage, inspectSerial = nil, nil, nil, 0
local personButton
local statChoices = {
    { key = "RESISTANCE0_NAME", label = "Броня" },
    { key = "ITEM_MOD_STRENGTH_SHORT", label = "Сила" },
    { key = "ITEM_MOD_AGILITY_SHORT", label = "Ловкость" },
    { key = "ITEM_MOD_STAMINA_SHORT", label = "Выносливость" },
    { key = "ITEM_MOD_INTELLECT_SHORT", label = "Интеллект" },
    { key = "ITEM_MOD_SPIRIT_SHORT", label = "Дух" },
    { key = "ITEM_MOD_ATTACK_POWER_SHORT", label = "Сила атаки" },
    { key = "ITEM_MOD_SPELL_POWER_SHORT", label = "Сила заклинаний" },
    { key = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", label = "Исцеление" },
    { key = "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT", label = "Урон заклинаний" },
    { key = "ITEM_MOD_MANA_REGENERATION_SHORT", label = "Восстановление маны" },
    { key = "ITEM_MOD_CRIT_RATING_SHORT", label = "Критический удар" },
    { key = "ITEM_MOD_HASTE_RATING_SHORT", label = "Скорость" },
    { key = "ITEM_MOD_HIT_RATING_SHORT", label = "Меткость" },
    { key = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", label = "Защита" },
    { key = "ITEM_MOD_DODGE_RATING_SHORT", label = "Уклонение" },
    { key = "ITEM_MOD_PARRY_RATING_SHORT", label = "Парирование" },
    { key = "ITEM_MOD_BLOCK_RATING_SHORT", label = "Блокирование" },
    { key = "ITEM_MOD_BLOCK_VALUE_SHORT", label = "Показатель блока" },
    { key = "ITEM_MOD_EXPERTISE_RATING_SHORT", label = "Мастерство" },
}

local function resultLink(key)
    if not key or not key.itemID or (key.battlePetSpeciesID or 0) ~= 0 then return nil end
    local data = C_TooltipInfo.GetItemKey(key.itemID, key.itemLevel or 0, key.itemSuffix or 0)
    return data and data.hyperlink
end

local armorLimit = { [1] = 4, [2] = 4, [3] = 3, [4] = 2, [5] = 1, [7] = 3, [8] = 1, [9] = 1, [11] = 2 }

local function evaluateInspected(item, link, stats)
    if not item.UnenchantedStats then return nil, link, false end
    local _, _, _, _, required, _, _, _, _, _, _, itemClass, subclass = C_Item.GetItemInfo(link)
    if not itemClass or not required then return nil, link, false end
    if required > inspected.level then return nil, link, true, stats, {}, {} end
    -- Weapon proficiencies and handedness cannot be established reliably from an inspection.
    if itemClass == 2 or item.InvType == "INVTYPE_SHIELD" or item.InvType == "INVTYPE_HOLDABLE" then
        return nil, link, true, stats, {}, {}
    end
    if itemClass ~= 4 or item.InvType == "INVTYPE_TRINKET" then return nil, link, true, stats, {}, {} end
    if subclass and subclass >= 1 and subclass <= 4 then
        local limit = armorLimit[inspected.classID] or 0
        if (inspected.classID == 1 or inspected.classID == 2 or inspected.classID == 3 or inspected.classID == 7) and inspected.level < 40 then
            limit = limit - 1
        end
        if subclass > limit then return nil, link, true, stats, {}, {} end
    end
    local slot1, slot2 = PawnGetSlotsForItemType(item.InvType)
    if not slot1 then return nil, link, true, stats, {}, {} end
    local upgrades, scores, differences = {}, {}, {}
    for scaleName, scale in pairs(PawnCommon.Scales or {}) do
        if scale.ClassID == inspected.classID and scale.ProviderActive and scale.Values then
            local value = PawnGetItemValue(item.UnenchantedStats, item.Level, item.UnenchantedSocketBonusStats, scaleName, false, true, true)
            if value then
                local label = scale.LocalizedName or scaleName
                scores[#scores + 1] = { scaleName, value, value, label }
                local previousValues, missing = {}, false
                for _, slot in ipairs(slot2 and {slot1, slot2} or {slot1}) do
                    local previousLink = inspected.gear[slot]
                    if previousLink then
                        local previous = PawnGetItemData(previousLink)
                        if not previous or not previous.Link or not previous.UnenchantedStats then missing = true; break end
                        local previousValue = PawnGetItemValue(previous.UnenchantedStats, previous.Level, previous.UnenchantedSocketBonusStats, scaleName, false, true, true)
                        if not previousValue then missing = true; break end
                        previousValues[#previousValues + 1] = previousValue
                    else
                        previousValues[#previousValues + 1] = 0
                    end
                end
                if missing then return nil, link, false end
                local old = math.min(unpack(previousValues))
                if value > old * 1.005 and value > 0 then
                    local diff = value - old
                    upgrades[#upgrades + 1] = { ScaleName = scaleName, LocalizedScaleName = label, PercentUpgrade = old > 0 and diff / old or 100 }
                    differences[#differences + 1] = { scale = scaleName, label = label, value = diff }
                end
            end
        end
    end
    return upgrades, link, true, stats, scores, differences
end

local function evaluate(result)
    if not PawnIsReady or not PawnIsReady() then return nil, nil, false end
    local key = result.itemKey
    if not key then return nil, nil, false end
    local info = C_AuctionHouse.GetItemKeyInfo(key)
    if not info then return nil, nil, false end
    if not info.isEquipment then return nil, nil, true, {} end
    local link = resultLink(key)
    if not link then return nil, nil, false end
    local item = PawnGetItemData(link)
    if not item or not item.Link then return nil, link, false end
    local stats = C_Item.GetItemStats(link)
    if not stats then return nil, link, false end
    if selectedPerson then
        if not inspected then return nil, link, false end
        return evaluateInspected(item, link, stats)
    end
    local upgrades = PawnIsItemAnUpgrade(item)
    local scores = PawnRecalculateItemValuesIfNecessary(item)
    local differences = {}
    for _, upgrade in ipairs(upgrades or {}) do
        if upgrade.ExistingItemLink then
            local previous = PawnGetItemData(upgrade.ExistingItemLink)
            if previous and previous.Link then
                local _, newValue = PawnGetSingleValueFromItem(item, upgrade.ScaleName)
                local _, oldValue = PawnGetSingleValueFromItem(previous, upgrade.ScaleName)
                if newValue and oldValue then
                    differences[#differences + 1] = {
                        scale = upgrade.ScaleName,
                        label = upgrade.LocalizedScaleName,
                        value = newValue - oldValue,
                    }
                end
            end
        end
    end
    return upgrades, link, true, stats, scores, differences
end

local function selectUpgrade(upgrades)
    local best
    for _, upgrade in ipairs(upgrades or {}) do
        if (not selectedScale or upgrade.ScaleName == selectedScale) and upgrade.PercentUpgrade
            and (not best or upgrade.PercentUpgrade > best.PercentUpgrade) then
            best = upgrade
        end
    end
    return best
end

local function selectDifference(differences)
    local best
    for _, difference in ipairs(differences or {}) do
        if (not selectedScale or difference.scale == selectedScale) and (not best or difference.value > best.value) then
            best = difference
        end
    end
    return best
end

local function showRows()
    if not panel or not panel:IsShown() then return end
    local shown = {}
    local pending = 0
    for _, entry in ipairs(entries) do
        if not entry.ready then pending = pending + 1 end
        entry.upgrade = selectUpgrade(entry.upgrades)
        entry.difference = selectDifference(entry.differences)
        entry.bestValue = nil
        local value
        entry.scoreScale = nil
        if selectedStat == "PAWN_DIFFERENCE" and entry.ready then
            if entry.difference then
                value = entry.difference.value
                entry.scoreScale = entry.difference.label or entry.difference.scale
            end
        elseif selectedStat == "PAWN_SCORE" and entry.ready then
            for _, score in ipairs(entry.scores or {}) do
                if not selectedScale or score[1] == selectedScale then
                    local scoreValue = PawnCommon.ShowEnchanted and score[2] or score[3]
                    if not scoreValue or scoreValue <= 0 then scoreValue = score[3] end
                    if scoreValue and (not value or scoreValue > value) then
                        value = scoreValue
                        entry.scoreScale = score[4] or score[1]
                    end
                end
            end
            value = value or 0
        elseif selectedStat and entry.ready then
            value = entry.stats and entry.stats[selectedStat] or 0
            if selectedStat == "RESISTANCE0_NAME" and entry.stats then
                value = entry.stats.RESISTANCE0_NAME or entry.stats.ITEM_MOD_ARMOR_SHORT or 0
            end
        elseif not selectedStat and entry.upgrade then
            value = entry.upgrade.PercentUpgrade
        end
        entry.value = value
        local price = entry.result.minPrice
        local priceMatches = not priceError and not statError and (not minPrice or (price and price >= minPrice))
            and (not maxPrice or (price and price <= maxPrice))
        local statMatches = not selectedStat or not statMinimum or not entry.ready or (value and value >= statMinimum)
        if priceMatches and statMatches and (not onlyUpgrades or entry.upgrade or not entry.ready) then shown[#shown + 1] = entry end
    end
    local ranked = {}
    for _, entry in ipairs(shown) do
        local price = entry.result.minPrice
        if entry.difference and entry.difference.value > 0 and price and price > 0 then
            ranked[#ranked + 1] = { entry = entry, ratio = entry.difference.value / price }
        end
    end
    table.sort(ranked, function(a, b)
        if a.ratio ~= b.ratio then return a.ratio > b.ratio end
        return a.entry.index < b.entry.index
    end)
    for i = 1, math.min(3, #ranked) do ranked[i].entry.bestValue = true end
    table.sort(shown, function(a, b)
        if (a.value ~= nil) ~= (b.value ~= nil) then return a.value ~= nil end
        if a.value and b.value and a.value ~= b.value then
            if ascending then return a.value < b.value end
            return a.value > b.value
        end
        return a.index < b.index
    end)
    local pages = math.max(1, math.ceil(#shown / PAGE_SIZE))
    page = math.min(page, pages)
    status:SetText(priceError or statError or inspectMessage or ((C_AuctionHouse.HasFullBrowseResults() and "Все результаты" or "Загруженная часть") ..
        ": " .. #entries .. "  |  Ожидают: " .. pending .. "  |  " .. page .. "/" .. pages))
    for i, row in ipairs(rows) do
        local entry = shown[(page - 1) * PAGE_SIZE + i]
        row.entry = entry
        if entry then
            local info = C_AuctionHouse.GetItemKeyInfo(entry.result.itemKey)
            local name = info and info.itemName or "Загрузка…"
            row.name:SetText(entry.bestValue and ("★ " .. name) or name)
            if entry.bestValue then row.name:SetTextColor(1, 0.82, 0) else row.name:SetTextColor(1, 1, 1) end
            local valueText = entry.ready and "—" or "?"
            if entry.value then
                if selectedStat == "PAWN_SCORE" or selectedStat == "PAWN_DIFFERENCE" then
                    local digits = math.min(4, math.max(0, PawnCommon.Digits or 1))
                    local sign = selectedStat == "PAWN_DIFFERENCE" and "+" or ""
                    valueText = string.format(sign .. "%." .. digits .. "f", entry.value)
                else
                    valueText = selectedStat and string.format("%g", entry.value) or string.format("+%.0f%%", entry.value * 100)
                end
            end
            row.percent:SetText(valueText)
            row.scale:SetText((selectedStat == "PAWN_SCORE" or selectedStat == "PAWN_DIFFERENCE") and (entry.scoreScale or "") or (entry.upgrade and entry.upgrade.LocalizedScaleName or ""))
            row.price:SetText(entry.result.minPrice and GetMoneyString(entry.result.minPrice) or "—")
            row:Show()
        else row:Hide() end
    end
end

local function scan()
    generation = generation + 1
    local current = generation
    entries = {}
    local results = C_AuctionHouse.GetBrowseResults() or {}
    for i, result in ipairs(results) do entries[i] = { result = result, index = i } end
    page = 1
    showRows()
    local index, retries = 1, 0
    local function step()
        if generation ~= current or not panel:IsShown() then return end
        local last = math.min(index + 7, #entries)
        for i = index, last do
            local e = entries[i]
            if not e.ready then
                local ok, upgrades, link, ready, stats, scores, differences = pcall(evaluate, e.result)
                if ok then e.upgrades, e.link, e.ready, e.stats, e.scores, e.differences = upgrades, link, ready, stats, scores, differences end
            end
        end
        index = last + 1
        if index > #entries then
            showRows()
            retries = retries + 1
            if retries >= 4 then return end
            index = 1
            C_Timer.After(1, step)
        else
            showRows()
            C_Timer.After(0.03, step)
        end
    end
    if #entries > 0 then C_Timer.After(0, step) end
end

local function selectPerson(unit, name)
    inspectSerial = inspectSerial + 1
    local serial = inspectSerial
    selectedScale = nil
    if scaleButton then scaleButton:SetText("Все шкалы") end
    inspected = nil
    if not name then
        selectedPerson = nil; inspectMessage = nil
        personButton:SetText("Для себя")
        scan()
        return
    end
    selectedPerson = { unit = unit, name = name, guid = unit and UnitGUID(unit) }
    personButton:SetText(name)
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then
        inspectMessage = "Выделите друга рядом для осмотра"
    elseif not selectedPerson.guid or not CanInspect(unit) or not CheckInteractDistance(unit, 1) or InCombatLockdown() then
        inspectMessage = "Осмотр недоступен: подойдите ближе и выйдите из боя"
    else
        inspectMessage = "Ожидание данных осмотра…"
        local ok = pcall(NotifyInspect, unit)
        if not ok then inspectMessage = "Не удалось запросить осмотр" end
        C_Timer.After(8, function()
            if serial == inspectSerial and selectedPerson and not inspected then
                inspectMessage = "Нет ответа осмотра — выберите персонажа снова"
                showRows()
            end
        end)
    end
    scan()
end

local function unitName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    return realm and realm ~= "" and (name .. "-" .. realm) or name
end

local function createPanel()
    browse = AuctionHouseFrame and AuctionHouseFrame.BrowseResultsFrame
    if not browse or panel then return end
    panel = CreateFrame("Frame", nil, AuctionHouseFrame, "BackdropTemplate")
    panel:SetSize(620, 445)
    panel:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 4, -45)
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=20, insets={left=4,right=4,top=4,bottom=4}})
    panel:Hide()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -16); title:SetText("Улучшения Pawn")
    personButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    personButton:SetSize(190, 22); personButton:SetPoint("TOP", panel, "TOP", 40, -12); personButton:SetText("Для себя")
    personButton:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle("Для кого искать")
            menu:CreateButton("Для себя", function() selectPerson(nil, nil) end)
            local seen = {}
            local function addUnit(unit)
                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                    local name = unitName(unit)
                    if name and not seen[name] then
                        seen[name] = true
                        menu:CreateButton(name .. " (группа)", function() selectPerson(unit, name) end)
                    end
                end
            end
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do addUnit("raid" .. i) end
            elseif IsInGroup() then
                for i = 1, GetNumSubgroupMembers() do addUnit("party" .. i) end
            end
            local targetName = UnitExists("target") and UnitIsPlayer("target") and unitName("target") or nil
            if C_FriendList and C_FriendList.GetNumFriends then
                local n = C_FriendList.GetNumFriends()
                if n > 0 then menu:CreateTitle("Друзья: для осмотра выделите рядом") end
                for i = 1, n do
                    local info = C_FriendList.GetFriendInfoByIndex(i)
                    if info and info.name and not seen[info.name] then
                        local name = info.name
                        local target = targetName and (targetName == name or (not name:find("-", 1, true) and targetName:match("^[^-]+") == name)) and "target" or nil
                        menu:CreateButton(name .. (info.connected and "" or " (не в сети)"), function() selectPerson(target, name) end)
                    end
                end
            end
        end)
    end)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -3)
    filter = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    filter:SetPoint("TOPLEFT", 14, -38); filter:SetChecked(true)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", filter, "RIGHT", 0, 0); label:SetText("Только улучшения")
    filter:SetScript("OnClick", function(self) onlyUpgrades = self:GetChecked(); page = 1; showRows() end)
    local reload = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reload:SetSize(95, 22); reload:SetPoint("TOPRIGHT", -35, -39); reload:SetText("Обновить")
    reload:SetScript("OnClick", function()
        if selectedPerson then
            local unit = selectedPerson.unit
            if unit and selectedPerson.guid and UnitGUID(unit) ~= selectedPerson.guid then unit = nil end
            selectPerson(unit, selectedPerson.name)
        else scan() end
    end)
    scaleButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    scaleButton:SetSize(190, 22); scaleButton:SetPoint("TOPLEFT", 20, -69); scaleButton:SetText("Все шкалы")
    scaleButton:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle("Шкала Pawn")
            menu:CreateButton("Все шкалы", function()
                selectedScale = nil; scaleButton:SetText("Все шкалы"); page = 1; showRows()
            end)
            local scales = {}
            if PawnCommon and PawnCommon.Scales then
                for name, scale in pairs(PawnCommon.Scales) do
                    if (not selectedPerson and PawnIsScaleVisible(name)) or (selectedPerson and inspected and scale.ClassID == inspected.classID and scale.ProviderActive and scale.Values) then
                        scales[#scales + 1] = { name = name, label = scale.LocalizedName or name }
                    end
                end
            end
            table.sort(scales, function(a, b) return a.label < b.label end)
            for _, scale in ipairs(scales) do
                local name, display = scale.name, scale.label
                menu:CreateButton(display, function()
                    selectedScale = name; scaleButton:SetText(display); page = 1; showRows()
                end)
            end
        end)
    end)
    local priceLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    priceLabel:SetPoint("TOPLEFT", 225, -75); priceLabel:SetText("Цена, золото: от")
    local function priceBox(x)
        local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        box:SetSize(60, 20); box:SetPoint("TOPLEFT", x, -70); box:SetAutoFocus(false); box:SetMaxLetters(12)
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        return box
    end
    minPriceBox = priceBox(327)
    local toLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toLabel:SetPoint("TOPLEFT", 395, -75); toLabel:SetText("до")
    maxPriceBox = priceBox(420)
    local function updatePrice()
        local function parse(box)
            local value = box:GetText():gsub("%s+", ""):gsub(",", ".")
            if value == "" then return nil, true end
            local amount = tonumber(value)
            if not amount or amount < 0 or amount > 100000000 then return nil, false end
            return math.floor(amount * 10000 + 0.5), true
        end
        local minOK, maxOK
        minPrice, minOK = parse(minPriceBox)
        maxPrice, maxOK = parse(maxPriceBox)
        priceError = (not minOK or not maxOK) and "Введите цену числом в золоте" or
            (minPrice and maxPrice and minPrice > maxPrice and "Цена «от» больше цены «до»" or nil)
        page = 1; showRows()
    end
    minPriceBox:SetScript("OnTextChanged", updatePrice)
    maxPriceBox:SetScript("OnTextChanged", updatePrice)
    local statLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statLabel:SetPoint("TOPLEFT", 20, -115); statLabel:SetText("Столбец:")
    local statButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    statButton:SetSize(155, 22); statButton:SetPoint("TOPLEFT", 83, -109); statButton:SetText("Улучшение Pawn")
    statButton:SetScript("OnClick", function(self)
        MenuUtil.CreateContextMenu(self, function(_, menu)
            menu:CreateTitle("Показатель столбца")
            menu:CreateButton("Улучшение Pawn", function()
                selectedStat = nil; statError = nil; statButton:SetText("Улучшение Pawn"); header:SetText("Улучшение")
                statMinBox:Disable(); page = 1; showRows()
            end)
            menu:CreateButton("Оценка Pawn", function()
                selectedStat = "PAWN_SCORE"; statButton:SetText("Оценка Pawn"); header:SetText("Оценка")
                statMinBox:Enable(); statMinBox:GetScript("OnTextChanged")(statMinBox)
            end)
            menu:CreateButton("Изменение оценки", function()
                selectedStat = "PAWN_DIFFERENCE"; statButton:SetText("Изменение оценки"); header:SetText("Разница")
                statMinBox:Enable(); statMinBox:GetScript("OnTextChanged")(statMinBox)
            end)
            for _, choice in ipairs(statChoices) do
                local key, label = choice.key, choice.label
                menu:CreateButton(label, function()
                    selectedStat = key; statButton:SetText(label); header:SetText(label)
                    statMinBox:Enable(); statMinBox:GetScript("OnTextChanged")(statMinBox)
                end)
            end
        end)
    end)
    local minStatLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minStatLabel:SetPoint("TOPLEFT", 257, -115); minStatLabel:SetText("Минимум:")
    local valueLegend = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueLegend:SetPoint("TOPRIGHT", -20, -115); valueLegend:SetText("★ Выгоднее по цене")
    statMinBox = priceBox(327)
    statMinBox:ClearAllPoints(); statMinBox:SetPoint("TOPLEFT", 327, -110); statMinBox:Disable()
    statMinBox:SetScript("OnTextChanged", function(self)
        local value = self:GetText():gsub("%s+", ""):gsub(",", ".")
        statMinimum = value ~= "" and tonumber(value) or nil
        statError = selectedStat and value ~= "" and (not statMinimum or statMinimum < 0) and "Введите минимум характеристики числом" or nil
        page = 1; showRows()
    end)
    local function heading(text, x, width)
        local f = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f:SetPoint("TOPLEFT", x, -156); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
    end
    heading("Предмет", 20, 245); heading("Шкала", 339, 125); heading("Цена", 470, 130)
    header = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    header:SetSize(83, 20); header:SetPoint("TOPLEFT", 250, -151); header:SetText("Улучшение")
    header:SetScript("OnClick", function() ascending = not ascending; showRows() end)
    for i = 1, PAGE_SIZE do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(580, 19); row:SetPoint("TOPLEFT", 20, -174 - (i - 1) * 19)
        local highlight = row:CreateTexture(nil, "HIGHLIGHT"); highlight:SetAllPoints(); highlight:SetColorTexture(1, 1, 1, 0.12)
        local function cell(x, width)
            local f = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            f:SetPoint("LEFT", x, 0); f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetWordWrap(false); return f
        end
        row.name = cell(0, 225); row.percent = cell(230, 80); row.scale = cell(319, 125); row.price = cell(450, 130)
        row:SetScript("OnClick", function(self) if self.entry then browse:OnBrowseResultSelected(self.entry.result) end end)
        row:SetScript("OnEnter", function(self)
            if self.entry and self.entry.link then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.entry.link); GameTooltip:Show() end
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rows[i] = row
    end
    local previous = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    previous:SetSize(35, 21); previous:SetPoint("BOTTOMLEFT", 18, 15); previous:SetText("<")
    previous:SetScript("OnClick", function() page = math.max(1, page - 1); showRows() end)
    local nextButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    nextButton:SetSize(35, 21); nextButton:SetPoint("LEFT", previous, "RIGHT", 4, 0); nextButton:SetText(">")
    nextButton:SetScript("OnClick", function() page = page + 1; showRows() end)
    status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", nextButton, "RIGHT", 12, 0)
    local open = CreateFrame("Button", nil, browse, "UIPanelButtonTemplate")
    open:SetSize(145, 22); open:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -25, 6); open:SetText("Улучшения Pawn")
    open:SetScript("OnClick", function() if panel:IsShown() then panel:Hide() else panel:Show(); scan() end end)
    browse:HookScript("OnHide", function() panel:Hide(); generation = generation + 1 end)
end

addon:RegisterEvent("AUCTION_HOUSE_SHOW")
addon:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
addon:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
addon:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
addon:RegisterEvent("INSPECT_READY")
addon:SetScript("OnEvent", function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then createPanel()
    elseif event == "INSPECT_READY" then
        if selectedPerson and selectedPerson.guid and selectedPerson.guid == arg and selectedPerson.unit and UnitGUID(selectedPerson.unit) == arg then
            local _, _, classID = UnitClass(selectedPerson.unit)
            local level = UnitLevel(selectedPerson.unit)
            if not classID or not level or level < 1 then
                inspectMessage = "Нет данных персонажа — повторите осмотр"
                showRows()
                return
            end
            local gear, count, incomplete = {}, 0, false
            for slot = 1, 19 do
                local link = GetInventoryItemLink(selectedPerson.unit, slot)
                if link then gear[slot] = link; count = count + 1
                elseif GetInventoryItemTexture(selectedPerson.unit, slot) then incomplete = true end
            end
            if incomplete or count == 0 then
                inspectMessage = "Данные экипировки неполные — нажмите «Обновить»"
                showRows()
                return
            end
            local hasScale = false
            for _, scale in pairs(PawnCommon.Scales or {}) do
                if scale.ClassID == classID and scale.ProviderActive and scale.Values then hasScale = true; break end
            end
            if not hasScale then
                inspectMessage = "В Pawn не найдены шкалы для этого класса"
                showRows()
                return
            end
            inspected = { classID = classID, level = level, gear = gear }
            inspectMessage = nil
            scan()
        end
    elseif panel and panel:IsShown() then
        generation = generation + 1
        C_Timer.After(0.1, function() if panel:IsShown() then scan() end end)
    end
end)
