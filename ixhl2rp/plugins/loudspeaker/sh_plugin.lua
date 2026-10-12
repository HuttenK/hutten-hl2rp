local PLUGIN = PLUGIN
PLUGIN.name = "Loudspeaker"
PLUGIN.author = "Hutten"
PLUGIN.description = "Synchronized positional announcements."
PLUGIN.speakerModel = "models/props_wasteland/speakercluster01a.mdl"
for _, definition in ipairs({{"loudspeaker", true}, {"loudspeakeronce", false}}) do
 local loop = definition[2]
 ix.command.Add(definition[1], {adminOnly = true, arguments = {ix.type.string},
  description = loop and "Запустить оповещение по кругу." or "Проиграть оповещение один раз.",
  OnRun = function(_, client, path)
   if not ix.BroadcastMedia.ValidSource(path) then return "Недопустимый путь к звуку." end
   PLUGIN.path, PLUGIN.started, PLUGIN.loop = path, ix.BroadcastMedia.StartTime(PLUGIN.started), loop
   ix.data.Set("ls_sound", path); ix.data.Set("ls_loop", loop)
   PLUGIN:Sync()
   client:Notify("Оповещение запущено.")
  end})
end
ix.command.Add("loudspeakerstop", {adminOnly = true, description = "Остановить оповещение.", OnRun = function()
 PLUGIN.path, PLUGIN.started = "", CurTime()
 ix.data.Set("ls_sound", ""); PLUGIN:Sync()
end})
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
