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

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
        if tooltip ~= GameTooltip or IsShiftKeyDown() then return end
        local _, link = tooltip:GetItem()
        if not link then return end
        local ok, vendor, auction, source = pcall(ns.tooltipPrices, link)
        if not ok then return end
        if vendor and vendor > 0 then
            tooltip:AddDoubleLine("Торговец (за шт.)", ns.money(vendor), 1, 1, 1, 1, 1, 1)
        end
        if auction then
            tooltip:AddDoubleLine(source .. " (за шт.)", ns.money(auction), 1, 1, 1, 1, 1, 1)
        else
            tooltip:AddDoubleLine("Аукцион", "Нет данных TSM", 1, 1, 1, 1, 0.7, 0.3)
        end
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