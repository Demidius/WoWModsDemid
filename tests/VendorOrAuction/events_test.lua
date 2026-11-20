-- Check bag-widget scope and coalescing of bursts of bag/item updates.
local onEvent, pendingTimer, timerCount, baganatorRefreshes, widget = nil, nil, 0, 0, nil
CreateFrame = function()
    return {RegisterEvent = function() end, SetScript = function(_, name, callback)
        if name == "OnEvent" then onEvent = callback end
    end}
end
C_Timer = {After = function(_, callback) timerCount = timerCount + 1; pendingTimer = callback end}
SlashCmdList = {}
Baganator = {API = {
    RegisterCornerWidget = function(_, _, callback) widget = callback end,
    RequestItemButtonsRefresh = function() baganatorRefreshes = baganatorRefreshes + 1 end,
}}
dofile("VendorOrAuction/Decision.lua")
local ns = VendorOrAuctionLogic
ns.safe = function() return {kind = "vendor"} end
assert(loadfile("VendorOrAuction/VendorOrAuction.lua"))("VendorOrAuction")
onEvent(nil, "ADDON_LOADED", "VendorOrAuction")
assert(widget, "Baganator widget should be registered")
local label = {GetFont = function() return "font" end, SetFont = function() end,
    SetShadowColor = function() end, SetShadowOffset = function() end,
    SetText = function(self, value) self.text = value end, SetTextColor = function() end}
assert(widget(label, {itemLink = "item:123", itemLocation = {bagID = 0}}) and label.text == "$")
assert(not widget(label, {itemLink = "item:123", itemLocation = {bagID = -1}}), "bank items must not use bag totals")
assert(not widget(label, {itemLink = "item:123"}), "unknown item location must not be treated as the current bags")
onEvent(nil, "BAG_UPDATE_DELAYED")
onEvent(nil, "GET_ITEM_INFO_RECEIVED")
onEvent(nil, "GET_ITEM_INFO_RECEIVED")
assert(timerCount == 1 and baganatorRefreshes == 0, "bursts should be coalesced")
assert(pendingTimer)()
assert(baganatorRefreshes == 1, "Baganator should refresh once after the burst")
print("Event scenarios passed")
