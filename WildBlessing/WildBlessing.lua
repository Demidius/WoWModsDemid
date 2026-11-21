local addonName = ...
local frame = CreateFrame("Frame")
local pending = {}
local markName
local casts = {}
local attempts = {}
local sendingAttempt
local isDruid = false

local oldBlessings = {
    "{имя}, да хранит тебя шёпот древних лесов! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, пусть свет Элуны освещает твой путь! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, да укроют тебя ветви Тельдрассила! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, пусть звёзды и духи леса оберегают тебя! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, прими благословение Изумрудного Сна! Ты получаешь мой Знак под номером {номер}.",
}

local defaultBlessings = {
    "Elune guide you, {имя}! #{номер}.",
    "Stars watch over you, {имя}! #{номер}.",
    "The forest blesses you, {имя}! #{номер}.",
    "Walk in moonlight, {имя}! #{номер}.",
    "Dream in peace, {имя}! #{номер}.",
}

local function sayLocal(message)
    print("|cff7fcf75My Blessing:|r " .. message)
end

local function getMarkName()
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(1126)
    end
    if GetSpellInfo then
        return GetSpellInfo(1126)
    end
end

local function createMacro()
    if not isDruid then return end
    if InCombatLockdown() then
        sayLocal("Создание макроса недоступно в бою. После боя введите /wild macro.")
        return
    end
    local existing = GetMacroIndexByName("WildMark")
    local name = getMarkName()
    if not name then
        sayLocal("Не удалось определить название заклинания. Попробуйте /wild macro позже.")
        return
    end
    local legacyBody = "#showtooltip " .. name .. "\n/cast [@mouseover,help,nodead] " .. name
    local body = "#showtooltip " .. name .. "\n/run WildBlessingAnnounce()\n/cast [@mouseover,help,nodead] " .. name
    if existing ~= 0 then
        local _, _, oldBody = GetMacroInfo(existing)
        if type(oldBody) == "string" then
            oldBody = oldBody:gsub("\r\n", "\n"):gsub("%s+$", "")
        end
        if oldBody == legacyBody then
            local ok = pcall(EditMacro, existing, nil, nil, body)
            if ok then sayLocal("Макрос WildMark обновлён.") end
        elseif oldBody ~= body then
            sayLocal("Ваш макрос WildMark изменён вручную; добавьте перед /cast строку /run WildBlessingAnnounce() или создайте макрос заново.")
        end
        return
    end
    local ok, index = pcall(CreateMacro, "WildMark", "INV_Misc_QuestionMark", body, 1)
    if ok and index then
        sayLocal("Макрос WildMark создан в разделе макросов персонажа. Перетащите его на панель.")
    else
        sayLocal("Не удалось создать макрос. Проверьте, есть ли свободное место в макросах персонажа.")
    end
end

