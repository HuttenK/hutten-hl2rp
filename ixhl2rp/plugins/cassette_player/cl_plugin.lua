local PLUGIN=PLUGIN
local M=ix.BroadcastMedia
if PLUGIN.audio then PLUGIN.audio:Destroy() end
PLUGIN.audio=M.NewAudio("Cassette",80,600)
local cache,refresh={},0
hook.Add("Think","ix_boombox_audio",function()
 if not IsValid(LocalPlayer()) then return end
 if CurTime()>=refresh then cache=ents.FindByClass("ix_boombox"); refresh=CurTime()+2 end
 local sources={}
 for _,ent in ipairs(cache) do
  if IsValid(ent) then
   sources[ent]={path=ent:GetNetVar("boombox_sound",""),start=ent:GetNetVar("boombox_stime",0),loop=true,
    volume=M.Volume(LocalPlayer():GetPos():Distance(ent:GetPos()),80,600)}
  end
 end
 PLUGIN.audio:Update(sources)
end)
function PLUGIN:OnUnload()
 self.audio:Destroy(); hook.Remove("Think","ix_boombox_audio")
end
hook.Add("ShutDown","ix_boombox_cleanup",function() PLUGIN.audio:Destroy() end)
concommand.Add("ix_cassette_status",function() PLUGIN.audio:Status() end)
-- Battery-powered cassette players intentionally remain usable during a blackout.
-- ─── Диалог записи кассеты ───────────────────────────────────────────────────
net.Receive("cassette.record", function()
	local itemID = net.ReadInt(32)
	Derma_StringRequest(
		"Название кассеты",
		"Введите название (оставьте пустым для сброса):",
		"",
		function(name)
			Derma_StringRequest(
				"Звуковой файл или URL",
				"Путь из sound/ (напр. music/song.mp3) или http(s)-ссылка:",
				"",
				function(track)
					net.Start("cassette.record.response")
						net.WriteInt(itemID, 32)
						net.WriteString(name)
						net.WriteString(track)
					net.SendToServer()
				end
			)
		end
	)
end)
