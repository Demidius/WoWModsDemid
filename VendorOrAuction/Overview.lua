local ns = VendorOrAuctionLogic
local frame, active = nil, "vendor"
local page, pageSize, rows, entries = 1, 10, {}, {}
local ordered = {"vendor", "auction", "keep", "check"}
local redraw

local function scan()
    local all = {}
    for _, kind in ipairs(ordered) do all[kind] = {} end
    for _, bag in ipairs(ns.playerBags()) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and (info.hyperlink or C_Container.GetContainerItemLink(bag, slot))
            if link then
                local result = ns.safe(link, ns.context(bag, slot, info))
                result.link, result.count = link, info.stackCount or 1
                table.insert(all[result.kind] or all.check, result)
            end
        end
    end
    return all
end

local function setRule(id, rule)
    if not id then return end
    VendorOrAuctionDB.keep[id] = nil
    VendorOrAuctionDB.alwaysVendor[id] = nil
    if rule == "keep" then VendorOrAuctionDB.keep[id] = true
    elseif rule == "vendor" then VendorOrAuctionDB.alwaysVendor[id] = true end
    ns.refresh()
    redraw()
end

local function makeButton(parent, text, width, x, y, action)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 23)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

redraw = function()
    if not frame or not frame:IsShown() then return end
    local all = scan()
    entries = all[active]
    local pages = math.max(1, math.ceil(#entries / pageSize))
    page = math.min(page, pages)
    local totalVendor, totalAuction, knownAuction = 0, 0, 0
    for _, item in ipairs(entries) do
        totalVendor = totalVendor + (item.vendor or 0) * item.count
        if item.price then
            totalAuction = totalAuction + item.price * (1 - VendorOrAuctionDB.auctionCut / 100) * item.count
            knownAuction = knownAuction + 1
        end
    end
    frame.heading:SetText(ns.labels[active] .. ": " .. #entries .. " стопок  |  Торговец: " .. ns.money(totalVendor))
    frame.totals:SetText("Аукцион после комиссии (" .. knownAuction .. "/" .. #entries .. "): " .. ns.money(totalAuction) .. "; залог не учтён")
    frame.pageText:SetText(page .. " / " .. pages)
    for i, row in ipairs(rows) do
        local item = entries[(page - 1) * pageSize + i]
        row.item = item
        if item then
            local icon = ns.icons[item.kind]
            row.text:SetText(string.format("|cff%02x%02x%02x%s|r %s x%d", icon[2]*255, icon[3]*255, icon[4]*255, icon[1], item.name or ("Предмет " .. (item.id or "?")), item.count))
            row:Show()
        else row:Hide() end
    end
end

local function createOverview()
    frame = CreateFrame("Frame", "VendorOrAuctionOverview", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(710, 490)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("Vendor or Auction — разобрать сумки")
    for i, kind in ipairs(ordered) do
        makeButton(frame, ns.labels[kind], 110, 20 + (i-1)*113, -38, function() active, page = kind, 1 redraw() end)
    end
    local update = makeButton(frame, "Обновить", 94, 473, -38, function()
        ns.invalidateBagCounts()
        if ns.refreshQuests then pcall(ns.refreshQuests) end
        ns.refresh()
        redraw()
        print("|cffffcc00Vendor or Auction:|r рекомендации пересчитаны по текущим данным TSM.")
    end)
    update:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Пересчитать рекомендации")
        GameTooltip:AddLine("Использует данные TSM, доступные сейчас. Сканирование аукциона не запускается.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    update:SetScript("OnLeave", function() GameTooltip:Hide() end)
    makeButton(frame, "Настройки", 110, 570, -38, function() ns.openSettings() end)
    frame.heading = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.heading:SetPoint("TOPLEFT", 25, -72)
    frame.totals = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.totals:SetPoint("TOPLEFT", 25, -92)
    for i = 1, pageSize do
        local row = CreateFrame("Button", nil, frame)
        row:SetSize(660, 25)
        row:SetPoint("TOPLEFT", 25, -108 - (i-1)*29)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 2, 0)
        row.text:SetWidth(350)
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.item.link)
            GameTooltip:AddLine(ns.labels[self.item.kind] .. ": " .. self.item.reason, 1, .82, 0, true)
            if self.item.profit then GameTooltip:AddLine("Выгода за стопку: " .. ns.money(self.item.profit * self.item.count), 1, 1, 1) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        makeButton(row, "Хранить", 80, 365, 0, function() if row.item then setRule(row.item.id, "keep") end end)
        makeButton(row, "Торговцу", 80, 448, 0, function() if row.item then setRule(row.item.id, "vendor") end end)
        makeButton(row, "Авто", 70, 531, 0, function() if row.item then setRule(row.item.id, nil) end end)
        rows[i] = row
    end
    makeButton(frame, "<", 40, 240, -415, function() page = math.max(1, page - 1) redraw() end)
    makeButton(frame, ">", 40, 425, -415, function() page = page + 1 redraw() end)
    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.pageText:SetPoint("TOP", 0, -420)
    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("BOTTOMLEFT", 25, 15)
    note:SetText("Наведите на предмет для подробностей. Кнопки задают правило для всех таких предметов.")
    frame:SetScript("OnShow", redraw)
end

function ns.openOverview()
    if not frame then createOverview() end
    frame:Show()
    redraw()
end

local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function() if frame and frame:IsShown() then redraw() end end)

-- Keep item descriptions and stats, but remove duplicate native vendor and reagent labels.
local function compactNativeLines(tooltip, link)
    local name = tooltip:GetName()
    if not name or not tooltip.NumLines or not tooltip.ClearLines then return end
    local lines, removed, itemLevel = {}, false, nil
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    local requiredLevel, equipSlot
    if getInfo then
        local _, _, _, baseLevel, required, _, _, _, equipLoc = getInfo(link)
        if type(baseLevel) == "number" and baseLevel > 0 then itemLevel = baseLevel end
        if type(required) == "number" and required > 0 then requiredLevel = required end
        if equipLoc and equipLoc ~= "" and type(_G[equipLoc]) == "string" then equipSlot = _G[equipLoc] end
    end
    local inFishingBlock = false
    for i = 1, tooltip:NumLines() do
        local left, right = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        local text = left and left:GetText()
        local level = type(text) == "string" and (text:match("^Уровень предмета:%s*(%d+)") or text:match("^Item Level%s*(%d+)"))
        if level then itemLevel = level end
        if text == "OneCast" then inFishingBlock = true end
        local requiresLevel = requiredLevel and type(text) == "string" and (text:match("^Требуется%s+%d+%-й%s+уровень") or text:match("^Requires Level%s+%d+"))
        local skip = level or requiresLevel or inFishingBlock or type(text) == "string" and (text:match("^Цена продажи:") or text == "Используется для ремесел" or text == "Используется для ремёсел" or text:match("^Sell Price:") or text == "Crafting Reagent")
        if skip then
            removed = true
        elseif text and text ~= "" then
            local r, g, b = left:GetTextColor()
            local rightText = right and right:GetText()
            if equipSlot and text == equipSlot then
                if rightText and rightText ~= "" then text = " " else text = nil end
                removed = true
            end
            local rr, rg, rb = 1, 1, 1
            if rightText and rightText ~= "" then rr, rg, rb = right:GetTextColor() end
            if text then lines[#lines + 1] = {text, rightText, r, g, b, rr, rg, rb} end
        end
    end
    if not removed then return end
    if (itemLevel or requiredLevel) and lines[1] and (not lines[1][2] or lines[1][2] == "") then
        lines[1][2], lines[1][6], lines[1][7], lines[1][8] = "Lv. " .. (itemLevel or "-") .. " / " .. (requiredLevel or "-"), 1, 0.82, 0
    end
    tooltip:ClearLines()
    for _, line in ipairs(lines) do
        if line[2] and line[2] ~= "" then
            tooltip:AddDoubleLine(line[1], line[2], line[3], line[4], line[5], line[6], line[7], line[8])
        else
            tooltip:AddLine(line[1], line[3], line[4], line[5], true)
        end
    end
end
-- The standard tooltip has two columns; overlay two independently aligned value columns.
local function addPriceTable(tooltip, vendor, auction, count, tradable, bound)
    if not tooltip.voaPriceTable then
        local tableState = {rows = {}}
        tooltip.voaPriceTable = tableState
        tooltip:HookScript("OnTooltipCleared", function()
            for _, row in ipairs(tableState.rows) do
                if row.anchor and row.alpha then row.anchor:SetAlpha(row.alpha) end
                if row.unit then row.unit:Hide() end
                if row.total then row.total:Hide() end
            end
        end)
    end
    local tableState = tooltip.voaPriceTable
    local rows = {
        {"Цена", "За шт.", "За всё", true},
        {"Торговец", vendor and vendor > 0 and ns.money(vendor) or "-", vendor and vendor > 0 and count and count > 0 and ns.money(vendor * count) or "-"},
        {"Аукцион", not bound and auction and ns.money(auction) or "-", not bound and auction and tradable and tradable > 0 and ns.money(auction * tradable) or "-"},
    }
    local anchors = {}
    for i, data in ipairs(rows) do
        -- Always build a complete native table first, as a fallback if overlays fail.
        tooltip:AddDoubleLine(data[1], data[2] .. "  /  " .. data[3], 1, 1, 1, 1, 1, 1)
        anchors[i] = _G[tooltip:GetName() .. "TextRight" .. tooltip:NumLines()]
    end
    local ok = pcall(function()
    local maxTotalWidth = 0
    for i, data in ipairs(rows) do
        local anchor = anchors[i]
        if not anchor then error("Tooltip price anchor unavailable") end
        local row = tableState.rows[i]
        if not row then
            row = {unit = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"), total = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")}
            tableState.rows[i] = row
        end
        row.anchor, row.alpha = anchor, anchor:GetAlpha()
        local font, size, flags = anchor:GetFont()
        if font then row.unit:SetFont(font, size, flags) row.total:SetFont(font, size, flags) end
        local tint = data[4] and 0.65 or 1
        row.unit:SetTextColor(tint, tint, tint)
        row.total:SetTextColor(tint, tint, tint)
        row.unit:SetText(data[2])
        row.total:SetText(data[3])
        row.unit:Show()
        row.total:Show()
        maxTotalWidth = math.max(maxTotalWidth, row.total:GetStringWidth() or 0)
    end
    for _, row in ipairs(tableState.rows) do
        row.unit:ClearAllPoints()
        row.unit:SetPoint("RIGHT", row.anchor, "RIGHT", -(maxTotalWidth + 12), 0)
        row.total:ClearAllPoints()
        row.total:SetPoint("RIGHT", row.anchor, "RIGHT", 0, 0)
    end
    for _, row in ipairs(tableState.rows) do row.anchor:SetAlpha(0) end
    end)
    if not ok then
        for _, row in ipairs(tableState.rows) do
            if row.anchor and row.alpha then row.anchor:SetAlpha(row.alpha) end
            if row.unit then row.unit:Hide() end
            if row.total then row.total:Hide() end
        end
    end
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if tooltip ~= GameTooltip or IsShiftKeyDown() then return end
        local _, link = tooltip:GetItem()
        if not link then return end
        local ok, vendor, auction, source = pcall(ns.tooltipPrices, link)
        if not ok then return end
        local categoryOk, category = pcall(ns.itemCategory, link)
        local countOk, count = pcall(ns.bagQuantity, link)
        if not countOk then count = nil end
        local owner = tooltip:GetOwner()
        local itemDetails = owner and owner.BGR
        local bound = itemDetails and itemDetails.isBound
        local tradableOk, tradable = pcall(ns.auctionBagQuantity, link)
        if not tradableOk then tradable = nil end
        pcall(compactNativeLines, tooltip, link)
        if categoryOk and category then
            local amount = count and count > 0 and ("  x" .. count) or ""
            tooltip:AddLine(category .. amount, 0.8, 0.8, 0.8)
        end
        addPriceTable(tooltip, vendor, auction, count, tradable, bound)
    end)
end

local modifierEvents = CreateFrame("Frame")
modifierEvents:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierEvents:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then return end
    if GameTooltip and GameTooltip:IsShown() and GameTooltip.RefreshData then
        pcall(GameTooltip.RefreshData, GameTooltip)
    end
end)
