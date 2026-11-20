-- Check active quest items from both Questie and the native quest objectives.
VendorOrAuctionLogic = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 2 end,
    GetInfo = function(index)
        if index == 1 then return {isHeader = true} end
        return {isHeader = false, questID = 17, title = "Active quest"}
    end,
    GetQuestObjectives = function()
        return {{type = "item", text = "Wolf meat: 7/10"}, {type = "monster", text = "Wolf: 1/2"}}
    end,
}
QuestieLoader = {ImportModule = function(_, name)
    assert(name == "QuestieDB")
    return {GetQuest = function(id)
        assert(id == 17)
        return {objectives = {[3] = {{41}, {42}}}, requiredSourceItems = {43}}
    end}
end}
dofile("VendorOrAuction/QuestItems.lua")
local ns = VendorOrAuctionLogic
ns.refreshQuests()
assert(ns.questForItem(41) == "Active quest")
assert(ns.questForItem(43) == "Active quest")
assert(ns.questForItem(99, "Wolf meat") == "Active quest")
assert(not ns.questForItem(99, "Wolf"), "monster objectives must not mark items")
local savedGetInfo = C_QuestLog.GetInfo
C_QuestLog.GetInfo = function() error("quest data is temporarily unavailable") end
ns.refreshQuests()
assert(ns.questForItem(41) == "Active quest", "a failed refresh must keep the previous protections")
C_QuestLog.GetInfo = savedGetInfo
C_QuestLog.GetQuestObjectives = function() error("objectives are temporarily unavailable") end
ns.refreshQuests()
assert(ns.questForItem(99, "Wolf meat") == "Active quest", "an objective failure must not discard the previous snapshot")
C_QuestLog.GetNumQuestLogEntries = function() return 0 end
ns.refreshQuests()
assert(not ns.questForItem(41) and not ns.questForItem(99, "Wolf meat"), "old quests must be cleared")
print("Quest scenarios passed")
