local PLUGIN = PLUGIN
PLUGIN.name = "Pose Studio"
PLUGIN.author = "Hutten"
PLUGIN.description = "Personal poses, keyframe animations and a moderated shared library."

ix.PoseStudio = ix.PoseStudio or {}
ix.util.Include("sh_clip.lua")
ix.util.Include("sh_rig.lua")
ix.util.Include("sh_placement.lua")
ix.util.Include("sv_studio.lua")
ix.util.Include("sv_placement.lua")
ix.util.Include("sv_radial.lua")
ix.util.Include("cl_playback.lua")
ix.util.Include("cl_rig.lua")
ix.util.Include("cl_preview.lua")
ix.util.Include("cl_placement.lua")
ix.util.Include("cl_gizmo.lua")
ix.util.Include("cl_starter_data.lua")
ix.util.Include("cl_starters.lua")
ix.util.Include("cl_pose_tools.lua")
ix.util.Include("cl_targets.lua")
ix.util.Include("cl_editor.lua")
ix.util.Include("cl_radial.lua")

ix.command.Add("PoseEditor", {
 description = "Открыть редактор поз и анимаций.",
 OnRun = function(_, client) PLUGIN:OpenStudio(client) end
})
ix.command.Add("PoseStop", {
 description = "Остановить свою анимацию.",
 OnRun = function(_, client) PLUGIN:StopPose(client); PLUGIN:StopPlacement(client) end
})
ix.command.Add("PosePlay", {
 description = "Проиграть сохранённую анимацию по имени или номеру.",
 arguments = ix.type.text,
 OnRun = function(_, client, name) PLUGIN:PlayNamedPose(client, name) end
})
ix.command.Add("PosePropAdd", {
 description = "Разрешить модель из контента сервера как реквизит редактора.",
 adminOnly = true, arguments = ix.type.text,
 OnRun = function(_, client, model) PLUGIN:SetPoseProp(client, model, true) end
})
ix.command.Add("PosePropRemove", {
 description = "Убрать модель из разрешённого реквизита.",
 adminOnly = true, arguments = ix.type.text,
 OnRun = function(_, client, model) PLUGIN:SetPoseProp(client, model, false) end
})
