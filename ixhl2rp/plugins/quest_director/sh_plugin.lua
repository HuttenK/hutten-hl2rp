local PLUGIN = PLUGIN
PLUGIN.name = "Quest Director"
PLUGIN.author = "AUTONOMOUS / Foundation restoration"
PLUGIN.description = "NPC, branching dialogue, personal and group assignments, rewards and journal."
CAMI.RegisterPrivilege({Name = "Helix - Quest Director", MinAccess = "admin"})
ix.util.Include("sh_model.lua")
ix.util.Include("sv_store.lua")
ix.util.Include("sv_runtime.lua")
ix.util.Include("sv_editor.lua")
ix.util.Include("sv_network.lua")
ix.util.Include("sh_placement_tools.lua")
for _, name in ipairs({"ui", "player_ui", "portrait", "dialogue", "quest_cards", "group", "npc_editor", "editor", "rewards", "reputation", "workbench", "placements"}) do
    ix.util.Include("cl_" .. name .. ".lua")
end
ix.command.Add("QuestAdmin", {description = "Конструктор квестов и NPC.", adminOnly = true,
    OnRun = function(_, client) if ix.questDirector.CanEdit(client) then ix.questDirector:OpenAdmin(client) end end})
ix.command.Add("QuestJournal", {description = "Личный журнал заданий и наград.",
    OnRun = function(_, client) ix.questDirector:OpenJournal(client) end})
ix.command.Add("QuestExamples", {description = "Создать безопасные тестовые задания.", adminOnly = true,
    OnRun = function(_, client)
        if not ix.questDirector.CanEdit(client) then return end
        local ok, message = ix.questDirector:EnsureQuickExamples(client)
        client:Notify(message)
        if ok then ix.questDirector:OpenAdmin(client) end
    end})