local function openNext()
    if #pending == 0 then return end
    if ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow() then
        sayLocal("Благословение ожидает отправки. Закончите ввод и введите /wild next.")
        return
    end
    local message = table.remove(pending, 1)
    ChatFrame_OpenChat("/say " .. message)
    if #pending > 0 then
        sayLocal("Ещё благословений в очереди: " .. #pending .. ". После отправки введите /wild next.")
    end
end

local function isSecret(value)
    return issecretvalue and issecretvalue(value) or false
end

local function findPlayer(targetName)
    if isSecret(targetName) or type(targetName) ~= "string" or targetName == "" then return end
    local candidates = { "mouseover", "target", "focus", "player" }
    for i = 1, 4 do candidates[#candidates + 1] = "party" .. i end
    for i = 1, 40 do candidates[#candidates + 1] = "raid" .. i end
    local found
    for _, unit in ipairs(candidates) do
        local isPlayer = UnitIsPlayer(unit)
        if not isSecret(isPlayer) and isPlayer then
            local name = GetUnitName(unit, true)
            local short = UnitName(unit)
            local guid = UnitGUID(unit)
            if not isSecret(name) and not isSecret(short) and not isSecret(guid)
                and type(name) == "string" and type(short) == "string"
                and type(guid) == "string" and guid:match("^Player%-")
                and (targetName == name or targetName == short) then
                if found and found.guid ~= guid then return end
                found = { name = name, guid = guid }
            end
        end
    end
    return found
end

local function isMark(spellID)
    if isSecret(spellID) or type(spellID) ~= "number" then return false end
    local name
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    elseif GetSpellInfo then
        name = GetSpellInfo(spellID)
    end
    if not markName then markName = getMarkName() end
    return not isSecret(name) and not isSecret(markName) and name ~= nil and name == markName
end

local function formatBlessing(name, number)
    local blessings = WildBlessingDB.blessings
    local template = blessings[((WildBlessingDB.messages or 0) % #blessings) + 1]
    local text = template:gsub("{имя}", function() return name end)
    return (text:gsub("{номер}", function() return tostring(number) end))
end

-- Called synchronously by the player's WildMark button, before the cast request.
function WildBlessingAnnounce()
    if not isDruid or not WildBlessingDB then return end
    local isPlayer = UnitIsPlayer("mouseover")
    local friendly = UnitCanAssist("player", "mouseover")
    local dead = UnitIsDeadOrGhost("mouseover")
    if isSecret(isPlayer) or isSecret(friendly) or isSecret(dead)
        or not isPlayer or not friendly or dead then return end
    local name, guid = GetUnitName("mouseover", true), UnitGUID("mouseover")
    if isSecret(name) or isSecret(guid) or type(name) ~= "string" or type(guid) ~= "string"
        or not guid:match("^Player%-") then return end
    if WildBlessingDB.names[string.lower(name)] or WildBlessingDB.players[guid] or attempts[guid] then return end
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return end
    local attempt = { text = formatBlessing(name, WildBlessingDB.count + 1), guid = guid }
    attempts[guid] = attempt
    sendingAttempt = attempt
    local ok = pcall(send, attempt.text, "SAY")
    sendingAttempt = nil
    if not ok or attempt.blocked then
        attempts[guid] = nil
        return
    end
    C_Timer.After(3, function()
        if attempts[guid] == attempt then attempts[guid] = nil end
    end)
end

local function recordBlessing(player, attempt)
    local name, guid = player.name, player.guid
    local key = string.lower(name)
    if WildBlessingDB.names[key] then return end
    local number = WildBlessingDB.players[guid]
    if number then
        -- Migrate identities recorded by the previous GUID-only version silently.
        WildBlessingDB.names[key] = { name = name, guid = guid, number = number }
        return
    end
    WildBlessingDB.count = WildBlessingDB.count + 1
    number = WildBlessingDB.count
    WildBlessingDB.players[guid] = number
    WildBlessingDB.names[key] = { name = name, guid = guid, number = number }
    if WildBlessingRefreshSettings then WildBlessingRefreshSettings() end
    local text = formatBlessing(name, number)
    WildBlessingDB.messages = (WildBlessingDB.messages or 0) + 1
    if attempt then
        C_Timer.After(2, function()
            if not attempt.confirmed then
                pending[#pending + 1] = text
                sayLocal("Отправка не подтверждена. При необходимости введите /wild next.")
            end
        end)
    else
        pending[#pending + 1] = text
        openNext()
    end
end

SLASH_WILDBLESSING1 = "/wild"
SlashCmdList.WILDBLESSING = function(message)
    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command)
    if command == "settings" then
        WildBlessingToggleSettings()
    elseif command == "add" then
        if not argument:find("{имя}", 1, true) or not argument:find("{номер}", 1, true) then
            sayLocal("Добавьте в текст обе подстановки: {имя} и {номер}.")
        elseif #argument > 180 then
            sayLocal("Текст слишком длинный. Сократите его до 180 байт, чтобы он поместился в чат.")
        else
            table.insert(WildBlessingDB.blessings, argument)
            sayLocal("Благословение добавлено под номером " .. #WildBlessingDB.blessings .. ".")
        end
    elseif command == "list" then
        for i, text in ipairs(WildBlessingDB.blessings) do
            sayLocal(i .. ": " .. text)
        end
    elseif command == "remove" then
        local index = tonumber(argument)
        if not index or index ~= math.floor(index) or not WildBlessingDB.blessings[index] then
            sayLocal("Укажите номер из списка: /wild remove 2")
        elseif #WildBlessingDB.blessings == 1 then
            sayLocal("Нужно оставить хотя бы одно благословение.")
        else
            table.remove(WildBlessingDB.blessings, index)
            sayLocal("Благословение удалено.")
        end
    elseif command == "players" then
        local names = {}
        for _, entry in pairs(WildBlessingDB.names) do names[#names + 1] = entry end
        table.sort(names, function(a, b) return a.number < b.number end)
        if #names == 0 then sayLocal("Список игроков пока пуст.") end
        for _, entry in ipairs(names) do sayLocal("#" .. entry.number .. ": " .. entry.name) end
    elseif command == "macro" then
        createMacro()
    elseif command == "next" then
        if #pending == 0 then
            sayLocal("Очередь благословений пуста.")
        else
            C_Timer.After(0, openNext)
        end
    else
        sayLocal("Уникальных игроков: " .. (WildBlessingDB and WildBlessingDB.count or 0) .. ".")
        sayLocal("/wild settings — настройки; /wild macro — создать макрос; /wild next — следующее сообщение.")
        sayLocal("/wild list — список; /wild add ТЕКСТ — добавить; /wild remove НОМЕР — удалить.")
        sayLocal("/wild players — имена игроков. В новом тексте используйте {имя} и {номер}.")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WildBlessingDB = WildBlessingDB or {}
        WildBlessingDB.players = WildBlessingDB.players or {}
        WildBlessingDB.names = WildBlessingDB.names or {}
        WildBlessingDB.count = WildBlessingDB.count or 0
        if not WildBlessingDB.blessings or #WildBlessingDB.blessings == 0 then
            WildBlessingDB.blessings = {}
            for i, text in ipairs(defaultBlessings) do WildBlessingDB.blessings[i] = text end
        end
        if not WildBlessingDB.shortDefaults then
            for i, text in ipairs(WildBlessingDB.blessings) do
                for _, newText in ipairs(defaultBlessings) do
                    local previous = newText:gsub("! #", "! Mark #")
                    if text == previous then WildBlessingDB.blessings[i] = newText; break end
                end
            end
            WildBlessingDB.shortDefaults = true
        end
        if not WildBlessingDB.englishDefaults then
            for i, text in ipairs(WildBlessingDB.blessings) do
                for j, oldText in ipairs(oldBlessings) do
                    if text == oldText then
                        WildBlessingDB.blessings[i] = defaultBlessings[j]
                        break
                    end
                end
            end
            WildBlessingDB.englishDefaults = true
        end
    elseif (event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN") and sendingAttempt then
        sendingAttempt.blocked = true
    elseif event == "CHAT_MSG_SAY" and not isSecret(arg1) and not isSecret(arg2)
        and type(arg1) == "string" and type(arg2) == "string" then
        local myName = UnitName("player")
        local myFullName = GetUnitName("player", true)
        if not isSecret(myName) and not isSecret(myFullName) and type(myName) == "string"
            and (arg2 == myName or arg2 == myFullName or arg2:match("^[^-]+") == myName) then
            for _, attempt in pairs(attempts) do
                if attempt.text == arg1 then attempt.confirmed = true end
            end
        end
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        isDruid = class == "DRUID"
        markName = getMarkName()
        createMacro()
    elseif event == "UNIT_SPELLCAST_SENT" and isDruid and arg1 == "player" then
        -- SENT: player, target name, cast GUID, spell ID.
        if not isSecret(arg3) and type(arg3) == "string" and isMark(arg4) then
            local player = findPlayer(arg2)
            casts[arg3] = { player = player, attempt = player and attempts[player.guid] }
        end
    elseif (event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED") and arg1 == "player" then
        -- SUCCEEDED/FAILED: player, cast GUID, spell ID.
        if not isSecret(arg2) and type(arg2) == "string" then
            local cast = casts[arg2]
            casts[arg2] = nil
            if cast and event == "UNIT_SPELLCAST_SUCCEEDED" and isMark(arg3) then
                if cast.player then
                    recordBlessing(cast.player, cast.attempt)
                else
                    sayLocal("Не удалось определить игрока; благословение не записано.")
                end
            end
        end
    end
end)

