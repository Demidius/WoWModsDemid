local ADDON = ...
local events = CreateFrame("Frame")
local buttons = setmetatable({}, {__mode = "k"})
local pending, panel
local defaults = {saleRate = 0.3, minProfit = 100, auctionCut = 5, iconSize = 18}

local function sizeLabel(label)
    local font = label:GetFont()
    if font then label:SetFont(font, VendorOrAuctionDB.iconSize, "OUTLINE") end
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
end

local function registerBaganator()
    if not (Baganator and Baganator.API and Baganator.API.RegisterCornerWidget) then return end
    Baganator.API.RegisterCornerWidget("Vendor or Auction: Рекомендация", "vendor-or-auction-sell",
        function(label, details)
            if not details or not details.itemLink then return false end
            local result = VendorOrAuctionLogic.safe(details.itemLink, {bound = details.isBound, quest = details.isQuestItem})
            if result.loading then return nil end
            local icon = VendorOrAuctionLogic.icons[result.kind]
            label:SetText(icon[1])
            sizeLabel(label)
            label:SetTextColor(icon[2], icon[3], icon[4])
            return true
        end,
        function(button)
            local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetShadowColor(0, 0, 0, 1)
            label:SetShadowOffset(1, -1)
            return label
        end,
        {corner = "top_left", priority = 1})
end

