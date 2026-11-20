-- Exercise both aligned prices and fallback when the client protects text widths.
local file = assert(io.open("VendorOrAuction/Overview.lua", "rb"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function addPriceTable", 1, true))
local finish = assert(source:find("local function getOwnerBound", start, true))
local chunk = "local ns = VendorOrAuctionLogic\n" .. source:sub(start, finish - 1) .. "\nreturn addPriceTable"
VendorOrAuctionLogic = {money = function(value) return tostring(value) end}
local addPriceTable = assert(loadstring(chunk))()
local protectedWidth = false
issecretvalue = function(value) return type(value) == "table" and value.protected end
local function makeFont()
    return {
        SetFont = function() end, SetTextColor = function(self, r, g, b) self.color = {r, g, b} end,
        SetText = function(self, text) self.text = text end,
        Show = function(self) self.visible = true end, Hide = function(self) self.visible = false end,
        GetStringWidth = function() return protectedWidth and {protected = true} or 20 end,
        ClearAllPoints = function() end, SetPoint = function() end,
    }
end
local tooltip = {lines = {}}
function tooltip:HookScript(_, callback) self.clear = callback end
function tooltip:GetName() return "AuditTooltip" end
function tooltip:NumLines() return #self.lines end
function tooltip:AddDoubleLine(left, right)
    self.lines[#self.lines + 1] = {left, right}
    _G["AuditTooltipTextRight" .. #self.lines] = {
        alpha = 1, GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, alpha) self.alpha = alpha end,
        GetFont = function() return "font", 12, "" end,
    }
end
function tooltip:CreateFontString() return makeFont() end
addPriceTable(tooltip, 60, 1500, 1, 1, false, true)
assert(#tooltip.lines == 3 and tooltip.lines[3][1] == "Аукцион")
assert(tooltip.voaPriceTable.rows[3].unit.color[2] == 0.33, "slow sale must be red")
assert(_G.AuditTooltipTextRight3.alpha == 0, "aligned prices should replace native values")
tooltip.clear()
tooltip.lines = {}
protectedWidth = true
addPriceTable(tooltip, 60, 1500, 1, 1, false, true)
assert(#tooltip.lines == 3 and tooltip.lines[3][2]:find("|cffff5555", 1, true), "fallback must retain red auction price")
assert(_G.AuditTooltipTextRight3.alpha == 1, "native prices must remain visible")
assert(not tooltip.voaPriceTable.rows[1].unit.visible, "fallback must hide overlays")

local ownerStart = assert(source:find("local function getOwnerBound", 1, true))
local ownerEnd = assert(source:find("if TooltipDataProcessor", ownerStart, true))
local getOwnerBound = assert(loadstring(source:sub(ownerStart, ownerEnd - 1) .. "\nreturn getOwnerBound"))()
C_Container = {GetContainerItemInfo = function(bag, slot) return {isBound = bag == 1 and slot == 2} end}
local owner = {GetBagID = function() return 1 end, GetID = function() return 2 end}
assert(getOwnerBound(owner) == true, "personal items in default bags must be recognized")
assert(getOwnerBound({BGR = {isBound = true}}) == true, "Baganator binding must be recognized")
assert(not getOwnerBound({}) and not getOwnerBound(nil))

local compactStart = assert(source:find("local function compactNativeLines", 1, true))
local compactEnd = assert(source:find("-- The standard tooltip", compactStart, true))
local compact = assert(loadstring(source:sub(compactStart, compactEnd - 1) .. "\nreturn compactNativeLines"))()
GetItemInfo = function() return "Item", nil, nil, 15, 10 end
_G.AuditCompactTextLeft1 = {GetText = function() return "Item" end, GetTextColor = function() return 1, 1, 1 end}
local compactTip = {GetName = function() return "AuditCompact" end, NumLines = function() return 1 end,
    ClearLines = function(self) self.cleared = true end,
    AddDoubleLine = function(self, left, right) self.header = {left, right} end,
    AddLine = function() end}
compact(compactTip, "item:123")
assert(compactTip.cleared and compactTip.header[2] == "Lv. 15 / 10", "levels must appear even without duplicate lines")
print("Tooltip scenarios passed")
