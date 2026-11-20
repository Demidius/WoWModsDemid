-- Run with Lua 5.1 from the workspace root.
VendorOrAuctionDB = {saleRate = 0.3, minProfit = 100, auctionCut = 5, keep = {}, alwaysVendor = {}}
local quantity, rate, minimum, average, market, recent = 1, 161, 70, 500, 1500, 900
local inventory
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and (inventory and #inventory or 1) or 0 end,
    GetContainerItemInfo = function(_, slot) return inventory and inventory[slot] or {itemID = 123, hyperlink = "item:123", stackCount = quantity} end,
}
GetItemInfo = function() return "Item", nil, nil, nil, nil, nil, nil, nil, nil, nil, 60, 4 end
TSM_API = {
    ToItemString = function(link)
        local suffix = link:match("item:123:(%d+)")
        return suffix and ("i:123:" .. suffix) or "i:123"
    end,
    GetCustomPriceValue = function(source)
        if source == "DBRegionSaleRate * 1000" then return rate end
        if source == "DBMinBuyout" then return minimum end
        if source == "DBRegionSaleAvg" then return average end
        if source == "DBMarket" then return market end
        if source == "DBRecent" then return recent end
    end,
}
dofile("VendorOrAuction/Decision.lua")
local ns, link = VendorOrAuctionLogic, "item:123"
assert(ns.saleRate(link) == 0.161)
assert(ns.evaluate(link).kind == "vendor")
rate = 300
assert(ns.evaluate(link).kind == "auction")
rate = 500
assert(ns.evaluate(link).kind == "auction")
local _, recentPrice, recentSource = ns.tooltipPrices(link)
assert(recentPrice == 900 and recentSource == "Последний снимок", "latest snapshot must be used instead of market average or minimum buyout")
assert(ns.evaluate(link).price == recentPrice, "the recommendation must use the displayed recent price")
recent = 0
local _, zeroRecentPrice = ns.tooltipPrices(link)
assert(zeroRecentPrice == nil and ns.evaluate(link).kind == "check", "zero recent price must not fall back to historical prices")
recent = nil
local _, missingRecentPrice = ns.tooltipPrices(link)
assert(missingRecentPrice == nil and ns.evaluate(link).kind == "check", "missing recent data must not use averages or minimum buyout")
rate = 161
assert(ns.evaluate(link).kind == "vendor", "slow sale needs no auction price")
rate, recent = nil, 1500
assert(ns.evaluate(link).kind == "check", "missing rate must not imply a fast sale")
rate = 500
quantity = 2
ns.invalidateBagCounts()
assert(ns.bagQuantity(link) == 2)
VendorOrAuctionDB.keep[123] = true
assert(ns.evaluate(link).kind == "keep")
VendorOrAuctionDB.keep[123] = nil
ns.questForItem = function() return "Quest" end
assert(ns.evaluate(link).kind == "keep")
ns.questForItem = nil
assert(ns.evaluate(link, {bound = true}).kind == "check")
VendorOrAuctionDB.alwaysVendor[123] = true
assert(ns.evaluate(link, {bound = true}).kind == "vendor")
VendorOrAuctionDB.alwaysVendor[123] = nil
inventory = {
    {itemID = 123, hyperlink = "item:123:1", stackCount = 2},
    {itemID = 123, hyperlink = "item:123:1", stackCount = 1, isBound = true},
    {itemID = 123, hyperlink = "item:123:2", stackCount = 4},
}
ns.invalidateBagCounts()
assert(ns.bagQuantity("item:123:1") == 3 and ns.auctionBagQuantity("item:123:1") == 2, "count only matching and tradable variants")
assert(ns.bagQuantity("item:123:2") == 4, "do not combine variants with the same item ID")
assert(ns.evaluate("item:123:1").bagCount == 2)
recent = 100
assert(ns.evaluate("item:123:1").kind == "vendor", "other variants must not push profit above the threshold")
assert(ns.evaluate("item:123:2").kind == "auction", "the same threshold applies to each variant's own quantity")
assert(ns.isPlayerBagLocation({bagID = 0}) and not ns.isPlayerBagLocation({bagID = -1}) and not ns.isPlayerBagLocation(nil), "bag locations")
print("Decision scenarios passed")