local function updateButton(button)
    if not button or not button.GetBagID or not button.GetID then return end
    local ok, bag = pcall(button.GetBagID, button)
    local slot = button:GetID()
    if not ok or type(bag) ~= "number" or bag < 0 or not slot or slot < 1 then return end
    local allowed = false
    for _, id in ipairs(VendorOrAuctionLogic.playerBags()) do if id == bag then allowed = true break end end
    if not allowed then return end
    local link = C_Container and C_Container.GetContainerItemLink(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local result = link and VendorOrAuctionLogic.safe(link, VendorOrAuctionLogic.context(bag, slot, info))
    local show = result and not result.loading
    if show and not button.VendorOrAuctionLabel then
        local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        label:SetText("$")
        label:SetTextColor(1, 0.82, 0)
        label:SetShadowColor(0, 0, 0, 1)
        label:SetShadowOffset(1, -1)
        button.VendorOrAuctionLabel = label
    end
    if button.VendorOrAuctionLabel then
        if show then
            local icon = VendorOrAuctionLogic.icons[result.kind]
            button.VendorOrAuctionLabel:SetText(icon[1])
            button.VendorOrAuctionLabel:SetTextColor(icon[2], icon[3], icon[4])
        end
        sizeLabel(button.VendorOrAuctionLabel)
        button.VendorOrAuctionLabel:SetShown(not not show)
    end
end

local function updateFrame(frame)
    if not frame or not frame.EnumerateValidItems then return end
    for first, second in frame:EnumerateValidItems() do
        local button = second or first
        if type(button) ~= "number" and button then
            buttons[button] = true
            pcall(updateButton, button)
        end
    end
end

local function refresh()
    pending = false
    pcall(updateFrame, ContainerFrameCombinedBags)
    if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
        for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do pcall(updateFrame, frame) end
    end
    for button in pairs(buttons) do pcall(updateButton, button) end
end
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(0.1, refresh)
end
local function refreshAll()
    schedule()
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        pcall(Baganator.API.RequestItemButtonsRefresh)
    end
end
local function hookFrame(frame)
    if frame and type(frame.UpdateItems) == "function" then
        hooksecurefunc(frame, "UpdateItems", function(self) pcall(updateFrame, self) end)
    end
end

local function showSettings()
    if not panel then
        panel = CreateFrame("Frame", "VendorOrAuctionSettings", UIParent, "BasicFrameTemplateWithInset")
        panel:SetFrameStrata("DIALOG")
        panel:SetToplevel(true)
        panel:SetSize(490, 445)
        panel:SetPoint("CENTER")
        panel:SetMovable(true)
        panel:EnableMouse(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", panel.StartMoving)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        panel.TitleText:SetText("Vendor or Auction — настройки")
        local function heading(text, y)
            local line = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line:SetPoint("TOPLEFT", 25, y)
            line:SetText(text)
        end
        heading("Прибыль и комиссия", -42)
        heading("Медленная продажа", -150)
        heading("Отображение", -218)
        local fields = {
            {"minProfit", "Мин. общая выгода, серебро", 0, 100000, 100, -68},
            {"auctionCut", "Комиссия аукциона, %", 0, 100, 1, -108},
            {"saleRate", "Скорость продаж ниже (0–1)", 0, 1, 1, -176},
            {"iconSize", "Размер значков (8–32)", 8, 32, 1, -244},
        }
        local boxes = {}
        for i, field in ipairs(fields) do
            local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            title:SetPoint("TOPLEFT", 30, field[6])
            title:SetText(field[2])
            local box = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
            box:SetSize(85, 25)
            box:SetPoint("TOPRIGHT", -38, field[6] + 6)
            box:SetAutoFocus(false)
            box:SetMaxLetters(12)
            boxes[i] = box
        end
        local explanation = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        explanation:SetPoint("TOPLEFT", 25, -286)
        explanation:SetPoint("RIGHT", -25, 0)
        explanation:SetJustifyH("LEFT")
        explanation:SetText("При скорости ниже порога советуем торговца. Красная цена — низкая скорость продажи. Залог не включён.")
        local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("TOPLEFT", 25, -360)
        status:SetPoint("RIGHT", -25, 0)
        status:SetJustifyH("LEFT")
        local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        save:SetSize(130, 25)
        save:SetPoint("BOTTOM", 0, 22)
        save:SetText("Сохранить")
        save:SetScript("OnClick", function()
            local values = {}
            for i, field in ipairs(fields) do
                local n = tonumber((boxes[i]:GetText():gsub(",", ".")))
                if not n or n < field[3] or n > field[4] then
                    status:SetText("Проверьте значение: " .. field[2])
                    return
                end
                values[field[1]] = n * field[5]
            end
            for key, n in pairs(values) do VendorOrAuctionDB[key] = n end
            refreshAll()
            panel:Hide()
            print("|cffffcc00Vendor or Auction:|r настройки сохранены.")
        end)
        panel:SetScript("OnShow", function()
            for i, field in ipairs(fields) do boxes[i]:SetText(tostring(VendorOrAuctionDB[field[1]] / field[5])) end
            status:SetText(TSM_API and "TSM обнаружен. Цена: минимум выкупа, затем средняя региональная." or "TSM не обнаружен. Проверьте, включён ли аддон.")
        end)
    end
    panel:Show()
    panel:Raise()
end

VendorOrAuctionLogic.openSettings = showSettings
VendorOrAuctionLogic.refresh = refreshAll

local function createShortcut()
    if not LibStub then return end
    local broker = LibStub("LibDataBroker-1.1", true)
    local icons = LibStub("LibDBIcon-1.0", true)
    if not broker or not icons then return end
    VendorOrAuctionDB.minimap = VendorOrAuctionDB.minimap or {}
    local data = broker:NewDataObject("VendorOrAuction", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        OnClick = function() if VendorOrAuctionLogic.openOverview then VendorOrAuctionLogic.openOverview() else showSettings() end end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Vendor or Auction")
            tooltip:AddLine("Нажмите, чтобы разобрать сумки", 1, 1, 1)
        end,
    })
    if data then icons:Register("VendorOrAuction", data, VendorOrAuctionDB.minimap) end
end
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        VendorOrAuctionDB = type(VendorOrAuctionDB) == "table" and VendorOrAuctionDB or {}
        VendorOrAuctionDB.keep = type(VendorOrAuctionDB.keep) == "table" and VendorOrAuctionDB.keep or {}
        VendorOrAuctionDB.alwaysVendor = type(VendorOrAuctionDB.alwaysVendor) == "table" and VendorOrAuctionDB.alwaysVendor or {}
        for key, default in pairs(defaults) do
            if type(VendorOrAuctionDB[key]) ~= "number" then VendorOrAuctionDB[key] = default end
        end
        -- The inventory summary belongs to Syndicator; keep it available on Shift.
        if SYNDICATOR_CONFIG and not VendorOrAuctionDB.syndicatorShiftConfigured then
            SYNDICATOR_CONFIG.show_tooltips_on_shift = true
            VendorOrAuctionDB.syndicatorShiftConfigured = true
        end
        registerBaganator()
    elseif event == "PLAYER_LOGIN" then
        if VendorOrAuctionLogic.refreshQuests then pcall(VendorOrAuctionLogic.refreshQuests) end
        createShortcut()
        hookFrame(ContainerFrameCombinedBags)
        if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
            for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do hookFrame(frame) end
        end
        if not TSM_API then print("|cffffcc00Vendor or Auction:|r TSM не найден. Проверьте, включён ли он.") end
        schedule()
    elseif event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
        VendorOrAuctionLogic.invalidateBagCounts()
        refreshAll()
    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
        if VendorOrAuctionLogic.refreshQuests then pcall(VendorOrAuctionLogic.refreshQuests) end
        refreshAll()
    elseif event ~= "ADDON_LOADED" then schedule() end
end)

SLASH_VENDORORAUCTION1 = "/voa"
SlashCmdList.VENDORORAUCTION = function(msg)
    if msg and msg:match("^%s*settings%s*$") then showSettings()
    elseif VendorOrAuctionLogic.openOverview then VendorOrAuctionLogic.openOverview()
    else showSettings() end
end
