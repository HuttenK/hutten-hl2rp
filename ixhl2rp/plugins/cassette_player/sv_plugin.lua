-- Server-side plugin for cassette_player.
-- Loaded explicitly by sh_plugin.lua via ix.util.Include("sv_plugin.lua").

local PLUGIN = PLUGIN

-- Net strings for the blank-cassette record flow.
util.AddNetworkString("cassette.record")           -- server → client: prompt dialog
util.AddNetworkString("cassette.record.response")  -- client → server: dialog result

-- Receive recording result from client.
net.Receive("cassette.record.response", function(len, client)
	if len > 20000 or (client.ixCassetteRecordAt or 0)>CurTime() then return end
 client.ixCassetteRecordAt=CurTime()+1
 local itemID   = net.ReadInt(32)
	local newName  = net.ReadString()
	local newTrack = net.ReadString()

	if #newName>160 or newName:find("[%c]") or not ix.BroadcastMedia.ValidSource(newTrack) then
  client:Notify("Недопустимое название или путь к звуку."); return
 end
 -- Item must exist.
	local item = ix.Item.instances[itemID]
	if not item then return end

	-- Prefix "sh_" is stripped by Item:Load, so uniqueID = "cassette_blank".
	if item.uniqueID != "cassette_blank" then
		client:Notify("Этот предмет не является пустой кассетой.")
		return
	end

	-- Re-recording is forbidden: track must still be blank.
	if item:GetData("track", "") != "" then
		client:Notify("Кассета уже записана. Перезапись невозможна.")
		return
	end

	-- The item must be in this player's inventory.
	if not client:HasItemByID(itemID) then return end

	-- Persist name and track on the item instance.
	item:SetData("customName", newName  != "" and newName  or nil)
	item:SetData("track",      newTrack != "" and newTrack or nil)

	-- SetData only queues Helix's fire-and-forget Async_SaveData (a data-column
	-- UPDATE). If that write doesn't commit before a restart — e.g. a non-graceful
	-- shutdown, or the item's DB row not existing yet right after it was created —
	-- the recorded track is lost and the cassette comes back blank/silent. Force a
	-- full immediate row save so the data column (customName + track) is written now.
	if item.Save then
		item:Save()
	end

	local display = newName != "" and newName or "Без названия"
	client:Notify("Кассета записана: " .. display)
end)

-- ─── Persistence across server restarts ──────────────────────────────────────
-- SaveData is called by Helix when the server shuts down / map changes.
-- We save every live ix_boombox: position, angles, loaded cassette info.

function PLUGIN:SaveData()
	local boomboxes = {}
	for _, ent in ipairs(ents.FindByClass("ix_boombox")) do
		if not IsValid(ent) then continue end
		boomboxes[#boomboxes + 1] = {
			pos              = ent:GetPos(),
			ang              = ent:GetAngles(),
			cassetteName     = ent:GetNetVar("boombox_cassette", ""),
			track            = ent:GetNetVar("boombox_sound",    ""),
			cassetteInstanceID = ent.cassetteInstanceID or nil,
			boomboxItemID    = ent.boomboxItemID    or nil,
		}
	end
	self:SetData(boomboxes)
end

-- LoadData is called after Helix has started the DB connection.
-- We recreate each saved boombox and, if it had a cassette, reload that item
-- from the database so the player can still eject and reclaim it.

function PLUGIN:LoadData()
 if self.boomboxesLoaded then return end
 self.boomboxesLoaded=true
 for _,v in ipairs(self:GetData() or {}) do
  local ent=ents.Create("ix_boombox")
  if IsValid(ent) then
   ent:SetPos(v.pos); ent:SetAngles(v.ang); ent:Spawn(); ent:Activate()
   ent.boomboxItemID=v.boomboxItemID
   ent.cassetteInstanceID=v.cassetteInstanceID
   ent.loadingItems=true
   local pending=0
   local function restore(id)
    if not id or ix.Item.instances[id] then return end
    pending=pending+1
    ix.Item:LoadInstanceByID(id,nil,function()
     pending=pending-1
     if IsValid(ent) and pending==0 then ent.loadingItems=false end
    end)
   end
   restore(v.boomboxItemID); restore(v.cassetteInstanceID)
   ent.loadingItems=pending>0
   if v.cassetteInstanceID then
    ent:SetNetVar("boombox_cassette",v.cassetteName or "Кассета")
    ent:SetNetVar("boombox_sound",ix.BroadcastMedia.ValidSource(v.track) and v.track or "")
    ent:SetNetVar("boombox_stime",CurTime())
   end
  end
 end
end
function PLUGIN:ShutDown() self.shuttingDown=true end
