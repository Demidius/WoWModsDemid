local ns = {}
VendorOrAuctionLogic = ns
ns.labels = {vendor = "Торговцу", auction = "Аукцион", keep = "Хранить", check = "Проверить"}
ns.icons = {vendor = {"$", 1, .78, .08}, auction = {"A", .3, 1, .35}, keep = {"K", .4, .75, 1}, check = {"?", 1, .6, .15}}

function ns.playerBags()
    local bags, seen = {}, {}
    local function add(bag)
        if type(bag) == "number" and bag >= 0 and not seen[bag] then
            seen[bag] = true
            bags[#bags + 1] = bag
        end
    end
    for bag = 0, (NUM_BAG_SLOTS or 4) do add(bag) end
    if Enum and Enum.BagIndex then add(Enum.BagIndex.ReagentBag) end
    return bags
end

local bagCounts

function ns.invalidateBagCounts()
    bagCounts = nil
end

local function countInBags(itemID)
    if not bagCounts then
        local counts = {}
        if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
            for _, bag in ipairs(ns.playerBags()) do
                local slots = C_Container.GetContainerNumSlots(bag) or 0
                for slot = 1, slots do
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local id = info and (info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)))
                    if id and not info.isBound then
                        counts[id] = (counts[id] or 0) + (info.stackCount or 1)
                    end
                end
            end
        end
        bagCounts = counts
    end
    return bagCounts[itemID] or 0
end
local function price(source, item)
    if not TSM_API or type(TSM_API.GetCustomPriceValue) ~= "function" then return nil end
    local ok, result = pcall(TSM_API.GetCustomPriceValue, source, item)
    if ok and type(result) == "number" and result >= 0 then return result end
end

function ns.evaluate(link, context)
    context = context or {}
    local result = {kind = "check", reason = "Недостаточно данных о предмете"}
    if type(link) ~= "string" then return result end
    local id = tonumber(link:match("item:(%d+)"))
    if not id then return result end
    result.id = id
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return result end
    local name, _, _, _, _, _, _, _, _, _, vendor, classID = getInfo(link)
    if not name then result.loading = true return result end
    result.name, result.vendor = name, vendor
    local db = VendorOrAuctionDB
    if db.keep[id] then result.kind, result.reason = "keep", "Ваш список хранения" return result end
    local quest = ns.questForItem and ns.questForItem(id, name)
    if quest or context.quest or classID == 12 then
        result.kind = "keep"
        result.reason = type(quest) == "string" and ("Нужен для задания: " .. quest) or "Предмет активного задания"
        return result
    end
    if db.alwaysVendor[id] then
        if vendor and vendor > 0 then result.kind, result.reason = "vendor", "Ваш список продажи торговцу"
        else result.reason = "Нет цены продажи торговцу" end
        return result
    end
    if not vendor or vendor <= 0 then result.reason = "Нет цены продажи торговцу" return result end
    if context.bound then result.kind, result.reason = "check", "Персональный предмет: аукцион недоступен" return result end
    if not TSM_API then result.reason = "TSM недоступен" return result end
    local item
    if type(TSM_API.ToItemString) == "function" then
        local ok, s = pcall(TSM_API.ToItemString, link)
        if ok and type(s) == "string" then item = s end
    end
    item = item or ("i:" .. id)
    result.price = price("DBMinBuyout", item)
    result.source = result.price and "DBMinBuyout" or "DBMarket"
    if not result.price or result.price <= 0 then result.price = price("DBMarket", item) result.source = "DBMarket" end
    if not result.price or result.price <= 0 then result.reason = "Нет цены аукциона в TSM" return result end
    result.profit = result.price * (1 - db.auctionCut / 100) - vendor
    result.bagCount = countInBags(id)
    if result.bagCount <= 0 then
        result.reason = "Нет подходящих предметов в сумках для расчёта"
        return result
    end
    result.totalProfit = result.profit * result.bagCount
    local rate = price("DBRegionSaleRate * 1000", item)
    result.rate = rate and rate / 1000
    if result.totalProfit < db.minProfit then
        result.kind, result.reason = "vendor", "Общая выгода за все предметы ниже установленного минимума"
    elseif result.rate == nil then
        result.reason = "Нет данных TSM о скорости продаж"
    elseif result.rate < db.saleRate and result.profit < vendor * db.profitPercent / 100 then
        result.kind, result.reason = "vendor", "Медленная продажа и небольшая выгода"
    elseif result.rate < db.saleRate then
        result.reason = "Медленная продажа: решите, стоит ли ждать"
    else
        result.kind, result.reason = "auction", "Выгода и скорость продаж выше заданных порогов"
    end
    return result
end

function ns.safe(link, context)
    local ok, result = pcall(ns.evaluate, link, context)
    if ok and type(result) == "table" then return result end
    return {kind = "check", reason = "Не удалось получить данные"}
end

function ns.context(bag, slot, info)
    local ctx = {bound = info and info.isBound}
    if C_Container.GetContainerItemQuestInfo then
        local ok, q = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        if ok and type(q) == "table" then ctx.quest = q.isQuestItem or (q.questID and q.questID ~= 0) end
    end
    return ctx
end

function ns.money(value)
    if not value then return "нет данных" end
    local sign = value < 0 and "−" or ""
    value = math.floor(math.abs(value) + 0.5)
    if GetCoinTextureString then return sign .. GetCoinTextureString(value) end
    return sign .. value .. " мед."
end
