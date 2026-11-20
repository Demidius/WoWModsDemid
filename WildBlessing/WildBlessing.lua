local addonName = ...
local frame = CreateFrame("Frame")
local pending = {}
local markName
local playerGUID
local isDruid = false

local oldBlessings = {
    "{имя}, да хранит тебя шёпот древних лесов! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, пусть свет Элуны освещает твой путь! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, да укроют тебя ветви Тельдрассила! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, пусть звёзды и духи леса оберегают тебя! Ты получаешь мой Знак под номером {номер}.",
    "{имя}, прими благословение Изумрудного Сна! Ты получаешь мой Знак под номером {номер}.",
}

local defaultBlessings = {
    "Elune guide you, {имя}! Mark #{номер}.",
    "Stars watch over you, {имя}! Mark #{номер}.",
    "The forest blesses you, {имя}! Mark #{номер}.",
    "Walk in moonlight, {имя}! Mark #{номер}.",
    "Dream in peace, {имя}! Mark #{номер}.",
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
    if GetMacroIndexByName("WildMark") ~= 0 then
        return
    end
    local name = getMarkName()
    if not name then
        sayLocal("Не удалось определить название заклинания. Попробуйте /wild macro позже.")
        return
    end
    local body = "#showtooltip " .. name .. "\n/cast [@mouseover,help,nodead] " .. name
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

local function recordBlessing(guid, name)
    local number = WildBlessingDB.players[guid]
    if not number then
        WildBlessingDB.count = WildBlessingDB.count + 1
        number = WildBlessingDB.count
        WildBlessingDB.players[guid] = number
    end
    local blessings = WildBlessingDB.blessings
    local template = blessings[((WildBlessingDB.messages or 0) % #blessings) + 1]
    WildBlessingDB.messages = (WildBlessingDB.messages or 0) + 1
    local text = template:gsub("{имя}", function() return name end)
    text = text:gsub("{номер}", function() return tostring(number) end)
    pending[#pending + 1] = text
    openNext()
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
        sayLocal("В новом тексте используйте {имя} и {номер}.")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        WildBlessingDB = WildBlessingDB or {}
        WildBlessingDB.players = WildBlessingDB.players or {}
        WildBlessingDB.count = WildBlessingDB.count or 0
        if not WildBlessingDB.blessings or #WildBlessingDB.blessings == 0 then
            WildBlessingDB.blessings = {}
            for i, text in ipairs(defaultBlessings) do WildBlessingDB.blessings[i] = text end
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
    elseif event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        isDruid = class == "DRUID"
        playerGUID = UnitGUID("player")
        markName = getMarkName()
        createMacro()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and isDruid and WildBlessingDB then
        local _, subevent, _, sourceGUID, _, _, _, destGUID, destName, _, _, _, spellName = CombatLogGetCurrentEventInfo()
        if (subevent == "SPELL_AURA_APPLIED" or subevent == "SPELL_AURA_REFRESH")
            and sourceGUID == playerGUID and destGUID and destGUID:match("^Player%-")
            and destName and markName and spellName == markName then
            recordBlessing(destGUID, destName)
        end
    end
end)

