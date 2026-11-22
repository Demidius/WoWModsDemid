-- Pal Macros: окно настроек (Макросы / Фразы / Классы) и кнопка у миникарты.
local _, ns = ...

local frame, pages, tabs = nil, {}, {}
local currentPhraseKey = "might"

local CHANNELS = { "SAY", "YELL", "EMOTE", "PARTY" }
local CHANNEL_NAMES = { SAY = "Сказать", YELL = "Крикнуть", EMOTE = "Эмоция", PARTY = "Группа/рейд" }
local STATUS = {
  none     = "|cff888888нет макроса|r",
  ok       = "|cff55ff55готов|r",
  outdated = "|cffffcc00обновится|r",
  manual   = "|cffff7744изменён вручную|r",
}

local function button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 120, h or 22)
  b:SetText(text)
  return b
end

local function check(parent, text, onClick)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(24, 24)
  local label = c.Text or c.text or c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if not c.Text and not c.text then label:SetPoint("LEFT", c, "RIGHT", 2, 0) end
  label:SetText(text)
  c.label = label
  c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
  return c
end

local function numberBox(parent, w, onSet)
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(w, 20)
  e:SetAutoFocus(false)
  e:SetNumeric(true)
  e:SetScript("OnEnterPressed", function(self) onSet(tonumber(self:GetText()) or 0); self:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function(self) onSet(tonumber(self:GetText()) or 0) end)
  return e
end

local function tooltip(widget, title, text)
  widget:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function classColor(cls)
  local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {})[cls]
  if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  return "|cffffffff"
end

local function className(cls)
  if cls ~= "OTHER" and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls] then
    return LOCALIZED_CLASS_NAMES_MALE[cls]
  end
  return ns.CLASS_NAMES_FALLBACK[cls] or cls
end

