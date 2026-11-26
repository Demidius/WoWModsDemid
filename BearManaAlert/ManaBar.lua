local frame = CreateFrame("Frame", "BearManaAlertBar", UIParent, "BackdropTemplate")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
frame:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
frame:SetBackdropBorderColor(0, 0, 0, 1)
local bar = CreateFrame("StatusBar", nil, frame)
bar:SetPoint("TOPLEFT", 1, -1)
bar:SetPoint("BOTTOMRIGHT", -1, 1)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
local pixelBackground = bar:CreateTexture(nil, "BACKGROUND")
pixelBackground:SetAllPoints(bar)
pixelBackground:SetColorTexture(0.015, 0.015, 0.08, 0.95)
pixelBackground:Hide()
local pixelFrame = bar:CreateTexture(nil, "OVERLAY", nil, 1)
pixelFrame:SetTexture("Interface\\AddOns\\BearManaAlert\\PixelManaFrame.tga")
pixelFrame:SetAllPoints(frame)
pixelFrame:Hide()
local arcadeFrame = bar:CreateTexture(nil, "OVERLAY", nil, 1)
arcadeFrame:SetTexture("Interface\\AddOns\\BearManaAlert\\ArcadeManaFrame.tga")
arcadeFrame:SetAllPoints(frame)
arcadeFrame:Hide()
local pixelDividers = {}
for i = 1, 9 do
    local line = bar:CreateTexture(nil, "OVERLAY", nil, 0)
    line:SetColorTexture(0.01, 0.01, 0.08, 0.85)
    line:SetHeight(2)
    line:Hide()
    pixelDividers[i] = line
end
local marker = bar:CreateTexture(nil, "OVERLAY")
marker:SetColorTexture(1, 0.85, 0.2, 1)
marker:SetWidth(2)
local thresholdBorder = bar:CreateTexture(nil, "OVERLAY", nil, 2)
thresholdBorder:SetColorTexture(0, 0, 0, 1)
thresholdBorder:SetWidth(5)
local thresholdMarker = bar:CreateTexture(nil, "OVERLAY", nil, 3)
thresholdMarker:SetColorTexture(1, 1, 1, 1)
thresholdMarker:SetWidth(2)
local threshold2Border = bar:CreateTexture(nil, "OVERLAY", nil, 2)
threshold2Border:SetColorTexture(0, 0, 0, 1)
threshold2Border:SetWidth(5)
local threshold2Marker = bar:CreateTexture(nil, "OVERLAY", nil, 3)
threshold2Marker:SetColorTexture(0.2, 1, 1, 1)
threshold2Marker:SetWidth(2)
local function createAlert()
    local holder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    holder:SetSize(32, 36)
    holder:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2})
    local alert = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    alert:SetPoint("CENTER")
    alert:SetText("!")
    alert:SetTextColor(1, 0.08, 0.08)
    alert:SetShadowColor(0, 0, 0, 1)
    alert:SetShadowOffset(1, -1)
    holder:Hide()
    return holder, alert
end
local db, isDruid, options, signOptions, dragging, lastLow, lastLow2, appliedBarStyle
local thresholdAlert, thresholdAlertText = createAlert()
local threshold2Alert, threshold2AlertText = createAlert()
frame:SetScript("OnUpdate", function()
    if thresholdAlert:IsShown() or threshold2Alert:IsShown() then
        local function pulse(index)
            if not db or not db["signBlink" .. index] then return 1 end
            return 0.25 + 0.75 * (0.5 + 0.5 * math.sin(GetTime() * db["signSpeed" .. index]))
        end
        thresholdAlertText:SetAlpha(pulse(1))
        threshold2AlertText:SetAlpha(pulse(2))
    end
end)
local alertCurves = {}
local function updateRestrictedAlert(holder, threshold, enabled)
    if not enabled then holder:Hide(); return end
    local curve = alertCurves[threshold]
    if not curve then
        curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        -- Include the threshold itself, as for the sound and bar colour.
        curve:AddPoint(0, 1)
        if threshold < 100 then curve:AddPoint(threshold / 100 + 0.000001, 0) end
        alertCurves[threshold] = curve
    end
    holder:SetAlpha(UnitPowerPercent("player", 0, false, curve))
    holder:Show()
end
local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetPoint("CENTER")
local ownsColorPicker, pickerOriginalStrata, pickerHooked
local colorCurve, colorCurveKey
local signSymbols = {"!", "!!", "?", "?!", "*", "**", "+", "X", "#", "^"}
local colors = {{0.12, 0.47, 1, "Синий"}, {0.25, 0.8, 0.4, "Зелёный"}, {0.7, 0.35, 1, "Фиолетовый"}, {0.1, 0.8, 0.8, "Бирюзовый"}}

