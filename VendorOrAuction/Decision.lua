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

function ns.isPlayerBagLocation(location)
    if type(location) ~= "table" or type(location.bagID) ~= "number" then return false end
    for _, bag in ipairs(ns.playerBags()) do
        if bag == location.bagID then return true end
    end
    return false
end

local bagCounts, allBagCounts

function ns.invalidateBagCounts()
    bagCounts, allBagCounts = nil, nil
end

-- TSM can value variants of the same item ID differently. Count them separately.
local function itemKey(link)
    if type(link) ~= "string" then return nil end
    if TSM_API and type(TSM_API.ToItemString) == "function" then
        local ok, item = pcall(TSM_API.ToItemString, link)
        if ok and type(item) == "string" and item ~= "" then return item end
    end
    local id = link:match("item:(%d+)")
    return id and ("i:" .. id) or nil
end

local function countInBags(link)
    local wanted = itemKey(link)
    if not wanted then return 0 end
    if not bagCounts then
        local counts, allCounts = {}, {}
        if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
            for _, bag in ipairs(ns.playerBags()) do
                local slots = C_Container.GetContainerNumSlots(bag) or 0
                for slot = 1, slots do
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local itemLink = info and (info.hyperlink or (C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)))
                    local key = itemLink and itemKey(itemLink)
                    if key then
                        local quantity = info.stackCount or 1
                        allCounts[key] = (allCounts[key] or 0) + quantity
                        if not info.isBound then counts[key] = (counts[key] or 0) + quantity end
                    end
                end
            end
        end
        bagCounts, allBagCounts = counts, allCounts
    end
    return bagCounts[wanted] or 0
end
function ns.bagQuantity(link)
    local key = itemKey(link)
    if not key then return nil end
    countInBags(link)
    return allBagCounts and (allBagCounts[key] or 0) or 0
end

function ns.auctionBagQuantity(link)
    return itemKey(link) and countInBags(link) or nil
end

function ns.itemCategory(link)
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return nil end
    local name, _, _, _, _, itemType, subType, _, equipLoc, _, _, classID, subClassID = getInfo(link)
    if not name then return nil end
    local label, icon
    if classID == 2 or classID == 4 then
        icon = "INV_Sword_04"
        local slot = equipLoc and _G[equipLoc]
        if type(slot) ~= "string" or slot == "" then slot = nil end
        label = slot and subType and (slot .. " - " .. subType) or subType or itemType or "Экипировка"
    elseif classID == 19 then
        icon, label = "INV_Misc_Wrench_01", subType or "Инструмент"
    elseif classID == 7 or classID == 5 then
        icon, label = "INV_Misc_Herb_07", "Ремесленный материал"
    elseif classID == 0 and subClassID == 5 then
        icon, label = "INV_Misc_Food_15", "Еда и напитки"
    elseif classID == 0 then
        icon, label = "INV_Potion_54", subType or itemType or "Расходуемое"
    elseif classID == 12 then
        icon, label = "INV_Misc_Note_01", "Предмет задания"
    else
        icon, label = "INV_Misc_Bag_10", subType or itemType or "Предмет"
    end
    return "|TInterface\\Icons\\" .. icon .. ":14:14:0:0|t " .. label
end
local function price(source, item)
    if not TSM_API or type(TSM_API.GetCustomPriceValue) ~= "function" then return nil end
    local ok, result = pcall(TSM_API.GetCustomPriceValue, source, item)
    if ok and type(result) == "number" and result >= 0 then return result end
end

function ns.saleRate(link)
    if type(link) ~= "string" then return nil end
    local id = link:match("item:(%d+)")
    if not id then return nil end
    local item
    if TSM_API and type(TSM_API.ToItemString) == "function" then
        local ok, converted = pcall(TSM_API.ToItemString, link)
        if ok and type(converted) == "string" then item = converted end
    end
    local rate = price("DBRegionSaleRate * 1000", item or ("i:" .. id))
    return rate and rate / 1000
end

-- Prices for the compact tooltip are independent of recommendations and bag state.
function ns.tooltipPrices(link)
    local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo or not link then return end
    local _, _, _, _, _, _, _, _, _, _, vendor = getInfo(link)
    local item
    if TSM_API and type(TSM_API.ToItemString) == "function" then
        local ok, converted = pcall(TSM_API.ToItemString, link)
        if ok and type(converted) == "string" then item = converted end
    end
    if not item then
        local id = link:match("item:(%d+)")
        if id then item = "i:" .. id end
    end
    if not item then return vendor end
    local auction = price("DBMarket", item)
    if auction and auction > 0 then return vendor, auction, "Рыночная цена" end
    auction = price("DBRegionSaleAvg", item)
    if auction and auction > 0 then return vendor, auction, "Средняя продажа" end
    return vendor
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
    result.rate = ns.saleRate(link)
    local _, auction, source = ns.tooltipPrices(link)
    result.price, result.source = auction, source
    if not result.price or result.price <= 0 then
        if result.rate and result.rate < db.saleRate then
            result.kind, result.reason = "vendor", "Скорость продаж ниже установленного порога"
        else
            result.reason = "Нет цены аукциона в TSM"
        end
        return result
    end
    result.profit = result.price * (1 - db.auctionCut / 100) - vendor
    result.bagCount = countInBags(link)
    if result.bagCount <= 0 then
        result.reason = "Нет подходящих предметов в сумках для расчёта"
        return result
    end
    result.totalProfit = result.profit * result.bagCount
    if result.rate and result.rate < db.saleRate then
        result.kind, result.reason = "vendor", "Скорость продаж ниже установленного порога"
    elseif result.totalProfit < db.minProfit then
        result.kind, result.reason = "vendor", "Общая выгода за все предметы ниже установленного минимума"
    elseif result.rate == nil then
        result.reason = "Нет данных TSM о скорости продаж"
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
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        local ok, formatted = pcall(C_CurrencyInfo.GetCoinTextureString, value, 12)
        if ok and formatted and formatted ~= "" then return sign .. formatted end
    end
    if GetCoinTextureString then
        local ok, formatted = pcall(GetCoinTextureString, value, 12)
        if ok and formatted and formatted ~= "" then return sign .. formatted end
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor(value / 100) % 100
    local copper = value % 100
    local parts = {}
    if gold > 0 then parts[#parts + 1] = gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t" end
    if silver > 0 then parts[#parts + 1] = silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:0:0|t" end
    if copper > 0 or #parts == 0 then parts[#parts + 1] = copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:0:0|t" end
    return sign .. table.concat(parts, " ")
end
