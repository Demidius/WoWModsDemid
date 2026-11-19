-- Cache item objectives of quests currently in the player's quest log.
local requiredIDs, requiredNames = {}, {}
local function public(v)
    if issecretvalue and issecretvalue(v) then return false end
    if type(v) == "table" and issecrettable and issecrettable(v) then return false end
    return true
end
local function rememberID(id, title)
    if public(id) and type(id) == "number" and id > 0 then requiredIDs[id] = title or true end
end
local function rememberName(text, title)
    if not public(text) or type(text) ~= "string" then return end
    local name = text:match("^%s*(.-)%s*:%s*%d+%s*/%s*%d+%s*$")
    if name and name ~= "" then requiredNames[name] = title or true end
end
function VendorOrAuctionLogic.refreshQuests()
    requiredIDs, requiredNames = {}, {}
    if not C_QuestLog or not C_QuestLog.GetNumQuestLogEntries or not C_QuestLog.GetInfo then return end
    local db
    if QuestieLoader and type(QuestieLoader.ImportModule) == "function" then
        local ok, result = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
        if ok and type(result) == "table" and type(result.GetQuest) == "function" then db = result end
    end
    local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not ok or not public(count) or type(count) ~= "number" then return end
    for i = 1, count do
        local success, info = pcall(C_QuestLog.GetInfo, i)
        if success and public(info) and type(info) == "table" and public(info.isHeader) and not info.isHeader
            and public(info.questID) and type(info.questID) == "number" then
            local id = info.questID
            local title = public(info.title) and type(info.title) == "string" and info.title or true
            if db then
                local found, quest = pcall(db.GetQuest, id)
                if found and public(quest) and type(quest) == "table" then
                    local objectives = quest.objectives
                    if public(objectives) and type(objectives) == "table" and public(objectives[3]) and type(objectives[3]) == "table" then
                        for _, objective in pairs(objectives[3]) do
                            if public(objective) and type(objective) == "table" then rememberID(objective[1], title) end
                        end
                    end
                    if public(quest.requiredSourceItems) and type(quest.requiredSourceItems) == "table" then
                        for _, itemID in pairs(quest.requiredSourceItems) do rememberID(itemID, title) end
                    end
                end
            end
            if C_QuestLog.GetQuestObjectives then
                local found, objectives = pcall(C_QuestLog.GetQuestObjectives, id)
                if found and public(objectives) and type(objectives) == "table" then
                    for _, objective in ipairs(objectives) do
                        if public(objective) and type(objective) == "table" then
                            local kind = objective.type
                            if public(kind) and (kind == "item" or kind == nil) then rememberName(objective.text, title) end
                        end
                    end
                end
            end
        end
    end
end
function VendorOrAuctionLogic.questForItem(id, name)
    return requiredIDs[id] or (name and requiredNames[name])
end