local function colorAt(percent)
    if db.threshold2Enabled and percent <= db.threshold2 then return db.lowColor2 end
    if percent <= db.threshold then return db.lowColor end
    return db.normalColor
end

local function applyRestrictedColor()
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitPowerPercent and Enum and Enum.LuaCurveType and CreateColor) then return false end
    local key = table.concat({db.threshold, db.threshold2, db.threshold2Enabled and 1 or 0, db.normalColor[1], db.normalColor[2], db.normalColor[3], db.lowColor[1], db.lowColor[2], db.lowColor[3], db.lowColor2[1], db.lowColor2[2], db.lowColor2[3]}, ":")
    if key ~= colorCurveKey then
        local curve = C_CurveUtil.CreateColorCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        local function point(x, percent)
            local c = colorAt(percent)
            curve:AddPoint(x, CreateColor(c[1], c[2], c[3], 1))
        end
        point(0, 0)
        local boundaries = {db.threshold}
        if db.threshold2Enabled then boundaries[#boundaries + 1] = db.threshold2 end
        table.sort(boundaries)
        local last
        for _, boundary in ipairs(boundaries) do
            if boundary < 100 and boundary ~= last then point(boundary / 100 + 0.000001, boundary + 0.0001) end
            last = boundary
        end
        point(1, 100)
        colorCurve, colorCurveKey = curve, key
    end
    local color = UnitPowerPercent("player", 0, false, colorCurve)
    bar:SetStatusBarColor(color:GetRGBA())
    return true
end

local function cost()
    local id = IsPlayerSpell(9634) and 9634 or (IsPlayerSpell(5487) and 5487)
    if not id then return end
    local costs = C_Spell and C_Spell.GetSpellPowerCost and C_Spell.GetSpellPowerCost(id) or (GetSpellPowerCost and GetSpellPowerCost(id))
    if costs then
        for _, item in ipairs(costs) do
            if item.type == 0 and item.cost and item.cost > 0 then return item.cost end
        end
    end
end
local function refresh(silent, enteringCombat)
    if not db then return end
    local signPreview = signOptions and signOptions:IsShown()
    local preview = signPreview or (options and options:IsShown() and db.unlocked)
    if not isDruid or (not preview and (not db.show or (db.combat and not UnitAffectingCombat("player")))) then frame:Hide(); lastLow = nil; lastLow2 = nil; return end
    frame:Show()
    frame:EnableMouse(db.unlocked or IsShiftKeyDown() or dragging)
    local vertical = db.style == "pixel"
    local arcade = db.style == "arcade"
    local decorated = vertical or arcade
    if appliedBarStyle ~= db.style then
        bar:SetStatusBarTexture(arcade and "Interface\\AddOns\\BearManaAlert\\ArcadeManaFill.tga" or "Interface\\TargetingFrame\\UI-StatusBar")
        appliedBarStyle = db.style
    end
    local length, thickness = db.width * db.scale / 100, db.height * db.scale / 100
    frame:SetSize(vertical and thickness * 2.5 or length, vertical and length or (arcade and thickness * 2.5 or thickness))
    frame:SetBackdropColor(0.04, 0.04, 0.06, decorated and 0 or 0.85)
    frame:SetBackdropBorderColor(0, 0, 0, decorated and 0 or 1)
    bar:ClearAllPoints()
    if vertical then
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", thickness * 2.5 * 28 / 64, -length * 7 / 256)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -thickness * 2.5 * 28 / 64, length * 7 / 256)
    elseif arcade then
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", length * 72 / 256, -thickness * 2.5 * 16 / 64)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -length * 35 / 256, thickness * 2.5 * 19 / 64)
    else
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    pixelFrame:SetShown(vertical)
    arcadeFrame:SetShown(arcade)
    pixelBackground:SetShown(decorated)
    local barLength = vertical and length * 242 / 256 or (arcade and length * 149 / 256 or length - 2)
    for i, line in ipairs(pixelDividers) do
        line:ClearAllPoints()
        if vertical then
            local y = barLength * i / 10
            line:SetHeight(2)
            line:SetPoint("LEFT", bar, "BOTTOMLEFT", 0, y)
            line:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, y)
        end
        line:SetShown(vertical)
    end
    local mana, maximum = UnitPower("player", 0), UnitPowerMax("player", 0)
    local thresholdX = math.max(2.5, math.min(barLength - 2.5, barLength * db.threshold / 100))
    for _, line in ipairs({thresholdBorder, thresholdMarker}) do
        line:ClearAllPoints()
        if vertical then
            line:SetHeight(line == thresholdBorder and 5 or 2)
            local y = barLength * db.threshold / 100
            line:SetPoint("LEFT", bar, "BOTTOMLEFT", 0, y)
            line:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, y)
        else
            line:SetWidth(line == thresholdBorder and 5 or 2)
            line:SetPoint("TOP", bar, "TOPLEFT", thresholdX, 0)
            line:SetPoint("BOTTOM", bar, "BOTTOMLEFT", thresholdX, 0)
        end
    end
    local threshold2X = math.max(2.5, math.min(barLength - 2.5, barLength * db.threshold2 / 100))
    for _, line in ipairs({threshold2Border, threshold2Marker}) do
        line:ClearAllPoints()
        if vertical then
            line:SetHeight(line == threshold2Border and 5 or 2)
            local y = barLength * db.threshold2 / 100
            line:SetPoint("LEFT", bar, "BOTTOMLEFT", 0, y)
            line:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, y)
        else
            line:SetWidth(line == threshold2Border and 5 or 2)
            line:SetPoint("TOP", bar, "TOPLEFT", threshold2X, 0)
            line:SetPoint("BOTTOM", bar, "BOTTOMLEFT", threshold2X, 0)
        end
        line:SetShown(db.threshold2Enabled)
    end
    local fontPath, fontSize, fontFlags = GameFontNormalHuge:GetFont()
    if fontPath then
        thresholdAlertText:SetFont(fontPath, fontSize * db.signSize1 / 100, fontFlags)
        threshold2AlertText:SetFont(fontPath, fontSize * db.signSize2 / 100, fontFlags)
    end
    thresholdAlertText:SetText(signSymbols[db.signSymbol1])
    threshold2AlertText:SetText(signSymbols[db.signSymbol2])
    thresholdAlertText:SetTextColor(unpack(db.signColor1))
    threshold2AlertText:SetTextColor(unpack(db.signColor2))
    for _, holder in ipairs({thresholdAlert, threshold2Alert}) do
        if vertical then
            holder:SetBackdropColor(0.07, 0.03, 0.01, 0.9)
            holder:SetBackdropBorderColor(1, 0.7, 0.15, 1)
        elseif arcade then
            holder:SetBackdropColor(0.08, 0.03, 0.18, 0.95)
            holder:SetBackdropBorderColor(1, 0.15, 0.25, 1)
        else
            holder:SetBackdropColor(0, 0, 0, 0)
            holder:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end
    thresholdAlert:ClearAllPoints()
    if vertical then thresholdAlert:SetPoint("LEFT", bar, "BOTTOMRIGHT", db.signOffset1, barLength * db.threshold / 100)
    else thresholdAlert:SetPoint("BOTTOM", bar, "TOPLEFT", thresholdX, db.signOffset1) end
    threshold2Alert:ClearAllPoints()
    if vertical then threshold2Alert:SetPoint("LEFT", bar, "BOTTOMRIGHT", db.signOffset2, barLength * db.threshold2 / 100)
    else threshold2Alert:SetPoint("BOTTOM", bar, "TOPLEFT", threshold2X, db.signOffset2) end
    -- Bear cost can still be displayed when only current mana is restricted.
    if not (issecretvalue and issecretvalue(maximum)) and maximum and maximum > 0 then
        local bear = cost()
        if bear and bear <= maximum then
            local bearX = barLength * bear / maximum
            marker:ClearAllPoints()
            if vertical then
                marker:SetHeight(2)
                local y = barLength * bear / maximum
                marker:SetPoint("LEFT", bar, "BOTTOMLEFT", 0, y)
                marker:SetPoint("RIGHT", bar, "BOTTOMRIGHT", 0, y)
            else
                marker:SetWidth(2)
                marker:SetPoint("TOP", bar, "TOPLEFT", bearX, 0)
                marker:SetPoint("BOTTOM", bar, "BOTTOMLEFT", bearX, 0)
            end
            marker:Show()
        else marker:Hide() end
    else marker:Hide() end
    if issecretvalue and (issecretvalue(mana) or issecretvalue(maximum)) then
        bar:SetMinMaxValues(0, maximum)
        bar:SetValue(mana)
        local ok, applied = pcall(applyRestrictedColor)
        if not ok or not applied then bar:SetStatusBarColor(unpack(db.normalColor)) end
        text:SetText("")
        local ok = pcall(function()
            if signPreview then
                thresholdAlert:SetAlpha(1); threshold2Alert:SetAlpha(1)
                thresholdAlert:SetShown(db.sign1)
                threshold2Alert:SetShown(db.threshold2Enabled and db.sign2)
            else
                updateRestrictedAlert(thresholdAlert, db.threshold, db.sign1)
                updateRestrictedAlert(threshold2Alert, db.threshold2, db.threshold2Enabled and db.sign2)
            end
        end)
        if not ok then thresholdAlert:Hide(); threshold2Alert:Hide() end
        lastLow = nil
        lastLow2 = nil
        return
    end
    maximum = math.max(maximum or 0, 1)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(mana)
    local low = mana * 100 <= maximum * db.threshold
    local low2 = db.threshold2Enabled and mana * 100 <= maximum * db.threshold2
    thresholdAlert:SetAlpha(1); threshold2Alert:SetAlpha(1)
    thresholdAlert:SetShown(db.sign1 and (signPreview or low))
    threshold2Alert:SetShown(db.threshold2Enabled and db.sign2 and (signPreview or low2))
    local c = low2 and db.lowColor2 or (low and db.lowColor or db.normalColor)
    bar:SetStatusBarColor(c[1], c[2], c[3])
    if not silent and (((lastLow == false or (enteringCombat and db.combat and lastLow == nil)) and low and db.thresholdSound) or ((lastLow2 == false or (enteringCombat and db.combat and lastLow2 == nil)) and low2 and db.threshold2Sound)) and not UnitIsDeadOrGhost("player") then
        PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
    lastLow = low
    lastLow2 = low2
    if db.text == 1 then text:SetText(string.format("%d / %d", mana, maximum))
    elseif db.text == 2 then text:SetText(string.format("%d%%", math.floor(mana * 100 / maximum + 0.5)))
    elseif db.text == 3 then text:SetText(string.format("%d / %d  (%d%%)", mana, maximum, math.floor(mana * 100 / maximum + 0.5)))
    else text:SetText("") end