-- ================================================================ Макросы
local macroRows = {}
local function buildMacrosPage(page)
  local smartIcon = CreateFrame("Button", nil, page)
  smartIcon:SetSize(40, 40)
  smartIcon:SetPoint("TOPLEFT", 8, -6)
  smartIcon.tex = smartIcon:CreateTexture(nil, "ARTWORK")
  smartIcon.tex:SetAllPoints()
  smartIcon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  smartIcon:RegisterForDrag("LeftButton")
  smartIcon:SetScript("OnDragStart", ns.PickupSmart)
  smartIcon:SetScript("OnClick", ns.PickupSmart)
  tooltip(smartIcon, "Умное благословение",
    "Перетащите на панель. Наведите мышь на игрока (или возьмите в цель) и нажмите: "
    .. "паладин выберет благословение по классу цели. Shift — большое благословение. Работает вне боя.")
  page.smartIcon = smartIcon

  local smartTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  smartTitle:SetPoint("TOPLEFT", smartIcon, "TOPRIGHT", 8, -2)
  smartTitle:SetText("Умное благословение по классу")
  local smartHint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  smartHint:SetPoint("TOPLEFT", smartTitle, "BOTTOMLEFT", 0, -3)
  smartHint:SetWidth(330)
  smartHint:SetJustifyH("LEFT")
  smartHint:SetText("Перетащите значок на панель. Shift — большое. Порядок — во вкладке «Классы».")

  local all = button(page, "Создать все", 110)
  all:SetPoint("TOPRIGHT", -8, -4)
  all:SetScript("OnClick", ns.CreateAllMacros)
  tooltip(all, "Создать все", "Создаёт макросы для всех изученных заклинаний. Места: сначала макросы персонажа, потом общие.")
  local upd = button(page, "Обновить", 110)
  upd:SetPoint("TOPRIGHT", all, "BOTTOMRIGHT", 0, -2)
  upd:SetScript("OnClick", function() ns.ScanSpells(); ns.UpdateAllMacros() end)

  local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", 8, -54)
  hint:SetText("Нажмите или перетащите значок — макрос создастся и окажется на курсоре. Ранги обновляются сами.")

  local scroll = CreateFrame("ScrollFrame", "PalMacrosScroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -72)
  scroll:SetPoint("BOTTOMRIGHT", -26, 4)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(540, 10)
  scroll:SetScrollChild(content)
  page.content = content
end

local function getRow(content, i)
  local row = macroRows[i]
  if row then return row end
  row = CreateFrame("Frame", nil, content)
  row:SetSize(540, 26)
  row.icon = CreateFrame("Button", nil, row)
  row.icon:SetSize(22, 22)
  row.icon:SetPoint("LEFT", 4, 0)
  row.icon.tex = row.icon:CreateTexture(nil, "ARTWORK")
  row.icon.tex:SetAllPoints()
  row.icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  row.icon:RegisterForDrag("LeftButton")
  local function pick() if row.rec then ns.PickupMacroFor(row.rec) end end
  row.icon:SetScript("OnClick", pick)
  row.icon:SetScript("OnDragStart", pick)
  row.icon:SetScript("OnEnter", function(self)
    if not row.rec then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(row.rec.name)
    GameTooltip:AddLine(ns.BuildBody(row.rec), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.name:SetWidth(170)
  row.name:SetJustifyH("LEFT")
  row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.desc:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
  row.desc:SetWidth(250)
  row.desc:SetJustifyH("LEFT")
  row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.status:SetPoint("RIGHT", -2, 0)
  row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.header:SetPoint("LEFT", 2, -2)
  macroRows[i] = row
  return row
end

local function refreshMacros()
  local page = pages.macros
  if not page then return end
  local kingsIcon = ns.known.kings and ns.known.kings.icon or (ns.known.might and ns.known.might.icon)
  page.smartIcon.tex:SetTexture(kingsIcon or "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings")

  local groupTitle = {}
  for _, g in ipairs(ns.GROUPS) do groupTitle[g.id] = g.title end
  local i, y, lastGroup = 0, 0, nil
  for _, rec in ipairs(ns.list) do
    if rec.group ~= lastGroup then
      lastGroup = rec.group
      i = i + 1
      local h = getRow(page.content, i)
      h:SetPoint("TOPLEFT", 0, -y)
      h.rec = nil
      h.icon:Hide(); h.name:SetText(""); h.desc:SetText(""); h.status:SetText("")
      h.header:SetText(groupTitle[rec.group] or rec.group)
      h:Show()
      y = y + 24
    end
    i = i + 1
    local row = getRow(page.content, i)
    row:SetPoint("TOPLEFT", 0, -y)
    row.rec = rec
    row.header:SetText("")
    row.icon:Show()
    row.icon.tex:SetTexture(rec.icon or 134400)
    row.name:SetText(rec.name)
    row.desc:SetText(rec.desc or ns.KIND_DESC[rec.kind] or "")
    row.status:SetText(STATUS[ns.MacroState(rec)] or "")
    row:Show()
    y = y + 26
  end
  if #ns.list == 0 then
    i = i + 1
    local row = getRow(page.content, i)
    row:SetPoint("TOPLEFT", 0, -y)
    row.rec = nil
    row.icon:Hide(); row.name:SetText(""); row.desc:SetText(""); row.status:SetText("")
    row.header:SetText(ns.isPaladin and "Заклинания не найдены. Нажмите «Обновить»." or "Аддон работает только на паладине.")
    row:Show()
    y = y + 26
  end
  for j = i + 1, #macroRows do macroRows[j]:Hide() end
  page.content:SetHeight(math.max(y, 10))
end

-- ================================================================ Фразы
local function buildPhrasesPage(page)
  page.keyButtons = {}
  for idx, key in ipairs(ns.BLESS_KEYS) do
    local b = button(page, ns.BLESS_TITLES[key], 110, 22)
    b:SetPoint("TOPLEFT", 34, -8 - (idx - 1) * 28)
    b:SetScript("OnClick", function()
      page.saveCurrent()
      currentPhraseKey = key
      ns.RefreshUI()
    end)
    local c = check(page, "", function(v) ns.db.blessOn[key] = v end)
    c:SetPoint("RIGHT", b, "LEFT", -2, 0)
    tooltip(c, "Фразы для «" .. ns.BLESS_TITLES[key] .. "»", "Галочка — произносить фразу при этом благословении.")
    b.check = c
    page.keyButtons[key] = b
  end

  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 160, -8)
  page.title = title
  page.langBtn = button(page, "", 150, 20)
  page.langBtn:SetPoint("TOPRIGHT", -4, -4)
  page.langBtn:SetScript("OnClick", function()
    page.saveCurrent()
    ns.db.lang = ns.db.lang == "ru" and "en" or "ru"
    ns.RefreshUI()
  end)
  tooltip(page.langBtn, "Язык фраз в чате",
    "Переключает готовые фразы: английский / русский. Свои фразы не меняются — чтобы вернуть готовые, нажмите «По умолчанию».")
  local help = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
  help:SetWidth(390)
  help:SetJustifyH("LEFT")
  help:SetText("Одна фраза — одна строка, выбирается случайно. {name} — имя цели, {class} — класс, {spell} — заклинание.")

  local bg = CreateFrame("Frame", nil, page, BackdropTemplateMixin and "BackdropTemplate" or nil)
  bg:SetPoint("TOPLEFT", 156, -44)
  bg:SetSize(404, 200)
  if bg.SetBackdrop then
    bg:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    bg:SetBackdropColor(0, 0, 0, 0.6)
  end
  local scroll = CreateFrame("ScrollFrame", "PalMacrosPhraseScroll", bg, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(368)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  scroll:SetScrollChild(edit)
  bg:EnableMouse(true)
  bg:SetScript("OnMouseDown", function() edit:SetFocus() end)
  page.edit = edit

  page.saveCurrent = function()
    if edit:GetText() == page.loaded then return end
    local list = {}
    for rawLine in (edit:GetText() .. "\n"):gmatch("(.-)\n") do
      local line = rawLine
      line = line:match("^%s*(.-)%s*$")
      if line ~= "" then list[#list + 1] = line:sub(1, 250) end
    end
    if #list > 0 then ns.db.phrases[currentPhraseKey] = list else ns.db.phrases[currentPhraseKey] = nil end
  end

  local save = button(page, "Сохранить", 110)
  save:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -4)
  save:SetScript("OnClick", function() page.saveCurrent(); edit:ClearFocus(); ns.print("Фразы сохранены."); ns.RefreshUI() end)
  local reset = button(page, "По умолчанию", 120)
  reset:SetPoint("LEFT", save, "RIGHT", 6, 0)
  reset:SetScript("OnClick", function()
    page.loaded = edit:GetText()
    ns.db.phrases[currentPhraseKey] = nil
    ns.RefreshUI()
  end)
  local test = button(page, "Пример в свой чат", 150)
  test:SetPoint("LEFT", reset, "RIGHT", 6, 0)
  test:SetScript("OnClick", function()
    page.saveCurrent()
    local list = ns.GetPhrases(currentPhraseKey)
    if #list > 0 then
      local unit = ns.pickHelpUnit()
      ns.print(ns.FormatPhrase(list[math.random(#list)], unit, ns.BLESS_TITLES[currentPhraseKey]))
    end
  end)

end

local function refreshPhrases()
  local page = pages.phrases
  if not page then return end
  for key, b in pairs(page.keyButtons) do
    b.check:SetChecked(ns.db.blessOn[key] and true or false)
    if key == currentPhraseKey then b:LockHighlight() else b:UnlockHighlight() end
  end
  page.saveCurrent()
  local custom = ns.db.phrases[currentPhraseKey]
  page.title:SetText("«" .. ns.BLESS_TITLES[currentPhraseKey] .. "»" .. (custom and " — свои фразы" or " — готовые фразы"))
  page.langBtn:SetText("Язык фраз: " .. (ns.db.lang == "en" and "English" or "Русский"))
  page.loaded = table.concat(ns.GetPhrases(currentPhraseKey), "\n")
  page.edit:SetText(page.loaded)
end


-- ================================================================ Настройки
local function buildSettingsPage(page)
  local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  head:SetPoint("TOPLEFT", 10, -8)
  head:SetText("Pal Macros")
  page.version = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  page.version:SetPoint("LEFT", head, "RIGHT", 10, -1)

  local sec1 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sec1:SetPoint("TOPLEFT", 10, -40)
  sec1:SetText("Фразы при благословениях")
  local y = -62
  page.announce = check(page, "Произносить фразы при благословении", function(v) ns.db.announce = v end)
  page.announce:SetPoint("TOPLEFT", 10, y)
  page.self = check(page, "Также когда благословляю себя", function(v) ns.db.announceSelf = v end)
  page.self:SetPoint("TOPLEFT", 10, y - 26)

  local chLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  chLabel:SetPoint("TOPLEFT", 300, y - 5)
  chLabel:SetText("Канал:")
  page.channel = button(page, "", 120)
  page.channel:SetPoint("LEFT", chLabel, "RIGHT", 8, 0)
  page.channel:SetScript("OnClick", function()
    local cur = 1
    for i, c in ipairs(CHANNELS) do if c == ns.db.channel then cur = i end end
    ns.db.channel = CHANNELS[cur % #CHANNELS + 1]
    ns.RefreshUI()
  end)
  tooltip(page.channel, "Канал", "«Группа/рейд» вне группы превращается в «Сказать». «Эмоция» — текст от третьего лица.")

  local langLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  langLabel:SetPoint("TOPLEFT", 300, y - 33)
  langLabel:SetText("Фразы по умолчанию:")
  page.lang = button(page, "", 70)
  page.lang:SetPoint("LEFT", langLabel, "RIGHT", 8, 0)
  page.lang:SetScript("OnClick", function()
    pages.phrases.saveCurrent()
    ns.db.lang = ns.db.lang == "ru" and "en" or "ru"
    ns.RefreshUI()
  end)
  tooltip(page.lang, "Язык готовых фраз", "Свои фразы не меняются. Готовые используются, пока поле пустое или после «По умолчанию».")

  local chanceLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  chanceLabel:SetPoint("TOPLEFT", 14, y - 62)
  chanceLabel:SetText("Шанс фразы, %:")
  page.chance = numberBox(page, 40, function(v) ns.db.chance = math.max(0, math.min(100, v)) end)
  page.chance:SetPoint("LEFT", chanceLabel, "RIGHT", 10, 0)

  local repLabel = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  repLabel:SetPoint("LEFT", page.chance, "RIGHT", 20, 0)
  repLabel:SetText("Не повторять тому же игроку, сек:")
  page.rep = numberBox(page, 50, function(v) ns.db.repeatDelay = v end)
  page.rep:SetPoint("LEFT", repLabel, "RIGHT", 10, 0)

  page.minimap = check(page, "Кнопка у миникарты", function(v)
    ns.db.hideMinimap = not v
    if ns.SetMinimapShown then ns.SetMinimapShown(v) end
  end)
  page.minimap:SetPoint("TOPLEFT", 10, y - 86)

  local sec2 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sec2:SetPoint("TOPLEFT", 10, y - 120)
  sec2:SetText("Макросы")
  local upd = button(page, "Обновить макросы", 160)
  upd:SetPoint("TOPLEFT", 10, y - 142)
  upd:SetScript("OnClick", function() ns.ScanSpells(); ns.UpdateAllMacros() end)
  local all = button(page, "Создать все", 140)
  all:SetPoint("LEFT", upd, "RIGHT", 8, 0)
  all:SetScript("OnClick", ns.CreateAllMacros)

  local info = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  info:SetPoint("BOTTOMLEFT", 10, 10)
  info:SetWidth(540)
  info:SetJustifyH("LEFT")
  info:SetText("Открыть окно: /pal, кнопка у миникарты, список аддонов (кнопка-конверт) или Настройки > Модификации > Pal Macros.")
end

local function refreshSettings()
  local page = pages.settings
  if not page then return end
  page.version:SetText("версия " .. (ns.version or "?"))
  page.announce:SetChecked(ns.db.announce)
  page.self:SetChecked(ns.db.announceSelf)
  page.channel:SetText(CHANNEL_NAMES[ns.db.channel] or ns.db.channel)
  page.lang:SetText(ns.db.lang == "en" and "English" or "Русский")
  page.chance:SetText(tostring(ns.db.chance or 100))
  page.rep:SetText(tostring(ns.db.repeatDelay or 0))
  page.minimap:SetChecked(not ns.db.hideMinimap)
end


-- ================================================================ Бой
local fightRows, candRows = {}, {}
local FIGHT_ROWS = 9

local function smallButton(parent, text, w)
  local b = button(parent, text, w or 24, 20)
  return b
end

local function buildFightPage(page)
  local icon = CreateFrame("Button", nil, page)
  icon:SetSize(40, 40)
  icon:SetPoint("TOPLEFT", 8, -6)
  icon.tex = icon:CreateTexture(nil, "ARTWORK")
  icon.tex:SetAllPoints()
  icon:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  icon:RegisterForDrag("LeftButton")
  local function pick()
    local rec = ns.known[ns.FIGHT_KEY]
    if rec then ns.PickupMacroFor(rec) else ns.print("Атакующие заклинания ещё не изучены.") end
  end
  icon:SetScript("OnClick", pick)
  icon:SetScript("OnDragStart", pick)
  icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Кнопка «Бой»")
    GameTooltip:AddLine((ns.BuildFightBody()), 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
  page.icon = icon

  local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -2)
  title:SetText("Кнопка «Бой» — перетащите значок на панель")
  page.mode = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.mode:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

  local help = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", 8, -54)
  help:SetWidth(560)
  help:SetJustifyH("LEFT")
  help:SetText("Каждое нажатие: если нет врага в цели — берётся ближайший, включается автоатака, затем пробуются "
    .. "заклинания сверху вниз; если первое на перезарядке или не подходит — срабатывает следующее.")

  local h1 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h1:SetPoint("TOPLEFT", 8, -86)
  h1:SetText("Очередь (сверху — главное)")
  local h2 = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  h2:SetPoint("TOPLEFT", 330, -86)
  h2:SetText("Можно добавить")

  for i = 1, FIGHT_ROWS do
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(310, 26)
    row:SetPoint("TOPLEFT", 4, -104 - (i - 1) * 27)
    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.num:SetPoint("LEFT", 2, 0)
    row.num:SetWidth(16)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 20, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(170)
    row.name:SetJustifyH("LEFT")
    row.up = smallButton(row, "^"); row.up:SetPoint("RIGHT", -54, 0)
    row.down = smallButton(row, "v"); row.down:SetPoint("RIGHT", -28, 0)
    row.del = smallButton(row, "x"); row.del:SetPoint("RIGHT", -2, 0)
    tooltip(row.up, "Выше"); tooltip(row.down, "Ниже"); tooltip(row.del, "Убрать из очереди")
    local function move(delta)
      local key = row.key
      ns.EditFight(function(list)
        for j, k in ipairs(list) do
          if k == key then
            local t = j + delta
            if t >= 1 and t <= #list then list[j], list[t] = list[t], list[j] end
            break
          end
        end
      end)
      ns.RefreshUI()
    end
    row.up:SetScript("OnClick", function() move(-1) end)
    row.down:SetScript("OnClick", function() move(1) end)
    row.del:SetScript("OnClick", function()
      local key = row.key
      ns.EditFight(function(list)
        for j, k in ipairs(list) do if k == key then table.remove(list, j); break end end
      end)
      ns.RefreshUI()
    end)
    fightRows[i] = row

    local c = CreateFrame("Frame", nil, page)
    c:SetSize(240, 26)
    c:SetPoint("TOPLEFT", 326, -104 - (i - 1) * 27)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(20, 20)
    c.icon:SetPoint("LEFT", 2, 0)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.name:SetPoint("LEFT", c.icon, "RIGHT", 6, 0)
    c.name:SetWidth(180)
    c.name:SetJustifyH("LEFT")
    c.add = smallButton(c, "+"); c.add:SetPoint("RIGHT", -2, 0)
    tooltip(c.add, "Добавить в конец очереди")
    c.add:SetScript("OnClick", function()
      local key = c.key
      ns.EditFight(function(list) list[#list + 1] = key end)
      ns.RefreshUI()
    end)
    candRows[i] = c
  end

  page.size = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.size:SetPoint("BOTTOMLEFT", 10, 40)
  page.size:SetWidth(560)
  page.size:SetJustifyH("LEFT")

  local reset = button(page, "Сбросить на рекомендуемую", 220)
  reset:SetPoint("BOTTOMLEFT", 8, 8)
  reset:SetScript("OnClick", function() ns.ResetFight(); ns.RefreshUI() end)
  tooltip(reset, "Рекомендуемая очередь",
    "Собирается из изученных заклинаний и сама дополняется при получении уровня и новых заклинаний: "
    .. "Правосудие > Удар Света и другие новые удары Forever > Удар воина > Молот гнева > Экзорцизм.")
end

local function refreshFight()
  local page = pages.fight
  if not page then return end
  local rec = ns.known[ns.FIGHT_KEY]
  page.icon.tex:SetTexture(rec and rec.icon or "Interface\\Icons\\Spell_Holy_RighteousFury")
  page.mode:SetText(ns.FightIsCustom() and "Режим: |cffffcc00своя очередь|r (новые заклинания сами не добавляются)"
    or "Режим: |cff55ff55рекомендуемая|r — обновляется сама при новом уровне и заклинаниях")

  local keys = ns.FightKeys()
  local inList = {}
  for i = 1, FIGHT_ROWS do
    local row, key = fightRows[i], keys[i]
    if key and ns.known[key] then
      inList[key] = true
      row.key = key
      row.num:SetText(i .. ".")
      row.icon:SetTexture(ns.known[key].icon or 134400)
      row.name:SetText(ns.known[key].name)
      row.up:SetEnabled(i > 1)
      row.down:SetEnabled(i < #keys)
      row:Show()
    else
      row.key = nil
      row:Hide()
    end
  end
  for _, k in ipairs(keys) do inList[k] = true end
  local j = 0
  for _, key in ipairs(ns.FightCandidates()) do
    if not inList[key] and j < FIGHT_ROWS then
      j = j + 1
      local c = candRows[j]
      c.key = key
      c.icon:SetTexture(ns.known[key].icon or 134400)
      c.name:SetText(ns.known[key].name)
      c:Show()
    end
  end
  for i = j + 1, FIGHT_ROWS do candRows[i]:Hide() end

  local body, used, skipped = ns.BuildFightBody()
  local text = "Макрос: " .. #body .. " из 255 байт, заклинаний в нём: " .. used
  if skipped > 0 then text = text .. "  |cffff7744не поместились (нижние): " .. skipped .. "|r" end
  if #keys == 0 then text = "Атакующие заклинания ещё не изучены." end
  page.size:SetText(text)
end


-- ================================================================ Игроки
local playerRows = {}
local selectedPlayer

local SPELL_SHORT = { might = "Могущество", wisdom = "Мудрость", kings = "Короли", salvation = "Спасение",
                      light = "Свет", sanctuary = "Святилище" }

local function buildPlayersPage(page)
  local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("TOPLEFT", 14, -8)
  search:SetAutoFocus(false)
  search:SetScript("OnTextChanged", function() ns.RefreshUI() end)
  search:SetScript("OnEscapePressed", search.ClearFocus)
  page.search = search
  local sl = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  sl:SetPoint("LEFT", search, "RIGHT", 8, 0)
  sl:SetText("поиск по имени или классу")
  page.count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  page.count:SetPoint("TOPRIGHT", -8, -12)

  local cols = { { "Имя", 8 }, { "Ур.", 190 }, { "Класс", 225 }, { "Раз", 345 }, { "Последнее", 385 } }
  for _, c in ipairs(cols) do
    local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h:SetPoint("TOPLEFT", c[2], -36)
    h:SetText(c[1])
  end

  local scroll = CreateFrame("ScrollFrame", "PalMacrosPlayersScroll", page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -50)
  scroll:SetPoint("BOTTOMRIGHT", -26, 96)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(540, 10)
  scroll:SetScrollChild(content)
  page.content = content

  -- карточка выбранного игрока
  page.info = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  page.info:SetPoint("BOTTOMLEFT", 10, 72)
  page.info:SetWidth(560)
  page.info:SetJustifyH("LEFT")
  page.copy = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
  page.copy:SetSize(170, 20)
  page.copy:SetPoint("BOTTOMLEFT", 16, 42)
  page.copy:SetAutoFocus(false)
  page.copy:SetScript("OnEscapePressed", page.copy.ClearFocus)
  page.copy:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  tooltip(page.copy, "Имя для копирования", "Ctrl+C — скопировать.")

  local function withSel(fn) return function() if selectedPlayer then fn(selectedPlayer) end end end
  local who = button(page, "Найти (/who)", 110)
  who:SetPoint("LEFT", page.copy, "RIGHT", 8, 0)
  who:SetScript("OnClick", withSel(function(p) ns.WhoPlayer(p.name) end))
  tooltip(who, "Найти игрока", "Поиск во внутриигровом списке «Кто». Находит только тех, кто сейчас в сети.")
  local friend = button(page, "В друзья", 90)
  friend:SetPoint("LEFT", who, "RIGHT", 4, 0)
  friend:SetScript("OnClick", withSel(function(p) ns.AddFriend(p.name) end))
  local tell = button(page, "Шёпот", 80)
  tell:SetPoint("LEFT", friend, "RIGHT", 4, 0)
  tell:SetScript("OnClick", withSel(function(p) ns.WhisperPlayer(p.name) end))
  local del = button(page, "Удалить", 80)
  del:SetPoint("LEFT", tell, "RIGHT", 4, 0)
  del:SetScript("OnClick", withSel(function(p)
    if IsShiftKeyDown() then
      ns.db.players[ns.lower(p.name)] = nil
      selectedPlayer = nil
      ns.RefreshUI()
    else
      ns.print("Чтобы удалить «" .. p.name .. "» из журнала, нажмите «Удалить» с зажатым Shift.")
    end
  end))
  tooltip(del, "Удалить из журнала", "Нажмите с зажатым Shift.")
  page.buttons = { who, friend, tell, del }

  local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOMLEFT", 10, 14)
  hint:SetWidth(560)
  hint:SetJustifyH("LEFT")
  hint:SetText("Записываются игроки после успешного благословения (макросом, умной кнопкой или из книги заклинаний). "
    .. "Журнал общий для всех ваших персонажей.")
end

local function playerRow(content, i)
  local row = playerRows[i]
  if row then return row end
  row = CreateFrame("Button", nil, content)
  row:SetSize(540, 20)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.sel = row:CreateTexture(nil, "BACKGROUND")
  row.sel:SetAllPoints()
  row.sel:SetColorTexture(1, 0.82, 0, 0.18)
  local function fs(x, w)
    local f = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f:SetPoint("LEFT", x, 0)
    f:SetWidth(w)
    f:SetJustifyH("LEFT")
    return f
  end
  row.name = fs(4, 180); row.level = fs(186, 30); row.class = fs(221, 118)
  row.count = fs(341, 36); row.last = fs(381, 160)
  row:SetScript("OnClick", function(self)
    selectedPlayer = self.player
    ns.RefreshUI()
  end)
  playerRows[i] = row
  return row
end

local function refreshPlayers()
  local page = pages.players
  if not page then return end
  local list = ns.SortedPlayers(page.search:GetText())
  local total = 0
  for _ in pairs(ns.db.players) do total = total + 1 end
  page.count:SetText("Всего игроков: " .. total)
  for i, p in ipairs(list) do
    local row = playerRow(page.content, i)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
    row.player = p
    row.name:SetText((p.class and classColor(p.class) or "|cffffffff") .. p.name .. "|r")
    row.level:SetText(p.level and tostring(p.level) or "?")
    row.class:SetText(p.className or "?")
    row.count:SetText(tostring(p.count or 0))
    row.last:SetText((p.last and date("%d.%m.%y %H:%M", p.last) or "") .. "  " .. (SPELL_SHORT[p.lastSpell] or ""))
    row.sel:SetShown(selectedPlayer == p)
    row:Show()
  end
  for j = #list + 1, #playerRows do playerRows[j]:Hide() end
  page.content:SetHeight(math.max(#list * 20, 10))

  if selectedPlayer and not ns.db.players[ns.lower(selectedPlayer.name)] then selectedPlayer = nil end
  local p = selectedPlayer
  for _, b in ipairs(page.buttons) do b:SetEnabled(p ~= nil) end
  if p then
    local parts = {}
    for k, v in pairs(p.spells or {}) do parts[#parts + 1] = (SPELL_SHORT[k] or k) .. " x" .. v end
    page.info:SetText((p.class and classColor(p.class) or "") .. p.name .. "|r — " .. (p.level or "?") .. " ур., "
      .. (p.race and (p.race .. ", ") or "") .. (p.className or "?")
      .. "   впервые: " .. (p.first and date("%d.%m.%y", p.first) or "?") .. "   " .. table.concat(parts, ", "))
    if page.copy:GetText() ~= p.name then page.copy:SetText(p.name) end
  else
    page.info:SetText(#list > 0 and "Выберите игрока в списке." or "Журнал пока пуст — благословите кого-нибудь!")
    page.copy:SetText("")
  end
end

-- ================================================================ Классы
local CHOICES = { "might", "wisdom", "kings", "salvation", "light", "sanctuary", "none" }
local function buildClassesPage(page)
  local help = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", 10, -8)
  help:SetWidth(540)
  help:SetJustifyH("LEFT")
  help:SetText("Умная кнопка берёт первое изученное благословение из пары. ЛКМ — следующее, ПКМ — предыдущее. "
    .. "В Forever все благословения длятся час, Короли — базовые с 20 уровня, Могущество ослаблено.")
  page.rows = {}
  for i, cls in ipairs(ns.CLASS_ORDER) do
    local y = -44 - (i - 1) * 30
    local label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", 20, y - 4)
    label:SetText(classColor(cls) .. className(cls) .. "|r")
    local row = { buttons = {} }
    for slot = 1, 2 do
      local b = button(page, "", 130)
      b:SetPoint("TOPLEFT", 200 + (slot - 1) * 150, y)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      b:SetScript("OnClick", function(_, mouse)
        local prio = ns.db.prio[cls]
        local cur = 1
        for k, v in ipairs(CHOICES) do if v == (prio[slot] or "none") then cur = k end end
        cur = mouse == "RightButton" and (cur - 2) % #CHOICES + 1 or cur % #CHOICES + 1
        prio[slot] = CHOICES[cur]
        ns.RefreshUI()
      end)
      row.buttons[slot] = b
    end
    page.rows[cls] = row
  end
  local reset = button(page, "Сбросить по умолчанию", 180)
  reset:SetPoint("BOTTOMLEFT", 10, 8)
  reset:SetScript("OnClick", function()
    for cls, list in pairs(ns.DEFAULT_PRIO) do ns.db.prio[cls] = { list[1], list[2] } end
    ns.RefreshUI()
  end)
end

local function refreshClasses()
  local page = pages.classes
  if not page then return end
  for cls, row in pairs(page.rows) do
    local prio = ns.db.prio[cls] or {}
    for slot = 1, 2 do
      local key = prio[slot] or "none"
      local known = key == "none" or ns.known[key]
      row.buttons[slot]:SetText((slot == 1 and "1. " or "2. ") .. (known and "" or "|cff888888")
        .. (ns.BLESS_TITLES[key] or key))
    end
  end
end

-- ================================================================ окно
local function showPage(id)
  if pages.phrases and pages.phrases:IsShown() and id ~= "phrases" then pages.phrases.saveCurrent() end
  for pid, p in pairs(pages) do p:SetShown(pid == id) end
  for tid, t in pairs(tabs) do if tid == id then t:LockHighlight() else t:UnlockHighlight() end end
  frame.current = id
  ns.RefreshUI()
end

local function createFrame()
  frame = CreateFrame("Frame", "PalMacrosFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(600, 560)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetFrameStrata("HIGH")
  frame:SetClampedToScreen(true)
  tinsert(UISpecialFrames, "PalMacrosFrame")
  local title = type(frame.TitleText) == "table" and frame.TitleText
  if not title then
    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
  end
  title:SetText("Pal Macros — макросы паладина  |cff999999v" .. (ns.version or "?") .. "|r")

  local defs = { { "macros", "Макросы" }, { "fight", "Бой" }, { "phrases", "Фразы" }, { "classes", "Классы" },
    { "players", "Игроки" }, { "settings", "Настройки" } }
  for i, d in ipairs(defs) do
    local t = button(frame, d[2], 92, 24)
    t:SetPoint("TOPLEFT", 12 + (i - 1) * 96, -28)
    t:SetScript("OnClick", function() showPage(d[1]) end)
    tabs[d[1]] = t
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPLEFT", 10, -58)
    p:SetPoint("BOTTOMRIGHT", -10, 10)
    p:Hide()
    pages[d[1]] = p
  end
  buildMacrosPage(pages.macros)
  buildPhrasesPage(pages.phrases)
  buildClassesPage(pages.classes)
  buildFightPage(pages.fight)
  buildPlayersPage(pages.players)
  buildSettingsPage(pages.settings)
  frame:SetScript("OnHide", function() if pages.phrases:IsShown() then pages.phrases.saveCurrent() end end)
  showPage("macros")
end

function ns.RefreshUI()
  if not frame or not frame:IsShown() then return end
  if frame.current == "macros" then refreshMacros()
  elseif frame.current == "phrases" then refreshPhrases()
  elseif frame.current == "classes" then refreshClasses()
  elseif frame.current == "fight" then refreshFight()
  elseif frame.current == "players" then refreshPlayers()
  elseif frame.current == "settings" then refreshSettings() end
end

function ns.ToggleUI()
  if not frame then createFrame(); return end
  if frame:IsShown() then frame:Hide() else frame:Show(); ns.RefreshUI() end
end

function ns.OpenUI(pageId)
  if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
  if not frame then createFrame() end
  frame:Show()
  showPage(pageId or "settings")
end

-- ================================================================ миникарта и ярлыки
local ICON = "Interface\\Icons\\Spell_Holy_FistOfJustice"

local function tooltipLines(tt)
  tt:AddLine("Pal Macros |cff999999v" .. (ns.version or "?") .. "|r")
  tt:AddLine("Нажмите, чтобы открыть окно.", 1, 1, 1)
  tt:AddLine("Перетащите, чтобы переместить кнопку.", 1, 1, 1)
end

local function createOwnMinimapButton()
  local b = CreateFrame("Button", "PalMacrosMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon:SetTexture(ICON)
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(52, 52)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  local function place()
    local a = math.rad(ns.db.minimapAngle or 215)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
  end
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local scale = Minimap:GetEffectiveScale()
      local cx, cy = Minimap:GetCenter()
      if not cx then return end
      local x, y = GetCursorPosition()
      ns.db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
      place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", ns.ToggleUI)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    tooltipLines(GameTooltip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  place()
  ns.minimapButton = b
end

-- Если есть LibDBIcon (например, в HidingBar) — регистрируемся через неё, чтобы кнопку подхватывали панели миникарты.
local ldbi
local function setupMinimap()
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  ldbi = LibStub and LibStub("LibDBIcon-1.0", true)
  if ldb and ldbi then
    local obj = ldb:GetDataObjectByName("PalMacros") or ldb:NewDataObject("PalMacros", {
      type = "launcher", text = "Pal Macros", icon = ICON,
      OnClick = function() ns.ToggleUI() end,
      OnTooltipShow = tooltipLines,
    })
    if type(ns.db.minimap) ~= "table" then ns.db.minimap = {} end
    ns.db.minimap.hide = ns.db.hideMinimap and true or false
    ldbi:Register("PalMacros", obj, ns.db.minimap)
  else
    ldbi = nil
    createOwnMinimapButton()
    ns.minimapButton:SetShown(not ns.db.hideMinimap)
  end
end

function ns.SetMinimapShown(show)
  ns.db.hideMinimap = not show
  if ldbi then
    ns.db.minimap.hide = not show
    if show then ldbi:Show("PalMacros") else ldbi:Hide("PalMacros") end
  elseif ns.minimapButton then
    ns.minimapButton:SetShown(show)
  end
end

-- Ярлык в «Настройки > Модификации»: версия и кнопка, открывающая окно аддона.
local function setupOptionsShortcut()
  local panel = CreateFrame("Frame")
  panel.name = "Pal Macros"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Pal Macros |cff999999v" .. (ns.version or "?") .. "|r")
  local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  text:SetWidth(560)
  text:SetJustifyH("LEFT")
  text:SetText("Макросы паладина, умное благословение по классу и дворфийские фразы. Все настройки — в окне аддона.")
  local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  open:SetSize(200, 26)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
  open:SetText("Открыть настройки")
  open:SetScript("OnClick", function() ns.OpenUI("settings") end)
  local open2 = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  open2:SetSize(200, 26)
  open2:SetPoint("LEFT", open, "RIGHT", 8, 0)
  open2:SetText("Открыть макросы")
  open2:SetScript("OnClick", function() ns.OpenUI("macros") end)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ns.InitUI()
  if not ns.isPaladin then return end
  setupMinimap()
  pcall(setupOptionsShortcut)
end
