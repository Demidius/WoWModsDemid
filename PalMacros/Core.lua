-- Pal Macros: книга заклинаний, создание макросов, фразы в чат, умная кнопка благословений.
local ADDON, ns = ...

local QUESTION_ICON = 134400 -- INV_Misc_QuestionMark: с #showtooltip значок берётся от заклинания
local MAX_PHRASE_BYTES = 250

ns.known = {}      -- key -> { key, name, id, icon, kind, group, label, entry }
ns.list = {}       -- упорядоченный список для окна
ns.isPaladin = false
do
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  ns.version = getMeta and getMeta(ADDON, "Version") or "?"
end

-- ---------------------------------------------------------------- утилиты
local function secret(v) return issecretvalue and issecretvalue(v) end

function ns.print(msg)
  print("|cfff5c542Pal Macros:|r " .. tostring(msg))
end

-- Выполнить шаг, не роняя аддон; ошибку один раз показать в чате.
local reported = {}
function ns.safe(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    local key = what .. tostring(err)
    if not reported[key] then
      reported[key] = true
      ns.print("|cffff5555ошибка (" .. what .. "):|r " .. tostring(err))
    end
  end
  return ok
end

local function spellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then
    local n = C_Spell.GetSpellName(id)
    if n then return n end
  end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

local function spellIcon(nameOrId)
  if C_Spell and C_Spell.GetSpellTexture then
    local t = C_Spell.GetSpellTexture(nameOrId)
    if t then return t end
  end
  if GetSpellTexture then return GetSpellTexture(nameOrId) end
end

local function utf8sub(s, n)
  local out, count = {}, 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
    if count > n then break end
    out[#out + 1] = ch
  end
  return table.concat(out)
end
ns.utf8sub = utf8sub

-- Нижний регистр с кириллицей (string.lower её не трогает).
local UPPER, LOWER = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ", "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local lowerMap = {}
do
  local up, lo = {}, {}
  for ch in UPPER:gmatch("[\192-\255][\128-\191]*") do up[#up + 1] = ch end
  for ch in LOWER:gmatch("[\192-\255][\128-\191]*") do lo[#lo + 1] = ch end
  for i = 1, #up do lowerMap[up[i]] = lo[i] end
end
function ns.lower(str)
  return (str:lower():gsub("[\192-\255][\128-\191]*", function(ch) return lowerMap[ch] or ch end))
end

local function copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = type(v) == "table" and copy(v) or v end
  return r
end

-- ---------------------------------------------------------------- база настроек
local DEFAULTS = {
  announce = true,       -- фразы в чат
  announceSelf = false,  -- фраза при благословении самого себя
  channel = "SAY",
  chance = 100,          -- шанс фразы, %
  repeatDelay = 60,      -- не повторять фразу тому же игроку раньше, сек
  lang = "en",
  blessOn = { might = true, wisdom = true, kings = true, salvation = true, light = true, sanctuary = true },
  minimapAngle = 215,
  hideMinimap = false,
}

local function initDB()
  PalMacrosDB = PalMacrosDB or {}
  for k, v in pairs(DEFAULTS) do
    if PalMacrosDB[k] == nil then PalMacrosDB[k] = type(v) == "table" and copy(v) or v end
  end
  PalMacrosDB.phrases = PalMacrosDB.phrases or {}
  PalMacrosDB.players = PalMacrosDB.players or {}
  PalMacrosDB.prio = PalMacrosDB.prio or {}
  for cls, list in pairs(ns.DEFAULT_PRIO) do
    if not PalMacrosDB.prio[cls] then PalMacrosDB.prio[cls] = copy(list) end
  end
  PalMacrosCharDB = PalMacrosCharDB or {}
  PalMacrosCharDB.macros = PalMacrosCharDB.macros or {}
  PalMacrosCharDB.fight = PalMacrosCharDB.fight or { mode = "auto", list = {} }
  -- 1.2.0: готовые фразы по умолчанию — английские
  if not PalMacrosDB.langEnDefault then
    PalMacrosDB.lang = "en"
    PalMacrosDB.langEnDefault = true
  end
  ns.db, ns.cdb = PalMacrosDB, PalMacrosCharDB
end

function ns.GetPhrases(key)
  local custom = ns.db.phrases[key]
  if custom and #custom > 0 then return custom end
  local lang = ns.DEFAULT_PHRASES[ns.db.lang] or ns.DEFAULT_PHRASES.ru
  return lang[key] or ns.DEFAULT_PHRASES.ru[key] or {}
end

-- ---------------------------------------------------------------- книга заклинаний
local function forEachSpellbookSpell(fn, forceLegacy)
  if not forceLegacy and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    for tab = 2, C_SpellBook.GetNumSpellBookSkillLines() do -- вкладка 1 - «Общее»
      local line = C_SpellBook.GetSpellBookSkillLineInfo(tab)
      if line and not line.shouldHide then
        for i = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
          local item = C_SpellBook.GetSpellBookItemInfo(i, bank)
          if item and item.name and (spellType == nil or item.itemType == spellType)
            and not item.isPassive and not item.isOffSpec then
            fn(item.name, item.spellID or item.actionID, item.iconID)
          end
        end
      end
    end
    return
  end
  local book = BOOKTYPE_SPELL or "spell"
  for tab = 2, (GetNumSpellTabs and GetNumSpellTabs() or 0) do
    local _, _, offset, num = GetSpellTabInfo(tab)
    for i = offset + 1, offset + num do
      local kind, id = GetSpellBookItemInfo(i, book)
      local name = GetSpellBookItemName and GetSpellBookItemName(i, book) or (GetSpellName and GetSpellName(i, book))
      local passive = IsPassiveSpell and IsPassiveSpell(i, book)
      if name and (kind == nil or kind == "SPELL") and not passive then
        fn(name, id, GetSpellBookItemTexture and GetSpellBookItemTexture(i, book))
      end
    end
  end
end

local function isHarmful(name)
  if C_Spell and C_Spell.IsSpellHarmful then return C_Spell.IsSpellHarmful(name) end
  return IsHarmfulSpell and IsHarmfulSpell(name)
end
local function isHelpful(name)
  if C_Spell and C_Spell.IsSpellHelpful then return C_Spell.IsSpellHelpful(name) end
  return IsHelpfulSpell and IsHelpfulSpell(name)
end

function ns.ScanSpells()
  -- локализованное имя -> запись таблицы
  local byName = {}
  for _, e in ipairs(ns.SPELLS) do
    local n = spellName(e.id)
    if n then byName[n] = e end
    byName[e.en] = byName[e.en] or e
  end

  local known, seen, list = {}, {}, {}
  local function add(name, id, icon)
    if type(name) ~= "string" or secret(name) then return end
    if seen[name] then
      if id then seen[name].id = id end -- старший ранг идёт последним
      return
    end
    local e = byName[name]
    local rec
    if e then
      rec = { key = e.key, name = name, id = id, icon = icon, kind = e.kind, group = e.group, label = e.label, entry = e }
    else
      local kind = isHarmful(name) and "generic_harm" or (isHelpful(name) and "generic_help") or "generic"
      rec = { key = "id:" .. name, name = name, id = id, icon = icon, kind = kind, group = "other", label = utf8sub(name, 12) }
    end
    seen[name] = rec
    known[rec.key] = rec
    list[#list + 1] = rec
  end
  local ok = pcall(forEachSpellbookSpell, add)
  if not ok or #list == 0 then
    known, seen, list = {}, {}, {}
    pcall(forEachSpellbookSpell, add, true)
  end

  -- комбинированные макросы
  local names = {}
  for k, r in pairs(known) do names[k] = r.name end
  for _, c in ipairs(ns.COMBOS) do
    local req = known[c.requires]
    if req then
      local rec = { key = c.key, name = c.label, icon = req.icon, kind = "combo", group = c.group,
                    label = c.label, combo = c, names = names, desc = c.desc }
      known[c.key] = rec
      list[#list + 1] = rec
    end
  end

  -- кнопка «Бой»: появляется, как только изучено хоть одно атакующее заклинание
  local fightKeys = ns.FightKeys(known, list)
  if #fightKeys > 0 then
    local first = known[fightKeys[1]]
    local rec = { key = ns.FIGHT_KEY, name = "Бой", label = "Бой", kind = "combo", group = "attack",
                  icon = first and first.icon, combo = { build = function() return (ns.BuildFightBody()) end } }
    known[rec.key] = rec
    list[#list + 1] = rec
  end

  local groupIndex, specIndex = {}, {}
  for i, g in ipairs(ns.GROUPS) do groupIndex[g.id] = i end
  for i, e in ipairs(ns.SPELLS) do specIndex[e.key] = i end
  table.sort(list, function(a, b)
    local ga, gb = groupIndex[a.group] or 99, groupIndex[b.group] or 99
    if ga ~= gb then return ga < gb end
    local sa, sb = specIndex[a.key] or 500, specIndex[b.key] or 500
    if sa ~= sb then return sa < sb end
    return a.name < b.name
  end)
  ns.known, ns.list = known, list
end

-- ---------------------------------------------------------------- кнопка «Бой»
ns.FIGHT_KEY = "combo_judgeattack"

-- Все атакующие заклинания, которые можно поставить в очередь.
function ns.FightCandidates(known, list)
  known, list = known or ns.known, list or ns.list
  local out = {}
  for _, r in ipairs(list) do
    if r.kind == "attack" or r.kind == "generic_harm" or r.key == "consecrate" or r.key == "holywrath" then
      out[#out + 1] = r.key
    end
  end
  return out
end

-- Рекомендуемая очередь из изученных заклинаний (растёт с уровнем сама).
function ns.RecommendedFight(known, list)
  known, list = known or ns.known, list or ns.list
  local out, used = {}, {}
  for _, k in ipairs(ns.FIGHT_RECOMMENDED) do
    if k == "@new" then
      for _, r in ipairs(list) do
        if r.kind == "generic_harm" and not used[r.key] then out[#out + 1] = r.key; used[r.key] = true end
      end
    elseif known[k] and not used[k] then
      out[#out + 1] = k; used[k] = true
    end
  end
  return out
end

function ns.FightIsCustom()
  local f = ns.cdb and ns.cdb.fight
  return f and f.mode == "custom" or false
end

-- Текущая очередь (ключи), только изученные.
function ns.FightKeys(known, list)
  known = known or ns.known
  if ns.FightIsCustom() then
    local out = {}
    for _, k in ipairs(ns.cdb.fight.list) do if known[k] then out[#out + 1] = k end end
    return out
  end
  return ns.RecommendedFight(known, list)
end

-- Текст макроса и сколько заклинаний поместилось в 255 байт.
function ns.BuildFightBody()
  local body = "#showtooltip\n/targetenemy [noharm][dead]\n/startattack"
  local used, skipped = 0, 0
  for _, k in ipairs(ns.FightKeys()) do
    local r = ns.known[k]
    if r and r.name then
      local line = "\n/cast " .. r.name
      if #body + #line <= 255 then body = body .. line; used = used + 1 else skipped = skipped + 1 end
    end
  end
  return body, used, skipped
end

-- Изменить очередь: при первом изменении копируем рекомендуемую и переходим в «свою».
function ns.EditFight(fn)
  local f = ns.cdb.fight
  if f.mode ~= "custom" then
    f.list = ns.RecommendedFight()
    f.mode = "custom"
  end
  fn(f.list)
  ns.ScanSpells()
  ns.UpdateAllMacros(true)
  if InCombatLockdown() then ns.print("Макрос «Бой» обновится после боя.") end
end

function ns.ResetFight()
  ns.cdb.fight = { mode = "auto", list = {} }
  ns.ScanSpells()
  ns.UpdateAllMacros(true)
end

-- ---------------------------------------------------------------- тексты макросов
function ns.BuildBody(rec)
  local n, k = rec.name, rec.kind
  if k == "combo" then return rec.combo.build(rec.names) end
  local head = "#showtooltip\n"
  if k == "bless" then
    local base = rec.entry and rec.entry.base or rec.key
    return head .. '/run PalMacros_Say("' .. base .. '","' .. rec.key .. '")\n'
      .. "/cast [@mouseover,help,nodead][help,nodead][@player] " .. n
  elseif k == "help" or k == "generic_help" then
    return head .. "/cast [@mouseover,help,nodead][help,nodead][@player] " .. n
  elseif k == "helpother" then
    return head .. "/cast [@mouseover,help,nodead][help,nodead] " .. n
  elseif k == "dead" then
    return head .. "/cast [@mouseover,help,dead][help,dead] " .. n
  elseif k == "urgent" then
    return head .. "/stopcasting\n/cancelaura [mod:alt] " .. n
      .. "\n/cast [nomod:alt,@mouseover,help,nodead][nomod:alt,help,nodead][nomod:alt,@player] " .. n
  elseif k == "dual" then
    return head .. "/cast [@mouseover,exists,nodead][exists,nodead][@player] " .. n
  elseif k == "attack" then
    return head .. "/targetenemy [noharm][dead]\n/cast " .. n .. "\n/startattack"
  elseif k == "generic_harm" then
    return head .. "/targetenemy [noharm][dead]\n/cast " .. n
  elseif k == "control" then
    return head .. "/stopcasting\n/targetenemy [noharm][dead]\n"
      .. "/cast [@mouseover,harm,nodead][harm,nodead] " .. n
  elseif k == "toggle" then
    return head .. "/cancelaura [mod:alt] " .. n .. "\n/cast [nomod:alt] " .. n
  elseif k == "mount" then
    return head .. "/dismount [mounted]\n/cast [nomounted] " .. n
  end
  return head .. "/cast " .. n
end

-- ---------------------------------------------------------------- работа с макросами
local function normalize(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("\r\n", "\n"):gsub("%s+$", ""))
end

local function macroIndex(name)
  if not name then return 0 end
  return GetMacroIndexByName(name) or 0
end

-- Состояние макроса: "none" | "ok" | "outdated" | "manual"
function ns.MacroState(rec)
  local saved = ns.cdb.macros[rec.key]
  if not saved then return "none" end
  local idx = macroIndex(saved.name)
  if idx == 0 then return "none" end
  local _, _, body = GetMacroInfo(idx)
  body = normalize(body)
  if body ~= normalize(saved.body) then return "manual" end
  if body ~= normalize(ns.BuildBody(rec)) then return "outdated" end
  return "ok"
end

local function freeSlots()
  local g, c = GetNumMacros()
  local maxG = MAX_ACCOUNT_MACROS or 120
  local maxC = MAX_CHARACTER_MACROS or 18
  return maxG - (g or 0), maxC - (c or 0)
end

local function uniqueName(label)
  local name = label
  local i = 2
  while macroIndex(name) ~= 0 do
    name = utf8sub(label, 13) .. i
    i = i + 1
  end
  return name
end

-- Создаёт или обновляет макрос. Возвращает индекс или nil.
function ns.EnsureMacro(rec, quiet)
  if InCombatLockdown() then
    if not quiet then ns.print("В бою макросы менять нельзя. Повторите после боя.") end
    return nil
  end
  local body = ns.BuildBody(rec)
  if #body > 255 then
    if not quiet then ns.print("Текст макроса «" .. rec.name .. "» длиннее 255 байт.") end
    return nil
  end
  local saved = ns.cdb.macros[rec.key]
  local idx = saved and macroIndex(saved.name) or 0
  if idx ~= 0 then
    local _, _, current = GetMacroInfo(idx)
    current = normalize(current)
    if current == normalize(body) then return idx end
    if current ~= normalize(saved.body) then
      if not quiet then ns.print("Макрос «" .. saved.name .. "» изменён вручную — не трогаю его.") end
      return idx
    end
    local ok, newIdx = pcall(EditMacro, idx, saved.name, nil, body)
    if ok then
      saved.body = body
      return macroIndex(saved.name) ~= 0 and macroIndex(saved.name) or newIdx
    end
    return idx
  end

  local freeG, freeC = freeSlots()
  local perChar = freeC > 0
  if not perChar and freeG <= 0 then
    if not quiet then ns.print("Нет свободных мест для макросов (общих и персонажа).") end
    return nil
  end
  local name = uniqueName(rec.label)
  local ok, newIdx = pcall(CreateMacro, name, QUESTION_ICON, body, perChar)
  if not ok or not newIdx then
    if not quiet then ns.print("Не удалось создать макрос «" .. name .. "».") end
    return nil
  end
  local realName = GetMacroInfo(newIdx) or name
  ns.cdb.macros[rec.key] = { name = realName, body = body }
  return macroIndex(realName) ~= 0 and macroIndex(realName) or newIdx
end

function ns.PickupMacroFor(rec)
  local idx = ns.EnsureMacro(rec)
  if idx and idx ~= 0 then
    PickupMacro(idx)
    if ns.RefreshUI then ns.RefreshUI() end
  end
end

-- Пересобрать все созданные аддоном макросы (кроме изменённых вручную).
function ns.UpdateAllMacros(quiet)
  if InCombatLockdown() then ns.pendingUpdate = true; return end
  local updated = 0
  for _, rec in pairs(ns.known) do
    if ns.MacroState(rec) == "outdated" then
      if ns.EnsureMacro(rec, true) then updated = updated + 1 end
    end
  end
  if ns.cdb.macros.smart then ns.EnsureSmartMacro(true) end
  if not quiet and updated > 0 then ns.print("Обновлено макросов: " .. updated .. ".") end
  if ns.RefreshUI then ns.RefreshUI() end
end

function ns.CreateAllMacros()
  if InCombatLockdown() then ns.print("В бою нельзя."); return end
  local made, failed = 0, 0
  for _, rec in ipairs(ns.list) do
    if ns.MacroState(rec) == "none" then
      if ns.EnsureMacro(rec, true) then made = made + 1 else failed = failed + 1 end
    end
  end
  ns.print("Создано макросов: " .. made .. (failed > 0 and (", не хватило мест: " .. failed) or "") .. ".")
  if ns.RefreshUI then ns.RefreshUI() end
end

-- ---------------------------------------------------------------- выбор цели
-- Тот же порядок, что в макросе: [@mouseover,help,nodead][help,nodead][@player]
-- Значения могут быть «секретными» (защищёнными игрой): такие считаем непригодными.
local function isTrue(v) return not secret(v) and v and true or false end
local function goodHelp(unit)
  return isTrue(UnitExists(unit)) and isTrue(UnitCanAssist("player", unit)) and not isTrue(UnitIsDeadOrGhost(unit))
end
local function pickHelpUnit()
  if goodHelp("mouseover") then return "mouseover" end
  if goodHelp("target") then return "target" end
  return "player"
end
ns.pickHelpUnit = pickHelpUnit

local function cooldownLeft(name)
  local start, duration
  if C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(name)
    if info then start, duration = info.startTime, info.duration end
  elseif GetSpellCooldown then
    start, duration = GetSpellCooldown(name)
  end
  if secret(start) or secret(duration) or not start or start == 0 then return 0 end
  return start + duration - GetTime()
end

local function usable(name)
  if C_Spell and C_Spell.IsSpellUsable then return C_Spell.IsSpellUsable(name) end
  if IsUsableSpell then return IsUsableSpell(name) end
  return true
end

local function outOfRange(name, unit)
  if unit == "player" then return false end
  local r
  if C_Spell and C_Spell.IsSpellInRange then
    r = C_Spell.IsSpellInRange(name, unit)
    return r == false
  elseif IsSpellInRange then
    r = IsSpellInRange(name, unit)
    return r == 0
  end
  return false
end

-- ---------------------------------------------------------------- журнал благословлённых
-- Запись делается только после успешного применения благословения (любым способом: макрос, кнопка, книга заклинаний).
local castTargets = {}  -- castGUID -> { unit data }

local function unitCandidates()
  local list = { "target", "mouseover", "focus" }
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do list[#list + 1] = "raid" .. i end
  else
    for i = 1, 4 do list[#list + 1] = "party" .. i end
  end
  return list
end

local function findUnitByName(targetName)
  if type(targetName) ~= "string" or secret(targetName) or targetName == "" then return nil end
  local short = targetName:match("^[^-]+")
  for _, u in ipairs(unitCandidates()) do
    if isTrue(UnitExists(u)) then
      local n = UnitName(u)
      local full = GetUnitName and GetUnitName(u, true)
      if not secret(n) and (n == targetName or n == short or (not secret(full) and full == targetName)) then
        return u
      end
    end
  end
end

local function isBlessingSpell(spellID)
  if not spellID or secret(spellID) then return nil end
  local name = spellName(spellID)
  if not name then return nil end
  for _, r in pairs(ns.known) do
    if r.kind == "bless" and r.name == name then return r end
  end
end

-- Снимок данных игрока в момент каста.
local function snapshot(unit, rec)
  if not unit or not isTrue(UnitIsPlayer(unit)) or isTrue(UnitIsUnit(unit, "player")) then return nil end
  local name = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
  local className, classFile = UnitClass(unit)
  local level = UnitLevel(unit)
  local race = UnitRace and UnitRace(unit)
  local guid = UnitGUID(unit)
  if secret(name) or type(name) ~= "string" or name == "" then return nil end
  if secret(className) then className, classFile = nil, nil end
  if secret(level) then level = nil end
  if secret(race) then race = nil end
  if secret(guid) then guid = nil end
  local base = rec.entry and rec.entry.base or rec.key
  return { name = name, className = className, class = classFile, level = level, race = race, guid = guid,
           spell = base }
end

function ns.RecordBlessed(data)
  local db = ns.db
  if not db or not data then return end
  local key = ns.lower(data.name)
  local p = db.players[key]
  local now = time()
  if not p then
    p = { name = data.name, first = now, count = 0, spells = {} }
    db.players[key] = p
  end
  p.name = data.name
  p.class = data.class or p.class
  p.className = data.className or p.className
  p.level = data.level and data.level > 0 and data.level or p.level
  p.race = data.race or p.race
  p.guid = data.guid or p.guid
  p.count = (p.count or 0) + 1
  p.last = now
  p.lastSpell = data.spell
  p.spells = p.spells or {}
  p.spells[data.spell] = (p.spells[data.spell] or 0) + 1
  if ns.RefreshUI then ns.RefreshUI() end
end

function ns.OnSpellcastSent(unit, targetName, castGUID, spellID)
  if unit ~= "player" or secret(castGUID) or type(castGUID) ~= "string" then return end
  local rec = isBlessingSpell(spellID)
  if not rec then return end
  local u = findUnitByName(targetName)
  if not u and (targetName == nil or targetName == "") then u = pickHelpUnit() end
  local data = snapshot(u, rec)
  if data then castTargets[castGUID] = data end
end

function ns.OnSpellcastResult(event, unit, castGUID)
  if unit ~= "player" or secret(castGUID) or not castGUID then return end
  local data = castTargets[castGUID]
  castTargets[castGUID] = nil
  if data and event == "UNIT_SPELLCAST_SUCCEEDED" then ns.RecordBlessed(data) end
end

function ns.SortedPlayers(filter)
  local out = {}
  filter = filter and filter ~= "" and ns.lower(filter) or nil
  for _, p in pairs(ns.db.players) do
    local hay = ns.lower((p.name or "") .. " " .. (p.className or "") .. " " .. (p.race or ""))
    if not filter or hay:find(filter, 1, true) then out[#out + 1] = p end
  end
  table.sort(out, function(a, b) return (a.last or 0) > (b.last or 0) end)
  return out
end

function ns.WhoPlayer(name)
  local short = name:match("^[^-]+") or name
  local query = 'n-"' .. short .. '"'
  if C_FriendList and C_FriendList.SendWho then
    C_FriendList.SendWho(query)
  elseif SendWho then
    SendWho(query)
  end
  if FriendsFrame and not FriendsFrame:IsShown() and ToggleFriendsFrame then pcall(ToggleFriendsFrame, 2) end
end

function ns.AddFriend(name)
  if C_FriendList and C_FriendList.AddFriend then
    C_FriendList.AddFriend(name)
  elseif AddFriend then
    AddFriend(name)
  end
  ns.print("Запрос в друзья: " .. name .. ".")
end

function ns.WhisperPlayer(name)
  if ChatFrame_SendTell then ChatFrame_SendTell(name)
  elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end
end

-- ---------------------------------------------------------------- фразы
local lastIndex, lastSaid = {}, {}

local function pickPhrase(key)
  local list = ns.GetPhrases(key)
  if #list == 0 then return nil end
  local i = math.random(#list)
  if #list > 1 and i == lastIndex[key] then i = (i % #list) + 1 end
  lastIndex[key] = i
  return list[i]
end

function ns.FormatPhrase(text, unit, spell)
  local name = UnitName(unit) or ""
  local className = UnitIsPlayer(unit) and UnitClass(unit) or (UnitCreatureFamily and UnitCreatureFamily(unit)) or ""
  if secret(name) then name = "" end
  if secret(className) then className = "" end
  local out = text:gsub("{name}", function() return name end)
    :gsub("{имя}", function() return name end)
    :gsub("{class}", function() return className or "" end)
    :gsub("{spell}", function() return spell or "" end)
  return out
end

-- Вызывается из макроса до /cast, пока идёт нажатие клавиши (иначе «Сказать» заблокирован игрой).
function ns.Announce(baseKey, spellNameStr, unit)
  local db = ns.db
  if not db or not db.announce or not db.blessOn[baseKey] then return end
  if not spellNameStr or not unit or not UnitExists(unit) then return end
  if unit == "player" or UnitIsUnit(unit, "player") then
    if not db.announceSelf then return end
  end
  if UnitCastingInfo and UnitCastingInfo("player") then return end
  if IsMounted and IsMounted() then return end
  if cooldownLeft(spellNameStr) > 0.15 then return end
  if not usable(spellNameStr) then return end
  if outOfRange(spellNameStr, unit) then return end
  if (db.chance or 100) < 100 and math.random(100) > db.chance then return end

  local guid = UnitGUID(unit)
  if guid and not secret(guid) then
    local mark = guid .. ":" .. baseKey
    local now = GetTime()
    if lastSaid[mark] and now - lastSaid[mark] < (db.repeatDelay or 0) then return end
    lastSaid[mark] = now
  end

  local text = pickPhrase(baseKey)
  if not text then return end
  text = ns.FormatPhrase(text, unit, spellNameStr)
  if #text > 255 then text = text:sub(1, 255) end
  local channel = db.channel or "SAY"
  if channel == "PARTY" then
    if IsInRaid and IsInRaid() then channel = "RAID"
    elseif not (IsInGroup and IsInGroup()) then channel = "SAY" end
  end
  local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
  pcall(send, text, channel)
end

-- Глобальная функция для макросов благословений.
function PalMacros_Say(baseKey, spellKey)
  if not ns.isPaladin then return end
  local rec = ns.known[spellKey or baseKey]
  if not rec then return end
  -- ошибка во фразе не должна мешать самому заклинанию
  pcall(function() ns.Announce(baseKey, rec.name, pickHelpUnit()) end)
end

-- ---------------------------------------------------------------- умная кнопка благословений
local smart = CreateFrame("Button", "PalMacrosSmart", UIParent, "SecureActionButtonTemplate")
smart:SetSize(1, 1)
smart:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
smart:RegisterForClicks("AnyUp", "AnyDown")
smart:SetAttribute("type", "spell")

-- Выбор благословения для юнита: первое изученное из приоритета класса; Shift - большое.
function ns.ChooseBlessing(unit)
  local cls = "OTHER"
  if UnitIsPlayer(unit) then
    local _, c = UnitClass(unit)
    if c and not secret(c) and ns.db.prio[c] then cls = c end
  end
  local prio = ns.db.prio[cls] or ns.DEFAULT_PRIO.OTHER
  local greater = IsShiftKeyDown()
  for _, key in ipairs(prio) do
    if key ~= "none" then
      local rec = greater and ns.known["g" .. key] or ns.known[key]
      if rec then return rec, key end
    end
  end
  -- запасной вариант: любое известное благословение
  for _, key in ipairs(ns.BLESS_KEYS) do
    if ns.known[key] then return ns.known[key], key end
  end
end

local function smartPreClick(self)
  if InCombatLockdown() then
    if not self.warned then
      ns.print("В бою умная кнопка не выбирает благословение. Используйте отдельные макросы благословений.")
      self.warned = true
    end
    return
  end
  self.warned = nil
  local unit = pickHelpUnit()
  local rec, baseKey = ns.ChooseBlessing(unit)
  if not rec then
    self:SetAttribute("spell", nil)
    ns.print("Благословения ещё не изучены.")
    return
  end
  self:SetAttribute("type", "spell")
  self:SetAttribute("spell", rec.name)
  self:SetAttribute("unit", unit)
  pcall(ns.Announce, baseKey, rec.name, unit)
end
smart:SetScript("PreClick", function(self) ns.safe("умная кнопка", smartPreClick, self) end)

function ns.SmartRecord()
  local icon = ns.known.kings and ns.known.kings.name or (ns.known.might and ns.known.might.name)
  return {
    key = "smart", label = "Благослов.", name = "Умное благословение", kind = "smart",
    body = "#showtooltip" .. (icon and (" " .. icon) or "") .. "\n/click PalMacrosSmart",
  }
end

function ns.EnsureSmartMacro(quiet)
  local rec = ns.SmartRecord()
  rec.combo = { build = function() return rec.body end }
  rec.kind = "combo"
  rec.names = {}
  return ns.EnsureMacro(rec, quiet)
end

function ns.PickupSmart()
  local idx = ns.EnsureSmartMacro()
  if idx and idx ~= 0 then PickupMacro(idx) end
  if ns.RefreshUI then ns.RefreshUI() end
end

-- ---------------------------------------------------------------- события
local ev = CreateFrame("Frame")
-- В разных клиентах набор событий отличается: неизвестное событие не должно ломать аддон.
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB",
                     "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                     "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
                     "UNIT_SPELLCAST_INTERRUPTED" }) do
  pcall(ev.RegisterEvent, ev, e)
end

local scanQueued
local function queueScan()
  if scanQueued then return end
  scanQueued = true
  C_Timer.After(0.5, function()
    scanQueued = false
    if not ns.isPaladin then return end
    ns.safe("книга заклинаний", ns.ScanSpells)
    ns.safe("обновление макросов", ns.UpdateAllMacros, true)
  end)
end

ev:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
  if event == "UNIT_SPELLCAST_SENT" then
    if arg1 == "player" and ns.isPaladin then ns.safe("журнал", ns.OnSpellcastSent, arg1, arg2, arg3, arg4) end
    return
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    if arg1 == "player" and ns.isPaladin then ns.safe("журнал", ns.OnSpellcastResult, event, arg1, arg2) end
    return
  end
  if event == "ADDON_LOADED" and arg1 == ADDON then
    ns.safe("загрузка настроек", initDB)
  elseif event == "PLAYER_LOGIN" then
    if not ns.db then initDB() end
    -- версия: сообщаем об установке и каждом обновлении (первым делом, чтобы было видно, что аддон жив)
    local prev = ns.db.lastVersion
    if prev ~= ns.version then
      if prev then
        ns.print("обновлён: |cff999999" .. prev .. "|r > |cff55ff55" .. ns.version .. "|r. Окно: /pal")
      else
        ns.print("установлен, версия |cff55ff55" .. ns.version .. "|r. Окно: /pal")
      end
      ns.db.lastVersion = ns.version
    end
    local _, cls = UnitClass("player")
    ns.isPaladin = cls == "PALADIN"
    if ns.isPaladin then
      ns.safe("книга заклинаний", ns.ScanSpells)
      C_Timer.After(2, function() ns.safe("обновление макросов", ns.UpdateAllMacros, true) end)
    end
    if ns.InitUI then ns.safe("кнопка у миникарты и ярлык", ns.InitUI) end
  elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE"
      or event == "PLAYER_LEVEL_UP" then
    queueScan()
  elseif event == "PLAYER_REGEN_DISABLED" then
    -- последний шанс до блокировки: не даём умной кнопке повторить прошлый выбор в бою
    pcall(smart.SetAttribute, smart, "spell", nil)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if ns.pendingUpdate then
      ns.pendingUpdate = false
      ns.safe("обновление макросов", ns.UpdateAllMacros, true)
    end
  end
end)

-- ---------------------------------------------------------------- команды
SLASH_PALMACROS1 = "/pal"
SLASH_PALMACROS2 = "/palmacros"
SlashCmdList.PALMACROS = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if not ns.isPaladin and msg ~= "" and msg ~= "version" and msg ~= "ver" then ns.print("Аддон работает только на паладине."); return end
  if msg == "all" then
    ns.CreateAllMacros()
  elseif msg == "update" then
    ns.ScanSpells(); ns.UpdateAllMacros()
  elseif msg == "say" or msg == "chat" then
    ns.db.announce = not ns.db.announce
    ns.print("Фразы в чат: " .. (ns.db.announce and "включены" or "выключены") .. ".")
    if ns.RefreshUI then ns.RefreshUI() end
  elseif msg == "test" then
    local unit = pickHelpUnit()
    local rec, key = ns.ChooseBlessing(unit)
    if rec then
      ns.print("Для «" .. (UnitName(unit) or "?") .. "»: " .. rec.name .. " — "
        .. ns.FormatPhrase(pickPhrase(key) or "", unit, rec.name))
    end
  elseif msg == "players" or msg == "list" then
    if ns.OpenUI then ns.OpenUI("players") end
  elseif msg == "version" or msg == "ver" then
    ns.print("версия " .. ns.version)
  elseif msg == "config" or msg == "settings" or msg == "options" then
    if ns.OpenUI then ns.OpenUI("settings") end
  elseif msg == "help" then
    ns.print("Pal Macros v" .. ns.version .. ". /pal settings — настройки; /pal version — версия.")
    ns.print("/pal players — журнал благословлённых игроков.")
    ns.print("/pal — окно; /pal all — создать все макросы; /pal update — обновить;")
    ns.print("/pal say — вкл/выкл фразы; /pal test — что выберет умная кнопка (только в свой чат).")
  else
    if ns.ToggleUI then ns.ToggleUI() end
  end
end

function PalMacros_OnCompartmentClick()
  if ns.ToggleUI then ns.ToggleUI() end
end