end
frame:SetScript("OnDragStart", function(self)
    if db and (db.unlocked or IsShiftKeyDown()) then dragging = true; self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
    if not dragging then return end
    self:StopMovingOrSizing()
    dragging = false
    local x, y = self:GetCenter()
    local px, py = UIParent:GetCenter()
    if x and y and px and py then
        db.x, db.y = x - px, y - py
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    end
    refresh(true)
end)
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UNIT_POWER_UPDATE")
events:RegisterEvent("UNIT_MAXPOWER")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("MODIFIER_STATE_CHANGED")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= "BearManaAlert" then return end
        BearManaAlertDB.bar = type(BearManaAlertDB.bar) == "table" and BearManaAlertDB.bar or {}
        db = BearManaAlertDB.bar
        if db.style ~= "pixel" and db.style ~= "arcade" then db.style = "classic" end
        if db.show == nil then db.show = true end
        if db.combat == nil then db.combat = false end
        if db.unlocked == nil then db.unlocked = false end
        db.width = math.max(100, math.min(600, tonumber(db.width) or 260))
        db.height = math.max(10, math.min(60, tonumber(db.height) or 24))
        db.styles = type(db.styles) == "table" and db.styles or {}
        for _, name in ipairs({"classic", "pixel", "arcade"}) do
            local saved = type(db.styles[name]) == "table" and db.styles[name] or {}
            saved.width = math.max(100, math.min(600, tonumber(saved.width) or db.width))
            saved.height = math.max(10, math.min(60, tonumber(saved.height) or db.height))
            saved.scale = math.max(50, math.min(200, tonumber(saved.scale) or 100))
            db.styles[name] = saved
        end
        db.width, db.height, db.scale = db.styles[db.style].width, db.styles[db.style].height, db.styles[db.style].scale
        db.x, db.y = tonumber(db.x) or 0, tonumber(db.y) or -150
        db.color = math.max(1, math.min(#colors, math.floor(tonumber(db.color) or 1)))
        local oldColor = colors[db.color]
        local function validColor(value, fallback)
            if type(value) ~= "table" then return {fallback[1], fallback[2], fallback[3]} end
            return {math.max(0, math.min(1, tonumber(value[1]) or fallback[1])), math.max(0, math.min(1, tonumber(value[2]) or fallback[2])), math.max(0, math.min(1, tonumber(value[3]) or fallback[3]))}
        end
        db.normalColor = validColor(db.normalColor, oldColor)
        db.lowColor = validColor(db.lowColor, {0.85, 0.16, 0.16})
        db.lowColor2 = validColor(db.lowColor2, {1, 0.2, 0.7})
        db.signColor = validColor(db.signColor, {1, 0.08, 0.08})
        db.signSymbol = math.max(1, math.min(#signSymbols, math.floor(tonumber(db.signSymbol) or 1)))
        db.threshold = math.max(0, math.min(100, tonumber(db.threshold) or 30))
        db.threshold2 = math.max(0, math.min(100, tonumber(db.threshold2) or 15))
        if db.threshold2Enabled == nil then db.threshold2Enabled = false end
        if db.threshold2Sound == nil then db.threshold2Sound = true end
        if db.thresholdSound == nil then db.thresholdSound = true end
        if db.sign1 == nil then db.sign1 = true end
        if db.sign2 == nil then db.sign2 = true end
        if db.signBlink == nil then db.signBlink = true end
        db.signSize = math.max(50, math.min(250, tonumber(db.signSize) or 100))
        db.signOffset = math.max(-40, math.min(100, tonumber(db.signOffset) or 8))
        db.signSpeed = math.max(1, math.min(15, tonumber(db.signSpeed) or 7))
        for i = 1, 2 do
            local suffix = tostring(i)
            db["signColor" .. suffix] = validColor(db["signColor" .. suffix], db.signColor)
            db["signSymbol" .. suffix] = math.max(1, math.min(#signSymbols, math.floor(tonumber(db["signSymbol" .. suffix]) or db.signSymbol)))
            db["signSize" .. suffix] = math.max(50, math.min(250, tonumber(db["signSize" .. suffix]) or db.signSize))
            db["signOffset" .. suffix] = math.max(-40, math.min(100, tonumber(db["signOffset" .. suffix]) or db.signOffset))
            db["signSpeed" .. suffix] = math.max(1, math.min(15, tonumber(db["signSpeed" .. suffix]) or db.signSpeed))
            if db["signBlink" .. suffix] == nil then db["signBlink" .. suffix] = db.signBlink end
        end
        db.text = math.max(1, math.min(4, math.floor(tonumber(db.text) or 3)))
        local _, class = UnitClass("player")
        isDruid = class == "DRUID"
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    elseif (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") and arg ~= "player" then return end
    refresh(event == "MODIFIER_STATE_CHANGED" or event == "ADDON_LOADED", event == "PLAYER_REGEN_DISABLED")
end)
local timer = 0
events:SetScript("OnUpdate", function(_, elapsed)
    timer = timer + elapsed
    if timer >= 1 then timer = 0; refresh() end
end)

local function openSignSettings()
    if options then options:Hide() end
    if signOptions then signOptions:Show(); return end
    signOptions = CreateFrame("Frame", "BearManaAlertSignSettings", UIParent, "BasicFrameTemplateWithInset")
    signOptions:SetSize(420, 535)
    signOptions:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
    signOptions:SetFrameStrata("DIALOG")
    signOptions:SetClampedToScreen(true)
    signOptions:SetMovable(true)
    signOptions:EnableMouse(true)
    signOptions:RegisterForDrag("LeftButton")
    signOptions:SetScript("OnDragStart", signOptions.StartMoving)
    signOptions:SetScript("OnDragStop", signOptions.StopMovingOrSizing)
    signOptions.TitleText:SetText("MyMana — настройки знака")
    table.insert(UISpecialFrames, "BearManaAlertSignSettings")
    local function checkbox(y, title, key)
        local button = CreateFrame("CheckButton", nil, signOptions, "UICheckButtonTemplate")
        button:SetPoint("TOPLEFT", 22, y)
        local caption = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        caption:SetPoint("LEFT", button, "RIGHT", 2, 0)
        caption:SetText(title)
        button:SetScript("OnClick", function(self) db[key] = self:GetChecked() and true or false; refresh(true) end)
        return button
    end
    local sign1 = checkbox(-40, "Знак для порога 1", "sign1")
    local sign2 = checkbox(-72, "Знак для порога 2", "sign2")
    local editing, updating = 1, false
    local blink = checkbox(-104, "Мигание выбранного знака", "signBlink")
    blink:SetScript("OnClick", function(self) db["signBlink" .. editing] = self:GetChecked() and true or false; refresh(true) end)
    local function slider(name, title, y, min, max, key, suffix)
        local heading = signOptions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 30, y)
        local control = CreateFrame("Slider", name, signOptions, "OptionsSliderTemplate")
        control:SetPoint("TOPLEFT", 36, y - 25)
        control:SetWidth(345)
        control:SetMinMaxValues(min, max)
        control:SetValueStep(1)
        control:SetObeyStepOnDrag(true)
        _G[name .. "Low"]:SetText(tostring(min))
        _G[name .. "High"]:SetText(tostring(max))
        _G[name .. "Text"]:SetText("")
        local function updateLabel() heading:SetText(title .. ": " .. db[key .. editing] .. (suffix or "")) end
        control:SetScript("OnValueChanged", function(_, value)
            if updating then return end
            db[key .. editing] = math.floor(value + 0.5)
            updateLabel(); refresh(true)
        end)
        return control, updateLabel
    end
    local size, sizeLabel = slider("BearManaSignSizeSlider", "Размер", -153, 50, 250, "signSize", "%")
    local offset, offsetLabel = slider("BearManaSignOffsetSlider", "Высота над полоской", -220, -40, 100, "signOffset")
    local speed, speedLabel = slider("BearManaSignSpeedSlider", "Скорость мигания", -287, 1, 15, "signSpeed")
    local colorButton = CreateFrame("Button", nil, signOptions, "UIPanelButtonTemplate")
    colorButton:SetSize(150, 25)
    colorButton:SetPoint("TOPRIGHT", -28, -350)
    colorButton:SetText("Цвет знака")
    colorButton:SetScript("OnClick", function()
        local colorKey = "signColor" .. editing
        local initial = {unpack(db[colorKey])}
        if not pickerHooked then
            ColorPickerFrame:HookScript("OnHide", function(self)
                if ownsColorPicker then
                    ownsColorPicker = false
                    if pickerOriginalStrata then self:SetFrameStrata(pickerOriginalStrata) end
                    pickerOriginalStrata = nil
                end
            end)
            pickerHooked = true
        end
        if ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        pickerOriginalStrata = ColorPickerFrame:GetFrameStrata()
        local function update(r, g, b) db[colorKey] = {r, g, b}; refresh(true) end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = initial[1], g = initial[2], b = initial[3], hasOpacity = false,
            swatchFunc = function() update(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() update(unpack(initial)) end,
        })
        ownsColorPicker = true
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    end)
    local symbolsHeading = signOptions:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    symbolsHeading:SetPoint("TOPLEFT", 30, -389)
    symbolsHeading:SetText("Вид знака")
    local symbolButtons = {}
    local function updateSymbolButtons()
        for i, button in ipairs(symbolButtons) do
            if i == db["signSymbol" .. editing] then button:LockHighlight() else button:UnlockHighlight() end
        end
    end
    for i, symbol in ipairs(signSymbols) do
        local button = CreateFrame("Button", nil, signOptions, "UIPanelButtonTemplate")
        button:SetSize(60, 26)
        button:SetPoint("TOPLEFT", 30 + ((i - 1) % 5) * 72, -410 - math.floor((i - 1) / 5) * 32)
        button:SetText(symbol)
        button:SetScript("OnClick", function()
            db["signSymbol" .. editing] = i
            updateSymbolButtons(); refresh(true)
        end)
        symbolButtons[i] = button
    end
    local selectButton = CreateFrame("Button", nil, signOptions, "UIPanelButtonTemplate")
    selectButton:SetSize(180, 25)
    selectButton:SetPoint("TOPLEFT", 30, -350)
    local function syncSelection()
        selectButton:SetText("Настраивать: порог " .. editing)
        blink:SetChecked(db["signBlink" .. editing])
        updating = true
        size:SetValue(db["signSize" .. editing])
        offset:SetValue(db["signOffset" .. editing])
        speed:SetValue(db["signSpeed" .. editing])
        updating = false
        sizeLabel(); offsetLabel(); speedLabel(); updateSymbolButtons()
    end
    selectButton:SetScript("OnClick", function()
        if ownsColorPicker and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        editing = editing == 1 and 2 or 1
        syncSelection()
    end)
    local close = CreateFrame("Button", nil, signOptions, "UIPanelButtonTemplate")
    close:SetSize(110, 25)
    close:SetPoint("BOTTOM", 0, 22)
    close:SetText("Назад")
    close:SetScript("OnClick", function() signOptions:Hide(); BearManaAlertOpenBarSettings() end)
    signOptions:SetScript("OnShow", function()
        sign1:SetChecked(db.sign1); sign2:SetChecked(db.sign2)
        syncSelection()
        refresh(true)
    end)
    signOptions:SetScript("OnHide", function()
        if ownsColorPicker and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        refresh(true)
    end)
    signOptions:Hide(); signOptions:Show()
end

function BearManaAlertOpenBarSettings()
    if signOptions then signOptions:Hide() end
    if options then options:Show(); return end
    options = CreateFrame("Frame", "BearManaAlertBarSettings", UIParent, "BasicFrameTemplateWithInset")
    options:SetSize(470, 600)
    options:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    options:SetFrameStrata("DIALOG")
    options:SetClampedToScreen(true)
    options:SetMovable(true)
    options:EnableMouse(true)
    options:RegisterForDrag("LeftButton")
    options:SetScript("OnDragStart", options.StartMoving)
    options:SetScript("OnDragStop", options.StopMovingOrSizing)
    options.TitleText:SetText("MyMana — полоска маны")
    table.insert(UISpecialFrames, "BearManaAlertBarSettings")
    local function checkbox(y, label, key, x)
        local b = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", x or 22, y)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("LEFT", b, "RIGHT", 2, 0)
        t:SetText(label)
        b:SetScript("OnClick", function(self) db[key] = self:GetChecked() and true or false; refresh(true) end)
        return b
    end
    local show = checkbox(-40, "Показывать полоску", "show")
    local combat = checkbox(-72, "Только в бою", "combat")
    local unlock = checkbox(-104, "Разблокировать и перетащить", "unlocked")
    local width, height, widthText, heightText, scaleSlider, scaleLabel
    local updatingDimensions = false
    local style = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    style:SetSize(170, 25)
    style:SetPoint("TOPRIGHT", -22, -43)
    local function updateStyleLabel()
        local labels = {classic = "Стиль: обычный", pixel = "Стиль: золото", arcade = "Стиль: аркада"}
        style:SetText(labels[db.style])
    end
    style:SetScript("OnClick", function()
        local order = {classic = "pixel", pixel = "arcade", arcade = "classic"}
        db.style = order[db.style]
        local saved = db.styles[db.style]
        db.width, db.height, db.scale = saved.width, saved.height, saved.scale
        updatingDimensions = true
        width:SetValue(db.width); height:SetValue(db.height); scaleSlider:SetValue(db.scale)
        updatingDimensions = false
        widthText:SetText((db.style == "pixel" and "Длина: " or "Ширина: ") .. db.width)
        heightText:SetText((db.style == "pixel" and "Толщина: " or "Высота: ") .. db.height)
        scaleLabel:SetText("Размер: " .. db.scale .. "%")
        updateStyleLabel()
        refresh(true)
    end)
    style:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Стиль шкалы")
        GameTooltip:AddLine("Нажмите, чтобы переключить стиль. Размеры каждого стиля сохраняются отдельно.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    style:SetScript("OnLeave", GameTooltip_Hide)
    scaleLabel = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPRIGHT", -38, -80)
    scaleSlider = CreateFrame("Slider", "BearManaStyleScaleSlider", options, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPRIGHT", -32, -108)
    scaleSlider:SetWidth(145)
    scaleSlider:SetMinMaxValues(50, 200)
    scaleSlider:SetValueStep(1)
    scaleSlider:SetObeyStepOnDrag(true)
    BearManaStyleScaleSliderLow:SetText("50%")
    BearManaStyleScaleSliderHigh:SetText("200%")
    BearManaStyleScaleSliderText:SetText("")
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        if updatingDimensions or not db then return end
        db.scale = math.floor(value + 0.5)
        db.styles[db.style].scale = db.scale
        scaleLabel:SetText("Размер: " .. db.scale .. "%")
        refresh(true)
    end)
    local function slider(name, title, y, min, max, key)
        local heading = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", 29, y)
        local s = CreateFrame("Slider", name, options, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", 35, y - 27)
        s:SetWidth(350)
        s:SetMinMaxValues(min, max)
        s:SetValueStep(1)
        s:SetObeyStepOnDrag(true)
        _G[name .. "Low"]:SetText(tostring(min))
        _G[name .. "High"]:SetText(tostring(max))
        _G[name .. "Text"]:SetText("")
        s:SetScript("OnValueChanged", function(_, v)
            if updatingDimensions then return end
            db[key] = math.floor(v + 0.5)
            if key == "width" or key == "height" then db.styles[db.style][key] = db[key] end
            local label = title
            if db.style == "pixel" and key == "width" then label = "Длина" end
            if db.style == "pixel" and key == "height" then label = "Толщина" end
            heading:SetText(label .. ": " .. db[key])
            refresh(true)
        end)
        return s, heading
    end
    width, widthText = slider("BearManaBarWidthSlider", "Ширина", -150, 100, 600, "width")
    height, heightText = slider("BearManaBarHeightSlider", "Высота", -215, 10, 60, "height")
    local threshold, thresholdText = slider("BearManaBarThresholdSlider", "Порог 1 (%)", -280, 0, 100, "threshold")
    local thresholdSound = checkbox(-334, "Звук для порога 1", "thresholdSound")
    local function colorButton(label, key, x, y)
        local button = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
        button:SetSize(175, 25); button:SetPoint("TOPLEFT", x, y); button:SetText(label)
        button:SetScript("OnClick", function()
            local initial = {unpack(db[key])}
            local function update(r, g, b)
                db[key] = {r, g, b}; refresh(true)
            end
            if not pickerHooked then
                ColorPickerFrame:HookScript("OnHide", function(self)
                    if ownsColorPicker then
                        ownsColorPicker = false
                        if pickerOriginalStrata then self:SetFrameStrata(pickerOriginalStrata) end
                        pickerOriginalStrata = nil
                    end
                end)
                pickerHooked = true
            end
            if ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
            pickerOriginalStrata = ColorPickerFrame:GetFrameStrata()
            ColorPickerFrame:SetupColorPickerAndShow({
                r = initial[1], g = initial[2], b = initial[3], hasOpacity = false,
                swatchFunc = function() update(ColorPickerFrame:GetColorRGB()) end,
                cancelFunc = function() update(unpack(initial)) end,
            })
            ownsColorPicker = true
            ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        end)
        return button
    end
    colorButton("Цвет выше порогов", "normalColor", 28, -375)
    colorButton("Цвет порога 1", "lowColor", 227, -375)
    local modes = {"Числа", "Проценты", "Числа и %", "Без текста"}
    local mode = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    mode:SetSize(175, 25)
    mode:SetPoint("TOPLEFT", 28, -410)
    mode:SetScript("OnClick", function(self)
        db.text = db.text % #modes + 1
        self:SetText(modes[db.text]); refresh(true)
    end)
    local threshold2Enabled = checkbox(-407, "Включить порог 2", "threshold2Enabled", 214)
    local threshold2, threshold2Text = slider("BearManaBarThreshold2Slider", "Порог 2 (%)", -451, 0, 100, "threshold2")
    local threshold2Sound = checkbox(-505, "Звук порога 2", "threshold2Sound")
    colorButton("Цвет порога 2", "lowColor2", 227, -510)
    local reset = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    reset:SetSize(150, 25)
    reset:SetPoint("BOTTOMLEFT", 22, 25)
    reset:SetText("Сбросить позицию")
    reset:SetScript("OnClick", function()
        db.x, db.y = 0, -150
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    end)
    local signButton = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    signButton:SetSize(145, 25)
    signButton:SetPoint("BOTTOMLEFT", 183, 25)
    signButton:SetText("Настройки знака")
    signButton:SetScript("OnClick", openSignSettings)
    local close = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    close:SetSize(90, 25)
    close:SetPoint("BOTTOMRIGHT", -22, 25)
    close:SetText("Закрыть")
    close:SetScript("OnClick", function() options:Hide() end)
    options:SetScript("OnShow", function()
        updateStyleLabel()
        show:SetChecked(db.show); combat:SetChecked(db.combat); unlock:SetChecked(db.unlocked)
        thresholdSound:SetChecked(db.thresholdSound); threshold2Sound:SetChecked(db.threshold2Sound); threshold2Enabled:SetChecked(db.threshold2Enabled)
        updatingDimensions = true
        width:SetValue(db.width); height:SetValue(db.height); scaleSlider:SetValue(db.scale)
        updatingDimensions = false
        threshold:SetValue(db.threshold); threshold2:SetValue(db.threshold2)
        widthText:SetText((db.style == "pixel" and "Длина: " or "Ширина: ") .. db.width)
        heightText:SetText((db.style == "pixel" and "Толщина: " or "Высота: ") .. db.height)
        scaleLabel:SetText("Размер: " .. db.scale .. "%")
        thresholdText:SetText("Порог 1 (%): " .. db.threshold)
        threshold2Text:SetText("Порог 2 (%): " .. db.threshold2)
        mode:SetText(modes[db.text])
        refresh(true)
    end)
    options:SetScript("OnHide", function()
        if ownsColorPicker and ColorPickerFrame:IsShown() then ColorPickerFrame:Hide() end
        refresh(true)
    end)
    options:Hide(); options:Show()
end











