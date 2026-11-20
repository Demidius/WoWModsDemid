-- Model the settings controls and first-open behavior without the game client.
local widgets, panel, eventFrame = {}, nil, nil
local methods = {}
local fallback = function() end
local widgetMeta = {__index = function(_, key) return methods[key] or fallback end}
local function makeWidget(kind)
    local result = setmetatable({kind = kind, shown = true, scripts = {}, text = ""}, widgetMeta)
    widgets[#widgets + 1] = result
    return result
end
function methods:RegisterEvent() end
function methods:SetScript(event, callback) self.scripts[event] = callback end
function methods:CreateFontString() return makeWidget("FontString") end
function methods:SetText(value)
    self.text = value
    if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function methods:GetText() return self.text end
function methods:Hide() self.shown = false end
function methods:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function methods:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function methods:SetMinMaxValues(minimum, maximum) self.minimum, self.maximum = minimum, maximum end
function methods:SetValueStep(step) self.step = step end
function methods:SetObeyStepOnDrag(value) self.obeyStep = value end

UIParent = {}
CreateFrame = function(kind, name)
    local result = makeWidget(kind)
    if not eventFrame then eventFrame = result end
    if name == "VendorOrAuctionSettings" then
        panel = result
        panel.TitleText = makeWidget("FontString")
    end
    return result
end
C_Timer = {After = function() end}
SlashCmdList = {}
VendorOrAuctionLogic = {}
VendorOrAuctionDB = {minProfit = 250, auctionCut = 7, saleRate = 0.36, iconSize = 21}
assert(loadfile("VendorOrAuction/VendorOrAuction.lua"))("VendorOrAuction")
eventFrame.scripts.OnEvent(nil, "ADDON_LOADED", "VendorOrAuction")
VendorOrAuctionLogic.openSettings()
local boxes, buttons, slider = {}, {}, nil
for _, widget in ipairs(widgets) do
    if widget.kind == "EditBox" then boxes[#boxes + 1] = widget end
    if widget.kind == "Button" then buttons[#buttons + 1] = widget end
    if widget.kind == "Slider" then slider = widget end
end
assert(panel.shown and boxes[1]:GetText() == "2.5" and boxes[2]:GetText() == "7", "first opening must populate saved values")
assert(boxes[3]:GetText() == "0.36" and boxes[4]:GetText() == "21" and slider.value == 0.36)
boxes[3]:SetText("0,51")
assert(slider.value == 0.51 and boxes[3]:GetText() == "0,51", "typing should update the slider without changing the text")
slider:SetValue(0.42)
assert(boxes[3]:GetText() == "0.42", "dragging should update the field")
buttons[1].scripts.OnClick()
assert(boxes[2]:GetText() == "6")
buttons[2].scripts.OnClick()
assert(boxes[2]:GetText() == "7")
buttons[3].scripts.OnClick()
assert(boxes[4]:GetText() == "20")
buttons[4].scripts.OnClick()
assert(boxes[4]:GetText() == "21")
boxes[2]:SetText("100")
buttons[2].scripts.OnClick()
assert(boxes[2]:GetText() == "100", "buttons must obey the maximum")
boxes[4]:SetText("8")
buttons[3].scripts.OnClick()
assert(boxes[4]:GetText() == "8", "buttons must obey the minimum")
buttons[5].scripts.OnClick()
assert(not panel.shown and VendorOrAuctionDB.saleRate == 0.42 and VendorOrAuctionDB.auctionCut == 100 and VendorOrAuctionDB.iconSize == 8)
VendorOrAuctionLogic.openSettings()
assert(panel.shown and boxes[3]:GetText() == "0.42" and slider.value == 0.42, "reopening must show saved values")
boxes[3]:SetText("1.5")
buttons[5].scripts.OnClick()
assert(panel.shown and VendorOrAuctionDB.saleRate == 0.42, "invalid input must not be saved")
print("Settings scenarios passed")
