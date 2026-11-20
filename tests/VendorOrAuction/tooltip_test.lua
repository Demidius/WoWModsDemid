-- Exercise both aligned prices and fallback when the client protects text widths.
local file = assert(io.open("VendorOrAuction/Overview.lua", "rb"))
local source = file:read("*a")
file:close()
local start = assert(source:find("local function addPriceTable", 1, true))
local finish = assert(source:find("if TooltipDataProcessor", start, true))
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
print("Tooltip scenarios passed")
